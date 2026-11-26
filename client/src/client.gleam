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
  let next = shell.apply(model, msg)
  case msg, next.status {
    shell.AnalyzeClicked, shell.Loading -> #(next, post_analyze(model))
    _, _ -> #(next, effect.none())
  }
}

fn post_analyze(model: shell.Model) -> Effect(shell.Msg) {
  case model.stage {
    None -> effect.none()
    Some(stage) -> {
      let body =
        json.object([
          #("stage", json.string(shell.stage_wire(stage))),
          #("readings", json.string(model.readings)),
          #("api_key", json.string(model.api_key)),
        ])
        |> json.to_string
      effect.from(fn(dispatch) {
        let _ =
          fetch.send(analyze_request(body))
          |> promise.try_await(fetch.read_text_body)
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
}

fn analyze_request(body: String) -> request.Request(String) {
  let assert Ok(req) = request.to(page_origin() <> "/analyze")
  req
  |> request.set_method(http.Post)
  |> request.set_header("content-type", "application/json")
  |> request.set_body(body)
}

fn finished(
  result: Result(response.Response(String), fetch.FetchError),
) -> shell.Msg {
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
