import gleam/http
import gleam/http/response
import gleam/int
import gleam/option.{None, Some}
import gleam/result
import simplifile
import wisp.{type Request, type Response}

import grow_assist/page

pub fn handle_request(req: Request) -> Response {
  let req = wisp.method_override(req)
  let was_head = req.method == http.Head
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  // Mist sends file bodies on HTTP/1.1 even for HEAD, which corrupts the next
  // request on a keep-alive connection. Empty the file body here and keep the
  // length of the GET representation.
  use <- empty_head_file_body(was_head)
  use req <- wisp.handle_head(req)

  let assert Ok(priv) = wisp.priv_directory("grow_assist")
  use <- wisp.serve_static(req, under: "/static", from: priv <> "/static")

  case req.method, wisp.path_segments(req) {
    http.Get, [] -> wisp.html_response(page.shell_document(), 200)
    _, _ -> wisp.not_found()
  }
}

fn empty_head_file_body(was_head: Bool, next: fn() -> Response) -> Response {
  let response = next()
  case was_head {
    False -> response
    True -> drop_file_body(response)
  }
}

fn drop_file_body(resp: Response) -> Response {
  case resp.body {
    wisp.File(path:, offset:, limit:) -> {
      let resp = case representation_length(path, offset, limit) {
        Ok(length) ->
          response.set_header(resp, "content-length", int.to_string(length))
        Error(_) -> resp
      }
      wisp.set_body(resp, wisp.Text(""))
    }
    _ -> resp
  }
}

fn representation_length(
  path: String,
  offset: Int,
  limit: option.Option(Int),
) -> Result(Int, Nil) {
  use info <- result.try(
    simplifile.file_info(path) |> result.replace_error(Nil),
  )
  let start = case offset < 0 {
    True -> int.max(info.size + offset, 0)
    False -> int.min(offset, info.size)
  }
  let remaining = info.size - start
  case limit {
    Some(limit) -> Ok(int.min(int.max(limit, 0), remaining))
    None -> Ok(remaining)
  }
}
