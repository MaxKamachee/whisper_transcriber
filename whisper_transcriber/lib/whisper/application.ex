defmodule Whisper.Application do
@moduledoc """
  This is the main entry point of the WhisperTranscriber service. When you start the 
  application, this module gets everything up and running in the right order.

  It's responsible for starting all the key components:
  - The HTTP server to accept requests
  - The WorkerSupervisor to manage transcription workers
  - The TranscriptionCoordinator to handle transcription jobs
  - A Registry to keep track of everything

  Think of it as the morning routine that opens up the transcription office and gets 
  everything ready for business. It makes sure all the necessary systems are running 
  and working together properly.
  """
  use Application

  def start(_type, _args) do
    children = [
      {Plug.Cowboy, scheme: :http, plug: Whisper.Router, options: [port: 4000]},
      {Whisper.WorkerSupervisor, []},
      {Whisper.TranscriptionCoordinator, []},
      {Registry, keys: :unique, name: Whisper.WorkerRegistry}
    ]

    opts = [strategy: :one_for_one, name: Whisper.Supervisor]
    Supervisor.start_link(children, opts)
  end
end