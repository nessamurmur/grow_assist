import gleam/http
import wisp.{type Request, type Response}

import grow_assist/page

pub fn handle_request(req: Request) -> Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  let assert Ok(priv) = wisp.priv_directory("grow_assist")
  use <- wisp.serve_static(req, under: "/static", from: priv <> "/static")

  case req.method, wisp.path_segments(req) {
    http.Get, [] -> wisp.html_response(page.shell_document(), 200)
    _, _ -> wisp.not_found()
  }
}
