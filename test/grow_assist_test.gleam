import gleam/bit_array
import gleam/erlang/atom
import gleam/erlang/process
import gleam/http
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeunit
import mist
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
  assert string.contains(does: html, contain: "Analyze")
  assert string.contains(does: html, contain: "API key")
  assert string.contains(does: html, contain: "Readings")
  assert string.contains(does: html, contain: "Upload a CSV")
  assert string.contains(does: html, contain: "readings-file")
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
  let assert Ok(socket) = tcp_connect(#(127, 0, 0, 1), port, tcp_options())

  assert atom.to_string(tcp_send(
      socket,
      http_request("HEAD", "/static/styles.css"),
    ))
    == "ok"
  let assert Ok(#(head, rest)) = read_headers(socket, 2000)
  assert string.starts_with(head, "HTTP/1.1 200")
  let assert Ok(css_length) = header_value(head, "content-length")
  let assert Ok(css_length) = int.parse(css_length)
  let assert Ok(priv) = wisp.priv_directory("grow_assist")
  let assert Ok(info) = simplifile.file_info(priv <> "/static/styles.css")
  assert css_length == info.size
  assert_no_head_body(rest)
  assert_socket_stays_quiet(socket)

  assert atom.to_string(tcp_send(socket, http_request("GET", "/"))) == "ok"
  let assert Ok(#(get_head, get_rest)) = read_headers(socket, 2000)
  assert string.starts_with(get_head, "HTTP/1.1 200")
  let assert Ok(page_length) = header_value(get_head, "content-length")
  let assert Ok(page_length) = int.parse(page_length)
  let assert Ok(page) = read_body(socket, get_rest, page_length)
  let assert Ok(html) = bit_array.to_string(page)
  assert string.contains(html, "<!doctype html>")
  assert string.contains(html, "Grow Assist")
  assert atom.to_string(tcp_close(socket)) == "ok"
}

fn http_request(method: String, path: String) -> BitArray {
  bit_array.from_string(
    method
    <> " "
    <> path
    <> " HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: keep-alive\r\n\r\n",
  )
}

fn tcp_options() -> List(#(atom.Atom, atom.Atom)) {
  [
    #(atom.create("mode"), atom.create("binary")),
    #(atom.create("packet"), atom.create("raw")),
    #(atom.create("active"), atom.create("false")),
  ]
}

fn assert_no_head_body(rest: BitArray) -> Nil {
  case bit_array.byte_size(rest) {
    0 -> Nil
    n -> {
      let message =
        "HEAD leaked " <> int.to_string(n) <> " bytes: " <> prefix(rest)
      panic as message
    }
  }
}

fn assert_socket_stays_quiet(socket: TcpSocket) -> Nil {
  case tcp_recv(socket, 0, 300) {
    Error(reason) -> {
      assert atom.to_string(reason) == "timeout"
    }
    Ok(extra) -> {
      let message =
        "HEAD leaked "
        <> int.to_string(bit_array.byte_size(extra))
        <> " late bytes: "
        <> prefix(extra)
      panic as message
    }
  }
}

fn prefix(data: BitArray) -> String {
  let take = int.min(40, bit_array.byte_size(data))
  case bit_array.slice(data, 0, take) {
    Ok(slice) ->
      case bit_array.to_string(slice) {
        Ok(text) -> text
        Error(_) -> bit_array.inspect(slice)
      }
    Error(_) -> ""
  }
}

fn header_value(head: String, name: String) -> Result(String, Nil) {
  head
  |> string.split("\r\n")
  |> list.find_map(fn(line) {
    case string.starts_with(string.lowercase(line), name <> ":") {
      False -> Error(Nil)
      True ->
        Ok(
          line
          |> string.drop_start(string.length(name) + 1)
          |> string.trim,
        )
    }
  })
}

fn read_headers(
  socket: TcpSocket,
  timeout: Int,
) -> Result(#(String, BitArray), String) {
  read_headers_from(socket, timeout, <<>>, 16)
}

fn read_headers_from(
  socket: TcpSocket,
  timeout: Int,
  buf: BitArray,
  left: Int,
) -> Result(#(String, BitArray), String) {
  case find_marker(buf, 0) {
    Ok(at) -> {
      let assert Ok(raw_head) = bit_array.slice(buf, 0, at)
      let rest_at = at + 4
      let assert Ok(rest) =
        bit_array.slice(buf, rest_at, bit_array.byte_size(buf) - rest_at)
      case bit_array.to_string(raw_head) {
        Ok(head) -> Ok(#(head, rest))
        Error(_) -> Error("headers were not utf-8")
      }
    }
    Error(_) if left <= 0 -> Error("headers did not finish")
    Error(_) ->
      case tcp_recv(socket, 0, timeout) {
        Ok(chunk) ->
          read_headers_from(
            socket,
            timeout,
            bit_array.append(buf, chunk),
            left - 1,
          )
        Error(reason) -> Error("recv " <> atom.to_string(reason))
      }
  }
}

fn find_marker(data: BitArray, at: Int) -> Result(Int, Nil) {
  case bit_array.byte_size(data) < at + 4 {
    True -> Error(Nil)
    False -> {
      let assert Ok(window) = bit_array.slice(data, at, 4)
      case window == <<"\r\n\r\n":utf8>> {
        True -> Ok(at)
        False -> find_marker(data, at + 1)
      }
    }
  }
}

fn read_body(
  socket: TcpSocket,
  have: BitArray,
  needed: Int,
) -> Result(BitArray, String) {
  case bit_array.byte_size(have) >= needed {
    True ->
      bit_array.slice(have, 0, needed) |> result.replace_error("short body")
    False ->
      case tcp_recv(socket, 0, 2000) {
        Ok(more) -> read_body(socket, bit_array.append(have, more), needed)
        Error(reason) -> Error("body recv " <> atom.to_string(reason))
      }
  }
}

type TcpSocket

@external(erlang, "gen_tcp", "connect")
fn tcp_connect(
  address: #(Int, Int, Int, Int),
  port: Int,
  options: List(#(atom.Atom, atom.Atom)),
) -> Result(TcpSocket, atom.Atom)

@external(erlang, "gen_tcp", "send")
fn tcp_send(socket: TcpSocket, packet: BitArray) -> atom.Atom

@external(erlang, "gen_tcp", "recv")
fn tcp_recv(
  socket: TcpSocket,
  length: Int,
  timeout: Int,
) -> Result(BitArray, atom.Atom)

@external(erlang, "gen_tcp", "close")
fn tcp_close(socket: TcpSocket) -> atom.Atom

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
