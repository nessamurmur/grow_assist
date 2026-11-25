import gleam/result
import simplifile
import wisp

import shared/prompt.{type PromptError}

pub type AssetError {
  PrivUnavailable
  Unreadable(simplifile.FileError)
  Prompt(PromptError)
}

/// Reads the ported system prompt and catalog, then inserts the CSV where the
/// template says `{product_links}`.
pub fn load_system_prompt() -> Result(String, AssetError) {
  use priv <- result.try(
    wisp.priv_directory("grow_assist")
    |> result.replace_error(PrivUnavailable),
  )
  use template <- result.try(read_asset(priv, "system_prompt.txt"))
  use catalog <- result.try(read_asset(priv, "product_links.csv"))
  prompt.fill(template, catalog)
  |> result.map_error(Prompt)
}

pub fn read_product_links() -> Result(String, AssetError) {
  use priv <- result.try(
    wisp.priv_directory("grow_assist")
    |> result.replace_error(PrivUnavailable),
  )
  read_asset(priv, "product_links.csv")
}

fn read_asset(priv: String, name: String) -> Result(String, AssetError) {
  simplifile.read(priv <> "/" <> name)
  |> result.map_error(Unreadable)
}
