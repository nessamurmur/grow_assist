import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import simplifile
import wisp.{type Request, type Response}

import grow_assist/analyze
import grow_assist/assets
import grow_assist/page
import grow_assist/readings_csv
import grow_assist/req_llm
import shared/analysis_json

pub fn handle_request(req: Request) -> Response {
  handle(req, req_llm.recommend)
}

pub fn handle(req: Request, recommend: analyze.Analyzer) -> Response {
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
    http.Post, ["analyze"] -> analyze_request(req, recommend)
    _, _ -> wisp.not_found()
  }
}

fn analyze_request(req: Request, recommend: analyze.Analyzer) -> Response {
  case multipart(req) {
    True -> csv_analyze(req, recommend)
    False -> json_analyze(req, recommend)
  }
}

fn multipart(req: Request) -> Bool {
  case request.get_header(req, "content-type") {
    Ok(value) ->
      string.starts_with(string.lowercase(value), "multipart/form-data")
    Error(Nil) -> False
  }
}

fn json_analyze(req: Request, recommend: analyze.Analyzer) -> Response {
  use body <- wisp.require_json(req)
  case decode.run(body, request_decoder()) {
    Error(_) ->
      json_error("Send a growth stage, readings, and an API key.", 400)
    Ok(#(stage, readings, api_key)) ->
      complete(stage, readings, api_key, recommend)
  }
}

// The CSV is a file part, so Wisp streams it to a temp file and deletes that
// file when this handler returns. The API key is a text field and stays in
// memory. Neither is logged.
fn csv_analyze(req: Request, recommend: analyze.Analyzer) -> Response {
  let req = wisp.set_max_files_size(req, 1_048_576)
  use form <- wisp.require_form(req)
  case list.key_find(form.files, "csv") {
    Error(Nil) -> json_error("Choose a CSV file.", 400)
    Ok(file) ->
      case readings_csv.parse_file(file.path) {
        Error(error) -> json_error(csv_problem(error), 400)
        Ok(rows) ->
          complete(
            form_value(form.values, "stage"),
            readings_csv.render(rows),
            form_value(form.values, "api_key"),
            recommend,
          )
      }
  }
}

fn form_value(values: List(#(String, String)), name: String) -> String {
  list.key_find(values, name)
  |> result.unwrap("")
}

fn csv_problem(error: readings_csv.CsvError) -> String {
  case error {
    readings_csv.Unreadable -> "That file is not a readable CSV."
    readings_csv.NoReadings -> "That CSV has no readings."
    readings_csv.NoKnownColumn ->
      "That CSV needs a temperature, humidity, light, or soil moisture column."
    readings_csv.TooLarge -> "That CSV is too large."
  }
}

fn request_decoder() -> decode.Decoder(#(String, String, String)) {
  use stage <- decode.field("stage", decode.string)
  use readings <- decode.field("readings", decode.string)
  use api_key <- decode.field("api_key", decode.string)
  decode.success(#(stage, readings, api_key))
}

fn complete(
  stage: String,
  readings: String,
  api_key: String,
  recommend: analyze.Analyzer,
) -> Response {
  case string.trim(api_key) == "" {
    True -> json_error("Paste an API key.", 400)
    False ->
      case string.trim(readings) == "" {
        True -> json_error("Paste a few readings.", 400)
        False ->
          case analyze.canonical_stage(stage) {
            Error(Nil) ->
              json_error("Choose seedling, vegetation, or flowering.", 400)
            Ok(stage) ->
              dispatch(stage, string.trim(readings), api_key, recommend)
          }
      }
  }
}

fn dispatch(
  stage: String,
  readings: String,
  api_key: String,
  recommend: analyze.Analyzer,
) -> Response {
  case assets.load_system_prompt() {
    Error(_) -> json_error("The system prompt could not be loaded.", 500)
    Ok(system) ->
      case recommend(system, analyze.user_message(stage, readings), api_key) {
        Ok(response) -> wisp.json_response(analysis_json.encode(response), 200)
        Error(reason) -> json_error(analyze.redact(reason, api_key), 502)
      }
  }
}

fn json_error(message: String, status: Int) -> Response {
  let body =
    json.object([#("error", json.string(message))])
    |> json.to_string
  wisp.json_response(body, status)
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
        Error(Nil) -> resp
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
