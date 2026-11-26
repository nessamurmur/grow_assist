# Two-stage build from the Gleam Fly guide:
# https://gleam.run/deployment/fly/
#
# The guide pins Gleam 1.8 and OTP 27. This app targets OTP 28 or 29, so both
# stages use the OTP 29.1.1 Alpine image that ships with Gleam 1.19.2.
#
# Elixir, Hex, and rebar3 are installed in the build stage. rebar3 compiles
# Erlang packages such as hpack_erl. Elixir compiles the ReqLLM wrapper.
# The runtime stage stays Alpine Erlang and does not include mix, but it does
# include the Elixir standard library: ReqLLM is Elixir and is not bundled
# into the Gleam shipment. The browser bundle is built here too, because
# priv/static/client.js is gitignored and a clean deploy would otherwise 404 it.

FROM erlang:29.1.1.0-alpine AS build

COPY --from=ghcr.io/gleam-lang/gleam:v1.19.2-erlang-alpine /bin/gleam /bin/gleam

ARG ELIXIR_VERSION=1.20.5
ARG ELIXIR_SHA256=f424d6f0bb710a1d4898f2645d8ad6cab3f5eab8d71848c0dda2579d3a8e8a06
# The Erlang image already sets REBAR3_VERSION=3.27.0 and ships that binary.
# An ARG of the same name would be ignored, so this pin uses a different name
# and replaces the bundled rebar3.
ARG REBAR_VERSION=3.28.0
ARG REBAR_SHA256=5a28b1cca082d3b023ec0f5df9d9f9d52557036c6f2a21c1ffa11b93a984dd42

RUN apk add --no-cache ca-certificates curl unzip \
  && curl -fsSL -o /tmp/elixir.zip \
    "https://github.com/elixir-lang/elixir/releases/download/v${ELIXIR_VERSION}/elixir-otp-29.zip" \
  && echo "${ELIXIR_SHA256}  /tmp/elixir.zip" | sha256sum -c - \
  && unzip -q /tmp/elixir.zip -d /usr/local \
  && rm /tmp/elixir.zip \
  && chmod +x /usr/local/bin/elixir /usr/local/bin/elixirc /usr/local/bin/iex /usr/local/bin/mix \
  && mix local.hex --force \
  && curl -fsSL -o /usr/local/bin/rebar3 \
    "https://github.com/erlang/rebar3/releases/download/${REBAR_VERSION}/rebar3" \
  && echo "${REBAR_SHA256}  /usr/local/bin/rebar3" | sha256sum -c - \
  && chmod +x /usr/local/bin/rebar3 \
  && gleam --version \
  && elixir --version \
  && mix --version \
  && rebar3 version

COPY . /app/

# client.js has to exist before `gleam export erlang-shipment` packs priv/.
# Lustre joins --outdir onto the client project root, so this path is relative.
RUN cd /app/client \
  && gleam run -m lustre/dev build --outdir=../priv/static --no-html \
  && test -s /app/priv/static/client.js

RUN cd /app/elixir \
  && mix deps.get --only prod \
  && MIX_ENV=prod mix compile

# The shipment entrypoint puts /app/*/ebin on the code path. Each Elixir app
# has to sit next to the Gleam apps, not inside a nested lib directory.
RUN cd /app && gleam export erlang-shipment \
  && elixir_lib=$(elixir -e 'IO.puts(:code.lib_dir(:elixir) |> Path.dirname())') \
  && dest=/app/build/erlang-shipment \
  && for app in elixir eex logger; do \
       cp -a "$elixir_lib/$app" "$dest/$app"; \
     done \
  && for app in /app/elixir/_build/prod/lib/*; do \
       name=$(basename "$app"); \
       if [ ! -d "$dest/$name" ]; then \
         cp -a "$app" "$dest/$name"; \
       fi; \
     done \
  && test -f "$dest/elixir/ebin/Elixir.Application.beam" \
  && test -f "$dest/grow_assist_req_llm/ebin/Elixir.GrowAssist.ReqLlm.beam" \
  && test -f "$dest/req_llm/ebin/Elixir.ReqLLM.beam"

FROM erlang:29.1.1.0-alpine

# The Fly guide's `adduser --system webapp -g webapp` is Debian adduser. On
# this Alpine image those flags create the user in nogroup: busybox uses -g
# for GECOS and -G for the login group. -S/-G is the same non-root system user.
# The base image also ships rebar3 3.27.0. The server does not invoke it.
# Elixir's compiler is not installed in this stage. The shipment lib copied
# above includes the Elixir standard library and the compiled ReqLLM beams.
RUN addgroup -S webapp && adduser -S -D -H -G webapp webapp

USER webapp
COPY --from=build /app/build/erlang-shipment /app
WORKDIR /app
ENV PORT=8080
EXPOSE 8080
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
