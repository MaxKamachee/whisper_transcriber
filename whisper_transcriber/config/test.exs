import Config

# Use a different port for testing
config :whisper_transcriber, port: 4001

# Configure logger for testing
config :logger, level: :warning