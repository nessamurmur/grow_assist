//// Gleam side of the single ReqLLM wrapper. Elixir owns the atom-key option
//// map and the ReqLLM call. This module decodes the returned object.

import gleam/dynamic.{type Dynamic}
import shared/analysis.{type AnalysisResponse}
import shared/analysis_json

pub fn recommend(
  system: String,
  user: String,
  api_key: String,
) -> Result(AnalysisResponse, String) {
  case external_analyze(api_key, system, user) {
    Error(reason) -> Error(reason)
    Ok(data) -> analysis_json.decode_dynamic(data)
  }
}

pub fn recommend_with(
  system: String,
  user: String,
  api_key: String,
  generator: fn(String) -> String,
) -> Result(AnalysisResponse, String) {
  case external_analyze_with(api_key, system, user, generator) {
    Error(reason) -> Error(reason)
    Ok(data) -> analysis_json.decode_dynamic(data)
  }
}

pub fn capture_logs(run: fn() -> a) -> #(a, String) {
  external_capture(run)
}

@external(erlang, "Elixir.GrowAssist.ReqLlm", "analyze")
fn external_analyze(
  api_key: String,
  system: String,
  user: String,
) -> Result(Dynamic, String)

@external(erlang, "Elixir.GrowAssist.ReqLlm", "analyze_with")
fn external_analyze_with(
  api_key: String,
  system: String,
  user: String,
  generator: fn(String) -> String,
) -> Result(Dynamic, String)

@external(erlang, "Elixir.GrowAssist.ReqLlm", "preview")
pub fn preview(
  api_key: String,
  system: String,
  user: String,
) -> Result(Dynamic, String)

@external(erlang, "Elixir.GrowAssist.ReqLlm", "raise_for_test")
pub fn raise_for_test() -> Result(Dynamic, String)

@external(erlang, "Elixir.GrowAssist.ReqLlm", "schema_compiles")
pub fn schema_compiles() -> Result(String, String)

@external(erlang, "Elixir.GrowAssist.ReqLlm", "accept_model_text")
pub fn accept_model_text(
  finish: String,
  text: String,
) -> Result(Dynamic, String)

@external(erlang, "Elixir.GrowAssist.ReqLlm", "capture")
fn external_capture(run: fn() -> a) -> #(a, String)
