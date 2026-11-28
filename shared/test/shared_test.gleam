import gleam/option.{None, Some}
import gleam/string
import gleeunit
import lustre/element
import shared/analysis
import shared/prompt
import shared/shell

pub fn main() {
  gleeunit.main()
}

pub fn fill_inserts_catalog_test() {
  let assert Ok(prompt) =
    prompt.fill("Advice:\n{product_links}\nThanks.", "CLOUDLAB 844")
  assert string.contains(does: prompt, contain: "CLOUDLAB 844")
  assert !string.contains(does: prompt, contain: "{product_links}")
}

pub fn fill_requires_placeholder_test() {
  assert prompt.fill("no marker", "catalog") == Error(prompt.MissingPlaceholder)
}

pub fn shell_renders_grow_assist_test() {
  let html = shell.view(shell.initial_model()) |> element.to_string
  assert string.contains(does: html, contain: "Grow Assist")
  assert string.contains(
    does: html,
    contain: "Your AI recommendations will appear here...",
  )
  assert string.contains(does: html, contain: "0.4-0.8 kPa")
  assert string.contains(does: html, contain: "0.8-1.2 kPa")
  assert string.contains(does: html, contain: "1.2-1.6 kPa")
  assert string.contains(does: html, contain: "Analyze")
  assert string.contains(does: html, contain: "API key")
  assert string.contains(does: html, contain: "Readings")
  assert string.contains(does: html, contain: "Upload a CSV")
  assert string.contains(does: html, contain: "readings-file")
}

pub fn shell_shows_a_recommendation_and_product_link_test() {
  let assert Ok(product) =
    analysis.product_link(
      "HYDRONE 5 Dehumidifier",
      "https://acinfinity.com/hydroponics-growers/hydrone-5",
      Some("$399-499"),
    )
  let assert Ok(first) =
    analysis.recommendation(
      "Lower the humidity",
      "Run a dehumidifier.",
      analysis.High,
      Some(product),
    )
  let assert Ok(second) =
    analysis.recommendation(
      "Increase airflow",
      "Point a clip fan across the canopy.",
      analysis.Medium,
      None,
    )
  let assert Ok(response) =
    analysis.analysis_response("The tent is too humid.", [first, second])
  let model =
    shell.apply(shell.initial_model(), shell.AnalyzeFinished(Ok(response)))
  let html = shell.view(model) |> element.to_string
  assert string.contains(does: html, contain: "The tent is too humid.")
  assert string.contains(does: html, contain: "Lower the humidity")
  assert string.contains(does: html, contain: "High Impact")
  assert string.contains(
    does: html,
    contain: "https://acinfinity.com/hydroponics-growers/hydrone-5",
  )
  assert string.contains(does: html, contain: "View product")
}

pub fn analyze_requires_a_stage_readings_and_key_test() {
  let model = shell.apply(shell.initial_model(), shell.AnalyzeClicked)
  let assert shell.Problem(message) = model.status
  assert string.contains(does: message, contain: "growth stage")

  let model =
    shell.Model(
      ..shell.initial_model(),
      stage: Some(shell.Flowering),
      readings: "82 F",
      api_key: "secret",
    )
  let model = shell.apply(model, shell.AnalyzeClicked)
  assert model.status == shell.Loading
  assert model.api_key == "secret"
}

pub fn analyze_accepts_a_csv_without_pasted_readings_test() {
  let model =
    shell.Model(
      ..shell.initial_model(),
      stage: Some(shell.Flowering),
      api_key: "secret",
    )
  let blocked = shell.apply(model, shell.AnalyzeClicked)
  let assert shell.Problem(message) = blocked.status
  assert string.contains(does: message, contain: "Paste a few readings.")

  let model = shell.apply(model, shell.CsvChosen("tent-readings.csv"))
  let html = shell.view(model) |> element.to_string
  assert string.contains(does: html, contain: "tent-readings.csv")
  let model = shell.apply(model, shell.AnalyzeClicked)
  assert model.status == shell.Loading
}
