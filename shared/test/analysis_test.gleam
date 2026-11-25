import gleam/list
import gleam/option.{None, Some}
import gleeunit
import shared/analysis

pub fn main() {
  gleeunit.main()
}

pub fn product_link_with_all_fields_test() {
  let assert Ok(product) =
    analysis.product_link(
      "LEVOIT Humidifier",
      "https://htgsupply.com/products/levoit-humidifier",
      Some("$40-50"),
    )
  assert analysis.name(product) == "LEVOIT Humidifier"
  assert analysis.url(product)
    == "https://htgsupply.com/products/levoit-humidifier"
  assert analysis.price_range(product) == Some("$40-50")
}

pub fn product_link_price_is_optional_test() {
  let assert Ok(product) =
    analysis.product_link(
      "AC Infinity Fan",
      "https://acinfinity.com/hvac-home-ventilation/inline-duct-fan-systems/",
      None,
    )
  assert analysis.price_range(product) == None
}

pub fn product_link_rejects_blank_name_test() {
  assert analysis.product_link("  ", "https://example.com/item", None)
    == Error(analysis.EmptyProductName)
}

pub fn product_link_rejects_blank_url_test() {
  assert analysis.product_link("Test Product", "  ", None)
    == Error(analysis.EmptyProductUrl)
}

pub fn product_link_rejects_malformed_urls_test() {
  assert analysis.product_link("Test Product", "not-a-url", None)
    == Error(analysis.InvalidProductUrl("not-a-url"))
  assert analysis.product_link(
      "Test Product",
      "ftp://invalid-protocol.com",
      None,
    )
    == Error(analysis.InvalidProductUrl("ftp://invalid-protocol.com"))
  assert analysis.product_link("Test Product", "www.missing-protocol.com", None)
    == Error(analysis.InvalidProductUrl("www.missing-protocol.com"))
  assert analysis.product_link("Test Product", "https://nodomain", None)
    == Error(analysis.InvalidProductUrl("https://nodomain"))
}

pub fn recommendation_with_product_test() {
  let assert Ok(product) =
    analysis.product_link(
      "LEVOIT Humidifier",
      "https://htgsupply.com/products/levoit-humidifier",
      Some("$40-50"),
    )
  let assert Ok(recommendation) =
    analysis.recommendation(
      "Add a Humidifier",
      "Increase humidity levels to reach the optimal range",
      analysis.High,
      Some(product),
    )
  assert analysis.title(recommendation) == "Add a Humidifier"
  assert analysis.priority(recommendation) == analysis.High
  let assert Some(linked) = analysis.product(recommendation)
  assert analysis.name(linked) == "LEVOIT Humidifier"
}

pub fn recommendation_without_product_test() {
  let assert Ok(recommendation) =
    analysis.recommendation(
      "Adjust Plant Spacing",
      "Increase airflow by spacing plants further apart",
      analysis.Medium,
      None,
    )
  assert analysis.product(recommendation) == None
  assert analysis.priority(recommendation) == analysis.Medium
}

pub fn recommendation_priorities_test() {
  let assert Ok(low) =
    analysis.recommendation(
      "Lower the light",
      "Give seedlings room.",
      analysis.Low,
      None,
    )
  assert analysis.priority(low) == analysis.Low
}

pub fn recommendation_rejects_blank_title_test() {
  assert analysis.recommendation("", "A description", analysis.Low, None)
    == Error(analysis.EmptyTitle)
}

pub fn recommendation_rejects_blank_description_test() {
  assert analysis.recommendation("A title", " ", analysis.Low, None)
    == Error(analysis.EmptyDescription)
}

pub fn analysis_response_accepts_two_recommendations_test() {
  let response = sample(2)
  assert analysis.summary(response)
    == "Your tent is a little too humid for flowering."
  assert list.length(analysis.recommendations(response)) == 2
  let assert [first, second] = analysis.recommendations(response)
  assert analysis.product(first) != None
  assert analysis.product(second) == None
}

pub fn analysis_response_accepts_three_recommendations_test() {
  let response = sample(3)
  assert list.length(analysis.recommendations(response)) == 3
}

pub fn analysis_response_rejects_blank_summary_test() {
  let assert Ok(with_product) = with_link("With product")
  let assert Ok(without_product) = plain("Without product")
  assert analysis.analysis_response("  ", [with_product, without_product])
    == Error(analysis.EmptySummary)
}

pub fn analysis_response_rejects_one_recommendation_test() {
  let assert Ok(with_product) = with_link("Only one")
  assert analysis.analysis_response("Summary", [with_product])
    == Error(analysis.RecommendationCount(1))
}

pub fn analysis_response_rejects_four_recommendations_test() {
  let assert Ok(with_product) = with_link("First")
  let assert Ok(extra) = plain("Extra")
  assert analysis.analysis_response("Summary", [
      with_product,
      extra,
      extra,
      extra,
    ])
    == Error(analysis.RecommendationCount(4))
}

pub fn analysis_response_requires_a_product_link_test() {
  let assert Ok(first) = plain("First")
  let assert Ok(second) = plain("Second")
  assert analysis.analysis_response("Summary", [first, second])
    == Error(analysis.MissingProductLink)
}

pub fn analysis_response_accepts_multiple_product_links_test() {
  let assert Ok(first) = with_link("First")
  let assert Ok(second) = with_link("Second")
  let assert Ok(response) =
    analysis.analysis_response("Summary", [first, second])
  assert list.length(analysis.recommendations(response)) == 2
}

fn sample(count: Int) -> analysis.AnalysisResponse {
  let assert Ok(with_product) = with_link("Add a humidifier")
  let assert Ok(second) = plain("Lower the temperature")
  let assert Ok(third) = plain("Space the plants")
  let recommendations = case count {
    2 -> [with_product, second]
    _ -> [with_product, second, third]
  }
  let assert Ok(response) =
    analysis.analysis_response(
      "Your tent is a little too humid for flowering.",
      recommendations,
    )
  response
}

fn with_link(
  title: String,
) -> Result(analysis.Recommendation, analysis.AnalysisError) {
  let assert Ok(product) =
    analysis.product_link(
      "HYDRONE 5 Dehumidifier",
      "https://acinfinity.com/hydroponics-growers/hydrone-5",
      Some("$399-499"),
    )
  analysis.recommendation(
    title,
    "This matches the humidity problem.",
    analysis.High,
    Some(product),
  )
}

fn plain(
  title: String,
) -> Result(analysis.Recommendation, analysis.AnalysisError) {
  analysis.recommendation(
    title,
    "A step the grower can take today.",
    analysis.Medium,
    None,
  )
}
