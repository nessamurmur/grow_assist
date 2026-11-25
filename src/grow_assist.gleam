import envoy
import gleam/erlang/process
import gleam/int
import mist
import wisp
import wisp/wisp_mist

import grow_assist/router

const default_port = 8080

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    router.handle_request
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(listen_port())
    |> mist.start

  process.sleep_forever()
}

fn listen_port() -> Int {
  case envoy.get("PORT") {
    Ok(value) ->
      case int.parse(value) {
        Ok(port) -> port
        Error(_) -> default_port
      }
    Error(_) -> default_port
  }
}
