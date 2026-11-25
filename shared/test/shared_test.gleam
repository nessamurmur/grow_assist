import gleam/string
import gleeunit
import lustre/element
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
}
