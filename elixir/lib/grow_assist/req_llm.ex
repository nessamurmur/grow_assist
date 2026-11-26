defmodule GrowAssist.ReqLlm do
  @moduledoc """
  The only ReqLLM surface for Grow Assist.

  Hosted Ollama needs `Authorization: Bearer`. ReqLLM's built-in `:ollama`
  provider skips that header (it targets a local server with no key), so this
  wrapper does not call it. The call goes through ReqLLM's OpenAI-compatible
  provider, with `base_url` `https://ollama.com/v1` and
  `openai_compatible_backend: :ollama`, which still sends the bearer key.

  Option maps use atom keys. Raises and Erlang errors become `{:error, _}`.
  `generate_object` runs first. The schema asks for the analysis shape. An
  object Gleam cannot decode is not returned: the same call falls back to
  JSON-mode text, which Gleam decodes with `gleam/dynamic` into the analysis
  types. The API key is not written to disk, not stored with `ReqLLM.put_key/2`,
  and is stripped from errors and log events for the duration of the call.
  """

  @provider :openai
  @backend :ollama
  @model "inkling-2-small"
  @base_url "https://ollama.com/v1"
  @temperature 0.2
  # inkling-2-small spends this budget on reasoning before the JSON.
  # 1200 stopped a real analyze mid-object (finish_reason length). 4000
  # finished that same prompt with finish_reason stop.
  @max_tokens 4000
  @receive_timeout 60_000
  @out_of_tokens "model ran out of tokens"

  @priorities ["high", "medium", "low", "high impact", "medium impact", "low impact"]

  # A map schema so the model is asked for minItems/maxItems. NimbleOptions
  # lists in this ReqLLM version do not carry a length into JSON Schema.
  @schema %{
    "type" => "object",
    "additionalProperties" => false,
    "required" => ["summary", "recommendations"],
    "properties" => %{
      "summary" => %{"type" => "string", "minLength" => 1},
      "recommendations" => %{
        "type" => "array",
        "minItems" => 2,
        "maxItems" => 3,
        "items" => %{
          "type" => "object",
          "additionalProperties" => false,
          "required" => ["title", "description", "priority"],
          "properties" => %{
            "title" => %{"type" => "string", "minLength" => 1},
            "description" => %{"type" => "string", "minLength" => 1},
            "priority" => %{"type" => "string", "enum" => @priorities},
            "product" => %{
              "anyOf" => [
                %{
                  "type" => "object",
                  "additionalProperties" => false,
                  "required" => ["name", "url"],
                  "properties" => %{
                    "name" => %{"type" => "string", "minLength" => 1},
                    "url" => %{"type" => "string", "minLength" => 1},
                    "price_range" => %{"type" => ["string", "null"]}
                  }
                },
                %{"type" => "null"}
              ]
            }
          }
        }
      }
    }
  }

  def analyze(api_key, system, user)
      when is_binary(api_key) and is_binary(system) and is_binary(user) do
    opts = options(api_key, system, user)

    guarded(api_key, fn ->
      call_req_llm(opts)
    end)
  end

  def analyze_with(api_key, system, user, generator)
      when is_binary(api_key) and is_binary(system) and is_binary(user) and
             is_function(generator, 1) do
    guarded(api_key, fn ->
      finish_object(read_generated(generator), fn ->
        require_usable(decode_json_text(generator.("json")))
      end)
    end)
  end

  def preview(api_key, system, user)
      when is_binary(api_key) and is_binary(system) and is_binary(user) do
    opts = options(api_key, system, user)
    true = Enum.all?(Map.keys(opts), &is_atom/1)

    {:ok,
     %{
       "keys" => opts |> Map.keys() |> Enum.map(&Atom.to_string/1) |> Enum.sort(),
       "model" => opts.model,
       "provider" => Atom.to_string(opts.provider),
       "backend" => Atom.to_string(opts.backend),
       "base_url" => opts.base_url,
       "key_matches" => opts.api_key == api_key,
       "system_matches" => opts.system_prompt == system,
       "user_matches" => opts.user == user,
       "max_tokens" => opts.max_tokens
     }}
  end

  @doc false
  def accept_model_text(finish, text) when is_binary(finish) and is_binary(text) do
    case classify_text(finish_reason(finish), text) do
      {:ok, json} ->
        case Jason.decode(json) do
          {:ok, map} when is_map(map) -> {:ok, map}
          _ -> {:error, "model JSON could not be decoded"}
        end

      {:error, :exhausted} ->
        {:error, @out_of_tokens}
    end
  end

  def raise_for_test do
    guarded("not-a-key", fn ->
      raise "provider exploded"
    end)
  end

  def schema_compiles do
    ensure_started!()

    case ReqLLM.Schema.compile(@schema) do
      {:ok, %{schema: schema}} -> {:ok, Jason.encode!(schema)}
      other -> {:error, public_error(inspect(other), "")}
    end
  end

  def capture(fun) when is_function(fun, 0) do
    parent = self()
    id = unique_logger_id("grow_assist_capture")
    previous = :logger.get_primary_config()
    :ok = :logger.update_primary_config(%{level: :all})

    :ok =
      :logger.add_handler(id, __MODULE__, %{
        id: id,
        level: :all,
        config: %{pid: parent}
      })

    try do
      {fun.(), drain_logs("")}
    after
      :logger.remove_handler(id)
      _ = :logger.set_primary_config(previous)
    end
  end

  @doc false
  def log(%{msg: msg}, config) do
    pid = logger_pid(config)
    if is_pid(pid), do: send(pid, {:grow_assist_log, render_msg(msg)})
    :ok
  end

  def log(_event, _config), do: :ok

  defp logger_pid(%{config: %{pid: pid}}), do: pid
  defp logger_pid(%{pid: pid}), do: pid
  defp logger_pid(_config), do: nil

  defp options(api_key, system, user) do
    %{
      provider: @provider,
      backend: @backend,
      model: @model,
      base_url: @base_url,
      api_key: api_key,
      system_prompt: system,
      user: user,
      temperature: @temperature,
      max_tokens: @max_tokens,
      receive_timeout: @receive_timeout
    }
  end

  defp call_req_llm(opts) do
    ensure_started!()

    model =
      ReqLLM.model!(%{
        provider: opts.provider,
        id: opts.model,
        base_url: opts.base_url,
        extra: %{openai_compatible_backend: opts.backend}
      })

    req_opts = [
      system_prompt: opts.system_prompt,
      api_key: opts.api_key,
      temperature: opts.temperature,
      max_tokens: opts.max_tokens,
      receive_timeout: opts.receive_timeout
    ]

    finish_object(safe_generate_object(model, opts.user, req_opts), fn ->
      require_usable(json_mode(model, opts, req_opts))
    end)
  end

  defp read_generated(generator) do
    try do
      case generator.("object") do
        json when is_binary(json) ->
          case Jason.decode(json) do
            {:ok, map} when is_map(map) -> {:ok, map}
            _ -> {:error, :invalid_json}
          end

        _ ->
          {:error, :invalid_json}
      end
    rescue
      error -> {:error, error}
    catch
      kind, reason -> {:error, {kind, reason}}
    end
  end

  defp finish_object({:ok, object}, fallback) do
    map = stringify(object)

    case usable?(map) do
      true -> map
      false -> fallback.()
    end
  end

  defp finish_object({:error, :exhausted}, _fallback), do: raise(@out_of_tokens)

  defp finish_object({:error, _reason}, fallback), do: fallback.()

  defp require_usable(map) do
    case usable?(map) do
      true -> map
      false -> raise "The model response did not match the analysis shape."
    end
  end

  defp usable?(map) when is_map(map) do
    case :"shared@analysis_json".decode_dynamic(map) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp safe_generate_object(model, user, req_opts) do
    case ReqLLM.generate_object(model, user, @schema, req_opts) do
      {:ok, response} ->
        if length_finish?(ReqLLM.Response.finish_reason(response)) do
          {:error, :exhausted}
        else
          case ReqLLM.Response.object(response) do
            nil -> {:error, :empty_object}
            object -> {:ok, object}
          end
        end

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    error -> {:error, error}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp json_mode(model, opts, req_opts) do
    prompt =
      opts.user <>
        "\n\nReturn only one JSON object, with no markdown. Keys: summary (string) and recommendations (array of 2 or 3 objects with title, description, priority of high, medium, or low, and product with name, url, and price_range on at least one item)."

    text =
      case generate_text(model, prompt, json_format_opts(req_opts)) do
        {:ok, text} ->
          text

        {:error, :exhausted} ->
          raise @out_of_tokens

        {:error, _} ->
          case generate_text(model, prompt, req_opts) do
            {:ok, text} -> text
            {:error, :exhausted} -> raise @out_of_tokens
            {:error, reason} -> raise public_error(inspect(reason, limit: 8, printable_limit: 300), opts.api_key)
          end
      end

    decode_json_text(text)
  end

  defp json_format_opts(req_opts) do
    Keyword.put(req_opts, :provider_options,
      response_format: %{"type" => "json_object"}
    )
  end

  defp generate_text(model, prompt, req_opts) do
    case ReqLLM.generate_text(model, prompt, req_opts) do
      {:ok, response} ->
        case classify_text(ReqLLM.Response.finish_reason(response), ReqLLM.Response.text(response) || "") do
          {:ok, text} -> {:ok, text}
          {:error, :exhausted} -> {:error, :exhausted}
        end

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    error -> {:error, error}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp classify_text(finish, text) when is_binary(text) do
    cond do
      length_finish?(finish) -> {:error, :exhausted}
      String.trim(text) == "" -> {:error, :exhausted}
      true -> {:ok, String.trim(text)}
    end
  end

  defp length_finish?(finish) when finish in [:length, "length", "max_tokens", "max_output_tokens"],
    do: true

  defp length_finish?(_finish), do: false

  defp finish_reason("length"), do: :length
  defp finish_reason("max_tokens"), do: :length
  defp finish_reason("stop"), do: :stop
  defp finish_reason(_finish), do: :stop

  defp decode_json_text(text) when is_binary(text) do
    trimmed = String.trim(text)

    json =
      case Regex.run(~r/\{.*\}/s, trimmed) do
        [object | _] -> object
        _ -> trimmed
      end

    case Jason.decode(json) do
      {:ok, map} when is_map(map) -> map
      _ -> raise "model JSON could not be decoded"
    end
  end

  defp stringify(object) do
    object
    |> Jason.encode!()
    |> Jason.decode!()
  end

  defp guarded(api_key, fun) do
    with_redaction(api_key, fn ->
      try do
        {:ok, fun.()}
      rescue
        error -> {:error, public_error(Exception.message(error), api_key)}
      catch
        kind, reason ->
          text = Exception.format(kind, reason, __STACKTRACE__) <> " " <> inspect(reason)
          {:error, public_error(text, api_key)}
      end
    end)
  end

  defp with_redaction(api_key, fun) when api_key == "" do
    fun.()
  end

  defp with_redaction(api_key, fun) do
    id = unique_logger_id("grow_assist_redact")
    :ok = :logger.add_primary_filter(id, {&redact_event/2, api_key})

    try do
      fun.()
    after
      :logger.remove_primary_filter(id)
    end
  end

  defp redact_event(%{msg: msg} = event, key) do
    %{event | msg: {:string, redact(render_msg(msg), key)}}
  end

  defp render_msg({:string, iodata}) do
    IO.iodata_to_binary(iodata)
  end

  defp render_msg({:report, report}) do
    inspect(report, limit: 20, printable_limit: 500)
  end

  defp render_msg({format, args}) when is_list(args) do
    try do
      format |> :io_lib.format(args) |> IO.iodata_to_binary()
    rescue
      _ -> inspect({format, args}, limit: 20, printable_limit: 500)
    end
  end

  defp render_msg(other) do
    inspect(other, limit: 20, printable_limit: 500)
  end

  defp public_error(text, api_key) do
    text
    |> redact(api_key)
    |> String.slice(0, 500)
  end

  defp redact(text, key) when is_binary(key) and key != "" do
    String.replace(text, key, "[redacted]")
  end

  defp redact(text, _key), do: text

  defp unique_logger_id(prefix) do
    String.to_atom(prefix <> "_" <> Integer.to_string(System.unique_integer([:positive])))
  end

  defp ensure_started! do
    {:ok, _} = Application.ensure_all_started(:elixir)
    {:ok, _} = Application.ensure_all_started(:req_llm)
    :ok
  end

  defp drain_logs(acc) do
    receive do
      {:grow_assist_log, line} -> drain_logs(acc <> line <> "\n")
    after
      30 -> acc
    end
  end
end
