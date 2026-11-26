# Agent notes

Prove a change with [verify-grow-assist](.agents/skills/verify-grow-assist/SKILL.md), then follow [Ready to merge](CONTRIBUTING.md#ready-to-merge) before opening a pull request. The skill is plain markdown in this repository. It is not a bot skill-store entry.

## Stack

Gleam on the BEAM. The server in `src/` is Wisp and Mist. The browser UI in `client/` is Lustre and targets JavaScript. `shared/` holds the analysis types, the prompt filler, and the shell view, and both the server and `client/` import it.

## ReqLLM

One thin, tested Elixir wrapper is the only ReqLLM surface.

- Option maps use atom keys.
- Raises become `{:error, _}`.
- `generate_object` is decoded into Gleam types with `gleam/dynamic`.

Agents must not invent their own `@external` bindings.

## API keys

Keys are bring-your-own. The browser holds the key and sends it on each request. The server never persists the key and never logs it.

## How to prove work

- Types and static checks: `gleam format --check`, `gleam test`, and `gleam build` in the repository root, `shared/`, and `client/`.
- Property tests with qcheck where a property covers more than another hand-picked example.
- End to end, as the user, on the running server.
