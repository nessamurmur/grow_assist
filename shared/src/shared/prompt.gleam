//// Fills the system prompt template. The template text lives in
//// `priv/system_prompt.txt` and uses the literal `{product_links}` marker
//// where the catalog CSV is inserted.

import gleam/string

pub type PromptError {
  MissingPlaceholder
}

pub fn fill(
  template: String,
  product_links: String,
) -> Result(String, PromptError) {
  case string.contains(does: template, contain: "{product_links}") {
    False -> Error(MissingPlaceholder)
    True ->
      Ok(string.replace(template, each: "{product_links}", with: product_links))
  }
}
