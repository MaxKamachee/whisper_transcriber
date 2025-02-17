defmodule Whisper.WorkerSupervisor do
@moduledoc """
  The WorkerSupervisor is like a safety system for our transcription workers. Its main 
  job is to make sure workers are created properly and handle any problems that might 
  come up while they're running.

  Think of it as a manager who:
  - Creates new workers when needed
  - Keeps track of all active workers
  - Makes sure the system doesn't get overwhelmed with too many workers
  - Handles any crashes or problems gracefully

  You can set a maximum number of workers to prevent system overload:

      config :whisper_transcriber,
        max_workers: 5

  The supervisor uses a "one-for-one" strategy, which means if one worker has a problem, 
  it doesn't affect the others. This keeps the system stable and reliable even when 
  things go wrong.
  """
  
  use DynamicSupervisor

  def start_link(_arg) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_worker(file_path) do
    spec = {Whisper.TranscriptionWorker, file_path}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end