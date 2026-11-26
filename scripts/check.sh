#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

update=0
packages=""
for arg in "$@"; do
  case "$arg" in
    --update-lint-baseline) update=1 ;;
    root|shared|client)
      case " $packages " in
        *" $arg "*) ;;
        *) packages="$packages $arg" ;;
      esac
      ;;
    *)
      echo "usage: scripts/check.sh [--update-lint-baseline] [root|shared|client]..." >&2
      exit 2
      ;;
  esac
done

if [ -z "$packages" ]; then
  packages="root shared client"
fi

case " $packages " in
  *" root "*)
    scripts/compile-wrapper.sh
    elixir_lib=$(elixir -e 'IO.puts(:code.lib_dir(:elixir) |> Path.dirname())')
    ERL_LIBS="$root/elixir/_build/dev/lib:$elixir_lib${ERL_LIBS:+:$ERL_LIBS}"
    export ERL_LIBS
    ;;
esac

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

set --
if [ "$update" -eq 1 ]; then
  set -- --update
fi

for pkg in $packages; do
  if [ "$pkg" = "root" ]; then
    dir=$root
  else
    dir=$root/$pkg
  fi
  echo "== $pkg gleam format --check =="
  (cd "$dir" && gleam format --check)
  echo "== $pkg gleam build --warnings-as-errors =="
  (cd "$dir" && gleam build --warnings-as-errors)
  echo "== $pkg gleam test =="
  (cd "$dir" && gleam test)
  echo "== $pkg glinter =="
  (cd "$dir" && gleam run -m glinter -- --format json > "$tmpdir/$pkg.json")
  set -- "$@" "$pkg=$tmpdir/$pkg.json"
done

scripts/lint-ratchet.sh "$@"
