import gleam/erlang/process
import gleam/http
import gleam/int
import gleam/list
import gleam/string
import gleeunit
import mist
import shellout
import simplifile
import wisp
import wisp/simulate
import wisp/wisp_mist

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

pub fn head_stylesheet_has_no_file_body_test() {
  let response =
    router.handle_request(simulate.request(http.Head, "/static/styles.css"))
  assert response.status == 200
  let assert wisp.Text(body) = response.body
  assert body == ""
  let assert Ok(css_length) = list.key_find(response.headers, "content-length")
  let assert Ok(css_length) = int.parse(css_length)
  let assert Ok(priv) = wisp.priv_directory("grow_assist")
  let assert Ok(info) = simplifile.file_info(priv <> "/static/styles.css")
  assert css_length == info.size
}

pub fn head_stylesheet_then_get_reuses_the_connection_test() {
  let port_subject = process.new_subject()
  let assert Ok(_) =
    router.handle_request
    |> wisp_mist.handler(wisp.random_string(64))
    |> mist.new
    |> mist.bind("127.0.0.1")
    |> mist.port(0)
    |> mist.after_start(fn(port, _, _) { process.send(port_subject, port) })
    |> mist.start

  let assert Ok(port) = process.receive(port_subject, 5000)
  let assert Ok(output) =
    shellout.command(
      run: "python3",
      with: ["test/head_keepalive.py", int.to_string(port)],
      in: ".",
      opt: [],
    )
  assert string.contains(does: output, contain: "ok")
  // Leave the listener until the test VM exits. Killing the linked
  // supervisor dumps crash reports into the test log.
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
