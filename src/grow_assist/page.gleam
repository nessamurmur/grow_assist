import lustre/attribute
import lustre/element
import lustre/element/html
import shared/shell

pub fn shell_document() -> String {
  let page =
    html.html([attribute.lang("en")], [
      html.head([], [
        html.meta([attribute.charset("utf-8")]),
        html.meta([
          attribute.name("viewport"),
          attribute.content("width=device-width, initial-scale=1"),
        ]),
        html.title([], "Grow Assist"),
        html.link([
          attribute.rel("stylesheet"),
          attribute.href("/static/styles.css"),
        ]),
        html.script(
          [attribute.type_("module"), attribute.src("/static/client.js")],
          "",
        ),
      ]),
      html.body([], [
        html.div([attribute.id("app")], [shell.view(shell.initial_model())]),
      ]),
    ])

  element.to_document_string(page)
}
