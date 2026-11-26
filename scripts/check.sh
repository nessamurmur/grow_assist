#!/bin/sh
set -eu
root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

known="root shared client"
update=0
packages=""
for arg in "$@"; do
  case "$arg" in
    --update-lint-baseline) update=1 ;;
    *)
      case " $known " in
        *" $arg "*)
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
      ;;
  esac
done

if [ -z "$packages" ]; then
  packages=$known
fi

# Every gleam.toml outside build/, _build/, and deps/ must be a known package
# with a lint-baseline.json entry. This runs even when one package is named.
python3 - "$root" "$update" $known <<'PY'
import json
import os
import sys

root = sys.argv[1]
update = sys.argv[2] == "1"
known = sys.argv[3:]
allowed = {}
for name in known:
    path = "gleam.toml" if name == "root" else "%s/gleam.toml" % name
    allowed[path] = name
skip = {"build", "_build", "deps", ".git"}
found = []
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [name for name in dirnames if name not in skip]
    if "gleam.toml" not in filenames:
        continue
    rel = os.path.relpath(os.path.join(dirpath, "gleam.toml"), root)
    found.append(rel.replace(os.sep, "/"))

unknown = sorted(path for path in found if path not in allowed)
if unknown:
    sys.stderr.write("unknown Gleam package\n")
    for path in unknown:
        sys.stderr.write("  %s\n" % path)
    sys.stderr.write("scripts/check.sh checks %s\n" % ", ".join(known))
    sys.exit(1)

baseline_path = os.path.join(root, "lint-baseline.json")
if not os.path.exists(baseline_path):
    if update:
        sys.exit(0)
    names = sorted(allowed[path] for path in found)
    if names:
        sys.stderr.write("lint-baseline.json has no entry for %s\n" % ", ".join(names))
    else:
        sys.stderr.write("lint-baseline.json has no package entries\n")
    sys.exit(1)
try:
    baseline = json.load(open(baseline_path, encoding="utf-8"))
except json.JSONDecodeError as error:
    sys.stderr.write("cannot parse lint-baseline.json (%s)\n" % error)
    sys.exit(1)
if not isinstance(baseline, dict):
    sys.stderr.write("lint-baseline.json has no package entries\n")
    sys.exit(1)
missing = sorted(allowed[path] for path in found if allowed[path] not in baseline)
if missing:
    sys.stderr.write("lint-baseline.json has no entry for %s\n" % ", ".join(missing))
    sys.exit(1)
PY

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
