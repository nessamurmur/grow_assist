import client
import gleam/string
import gleeunit
import lustre/element
import shared/shell

pub fn main() {
  gleeunit.main()
}

pub fn shell_view_renders_on_javascript_test() {
  let html = shell.view(shell.initial_model()) |> element.to_string
  assert string.contains(does: html, contain: "Grow Assist")
  assert string.contains(
    does: html,
    contain: "Your AI recommendations will appear here...",
  )
  assert string.contains(does: html, contain: "Seedling")
  assert string.contains(does: html, contain: "Vegetation")
  assert string.contains(does: html, contain: "Flowering")
}

pub fn client_module_starts_test() {
  // `main` only mounts in a browser. Calling it on Node must not crash.
  client.main()
}
