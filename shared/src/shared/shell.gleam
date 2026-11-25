import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub type Model {
  Model(placeholder: String)
}

pub fn initial_model() -> Model {
  Model(placeholder: "Your AI recommendations will appear here...")
}

pub fn view(model: Model) -> Element(msg) {
  html.div([attribute.class("container")], [
    header(),
    html.main([], [stages(), recommendations(model)]),
    footer(),
  ])
}

fn header() -> Element(msg) {
  html.header([], [
    html.h1([], [html.text("🌱 Grow Assist")]),
    html.p([], [html.text("AI-powered grow tent optimization")]),
  ])
}

fn stages() -> Element(msg) {
  html.section([attribute.class("input-section")], [
    html.h2([], [html.text("Growth stage")]),
    html.p([], [
      html.text(
        "Seedling, vegetation, and flowering targets used for recommendations.",
      ),
    ]),
    html.div([attribute.class("growth-stage-selector")], [
      stage_card("🌱", "Seedling", "VPD 0.4-0.8 kPa", "68-77°F", "70-80% RH"),
      stage_card("🌿", "Vegetation", "VPD 0.8-1.2 kPa", "72-82°F", "55-70% RH"),
      stage_card("🌸", "Flowering", "VPD 1.2-1.6 kPa", "68-79°F", "40-50% RH"),
    ]),
  ])
}

fn stage_card(
  icon: String,
  name: String,
  vpd: String,
  temperature: String,
  humidity: String,
) -> Element(msg) {
  html.div([attribute.class("stage-card")], [
    html.div([attribute.class("stage-icon")], [html.text(icon)]),
    html.div([attribute.class("stage-name")], [html.text(name)]),
    html.div([attribute.class("stage-vpd")], [html.text(vpd)]),
    html.div([attribute.class("stage-details")], [
      html.span([], [html.text(temperature)]),
      html.span([], [html.text(humidity)]),
    ]),
  ])
}

fn recommendations(model: Model) -> Element(msg) {
  html.section([attribute.class("response-section")], [
    html.h2([], [html.text("AI Recommendations")]),
    html.div([attribute.class("response-container")], [
      html.p([attribute.class("placeholder")], [html.text(model.placeholder)]),
    ]),
  ])
}

fn footer() -> Element(msg) {
  html.footer([], [
    html.p([], [
      html.text("Optimized for seedling, vegetation, and flowering stages"),
    ]),
  ])
}
