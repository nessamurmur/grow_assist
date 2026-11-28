import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import shared/analysis.{type AnalysisResponse}

pub type Stage {
  Seedling
  Vegetation
  Flowering
}

pub type Status {
  Waiting
  Loading
  Problem(String)
  Ready(AnalysisResponse)
}

pub type Model {
  Model(stage: Option(Stage), readings: String, api_key: String, status: Status)
}

pub type Msg {
  StageChosen(Stage)
  ReadingsChanged(String)
  KeyChanged(String)
  AnalyzeClicked
  AnalyzeFinished(Result(AnalysisResponse, String))
}

pub fn initial_model() -> Model {
  Model(stage: None, readings: "", api_key: "", status: Waiting)
}

pub fn stage_wire(stage: Stage) -> String {
  case stage {
    Seedling -> "seedling"
    Vegetation -> "vegetation"
    Flowering -> "flowering"
  }
}

/// State change for a message. The browser sends the request only when this
/// moves the status to `Loading`.
pub fn apply(model: Model, msg: Msg) -> Model {
  case msg {
    StageChosen(stage) -> Model(..model, stage: Some(stage))
    ReadingsChanged(readings) -> Model(..model, readings:)
    KeyChanged(api_key) -> Model(..model, api_key:)
    AnalyzeClicked ->
      case ready(model) {
        Error(message) -> Model(..model, status: Problem(message))
        Ok(_) -> Model(..model, status: Loading)
      }
    AnalyzeFinished(Ok(response)) -> Model(..model, status: Ready(response))
    AnalyzeFinished(Error(message)) -> Model(..model, status: Problem(message))
  }
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("container")], [
    header(),
    html.main([], [form(model), recommendations(model)]),
    footer(),
  ])
}

fn missing_readings() -> String {
  "Paste a few readings."
}

fn waiting_copy() -> Element(Msg) {
  html.p([attribute.class("placeholder")], [
    html.text("Your AI recommendations will appear here..."),
  ])
}

fn readings_group(model: Model) -> Element(Msg) {
  let error = readings_error(model)
  html.div([attribute.class("form-group")], [
    html.label([attribute.for("readings")], [html.text("Readings")]),
    html.textarea(readings_attributes(model, error), ""),
    readings_message(error),
  ])
}

fn readings_error(model: Model) -> Option(String) {
  case model.status {
    Problem(message) ->
      case message == missing_readings() {
        True -> Some(message)
        False -> None
      }
    _ -> None
  }
}

fn readings_attributes(
  model: Model,
  error: Option(String),
) -> List(attribute.Attribute(Msg)) {
  let base = [
    attribute.id("readings"),
    attribute.placeholder(
      "Paste a few readings, for example: 82 F, 68% RH, VPD 1.4",
    ),
    attribute.rows(8),
    attribute.value(model.readings),
    event.on_input(ReadingsChanged),
  ]
  case error {
    None -> base
    Some(_) -> [
      attribute.attribute("aria-invalid", "true"),
      attribute.attribute("aria-describedby", "readings-error"),
      ..base
    ]
  }
}

fn readings_message(error: Option(String)) -> Element(Msg) {
  case error {
    None -> html.text("")
    Some(message) ->
      html.p([attribute.id("readings-error"), attribute.class("field-error")], [
        html.text(message),
      ])
  }
}

fn ready(model: Model) -> Result(Nil, String) {
  case model.stage {
    None -> Error("Choose a growth stage.")
    Some(_) ->
      case string.trim(model.readings) == "" {
        True -> Error(missing_readings())
        False ->
          case string.trim(model.api_key) == "" {
            True -> Error("Paste an API key.")
            False -> Ok(Nil)
          }
      }
  }
}

fn header() -> Element(Msg) {
  html.header([], [
    html.h1([], [html.text("🌱 Grow Assist")]),
    html.p([], [html.text("AI-powered grow tent optimization")]),
  ])
}

fn form(model: Model) -> Element(Msg) {
  html.section([attribute.class("input-section")], [
    html.h2([], [html.text("Growth stage")]),
    html.p([], [
      html.text(
        "Seedling, vegetation, and flowering targets used for recommendations.",
      ),
    ]),
    html.div([attribute.class("growth-stage-selector")], [
      stage_card(
        model,
        Seedling,
        "🌱",
        "Seedling",
        "VPD 0.4-0.8 kPa",
        "68-77°F",
        "70-80% RH",
      ),
      stage_card(
        model,
        Vegetation,
        "🌿",
        "Vegetation",
        "VPD 0.8-1.2 kPa",
        "72-82°F",
        "55-70% RH",
      ),
      stage_card(
        model,
        Flowering,
        "🌸",
        "Flowering",
        "VPD 1.2-1.6 kPa",
        "68-79°F",
        "40-50% RH",
      ),
    ]),
    readings_group(model),
    html.div([attribute.class("form-group")], [
      html.label([attribute.for("api-key")], [html.text("API key")]),
      html.input([
        attribute.id("api-key"),
        attribute.type_("password"),
        attribute.autocomplete("off"),
        attribute.placeholder("Ollama API key"),
        attribute.value(model.api_key),
        attribute.attribute("spellcheck", "false"),
        event.on_input(KeyChanged),
      ]),
      html.small([], [
        html.text(
          "The key stays in this browser and is sent only when you analyze.",
        ),
      ]),
    ]),
    html.button(
      [
        attribute.class("btn-primary"),
        attribute.type_("button"),
        attribute.disabled(model.status == Loading),
        event.on_click(AnalyzeClicked),
      ],
      [
        html.text(case model.status {
          Loading -> "Analyzing…"
          _ -> "Analyze"
        }),
      ],
    ),
  ])
}

