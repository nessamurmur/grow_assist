---
name: verify-grow-assist
description: Install Gleam, Erlang, Elixir, Hex, and rebar3, then format, test, build, bundle the client, curl the server, build the Docker image, and check the Fly deploy in yyz.
---

# Verify Grow Assist

Run this on the branch you are about to open. Paste the `gleam format --check`, `gleam test`, and `gleam build` output for each package, plus a `curl` of the running server, into the pull request description. [Ready to merge](../../../CONTRIBUTING.md#ready-to-merge) is the merge bar.

The commands below check the app as it exists today.

## Prerequisites

Install Gleam, Erlang/OTP 28 or 29, Elixir, Hex, and rebar3. Put all five on `PATH`.

`rebar3` is required. `gleam build` in the repository root compiles `hpack_erl` (a Mist dependency) with it, and that build fails when `rebar3` is missing. The README Development section already says to install rebar3 and keep it on `PATH`.

Elixir and Hex are required on a machine that builds the Docker image, and they are what the ReqLLM wrapper will use. The Gleam packages do not call Elixir yet. The runtime image does not include Elixir. Gleam downloads its own Hex packages; `mix local.hex` is the Elixir Hex client the Docker build stage installs.

Versions below match the Dockerfile: Gleam 1.19.2, OTP 29.1.1, Elixir 1.20.5, rebar3 3.28.0. OTP 28 is also fine for the Gleam commands.

### Install on Ubuntu 24.04 (x86_64)

Other systems can use another installer. The tools still have to end up on `PATH` at a compatible version. `unzip` is used for the Elixir archive.

```sh
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

curl -fsSL -o "$HOME/.local/bin/rebar3" \
  https://github.com/erlang/rebar3/releases/download/3.28.0/rebar3
echo "5a28b1cca082d3b023ec0f5df9d9f9d52557036c6f2a21c1ffa11b93a984dd42  $HOME/.local/bin/rebar3" | sha256sum -c -
chmod +x "$HOME/.local/bin/rebar3"

export PATH="$HOME/.local/OTP-29.1.1/bin:$HOME/.local/elixir/bin:$HOME/.local/bin:$PATH"
mix local.hex --force
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

Run these three commands in the repository root, then in `shared/`, then in `client/`:

```sh
gleam format --check
gleam test
gleam build
```

`client/` is the JavaScript target and runs its tests on Node.

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

The server listens on `0.0.0.0:8080`. Set `PORT` to use another port. In another shell:

```sh
curl -fsS -D - http://127.0.0.1:8080/ -o /tmp/grow-assist.html
```

Expect `HTTP/1.1 200` and an HTML document titled Grow Assist. `GET /` is the shell page. Paths under `/static` serve files from `priv/static`. Any other path is a 404, including `/analyze`. There is no analyze route.

The HTML references `/static/client.js`. After the bundle step above, that path is served. Stop the server when you are done.

## Docker image

From the repository root, with Docker:

```sh
docker build -t grow-assist:local .
```

This is the two-stage image from the Gleam Fly guide, with Elixir, Hex, and rebar3 in the build stage. The runtime stage is Alpine Erlang. The Dockerfile runs `gleam export erlang-shipment`. It does not build the Lustre bundle.

`priv/static/client.js` is gitignored and is not listed in `.dockerignore`. A clean checkout, which is what GitHub deploys, has no `client.js` in the image. A local `docker build` after the bundle step above includes the file you just wrote, because `COPY .` sends it and `gleam export erlang-shipment` packs it at `grow_assist/priv/static/client.js`. The page still references `/static/client.js`. Building that file inside the image is a later change.

## Live deploy

The app is [https://grow-assist.fly.dev](https://grow-assist.fly.dev). `fly.toml` sets `primary_region = "yyz"`. Machines stop when idle and start on the next request, so give the first request time.

```sh
curl -fsS -D - --retry 5 --retry-all-errors --max-time 90 \
  https://grow-assist.fly.dev/ -o /tmp/grow-assist-live.html
fly status -a grow-assist
```

`fly status` needs a logged-in `fly` (or `flyctl`) that can read the `grow-assist` app. The machine should be in region `yyz`. Pushes to `main` deploy through [`.github/workflows/fly-deploy.yml`](../../../.github/workflows/fly-deploy.yml). That workflow skips until the `FLY_API_TOKEN` Actions secret is set.

## Later M1 tickets

Later M1 tickets extend this skill as features land. Add the new check in the same change as the feature, once that feature is in the tree.

The ReqLLM wrapper, CSV upload, browser-held provider settings, the analyze page, the GitHub Actions Gleam checks (NES-152), and building `client.js` inside the Docker image are not steps above yet.
