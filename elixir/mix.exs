defmodule GrowAssistReqLlm.MixProject do
  use Mix.Project

  def project do
    [
      app: :grow_assist_req_llm,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:req_llm, "~> 1.31"}
    ]
  end
end
