#!/bin/sh
# Compile the ReqLLM wrapper and its Elixir dependencies for local Gleam tests.
set -eu
cd "$(dirname "$0")/../elixir"
mix deps.get
mix compile
