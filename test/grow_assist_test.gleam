import gleam/http
import gleam/list
import gleam/string
import gleeunit
import wisp
import wisp/simulate

import grow_assist/assets
import grow_assist/router

pub fn main() {
  wisp.configure_logger()
  gleeunit.main()
}

pub fn home_page_returns_shell_test() {
  let response = router.handle_request(simulate.request(http.Get, "/"))
  assert response.status == 200
  let assert wisp.Text(html) = response.body
  assert string.contains(does: html, contain: "<!doctype html>")
  assert string.contains(does: html, contain: "Grow Assist")
  assert string.contains(
    does: html,
    contain: "Your AI recommendations will appear here...",
  )
  assert string.contains(does: html, contain: "/static/styles.css")
  assert string.contains(does: html, contain: "/static/client.js")
  assert string.contains(does: html, contain: "Seedling")
  assert string.contains(does: html, contain: "Flowering")
}

pub fn unknown_path_is_not_found_test() {
  let response = router.handle_request(simulate.request(http.Get, "/analyze"))
  assert response.status == 404
}

pub fn stylesheet_is_served_test() {
  let response =
    router.handle_request(simulate.request(http.Get, "/static/styles.css"))
  assert response.status == 200
  let assert Ok(content_type) = list.key_find(response.headers, "content-type")
  assert string.contains(does: content_type, contain: "text/css")
}

pub fn catalog_csv_is_present_test() {
  let assert Ok(catalog) = assets.read_product_links()
  let rows =
    catalog
    |> string.split(on: "\n")
    |> list.filter(fn(line) { line != "" })
  assert list.length(rows) == 50
  assert list.first(rows)
    == Ok(
      "Problem Category,Product Name,Product Price,Product URL,Product Description",
    )
  assert string.contains(
    does: catalog,
    contain: "CLOUDLAB 844 Advance Grow Tent 4x4",
  )
  assert string.contains(does: catalog, contain: "CLOUDLAB 864D 2-in-1 Tent")
}

pub fn system_prompt_keeps_ported_text_and_catalog_test() {
  let assert Ok(prompt) = assets.load_system_prompt()
  assert string.contains(
    does: prompt,
    contain: "experienced, patient, and beginner-friendly mentor",
  )
  assert string.contains(does: prompt, contain: "**Seedling Stage:**")
  assert string.contains(does: prompt, contain: "Keep it between 0.4-0.8 kPa.")
  assert string.contains(does: prompt, contain: "**Vegetation Stage:**")
  assert string.contains(does: prompt, contain: "0.8-1.2 kPa")
  assert string.contains(does: prompt, contain: "**Flowering Stage:**")
  assert string.contains(does: prompt, contain: "1.2-1.6 kPa")
  assert string.contains(
    does: prompt,
    contain: "Provide 2-3 concrete, actionable recommendations.",
  )
  assert string.contains(
    does: prompt,
    contain: "at least ONE recommendation includes a relevant product link",
  )
  assert string.contains(
    does: prompt,
    contain: "**High Impact**, **Medium Impact**, or **Low Impact**",
  )
  assert string.contains(
    does: prompt,
    contain: "https://acinfinity.com/clip-on-fans/",
  )
  assert !string.contains(does: prompt, contain: "{product_links}")
}
