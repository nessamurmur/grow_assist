---
name: verify-grow-assist
description: Install Gleam, Erlang, Elixir, Hex, and rebar3, then format, test, build, bundle the client, curl the server, build the Docker image, and check the Fly deploy in yyz.
---

# Verify Grow Assist

Run this on the branch you are about to open. Paste the `scripts/check.sh` output, plus a `curl` of the running server when the change has a user-visible result, into the pull request description. [Ready to merge](../../../CONTRIBUTING.md#ready-to-merge) is the merge bar.

The commands below check the app as it exists today.

## Prerequisites

Install Gleam, Erlang/OTP 28 or 29, Elixir, Hex, and rebar3. Put all five on `PATH`.

`rebar3` is required. `gleam build` in the repository root compiles `hpack_erl` (a Mist dependency) with it, and that build fails when `rebar3` is missing. The README Development section already says to install rebar3 and keep it on `PATH`.

Elixir and Hex are required on a machine that builds the Docker image or runs the root package tests. The ReqLLM wrapper is Elixir. Gleam downloads its own Hex packages; `mix local.hex` is the Elixir Hex client the Docker build stage installs. The runtime image includes the Elixir standard library and the compiled wrapper, not the Elixir compiler.

Versions below match the Dockerfile: Gleam 1.19.2, OTP 29.1.1, Elixir 1.20.5, rebar3 3.28.0. OTP 28 is also fine for the Gleam commands.

### Install on Ubuntu 24.04 (x86_64)

Other systems can use another installer. The tools still have to end up on `PATH` at a compatible version. `unzip` is used for the Elixir archive.

A checksum mismatch stops the block before that archive is unpacked or put on `PATH`.

```sh
set -euo pipefail
mkdir -p "$HOME/.local/bin"
tmp=$(mktemp -d)

curl -fsSL -o "$tmp/OTP-29.1.1.tar.gz" \
  https://builds.hex.pm/builds/otp/amd64/ubuntu-24.04/OTP-29.1.1.tar.gz
echo "35186bdae840028df621d14f3a75c68eb52eea90fabd500f7946a5d74bdaf11b  $tmp/OTP-29.1.1.tar.gz" | sha256sum -c -
tar -xzf "$tmp/OTP-29.1.1.tar.gz" -C "$HOME/.local"
"$HOME/.local/OTP-29.1.1/Install" -minimal "$HOME/.local/OTP-29.1.1"

curl -fsSL -o "$tmp/gleam.tar.gz" \
  https://github.com/gleam-lang/gleam/releases/download/v1.19.2/gleam-v1.19.2-x86_64-unknown-linux-musl.tar.gz
echo "2ba2afb66ca9f6dcc01a4a6e9169b6942963bad6483bec9571ddc078cfe6f41f  $tmp/gleam.tar.gz" | sha256sum -c -
tar -xzf "$tmp/gleam.tar.gz" -C "$HOME/.local/bin"
chmod +x "$HOME/.local/bin/gleam"

curl -fsSL -o "$tmp/elixir.zip" \
  https://github.com/elixir-lang/elixir/releases/download/v1.20.5/elixir-otp-29.zip
echo "f424d6f0bb710a1d4898f2645d8ad6cab3f5eab8d71848c0dda2579d3a8e8a06  $tmp/elixir.zip" | sha256sum -c -
unzip -q -o "$tmp/elixir.zip" -d "$HOME/.local/elixir"

curl -fsSL -o "$tmp/rebar3" \
  https://github.com/erlang/rebar3/releases/download/3.28.0/rebar3
echo "5a28b1cca082d3b023ec0f5df9d9f9d52557036c6f2a21c1ffa11b93a984dd42  $tmp/rebar3" | sha256sum -c -
install -m 755 "$tmp/rebar3" "$HOME/.local/bin/rebar3"

export PATH="$HOME/.local/OTP-29.1.1/bin:$HOME/.local/elixir/bin:$HOME/.local/bin:$PATH"
mix local.hex --force
set +e
set +u
set +o pipefail
```

Confirm:

```sh
gleam --version
erl -eval 'io:format("~s~n",[erlang:system_info(otp_release)]),halt().' -noshell
elixir --version
rebar3 version
mix hex.info
```

Expect Gleam 1.19.2, OTP 29, Elixir 1.20.5, rebar3 3.28.0, and a Hex version line.

## Format, test, and build

`scripts/check.sh` is the local gate. It checks the repository root, `shared/`, and `client/`. In each package it runs `gleam format --check`, `gleam build --warnings-as-errors`, `gleam test`, and glinter. It compares glinter's per-rule counts with `lint-baseline.json`. A count above the baseline fails the script. `scripts/check.sh --update-lint-baseline` writes a lower baseline and refuses to raise one.

The root tests call the ReqLLM wrapper. `scripts/check.sh` compiles that wrapper and puts its beams and the Elixir standard library on `ERL_LIBS` before those tests. `shared/` and `client/` do not use the wrapper.

```sh
scripts/check.sh
```

`client/` is the JavaScript target and runs its tests on Node.

The root tests are the mocked wrapper path. They do not call Ollama. They cover a raise becoming `Error(...)` without a process crash, an atom-key option map for hosted Ollama (`inkling-2-small` at `https://ollama.com/v1`), a mocked object decoding to the analysis type, and a canary key that must not appear in the captured server logs or the HTTP body. `shared/` qcheck covers the JSON decoder: arbitrary text decodes only when the summary, 2 or 3 recommendations, and product-link rules hold, and generated valid responses round-trip.

## Client bundle

The shell page loads `/static/client.js`. That file is gitignored. Build it from `client/`:

```sh
cd client
gleam run -m lustre/dev build --outdir=../priv/static --no-html
```

The command writes `priv/static/client.js`. `priv/static/styles.css` is already in git.

## Server

From the repository root:

```sh
gleam run
```

The server listens on `0.0.0.0` and port 8080, or on `PORT` when that variable is set for `gleam run`. Export that same `PORT` in the probe shell. An unset `PORT` probes 8080.

```sh
curl -fsS -D - "http://127.0.0.1:${PORT:-8080}/" -o /tmp/grow-assist.html
```

Expect `HTTP/1.1 200` and an HTML document titled Grow Assist. `GET /` is the shell page, with a growth stage, a readings box, an API key field, and an Analyze button. Paths under `/static` serve files from `priv/static`. `GET /analyze` is a 404. `POST /analyze` is the JSON analyze route.

The HTML references `/static/client.js`. After the bundle step above, that path is served. Stop the server when you are done.

A mocked analyze, without an Ollama key, is the root test `post_analyze_returns_a_recommendation_test`. It posts a stage, readings, and a key to the route with a stubbed wrapper. The canary test in the same file posts a distinctive key and checks that the key is absent from the response and from the logger output captured around the request.

## Docker image

From the repository root, with Docker. The image listens on port 8080.

```sh
docker build -t grow-assist:local .
docker run --rm -p 8080:8080 grow-assist:local
```

This is the two-stage image from the Gleam Fly guide, with Elixir, Hex, and rebar3 in the build stage. The build stage compiles `client/`, so `/static/client.js` is in the image even from a clean checkout. It also compiles the ReqLLM wrapper. The runtime stage is Alpine Erlang plus the Elixir standard library and those compiled beams. It does not include mix.

`priv/static/client.js` is gitignored. The Dockerfile builds it before `gleam export erlang-shipment`, which packs it at `grow_assist/priv/static/client.js`.

Against that running container:

```sh
curl -fsS -D - http://127.0.0.1:8080/static/client.js -o /dev/null
```

Expect `HTTP/1.1 200`. Then open `http://127.0.0.1:8080/`, choose a stage, paste readings and a key, and press Analyze. A real recommendation needs `GROW_ASSIST_OLLAMA_TEST_KEY`:

```sh
GROW_ASSIST_OLLAMA_TEST_KEY=... scripts/live-check.sh http://127.0.0.1:8080
```

The script prints the JSON response, never the key, and exits non-zero unless the body has a summary, 2 or 3 recommendations, and at least one product link. The same command with `https://grow-assist.fly.dev` is the live user path after a deploy. There is no key in this environment, so that live call is for the person who holds the key.

## Live deploy

The app is [https://grow-assist.fly.dev](https://grow-assist.fly.dev). `fly.toml` sets `primary_region = "yyz"`. Machines stop when idle and start on the next request, so give the first request time. Pushes to `main` deploy through [`.github/workflows/fly-deploy.yml`](../../../.github/workflows/fly-deploy.yml).

```sh
curl -fsS -D - --retry 5 --retry-all-errors --max-time 90 \
  https://grow-assist.fly.dev/ -o /tmp/grow-assist-live.html
curl -fsS -D - --retry 5 --retry-all-errors --max-time 90 \
  https://grow-assist.fly.dev/static/client.js -o /dev/null
fly status -a grow-assist
GROW_ASSIST_OLLAMA_TEST_KEY=... scripts/live-check.sh https://grow-assist.fly.dev
```

`fly status` needs a logged-in `fly` (or `flyctl`) that can read the `grow-assist` app. The machine should be in region `yyz`. `live-check.sh` is the live user path: one flowering analyze with a small readings sample. It does not print the key. The machine stays `shared-cpu-1x` with 256 MB unless an analyze run runs out of memory.

## Later M1 tickets

Later M1 tickets extend this skill as features land. Add the new check in the same change as the feature, once that feature is in the tree.

CSV upload, a settings screen for provider and model, and the GitHub Actions Gleam checks (NES-152) are not steps above yet.
