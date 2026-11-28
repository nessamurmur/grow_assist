import gleam/dynamic/decode
import gleam/fetch
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/io
import gleam/javascript/promise
import gleam/json
import gleam/option.{None, Some}
import gleam/string
import lustre
import lustre/effect.{type Effect}
import shared/analysis_json
import shared/shell

pub fn main() -> Nil {
  let app = lustre.application(init, update, shell.view)
  case lustre.start(app, "#app", Nil) {
    Ok(_) -> Nil
    Error(_) -> io.println("Grow Assist shell is waiting for a browser")
  }
}

fn init(_flags: Nil) -> #(shell.Model, Effect(shell.Msg)) {
  #(shell.initial_model(), effect.none())
}

fn update(
  model: shell.Model,
  msg: shell.Msg,
) -> #(shell.Model, Effect(shell.Msg)) {
  let msg = case msg {
    shell.CsvChosen(_) -> shell.CsvChosen(snapshot_readings_file())
    shell.CsvCleared -> {
      clear_readings_file()
      msg
    }
    _ -> msg
  }
  let next = shell.apply(model, msg)
  case msg, next.status {
    shell.AnalyzeClicked, shell.Loading -> #(next, post_analyze(model))
    _, _ -> #(next, effect.none())
  }
}

fn post_analyze(model: shell.Model) -> Effect(shell.Msg) {
  case model.stage {
    None -> effect.none()
    Some(stage) ->
      effect.from(fn(dispatch) {
        let _ =
          send(model, stage)
          |> promise.map(fn(result) { dispatch(finished(result)) })
          |> promise.rescue(fn(_) {
            dispatch(
              shell.AnalyzeFinished(Error(
                "The request did not reach the server.",
              )),
            )
          })
        Nil
      })
  }
}

fn send(
  model: shell.Model,
  stage: shell.Stage,
) -> promise.Promise(Result(response.Response(String), Nil)) {
  case model.csv_name == "" {
    True ->
      fetch.send(analyze_request(json_body(model, stage)))
      |> promise.try_await(fetch.read_text_body)
      |> promise.map(fn(result) {
        case result {
          Ok(response) -> Ok(response)
          Error(_) -> Error(Nil)
        }
      })
    False ->
      post_csv(
        page_origin() <> "/analyze",
        shell.stage_wire(stage),
        model.api_key,
      )
      |> promise.map(fn(pair) {
        let #(status, body) = pair
        Ok(response.Response(status:, headers: [], body:))
      })
  }
}

fn json_body(model: shell.Model, stage: shell.Stage) -> String {
  json.object([
    #("stage", json.string(shell.stage_wire(stage))),
    #("readings", json.string(model.readings)),
    #("api_key", json.string(model.api_key)),
  ])
  |> json.to_string
}

fn analyze_request(body: String) -> request.Request(String) {
  let assert Ok(req) = request.to(page_origin() <> "/analyze")
  req
  |> request.set_method(http.Post)
  |> request.set_header("content-type", "application/json")
  |> request.set_body(body)
}

fn finished(result: Result(response.Response(String), Nil)) -> shell.Msg {
  let outcome = case result {
    Error(_) -> Error("The request did not reach the server.")
    Ok(response) ->
      case response.status {
        200 ->
          case analysis_json.decode(response.body) {
            Ok(value) -> Ok(value)
            Error(message) -> Error(message)
          }
        _ -> Error(error_text(response.body))
      }
  }
  shell.AnalyzeFinished(outcome)
}

fn error_text(body: String) -> String {
  let decoder = {
    use message <- decode.field("error", decode.string)
    decode.success(message)
  }
  case json.parse(body, decoder) {
    Ok(message) ->
      case string.trim(message) == "" {
        True -> "The analysis request failed."
        False -> message
      }
    Error(_) -> "The analysis request failed."
  }
}

@external(javascript, "./client_ffi.mjs", "pageOrigin")
fn page_origin() -> String

@external(javascript, "./client_ffi.mjs", "snapshotReadingsFile")
fn snapshot_readings_file() -> String

@external(javascript, "./client_ffi.mjs", "clearReadingsFile")
fn clear_readings_file() -> Nil

@external(javascript, "./client_ffi.mjs", "postCsv")
fn post_csv(
  url: String,
  stage: String,
  api_key: String,
) -> promise.Promise(#(Int, String))