fn stage_card(
  model: Model,
  stage: Stage,
  icon: String,
  name: String,
  vpd: String,
  temperature: String,
  humidity: String,
) -> Element(Msg) {
  html.button(
    [
      attribute.class("stage-card"),
      attribute.type_("button"),
      attribute.data("selected", selected(model.stage, stage)),
      event.on_click(StageChosen(stage)),
    ],
    [
      html.div([attribute.class("stage-icon")], [html.text(icon)]),
      html.div([attribute.class("stage-name")], [html.text(name)]),
      html.div([attribute.class("stage-vpd")], [html.text(vpd)]),
      html.div([attribute.class("stage-details")], [
        html.span([], [html.text(temperature)]),
        html.span([], [html.text(humidity)]),
      ]),
    ],
  )
}

fn selected(current: Option(Stage), stage: Stage) -> String {
  case current {
    Some(chosen) if chosen == stage -> "true"
    _ -> "false"
  }
}

fn recommendations(model: Model) -> Element(Msg) {
  html.section([attribute.class("response-section")], [
    html.h2(
      [attribute.id("results-heading"), attribute.attribute("tabindex", "-1")],
      [html.text("AI Recommendations")],
    ),
    html.div([attribute.class("response-container")], [response_body(model)]),
  ])
}

fn response_body(model: Model) -> Element(Msg) {
  case model.status {
    Waiting -> waiting_copy()
    Loading ->
      html.p([attribute.class("analysis-loading")], [
        html.text("Analyzing your tent…"),
      ])
    Problem(message) ->
      case message == missing_readings() {
        True -> waiting_copy()
        False ->
          html.p([attribute.class("analysis-error")], [html.text(message)])
      }
    Ready(response) -> recommendation_result(response)
  }
}

fn recommendation_result(response: AnalysisResponse) -> Element(Msg) {
  html.div([], [
    html.div([attribute.class("analysis-summary")], [
      html.h3([], [html.text("Summary")]),
      html.p([], [html.text(analysis.summary(response))]),
    ]),
    html.div(
      [attribute.class("recommendations-list")],
      list_cards(analysis.recommendations(response)),
    ),
  ])
}

fn list_cards(
  recommendations: List(analysis.Recommendation),
) -> List(Element(Msg)) {
  list.map(recommendations, card)
}

fn card(recommendation: analysis.Recommendation) -> Element(Msg) {
  let priority = analysis.priority(recommendation)
  let class = "recommendation-card " <> priority_class(priority)
  html.article([attribute.class(class)], [
    html.div([attribute.class("recommendation-header")], [
      html.h4([], [html.text(analysis.title(recommendation))]),
      html.span(
        [attribute.class("priority-badge " <> priority_class(priority))],
        [html.text(priority_label(priority))],
      ),
    ]),
    html.p([attribute.class("recommendation-description")], [
      html.text(analysis.description(recommendation)),
    ]),
    product_block(analysis.product(recommendation)),
  ])
}

fn product_block(product: Option(analysis.ProductLink)) -> Element(Msg) {
  case product {
    None -> html.text("")
    Some(product) ->
      html.div([attribute.class("product-recommendation")], [
        html.div([attribute.class("product-info")], [
          html.div([attribute.class("product-icon")], [html.text("🛒")]),
          html.div([attribute.class("product-details")], [
            html.strong([], [html.text(analysis.name(product))]),
            price_line(analysis.price_range(product)),
          ]),
        ]),
        html.a(
          [
            attribute.class("product-link"),
            attribute.href(analysis.url(product)),
            attribute.target("_blank"),
            attribute.rel("noopener noreferrer"),
          ],
          [html.text("View product")],
        ),
      ])
  }
}

fn price_line(price: Option(String)) -> Element(Msg) {
  case price {
    None -> html.text("")
    Some(price) ->
      html.span([attribute.class("product-price")], [html.text(price)])
  }
}

fn priority_class(priority: analysis.Priority) -> String {
  case priority {
    analysis.High -> "priority-high"
    analysis.Medium -> "priority-medium"
    analysis.Low -> "priority-low"
  }
}

fn priority_label(priority: analysis.Priority) -> String {
  case priority {
    analysis.High -> "High Impact"
    analysis.Medium -> "Medium Impact"
    analysis.Low -> "Low Impact"
  }
}

fn footer() -> Element(Msg) {
  html.footer([], [
    html.p([], [
      html.text("Optimized for seedling, vegetation, and flowering stages"),
    ]),
  ])
}
