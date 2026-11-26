//// JSON shape for an analysis response. The server decodes ReqLLM's object
//// with these decoders, and the browser decodes the same shape from `POST
//// /analyze`.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/string
import shared/analysis.{type AnalysisResponse, type Recommendation}

const shape_error = "The model response did not match the analysis shape."

pub fn decoder() -> decode.Decoder(AnalysisResponse) {
  use summary <- decode.field("summary", decode.string)
  use recommendations <- decode.field(
    "recommendations",
    decode.list(recommendation_decoder()),
  )
  case analysis.analysis_response(summary, recommendations) {
    Ok(response) -> decode.success(response)
    Error(_) -> decode.failure(unused_response(), shape_error)
  }
}

pub fn decode(text: String) -> Result(AnalysisResponse, String) {
  case json.parse(text, decoder()) {
    Ok(response) -> Ok(response)
    Error(_) -> Error(shape_error)
  }
}

pub fn decode_dynamic(data: Dynamic) -> Result(AnalysisResponse, String) {
  case decode.run(data, decoder()) {
    Ok(response) -> Ok(response)
    Error(_) -> Error(shape_error)
  }
}

pub fn encode(response: AnalysisResponse) -> String {
  json.to_string(to_json(response))
}

pub fn to_json(response: AnalysisResponse) -> json.Json {
  json.object([
    #("summary", json.string(analysis.summary(response))),
    #(
      "recommendations",
      json.array(analysis.recommendations(response), recommendation_json),
    ),
  ])
}

fn recommendation_decoder() -> decode.Decoder(Recommendation) {
  use title <- decode.field("title", decode.string)
  use description <- decode.field("description", decode.string)
  use priority_raw <- decode.field("priority", decode.string)
  use product <- decode.optional_field(
    "product",
    None,
    decode.optional(product_decoder()),
  )
  case priority(priority_raw) {
    Error(Nil) -> decode.failure(unused_recommendation(), "Priority")
    Ok(priority) ->
      case analysis.recommendation(title, description, priority, product) {
        Ok(recommendation) -> decode.success(recommendation)
        Error(_) -> decode.failure(unused_recommendation(), "Recommendation")
      }
  }
}

fn product_decoder() -> decode.Decoder(analysis.ProductLink) {
  use name <- decode.field("name", decode.string)
  use url <- decode.field("url", decode.string)
  use price <- decode.optional_field(
    "price_range",
    None,
    decode.optional(decode.string),
  )
  case analysis.product_link(name, url, blank_to_none(price)) {
    Ok(product) -> decode.success(product)
    Error(_) -> decode.failure(unused_product(), "ProductLink")
  }
}

fn priority(raw: String) -> Result(analysis.Priority, Nil) {
  case string.lowercase(string.trim(raw)) {
    "high" | "high impact" -> Ok(analysis.High)
    "medium" | "medium impact" -> Ok(analysis.Medium)
    "low" | "low impact" -> Ok(analysis.Low)
    _ -> Error(Nil)
  }
}

fn blank_to_none(price: Option(String)) -> Option(String) {
  case price {
    Some(value) ->
      case string.trim(value) == "" {
        True -> None
        False -> Some(value)
      }
    None -> None
  }
}

fn recommendation_json(recommendation: Recommendation) -> json.Json {
  json.object([
    #("title", json.string(analysis.title(recommendation))),
    #("description", json.string(analysis.description(recommendation))),
    #("priority", json.string(priority_wire(analysis.priority(recommendation)))),
    #("product", json.nullable(analysis.product(recommendation), product_json)),
  ])
}

fn product_json(product: analysis.ProductLink) -> json.Json {
  let price = case analysis.price_range(product) {
    Some(value) -> json.string(value)
    None -> json.null()
  }
  json.object([
    #("name", json.string(analysis.name(product))),
    #("url", json.string(analysis.url(product))),
    #("price_range", price),
  ])
}

fn priority_wire(priority: analysis.Priority) -> String {
  case priority {
    analysis.High -> "high"
    analysis.Medium -> "medium"
    analysis.Low -> "low"
  }
}

fn unused_product() -> analysis.ProductLink {
  let assert Ok(product) =
    analysis.product_link("unused", "https://example.com/unused", None)
  product
}

fn unused_recommendation() -> Recommendation {
  let assert Ok(recommendation) =
    analysis.recommendation("unused", "unused", analysis.Low, None)
  recommendation
}

fn unused_response() -> AnalysisResponse {
  let assert Ok(product) =
    analysis.product_link("unused", "https://example.com/u", None)
  let assert Ok(first) =
    analysis.recommendation("unused", "unused", analysis.Low, Some(product))
  let assert Ok(second) =
    analysis.recommendation("unused two", "unused", analysis.Low, None)
  let assert Ok(response) =
    analysis.analysis_response("unused", [first, second])
  response
}
