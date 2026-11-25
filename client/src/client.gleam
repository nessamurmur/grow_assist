import gleam/io
import lustre
import shared/shell

pub fn main() {
  let app = lustre.simple(init, update, shell.view)
  case lustre.start(app, "#app", Nil) {
    Ok(_) -> Nil
    Error(_) -> io.println("Grow Assist shell is waiting for a browser")
  }
}

fn init(_flags: Nil) -> shell.Model {
  shell.initial_model()
}

fn update(model: shell.Model, _msg: Nil) -> shell.Model {
  model
}
