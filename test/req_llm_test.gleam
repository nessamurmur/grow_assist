import gleam/dynamic/decode
import gleam/list
import gleam/string
import gleeunit

import grow_assist/req_llm
import shared/analysis

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
      \"priority\": \"low\"
    }
  ]
}"

pub fn main() {
  gleeunit.main()
}

pub fn raise_becomes_an_error_without_a_crash_test() {
  let assert Error(message) = req_llm.raise_for_test()
  assert string.contains(message, "provider exploded")
  assert string.length(message) > 0
}

pub fn option_map_uses_atom_keys_for_hosted_ollama_test() {
  let assert Ok(data) = req_llm.preview(canary, "system text", "user text")
  let decoder = {
    use keys <- decode.field("keys", decode.list(decode.string))
    use model <- decode.field("model", decode.string)
    use provider <- decode.field("provider", decode.string)
    use backend <- decode.field("backend", decode.string)
    use base_url <- decode.field("base_url", decode.string)
    use key_matches <- decode.field("key_matches", decode.bool)
    use system_matches <- decode.field("system_matches", decode.bool)
    use user_matches <- decode.field("user_matches", decode.bool)
    use max_tokens <- decode.field("max_tokens", decode.int)
    decode.success(#(
      keys,
      model,
      provider,
      backend,
      base_url,
      key_matches,
      system_matches,
      user_matches,
      max_tokens,
    ))
  }
  let assert Ok(#(
    keys,
    model,
    provider,
    backend,
    base_url,
    key_matches,
    system_matches,
    user_matches,
    max_tokens,
  )) = decode.run(data, decoder)
  assert model == "inkling-2-small"
  assert max_tokens == 4000
  assert provider == "openai"
  assert backend == "ollama"
  assert base_url == "https://ollama.com/v1"
  assert key_matches
  assert system_matches
  assert user_matches
  assert list.contains(keys, "api_key")
  assert list.contains(keys, "model")
  assert list.contains(keys, "provider")
  assert list.contains(keys, "backend")
  assert list.contains(keys, "base_url")
  assert list.contains(keys, "system_prompt")
  assert !list.contains(keys, canary)
}

pub fn mocked_object_decodes_to_the_analysis_type_test() {
  let #(result, logs) =
    req_llm.capture_logs(fn() {
      req_llm.recommend_with("system", "user", canary, fn(_options) { fixture })
    })
  let assert Ok(response) = result
  assert analysis.summary(response) == "The tent is too humid for flowering."
  assert list.length(analysis.recommendations(response)) == 2
  assert !string.contains(logs, canary)
}

pub fn invalid_model_json_is_an_error_test() {
  let assert Error(_) =
    req_llm.recommend_with("system", "user", canary, fn(_options) { "not json" })
}

pub fn a_raise_that_includes_the_key_is_redacted_test() {
  let #(result, logs) =
    req_llm.capture_logs(fn() {
      req_llm.recommend_with("system", "user", canary, fn(_options) {
        let message = "boom " <> canary
        panic as message
      })
    })
  let assert Error(message) = result
  assert !string.contains(message, canary)
  assert !string.contains(logs, canary)
}

pub fn object_schema_compiles_test() {
  let assert Ok(schema) = req_llm.schema_compiles()
  assert string.contains(schema, "minItems")
  assert string.contains(schema, "maxItems")
  assert string.contains(schema, "\"title\"")
  assert string.contains(schema, "\"priority\"")
  assert string.contains(schema, "high impact")
  assert string.contains(schema, "\"url\"")
}

const loose_object =
  "{\"summary\":\"ok\",\"recommendations\":[{\"foo\":\"bar\"}]}"

pub fn loose_object_falls_back_to_json_mode_test() {
  let assert Ok(response) =
    req_llm.recommend_with("system", "user", canary, fn(phase) {
      case phase {
        "object" -> loose_object
        _ -> fixture
      }
    })
  assert analysis.summary(response) == "The tent is too humid for flowering."
  assert list.length(analysis.recommendations(response)) == 2
}

pub fn loose_object_and_bad_fallback_is_an_error_test() {
  let assert Error(message) =
    req_llm.recommend_with("system", "user", canary, fn(phase) {
      case phase {
        "object" -> loose_object
        _ -> "{\"summary\":\"ok\",\"recommendations\":[{\"foo\":\"bar\"}]}"
      }
    })
  assert message == "The model response did not match the analysis shape."
}

pub fn length_finish_is_not_decoded_test() {
  let truncated = "{\"summary\": \"The tent is too humid"
  let assert Error(message) = req_llm.accept_model_text("length", truncated)
  assert message == "model ran out of tokens"
}

pub fn empty_content_is_not_decoded_test() {
  let assert Error(message) = req_llm.accept_model_text("stop", "  \n")
  assert message == "model ran out of tokens"
}
