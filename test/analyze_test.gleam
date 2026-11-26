import gleam/http
import gleam/json
import gleam/string
import gleeunit
import wisp
import wisp/simulate

import grow_assist/req_llm
import grow_assist/router
import shared/analysis_json

const canary = "grow-assist-canary-7c1e9b2a"

const fixture =
  "{
  \"summary\": \"The tent is too humid for flowering.\",
  \"recommendations\": [
    {
      \"title\": \"Lower the humidity\",
      \"description\": \"Run a dehumidifier so flowering stays near 40-50% RH.\",
      \"priority\": \"high\",
      \"product\": {
        \"name\": \"HYDRONE 5 Dehumidifier\",
        \"url\": \"https://acinfinity.com/hydroponics-growers/hydrone-5\",
        \"price_range\": \"$399-499\"
      }
    },
    {
      \"title\": \"Increase airflow\",
      \"description\": \"Point a clip fan across the canopy.\",
      \"priority\": \"medium\"
    }
  ]
}"

pub fn main() {
  wisp.configure_logger()
  gleeunit.main()
}

pub fn post_analyze_returns_a_recommendation_test() {
  let response =
    router.handle(
      post_analyze("test-key", "82 F, 68% RH"),
      fn(system, user, api_key) {
        assert string.contains(system, "beginner-friendly")
        assert string.contains(user, "Flowering")
        assert string.contains(user, "82 F, 68% RH")
        assert api_key == "test-key"
        analysis_json.decode(fixture)
      },
    )
  assert response.status == 200
  let assert wisp.Text(body) = response.body
  assert string.contains(body, "The tent is too humid for flowering.")
  assert string.contains(
    body,
    "https://acinfinity.com/hydroponics-growers/hydrone-5",
  )
  assert !string.contains(body, "test-key")
}

pub fn post_analyze_rejects_a_blank_key_test() {
  let response =
    router.handle(post_analyze("  ", "82 F"), fn(_system, _user, _api_key) {
      panic as "the key was blank"
    })
  assert response.status == 400
  let assert wisp.Text(body) = response.body
  assert string.contains(body, "API key")
}

pub fn canary_key_is_absent_from_logs_and_the_response_test() {
  let #(response, logs) =
    req_llm.capture_logs(fn() {
      router.handle(
        post_analyze(canary, "82 F, 68% RH"),
        fn(_system, _user, api_key) {
          Error("provider failed with " <> api_key)
        },
      )
    })
  assert response.status == 502
  let assert wisp.Text(body) = response.body
  assert !string.contains(body, canary)
  assert string.contains(body, "[redacted]")
  assert !string.contains(logs, canary)
}

fn post_analyze(api_key: String, readings: String) -> wisp.Request {
  simulate.request(http.Post, "/analyze")
  |> simulate.json_body(
    json.object([
      #("stage", json.string("flowering")),
      #("readings", json.string(readings)),
      #("api_key", json.string(api_key)),
    ]),
  )
}
