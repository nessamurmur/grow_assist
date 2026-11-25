//// Analysis shape carried over from the previous app: a summary, two or three
//// recommendations with priorities, and at least one product link.
////
//// Build values with `product_link`, `recommendation`, and `analysis_response`.
//// Those functions reject a blank required field, a bad product URL, the wrong
//// number of recommendations, and a response with no product link.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub type Priority {
  High
  Medium
  Low
}

pub opaque type ProductLink {
  ProductLink(name: String, url: String, price_range: Option(String))
}

pub opaque type Recommendation {
  Recommendation(
    title: String,
    description: String,
    priority: Priority,
    product: Option(ProductLink),
  )
}

pub opaque type AnalysisResponse {
  AnalysisResponse(summary: String, recommendations: List(Recommendation))
}

pub type AnalysisError {
  EmptyProductName
  EmptyProductUrl
  InvalidProductUrl(String)
  EmptyTitle
  EmptyDescription
  EmptySummary
  RecommendationCount(Int)
  MissingProductLink
}

pub fn product_link(
  name: String,
  url: String,
  price_range: Option(String),
) -> Result(ProductLink, AnalysisError) {
  case string.trim(name) == "" {
    True -> Error(EmptyProductName)
    False ->
      case string.trim(url) == "" {
        True -> Error(EmptyProductUrl)
        False ->
          case valid_product_url(url) {
            True -> Ok(ProductLink(name:, url:, price_range:))
            False -> Error(InvalidProductUrl(url))
          }
      }
  }
}

pub fn recommendation(
  title: String,
  description: String,
  priority: Priority,
  product: Option(ProductLink),
) -> Result(Recommendation, AnalysisError) {
  case string.trim(title) == "" {
    True -> Error(EmptyTitle)
    False ->
      case string.trim(description) == "" {
        True -> Error(EmptyDescription)
        False -> Ok(Recommendation(title:, description:, priority:, product:))
      }
  }
}

pub fn analysis_response(
  summary: String,
  recommendations: List(Recommendation),
) -> Result(AnalysisResponse, AnalysisError) {
  case string.trim(summary) == "" {
    True -> Error(EmptySummary)
    False -> {
      let count = list.length(recommendations)
      case count >= 2 && count <= 3 {
        False -> Error(RecommendationCount(count))
        True ->
          case list.any(recommendations, has_product) {
            False -> Error(MissingProductLink)
            True -> Ok(AnalysisResponse(summary:, recommendations:))
          }
      }
    }
  }
}

pub fn name(product: ProductLink) -> String {
  product.name
}

pub fn url(product: ProductLink) -> String {
  product.url
}

pub fn price_range(product: ProductLink) -> Option(String) {
  product.price_range
}

pub fn title(recommendation: Recommendation) -> String {
  recommendation.title
}

pub fn description(recommendation: Recommendation) -> String {
  recommendation.description
}

pub fn priority(recommendation: Recommendation) -> Priority {
  recommendation.priority
}

pub fn product(recommendation: Recommendation) -> Option(ProductLink) {
  recommendation.product
}

pub fn summary(response: AnalysisResponse) -> String {
  response.summary
}

pub fn recommendations(response: AnalysisResponse) -> List(Recommendation) {
  response.recommendations
}

fn valid_product_url(url: String) -> Bool {
  let has_scheme =
    string.starts_with(url, "https://") || string.starts_with(url, "http://")
  has_scheme && string.contains(does: url, contain: ".")
}

fn has_product(recommendation: Recommendation) -> Bool {
  case recommendation.product {
    Some(_) -> True
    None -> False
  }
}
