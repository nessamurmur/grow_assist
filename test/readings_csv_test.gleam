import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleeunit
import qcheck
import simplifile
import wisp

import grow_assist/readings_csv

pub fn main() {
  gleeunit.main()
}

const fixture =
  "time,temperature,humidity,ppfd,soil_moisture,vpd
2026-11-26T00:00:00Z,82,68,450,42,1.4
2026-11-26T00:05:00Z,83,70,440,41,1.5
2026-11-26T00:10:00Z,81,66,460,43,1.35
"

type Sample {
  Sample(
    temp_f: Option(Int),
    temp_c: Option(Int),
    humidity: Option(Int),
    ppfd: Option(Int),
    soil: Option(Int),
    extra: Option(String),
  )
}

pub fn fixture_file_parses_and_round_trips_test() {
  let assert Ok(priv) = wisp.priv_directory("grow_assist")
  let assert Ok(text) = simplifile.read(priv <> "/fixtures/tent-readings.csv")
  assert text == fixture
  let assert Ok(rows) = readings_csv.parse(text)
  assert list.length(rows) == 3
  let assert [first, _, _] = rows
  assert first.temperature == Some(readings_csv.Fahrenheit(82.0))
  assert first.humidity_pct == Some(68.0)
  assert first.ppfd == Some(450.0)
  assert first.soil_moisture_pct == Some(42.0)
  assert first.extras == [#("time", "2026-11-26T00:00:00Z"), #("vpd", "1.4")]
  let assert Ok(again) = readings_csv.parse(readings_csv.render(rows))
  assert again == rows
}

pub fn aliases_and_celsius_marker_are_accepted_test() {
  let csv =
    "temp_f,humidity %,light,soil moisture,co2
78,60%,500,30,800
25 C,70,400,28,700
"
  let assert Ok(rows) = readings_csv.parse(csv)
  let assert [first, second] = rows
  assert first.temperature == Some(readings_csv.Fahrenheit(78.0))
  assert first.humidity_pct == Some(60.0)
  assert second.temperature == Some(readings_csv.Celsius(25.0))
  assert list.any(first.extras, fn(extra) { extra == #("co2", "800") })
  let assert Ok(again) = readings_csv.parse(readings_csv.render(rows))
  assert again == rows
}

pub fn quoted_extra_with_a_comma_round_trips_test() {
  let csv =
    "temperature,note
82,\"a,b\"
"
  let assert Ok(rows) = readings_csv.parse(csv)
  let assert [row] = rows
  assert row.extras == [#("note", "a,b")]
  let assert Ok(again) = readings_csv.parse(readings_csv.render(rows))
  assert again == rows
}

pub fn garbage_without_a_known_column_is_rejected_test() {
  assert readings_csv.parse("hello\nthis is not a csv")
    == Error(readings_csv.NoKnownColumn)
  assert readings_csv.parse("foo,bar\n1,2") == Error(readings_csv.NoKnownColumn)
  assert readings_csv.parse("temperature\n") == Error(readings_csv.NoReadings)
  assert readings_csv.parse("\"unterminated") == Error(readings_csv.Unreadable)
  assert readings_csv.parse("") == Error(readings_csv.NoReadings)
}

pub fn generated_rows_round_trip_test() {
  let samples =
    qcheck.bounded_int(1, 4)
    |> qcheck.then(qcheck.fixed_length_list_from(sample_generator(), _))
    |> qcheck.map(list.map(_, ensure_known))
  use samples <- qcheck.given(samples)
  let assert Ok(rows) = readings_csv.parse(sample_csv(samples))
  let assert Ok(again) = readings_csv.parse(readings_csv.render(rows))
  assert again == rows
  assert list.length(rows) == list.length(samples)
}

pub fn digit_garbage_is_rejected_test() {
  use text <- qcheck.given(qcheck.string_from(qcheck.ascii_digit_codepoint()))
  case readings_csv.parse(text) {
    Error(_) -> Nil
    Ok(_) -> panic as "digits parsed as tent readings"
  }
}

pub fn unknown_columns_are_rejected_test() {
  let header =
    qcheck.non_empty_string_from(qcheck.lowercase_ascii_codepoint())
    |> qcheck.map(fn(word) { "x" <> word })
  let table =
    qcheck.bounded_int(1, 3)
    |> qcheck.then(qcheck.fixed_length_list_from(header, _))
    |> qcheck.then(fn(headers) {
      let cell = qcheck.bounded_int(0, 50) |> qcheck.map(int.to_string)
      qcheck.bounded_int(1, 3)
      |> qcheck.then(fn(height) {
        qcheck.fixed_length_list_from(
          qcheck.fixed_length_list_from(cell, list.length(headers)),
          height,
        )
        |> qcheck.map(fn(rows) { #(headers, rows) })
      })
    })
  use #(headers, rows) <- qcheck.given(table)
  let csv =
    [string.join(headers, ","), ..list.map(rows, string.join(_, ","))]
    |> string.join("\n")
  assert readings_csv.parse(csv) == Error(readings_csv.NoKnownColumn)
}

fn sample_generator() -> qcheck.Generator(Sample) {
  qcheck.tuple6(
    qcheck.option_from(qcheck.bounded_int(32, 100)),
    qcheck.option_from(qcheck.bounded_int(10, 40)),
    qcheck.option_from(qcheck.bounded_int(20, 90)),
    qcheck.option_from(qcheck.bounded_int(0, 1500)),
    qcheck.option_from(qcheck.bounded_int(0, 100)),
    qcheck.option_from(
      qcheck.non_empty_string_from(qcheck.lowercase_ascii_codepoint()),
    ),
  )
  |> qcheck.map(fn(values) {
    let #(temp_f, temp_c, humidity, ppfd, soil, extra) = values
    Sample(temp_f:, temp_c:, humidity:, ppfd:, soil:, extra:)
  })
}

fn ensure_known(sample: Sample) -> Sample {
  case sample.temp_f, sample.temp_c, sample.humidity, sample.ppfd, sample.soil {
    None, None, None, None, None -> Sample(..sample, humidity: Some(55))
    _, _, _, _, _ -> sample
  }
}

fn sample_csv(samples: List(Sample)) -> String {
  let lines =
    list.map(samples, fn(sample) {
      string.join(
        [
          cell(sample.temp_f),
          cell(sample.temp_c),
          cell(sample.humidity),
          cell(sample.ppfd),
          cell(sample.soil),
          case sample.extra {
            Some(value) -> value
            None -> ""
          },
        ],
        ",",
      )
    })
  string.join(
    [
      "temperature_f,temperature_c,humidity_pct,ppfd,soil_moisture,note",
      ..lines
    ],
    "\n",
  )
}

fn cell(value: Option(Int)) -> String {
  case value {
    Some(value) -> int.to_string(value)
    None -> ""
  }
}
