#!/bin/sh
# One real analyze call against a running Grow Assist server.
# The Ollama bearer key is read from GROW_ASSIST_OLLAMA_TEST_KEY and is never printed.
#
#   GROW_ASSIST_OLLAMA_TEST_KEY=... scripts/live-check.sh http://127.0.0.1:8080
#   GROW_ASSIST_OLLAMA_TEST_KEY=... scripts/live-check.sh https://grow-assist.fly.dev
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: scripts/live-check.sh BASE_URL" >&2
  exit 2
fi

if [ -z "${GROW_ASSIST_OLLAMA_TEST_KEY:-}" ]; then
  echo "Set GROW_ASSIST_OLLAMA_TEST_KEY to the Ollama bearer key." >&2
  exit 2
fi

base=$1

python3 - "$base" <<'PY'
import json
import os
import sys
import urllib.error
import urllib.request

base = sys.argv[1].rstrip("/")
key = os.environ["GROW_ASSIST_OLLAMA_TEST_KEY"]
readings = "\n".join([
    "time,temp_f,humidity_pct,vpd",
    "2026-11-26T00:00:00Z,82,68,1.4",
    "2026-11-26T00:05:00Z,83,70,1.5",
])
payload = json.dumps({
    "stage": "flowering",
    "readings": readings,
    "api_key": key,
}).encode()
request = urllib.request.Request(
    base + "/analyze",
    data=payload,
    headers={"content-type": "application/json"},
    method="POST",
)

try:
    with urllib.request.urlopen(request, timeout=90) as response:
        body = response.read().decode()
        status = response.status
except urllib.error.HTTPError as error:
    body = error.read().decode(errors="replace")
    status = error.code
except urllib.error.URLError as error:
    print(f"request failed: {error.reason}", file=sys.stderr)
    sys.exit(1)

redacted = body.replace(key, "[redacted]") if key else body
print(redacted)
if key and key in body:
    print("response contained the API key", file=sys.stderr)
    sys.exit(1)

try:
    data = json.loads(body)
except json.JSONDecodeError:
    print(f"response was not JSON (HTTP {status})", file=sys.stderr)
    sys.exit(1)

summary = data.get("summary") if isinstance(data, dict) else None
recommendations = data.get("recommendations") if isinstance(data, dict) else None
if not isinstance(summary, str) or not summary.strip():
    print("missing summary", file=sys.stderr)
    sys.exit(1)
if not isinstance(recommendations, list) or len(recommendations) not in (2, 3):
    print("expected 2 or 3 recommendations", file=sys.stderr)
    sys.exit(1)

links = []
for recommendation in recommendations:
    product = recommendation.get("product") if isinstance(recommendation, dict) else None
    if isinstance(product, dict):
        url = product.get("url")
        if isinstance(url, str) and url.startswith("http"):
            links.append(url)
if not links:
    print("expected at least one product link", file=sys.stderr)
    sys.exit(1)

print(
    f"ok: HTTP {status}, {len(recommendations)} recommendations, {len(links)} product link(s)",
    file=sys.stderr,
)
PY
