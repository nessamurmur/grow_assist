//// A tent CSV parsed into rows the recommendation prompt can use.
////
//// Temperature, humidity, light or PPFD, and soil moisture are the columns
//// the previous app accepted. Other columns stay on the row. A file that
//// has none of those columns, or no numeric reading, is rejected.

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile

const max_bytes = 1_048_576

const max_rows = 5000

pub type Temperature {
  Fahrenheit(Float)
  Celsius(Float)
}

pub type Reading {
  Reading(
    temperature: Option(Temperature),
    humidity_pct: Option(Float),
    ppfd: Option(Float),
    soil_moisture_pct: Option(Float),
    extras: List(#(String, String)),
  )
}

pub type CsvError {
  Unreadable
  NoReadings
  NoKnownColumn
  TooLarge
}

type Column {
  TempF
  TempC
  Humidity
  Light
  Soil
  Extra(String)
}

pub fn parse_file(path: String) -> Result(List(Reading), CsvError) {
  case simplifile.file_info(path) {
    Error(error) -> Error(unreadable(error))
    Ok(info) ->
      case info.size > max_bytes {
        True -> Error(TooLarge)
        False ->
          case simplifile.read(path) {
            Error(error) -> Error(unreadable(error))
            Ok(text) -> parse(text)
          }
      }
  }
}

pub fn parse(text: String) -> Result(List(Reading), CsvError) {
  case string.byte_size(text) > max_bytes {
    True -> Error(TooLarge)
    False -> parse_text(text)
  }
}

pub fn render(rows: List(Reading)) -> String {
  let headers = headers(rows)
  let lines = [
    join(headers),
    ..list.map(rows, fn(row) { join(cells(headers, row)) })
  ]
  string.join(lines, "\n")
}

fn unreadable(_error: simplifile.FileError) -> CsvError {
  Unreadable
}

fn parse_text(text: String) -> Result(List(Reading), CsvError) {
  let text =
    text
    |> strip_bom
    |> string.replace("\r\n", "\n")
    |> string.replace("\r", "\n")
    |> string.trim
  case text == "" {
    True -> Error(NoReadings)
    False -> {
      let lines = string.split(text, "\n")
      case list.length(lines) > max_rows + 1 {
        True -> Error(TooLarge)
        False ->
          case list.try_map(lines, parse_line) {
            Error(Nil) -> Error(Unreadable)
            Ok(table) -> interpret(table)
          }
      }
    }
  }
}

fn strip_bom(text: String) -> String {
  case string.starts_with(text, "\u{feff}") {
    True -> string.drop_start(text, 1)
    False -> text
  }
}

fn interpret(table: List(List(String))) -> Result(List(Reading), CsvError) {
  case table {
    [] -> Error(NoReadings)
    [header, ..rest] -> readings_from(header, rest)
  }
}

fn readings_from(
  header: List(String),
  rest: List(List(String)),
) -> Result(List(Reading), CsvError) {
  let columns = list.map(header, column)
  case list.any(columns, known_column) {
    False -> Error(NoKnownColumn)
    True -> non_empty(list.filter_map(rest, reading_from(_, columns)))
  }
}

fn non_empty(rows: List(Reading)) -> Result(List(Reading), CsvError) {
  case rows {
    [] -> Error(NoReadings)
    _ -> Ok(rows)
  }
}

fn known_column(column: Column) -> Bool {
  case column {
    Extra(_) -> False
    _ -> True
  }
}

fn column(header: String) -> Column {
  case normalize(header) {
    "temperature"
    | "temp"
    | "tempf"
    | "temperaturef"
    | "airtemp"
    | "airtemperature"
    | "tempfahrenheit"
    | "temperaturefahrenheit" -> TempF
    "tempc" | "temperaturec" | "tempcelsius" | "temperaturecelsius" -> TempC
    "humidity"
    | "humiditypct"
    | "rh"
    | "relativehumidity"
    | "humiditypercent"
    | "hum" -> Humidity
    "light"
    | "ppfd"
    | "lightppfd"
    | "par"
    | "lightintensity"
    | "umol"
    | "ppfdumolm2s" -> Light
    "soilmoisture"
    | "soilmoisturepct"
    | "soil"
    | "moisture"
    | "vwc"
    | "soilmoist" -> Soil
    _ -> Extra(string.trim(header))
  }
}

fn normalize(name: String) -> String {
  name
  |> string.lowercase
  |> string.to_graphemes
  |> list.filter(alphanumeric)
  |> string.concat
}

fn alphanumeric(char: String) -> Bool {
  case char {
    "a"
    | "b"
    | "c"
    | "d"
    | "e"
    | "f"
    | "g"
    | "h"
    | "i"
    | "j"
    | "k"
    | "l"
    | "m"
    | "n"
    | "o"
    | "p"
    | "q"
    | "r"
    | "s"
    | "t"
    | "u"
    | "v"
    | "w"
    | "x"
    | "y"
    | "z"
    | "0"
    | "1"
    | "2"
    | "3"
    | "4"
    | "5"
    | "6"
    | "7"
    | "8"
    | "9" -> True
    _ -> False
  }
}

fn reading_from(
  cells: List(String),
  columns: List(Column),
) -> Result(Reading, Nil) {
  let cells = pad(cells, list.length(columns))
  let reading =
    list.zip(columns, cells)
    |> list.fold(empty_reading(), apply_cell)
  case has_known(reading) {
    True -> Ok(reading)
    False -> Error(Nil)
  }
}

fn empty_reading() -> Reading {
  Reading(
    temperature: None,
    humidity_pct: None,
    ppfd: None,
    soil_moisture_pct: None,
    extras: [],
  )
}

fn pad(cells: List(String), width: Int) -> List(String) {
  case list.length(cells) >= width {
    True -> list.take(cells, width)
    False -> list.append(cells, list.repeat("", width - list.length(cells)))
  }
}

fn apply_cell(reading: Reading, pair: #(Column, String)) -> Reading {
  let #(column, raw) = pair
  let raw = string.trim(raw)
  case column {
    TempF -> set_temperature(reading, parsed_temperature(raw, False))
    TempC -> set_temperature(reading, parsed_temperature(raw, True))
    Humidity -> set_humidity(reading, parse_number(raw))
    Light -> set_light(reading, parse_number(raw))
    Soil -> set_soil(reading, parse_number(raw))
    Extra(name) -> set_extra(reading, string.trim(name), raw)
  }
}

fn set_temperature(
  reading: Reading,
  next: Result(Temperature, Nil),
) -> Reading {
  case reading.temperature, next {
    None, Ok(temperature) -> Reading(..reading, temperature: Some(temperature))
    _, _ -> reading
  }
}

fn set_humidity(reading: Reading, next: Result(Float, Nil)) -> Reading {
  case reading.humidity_pct, next {
    None, Ok(value) -> Reading(..reading, humidity_pct: Some(value))
    _, _ -> reading
  }
}

fn set_light(reading: Reading, next: Result(Float, Nil)) -> Reading {
  case reading.ppfd, next {
    None, Ok(value) -> Reading(..reading, ppfd: Some(value))
    _, _ -> reading
  }
}

fn set_soil(reading: Reading, next: Result(Float, Nil)) -> Reading {
  case reading.soil_moisture_pct, next {
    None, Ok(value) -> Reading(..reading, soil_moisture_pct: Some(value))
    _, _ -> reading
  }
}

fn set_extra(reading: Reading, name: String, raw: String) -> Reading {
  case name == "" || raw == "" {
    True -> reading
    False ->
      case list.key_find(reading.extras, name) {
        Ok(_) -> reading
        Error(Nil) ->
          Reading(
            ..reading,
            extras: list.append(reading.extras, [#(name, raw)]),
          )
      }
  }
}

fn parsed_temperature(
  raw: String,
  column_is_celsius: Bool,
) -> Result(Temperature, Nil) {
  case parse_number(raw) {
    Error(Nil) -> Error(Nil)
    Ok(value) -> Ok(temperature_value(raw, value, column_is_celsius))
  }
}

fn temperature_value(
  raw: String,
  value: Float,
  column_is_celsius: Bool,
) -> Temperature {
  let lower = string.lowercase(raw)
  let has_c = string.contains(lower, "c")
  let has_f = string.contains(lower, "f")
  let celsius = case has_c, has_f {
    True, False -> True
    False, True -> False
    _, _ -> column_is_celsius
  }
  case celsius {
    True -> Celsius(value)
    False -> Fahrenheit(value)
  }
}

fn parse_number(raw: String) -> Result(Float, Nil) {
  let token = first_token(without_percent(raw))
  case token == "" {
    True -> Error(Nil)
    False ->
      float.parse(token)
      |> result.or(result.map(int.parse(token), int.to_float))
  }
}

fn without_percent(raw: String) -> String {
  case string.ends_with(raw, "%") {
    True -> string.drop_end(raw, 1) |> string.trim
    False -> raw
  }
}

fn first_token(raw: String) -> String {
  case string.split(raw, " ") {
    [first, ..] -> first
    [] -> raw
  }
}

fn has_known(reading: Reading) -> Bool {
  case
    reading.temperature,
    reading.humidity_pct,
    reading.ppfd,
    reading.soil_moisture_pct
  {
    None, None, None, None -> False
    _, _, _, _ -> True
  }
}

fn headers(rows: List(Reading)) -> List(String) {
  let known =
    []
    |> push_header("temperature_f", list.any(rows, has_fahrenheit))
    |> push_header("temperature_c", list.any(rows, has_celsius))
    |> push_header("humidity_pct", list.any(rows, has_humidity))
    |> push_header("ppfd", list.any(rows, has_light))
    |> push_header("soil_moisture", list.any(rows, has_soil))
  list.append(known, extra_names(rows))
}

fn push_header(
  headers: List(String),
  name: String,
  present: Bool,
) -> List(String) {
  case present {
    True -> list.append(headers, [name])
    False -> headers
  }
}

fn has_fahrenheit(row: Reading) -> Bool {
  case row.temperature {
    Some(Fahrenheit(_)) -> True
    _ -> False
  }
}

fn has_celsius(row: Reading) -> Bool {
  case row.temperature {
    Some(Celsius(_)) -> True
    _ -> False
  }
}

fn has_humidity(row: Reading) -> Bool {
  row.humidity_pct != None
}

fn has_light(row: Reading) -> Bool {
  row.ppfd != None
}

fn has_soil(row: Reading) -> Bool {
  row.soil_moisture_pct != None
}

fn extra_names(rows: List(Reading)) -> List(String) {
  list.fold(rows, [], fn(names, row) {
    list.fold(row.extras, names, fn(names, extra) {
      let #(name, _) = extra
      case list.contains(names, name) {
        True -> names
        False -> list.append(names, [name])
      }
    })
  })
}

fn cells(headers: List(String), row: Reading) -> List(String) {
  list.map(headers, cell_value(_, row))
}

fn cell_value(header: String, row: Reading) -> String {
  case header {
    "temperature_f" -> temperature_cell(row, False)
    "temperature_c" -> temperature_cell(row, True)
    "humidity_pct" -> optional_float(row.humidity_pct)
    "ppfd" -> optional_float(row.ppfd)
    "soil_moisture" -> optional_float(row.soil_moisture_pct)
    name -> extra_value(row.extras, name)
  }
}

fn temperature_cell(row: Reading, celsius: Bool) -> String {
  case row.temperature {
    Some(Fahrenheit(value)) if !celsius -> format_float(value)
    Some(Celsius(value)) if celsius -> format_float(value)
    _ -> ""
  }
}

fn optional_float(value: Option(Float)) -> String {
  case value {
    Some(value) -> format_float(value)
    None -> ""
  }
}

fn extra_value(extras: List(#(String, String)), name: String) -> String {
  list.key_find(extras, name)
  |> result.unwrap("")
}

fn format_float(value: Float) -> String {
  let whole = float.round(value)
  case int.to_float(whole) == value {
    True -> int.to_string(whole)
    False -> float.to_string(value)
  }
}

fn join(cells: List(String)) -> String {
  cells
  |> list.map(escape)
  |> string.join(",")
}

fn escape(value: String) -> String {
  let quote =
    string.contains(value, ",")
    || string.contains(value, "\"")
    || string.contains(value, "\n")
  case quote {
    False -> value
    True -> "\"" <> string.replace(value, each: "\"", with: "\"\"") <> "\""
  }
}

fn parse_line(line: String) -> Result(List(String), Nil) {
  parse_chars(string.to_graphemes(line), False, "", [])
}

fn parse_chars(
  chars: List(String),
  quoted: Bool,
  field: String,
  acc: List(String),
) -> Result(List(String), Nil) {
  case chars {
    [] ->
      case quoted {
        True -> Error(Nil)
        False -> Ok(list.reverse([field, ..acc]))
      }
    ["\"", ..rest] -> parse_quote(rest, quoted, field, acc)
    [",", ..rest] ->
      case quoted {
        True -> parse_chars(rest, True, field <> ",", acc)
        False -> parse_chars(rest, False, "", [field, ..acc])
      }
    [char, ..rest] -> parse_chars(rest, quoted, field <> char, acc)
  }
}

fn parse_quote(
  rest: List(String),
  quoted: Bool,
  field: String,
  acc: List(String),
) -> Result(List(String), Nil) {
  case quoted {
    False ->
      case field == "" {
        True -> parse_chars(rest, True, "", acc)
        False -> Error(Nil)
      }
    True ->
      case rest {
        ["\"", ..more] -> parse_chars(more, True, field <> "\"", acc)
        [",", ..more] -> parse_chars(more, False, "", [field, ..acc])
        [] -> Ok(list.reverse([field, ..acc]))
        _ -> Error(Nil)
      }
  }
}
