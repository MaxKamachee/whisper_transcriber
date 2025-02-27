# prod.exs
import Config

config :whisper_transcriber,
  port: String.to_integer(System.get_env("PORT") || "4000")

config :logger,
  level: :info,
  backends: [:console]

config :porcelain,
  driver: Porcelain.Driver.Basic

# Update CORS configuration for production
config :cors_plug,
  origin: ["https://whisper-frontend.onrender.com"],
  methods: ["GET", "POST", "OPTIONS"],
  headers: ["Content-Type", "Accept", "Origin"],
  expose: ["content-type", "content-length"],
  max_age: 86400,
  credentials: true

# router.ex modifications
defmodule Whisper.Router do
  use Plug.Router
  require Logger
  
  
  
  plug :match
  plug Plug.Parsers,
    parsers: [:multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason,
    length: 100_000_000

  plug :dispatch

  # Remove the custom call/2 function that was adding CORS headers
  # The rest of your router code remains the same...
end