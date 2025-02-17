defmodule Whisper.MixProject do
  use Mix.Project

  def project do
    [
      app: :whisper_transcriber,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :observer, :wx, :runtime_tools],
      mod: {Whisper.Application, []}
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.6"},
      {:porcelain, "~> 2.0"},
      {:mock, "~> 0.3.0", only: :test},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
      {:cors_plug, "~> 3.0"}
    ]
  end
end