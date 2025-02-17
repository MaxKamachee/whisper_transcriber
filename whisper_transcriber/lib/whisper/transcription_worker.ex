defmodule Whisper.TranscriptionWorker do
@moduledoc """
  A TranscriptionWorker is like an individual employee who focuses on transcribing just 
  one audio file. Each worker is created by the Coordinator when needed and works on 
  their assigned task until it's complete.

  The worker's job is straightforward but important:
  - Take an audio file
  - Run it through the transcription process
  - Report back with the results
  - Clean up and finish

  Workers are designed to be temporary - they're created for a specific transcription 
  job and go away once that job is done. This keeps the system efficient and prevents 
  resource waste.

  The worker also acts as a safety net, catching and reporting any problems that might 
  come up during transcription. If something goes wrong, it makes sure the Coordinator 
  knows about it so appropriate action can be taken.
  """
  
  use GenServer, restart: :temporary
  require Logger

  def start_link(file_path) do
    GenServer.start_link(__MODULE__, file_path)
  end

  def init(file_path) do
    Process.flag(:trap_exit, true)
    python_path = get_python_path()
    send(self(), :transcribe)
    {:ok, %{file_path: file_path, python_path: python_path}}
  end

  def handle_info(:transcribe, state) do
    result = run_transcription(state.file_path, state.python_path)
    case result do
      {:ok, transcription} ->
        # Send the result directly to the coordinator
        GenServer.cast(Whisper.TranscriptionCoordinator, {:transcription_complete, state.file_path, transcription["transcription"]})
        Logger.info("Transcription completed: #{inspect(transcription)}")
      {:error, reason} ->
        GenServer.cast(Whisper.TranscriptionCoordinator, {:transcription_error, state.file_path, reason})
        Logger.error("Transcription failed: #{inspect(reason)}")
    end
    {:stop, :normal, state}
  end

  defp get_python_path do
    Path.join(:code.priv_dir(:whisper_transcriber), "python/transcribe.py")
  end

  defp run_transcription(file_path, python_path) do
    venv_python = Path.join([File.cwd!(), ".venv", "bin", "python3"])
    
    Task.async(fn ->
      try do
        %Porcelain.Result{out: output, status: status} =
          Porcelain.exec(venv_python, [python_path, file_path])

        case status do
          0 -> 
            case Jason.decode(String.trim(output)) do
              {:ok, result} -> {:ok, result}
              {:error, decode_error} -> 
                Logger.error("JSON decode error: #{inspect(decode_error)}")
                {:error, "Failed to parse transcription output"}
            end
          _ -> 
            {:error, "Transcription failed with status #{status}"}
        end
      rescue
        e in RuntimeError ->
          Logger.error("Runtime error: #{inspect(e)}")
          {:error, "Runtime error during transcription"}
        e ->
          Logger.error("Unknown error: #{inspect(e)}")
          {:error, "Unknown error during transcription"}
      end
    end)
    |> Task.await(:infinity)
  end
end