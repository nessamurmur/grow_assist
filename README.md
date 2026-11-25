# Grow Assist

This is a toy application to help new indoor cannabis growers optimize conditions in their grow tent.

It takes environmental data and gives about three suggestions of improvements to make, sometimes suggesting a relevant product.

The advice still needs prompt work. It should talk about the tent in plain language, for example telling a grower the air is too humid and what to change, with a product link when one would help. Analysis is not connected yet: this repository is the Gleam shell that later work will fill in.

## Development

Install Gleam and Erlang/OTP 28 or 29, then from the repository root:

```sh
gleam run
```

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

## Layout

- `src/` is the Wisp and Mist server.
- `client/` is the Lustre application.
- `shared/` holds the analysis types, the prompt filler, and the shell view.
- `priv/system_prompt.txt` and `priv/product_links.csv` are the prompt and catalog carried over from the previous app.
