#!/bin/sh
# Build the client, serve the app, and run the axe gate plus Lighthouse.
# No model is called and no API key is read.
set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"

if ! command -v gleam >/dev/null 2>&1; then
  if [ -x "$HOME/.local/bin/gleam" ]; then
    export PATH="$HOME/.local/OTP-29.1.1/bin:$HOME/.local/elixir/bin:$HOME/.local/bin:$PATH"
  fi
fi

(cd client && gleam run -m lustre/dev build --outdir=../priv/static --no-html)
test -s priv/static/client.js

port=${PORT:-8080}
base="http://127.0.0.1:${port}"
started=0
log=/tmp/grow-assist-a11y.log
pid=""

cleanup() {
  if [ "$started" -eq 1 ] && [ -n "$pid" ]; then
    kill "$pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if ! curl -fsS "$base/" -o /dev/null 2>/dev/null; then
  started=1
  PORT="$port" gleam run >"$log" 2>&1 &
  pid=$!
  ready=0
  i=0
  while [ "$i" -lt 120 ]; do
    if curl -fsS "$base/" -o /dev/null 2>/dev/null; then
      ready=1
      break
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      break
    fi
    i=$((i + 1))
    sleep 2
  done
  if [ "$ready" -ne 1 ]; then
    echo "grow assist did not serve $base" >&2
    cat "$log" >&2 || true
    exit 1
  fi
fi

cd "$root/a11y"
if [ ! -d node_modules/@playwright/test ]; then
  npm ci
fi
npx playwright install chromium

if [ -z "${CHROME_PATH:-}" ]; then
  CHROME_PATH=$(find "$HOME/.cache/ms-playwright" -type f -name chrome -path '*chrome-linux*' -print -quit || true)
  if [ -z "$CHROME_PATH" ] && [ -x /usr/bin/google-chrome ]; then
    CHROME_PATH=/usr/bin/google-chrome
  fi
  if [ -n "$CHROME_PATH" ]; then
    export CHROME_PATH
  fi
fi

export A11Y_BASE_URL="$base"
set +e
npx playwright test
axe_status=$?
npx lhci autorun
lighthouse_status=$?
set -e

if [ "$axe_status" -ne 0 ]; then
  exit "$axe_status"
fi
exit "$lighthouse_status"
