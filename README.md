# Grow Assist

This is a toy application to help new indoor cannabis growers optimize conditions in their grow tent.

It takes environmental data and gives about three suggestions of improvements to make, sometimes suggesting a relevant product.

The advice still needs prompt work. It should talk about the tent in plain language, for example telling a grower the air is too humid and what to change, with a product link when one would help. A grower picks a growth stage, pastes readings and an Ollama API key, and presses Analyze. The model is `inkling-2-small` on hosted Ollama. The key stays in the browser and is sent only on that request.

## Development

Install Gleam, rebar3, and Erlang/OTP 28 or 29, then from the repository root:

```sh
gleam run
```

`rebar3` has to be on `PATH`. Gleam uses it to compile rebar3 packages such as `hpack_erl`, which Mist depends on.

The server listens on `0.0.0.0:8080`. Set `PORT` to use a different port.

API keys are bring-your-own and stay in the browser. The server does not store or log them.

The page is server-rendered. To also build the Lustre browser bundle the page loads from `/static/client.js`:

```sh
cd client
gleam run -m lustre/dev build --outdir=../priv/static --no-html
```

## Checks

Run these in the repository root, `shared/`, and `client/`:

```sh
gleam format --check
gleam test
gleam build
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the merge checks.

## Deploy

The latest commit on `main` deploys to [Fly.io](https://fly.io) in Toronto (`yyz`) through [`.github/workflows/fly-deploy.yml`](.github/workflows/fly-deploy.yml) after CI succeeds on it. Re-running CI for an older commit does not deploy. There is no versioning yet. The deploy job fails if the `FLY_API_TOKEN` Actions secret is missing.

One `shared-cpu-1x` machine with 256 MB stops when it is idle and starts on the next request. The workflow deploys with `flyctl deploy --remote-only --ha=false`, because `flyctl deploy` otherwise creates a second machine on the first deploy, and both root filesystems stay billable after they stop. There is no volume, no database, and no server-side secret. API keys stay in the browser.

Create the app once, from this repository, without deploying. `fly.toml` is already committed, and its `primary_region` is `yyz`.

```sh
fly auth login
fly apps create grow-assist
```

`fly launch` can do the same create, but its default is a second high-availability machine and it will offer Postgres. Skip those:

```sh
fly launch --no-deploy --copy-config --yes --name grow-assist --region yyz --ha=false --no-db --no-redis --no-object-storage --no-github-workflow
```

Fly app names are global. If `grow-assist` is taken, pick another name and change `app` in `fly.toml`.

Create a deploy token and store the whole value, including the `FlyV1 ` prefix, as the `FLY_API_TOKEN` repository secret (Settings → Secrets and variables → Actions):

```sh
fly tokens create deploy -a grow-assist
```

The next push to `main` deploys. Read the logs with:

```sh
fly logs -a grow-assist
```

The runtime image is the Alpine Erlang image from the [Gleam Fly guide](https://gleam.run/deployment/fly/), plus the Elixir standard library and the compiled ReqLLM wrapper. Elixir, Hex, and rebar3 in the build stage compile that wrapper and the browser bundle.

Build and run the production image locally. It listens on port 8080.

```sh
docker build -t grow-assist:local .
docker run --rm -p 8080:8080 grow-assist:local
```

With a hosted Ollama key in the environment, one real analyze against that process or against production:

```sh
GROW_ASSIST_OLLAMA_TEST_KEY=... scripts/live-check.sh http://127.0.0.1:8080
GROW_ASSIST_OLLAMA_TEST_KEY=... scripts/live-check.sh https://grow-assist.fly.dev
```

The script prints the response and never the key. It exits non-zero unless the response has a summary, 2 or 3 recommendations, and at least one product link. Root package tests need the wrapper compiled first: `scripts/compile-wrapper.sh`, then `ERL_LIBS` set to `elixir/_build/dev/lib` and the Elixir `lib` directory. The verify skill has the exact commands.

## Layout

- `src/` is the Wisp and Mist server.
- `client/` is the Lustre application.
- `shared/` holds the analysis types, the prompt filler, and the shell view.
- `priv/system_prompt.txt` and `priv/product_links.csv` are the prompt and catalog carried over from the previous app.
