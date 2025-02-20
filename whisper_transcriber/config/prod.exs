import Config

config :whisper_transcriber,
  port: String.to_integer(System.get_env("PORT") || "4000")

config :logger,
  level: :info,
  backends: [:console]

config :porcelain,
  driver: Porcelain.Driver.Basic

config :cors_plug,
  origin: ["https://whisper-frontend.onrender.com"]