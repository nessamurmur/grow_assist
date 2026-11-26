import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import qcheck
import shared/analysis
import shared/analysis_json

pub fn main() {
  gleeunit.main()
}

const fixture =
  "{
  \"summary\": \"The tent is too humid for flowering.\",
  \"recommendations\": [
    {
      \"title\": \"Lower the humidity\",
      \"description\": \"Run a dehumidifier so flowering stays near 40-50% RH.\",
      \"priority\": \"High Impact\",
      \"product\": {
        \"name\": \"HYDRONE 5 Dehumidifier\",
        \"url\": \"https://acinfinity.com/hydroponics-growers/hydrone-5\",
        \"price_range\": \"$399-499\"
      }
    },
    {
      \"title\": \"Increase airflow\",
      \"description\": \"Point a clip fan across the canopy.\",
      \"priority\": \"medium\",
      \"product\": null
    }
  ]
}"

pub fn fixture_decodes_summary_priorities_and_product_test() {
  let assert Ok(response) = analysis_json.decode(fixture)
  assert analysis.summary(response) == "The tent is too humid for flowering."
  let assert [first, second] = analysis.recommendations(response)
  assert analysis.priority(first) == analysis.High
  assert analysis.priority(second) == analysis.Medium
  let assert Some(product) = analysis.product(first)
  assert analysis.url(product)
    == "https://acinfinity.com/hydroponics-growers/hydrone-5"
  assert analysis.price_range(product) == Some("$399-499")
  assert analysis.product(second) == None
}

pub fn blank_summary_is_rejected_test() {
  let assert Error(_) =
    analysis_json.decode(
      "{\"summary\":\"  \",\"recommendations\":[{\"title\":\"A\",\"description\":\"B\",\"priority\":\"low\"},{\"title\":\"C\",\"description\":\"D\",\"priority\":\"low\",\"product\":{\"name\":\"Fan\",\"url\":\"https://example.com/fan\"}}]}",
    )
}

pub fn response_without_a_product_link_is_rejected_test() {
  let assert Error(_) =
    analysis_json.decode(
      "{\"summary\":\"Humid.\",\"recommendations\":[{\"title\":\"A\",\"description\":\"B\",\"priority\":\"low\"},{\"title\":\"C\",\"description\":\"D\",\"priority\":\"low\"}]}",
    )
}

pub fn any_text_decodes_only_when_the_rules_hold_test() {
  use text <- qcheck.given(qcheck.string())
  case analysis_json.decode(text) {
    Error(_) -> Nil
    Ok(response) -> assert_rules(response)
  }
}

pub fn built_responses_roundtrip_test() {
  let word =
    qcheck.string_from(qcheck.lowercase_ascii_codepoint())
    |> qcheck.map(fn(value) { "n" <> value })
  let priority =
    qcheck.from_generators(qcheck.constant(analysis.High), [
      qcheck.constant(analysis.Medium),
      qcheck.constant(analysis.Low),
    ])
  let count = qcheck.bounded_int(2, 3)
  use #(summary, title, host, priority, count) <- qcheck.given(qcheck.tuple5(
    word,
    word,
    word,
    priority,
    count,
  ))
  let response = built(summary, title, host, priority, count)
  let assert Ok(again) = analysis_json.decode(analysis_json.encode(response))
  assert analysis.summary(again) == summary
  assert list.length(analysis.recommendations(again)) == count
  assert_rules(again)
  let assert [first, ..] = analysis.recommendations(again)
  let assert Some(product) = analysis.product(first)
  assert analysis.url(product) == "https://" <> host <> ".example/item"
  assert analysis.priority(first) == priority
}

fn assert_rules(response: analysis.AnalysisResponse) -> Nil {
  let count = list.length(analysis.recommendations(response))
  assert count == 2 || count == 3
  assert string_nonempty(analysis.summary(response))
  assert list.any(analysis.recommendations(response), fn(recommendation) {
    analysis.product(recommendation) != None
  })
}

fn string_nonempty(value: String) -> Bool {
  string.trim(value) != ""
}

fn built(
  summary: String,
  title: String,
  host: String,
  priority: analysis.Priority,
  count: Int,
) -> analysis.AnalysisResponse {
  let assert Ok(product) =
    analysis.product_link(
      title,
      "https://" <> host <> ".example/item",
      Some("$10"),
    )
  let assert Ok(with_product) =
    analysis.recommendation(title, title <> " why", priority, Some(product))
  let assert Ok(plain) =
    analysis.recommendation(title <> " two", title <> " how", priority, None)
  let recommendations = case count {
    2 -> [with_product, plain]
    _ -> [
      with_product,
      plain,
      {
        let assert Ok(third) =
          analysis.recommendation(
            title <> " three",
            title <> " step",
            priority,
            None,
          )
        third
      },
    ]
  }
  let assert Ok(response) = analysis.analysis_response(summary, recommendations)
  response
}
