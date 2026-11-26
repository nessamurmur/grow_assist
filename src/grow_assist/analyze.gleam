import gleam/string
import shared/analysis.{type AnalysisResponse}

pub type Analyzer =
  fn(String, String, String) -> Result(AnalysisResponse, String)

pub fn user_message(stage: String, readings: String) -> String {
  "Growth stage: "
  <> stage
  <> "\n\nReadings:\n"
  <> readings
  <> "\n\nFollow the system instructions. Include a summary and 2 or 3 recommendations. At least one recommendation includes a product link from the catalog. Priorities are high, medium, or low."
}

pub fn canonical_stage(raw: String) -> Result(String, Nil) {
  case string.lowercase(string.trim(raw)) {
    "seedling" -> Ok("Seedling")
    "vegetation" | "vegetative" -> Ok("Vegetation")
    "flowering" | "flower" -> Ok("Flowering")
    _ -> Error(Nil)
  }
}

pub fn redact(message: String, api_key: String) -> String {
  let message = case api_key == "" {
    True -> message
    False -> string.replace(message, each: api_key, with: "[redacted]")
  }
  case string.length(message) > 500 {
    True -> string.slice(message, 0, 500)
    False -> message
  }
}
