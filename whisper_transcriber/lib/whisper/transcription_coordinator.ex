defmodule Whisper.TranscriptionCoordinator do
@moduledoc """
  The TranscriptionCoordinator is like a manager at a transcription office. It keeps track 
  of all ongoing transcription jobs and makes sure they're handled properly. Unlike the 
  TranscriptionServer, which handles one job at a time, the Coordinator can manage multiple 
  transcriptions happening at once.

  When you submit an audio file for transcription, the Coordinator:
  1. Creates a new worker to handle your specific transcription
  2. Keeps an eye on the worker to make sure everything's going well
  3. Lets you know when your transcription is ready or if something went wrong

  The Coordinator is particularly useful when you need to handle multiple transcription 
  requests at the same time. It manages all the complexity of running parallel tasks 
  while keeping everything organized and stable.

  You can use it like this:

      # Start a new transcription
      Whisper.TranscriptionCoordinator.transcribe("my_audio.mp3")

  The Coordinator will take care of everything else, and you'll get a message when 
  it's done or if there's a problem.
  """

  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def transcribe(file_path) do
    GenServer.cast(__MODULE__, {:transcribe, file_path})
  end

  def get_result(path) do
    GenServer.call(__MODULE__, {:get_result, path})
  end

  def init(:ok) do
    {:ok, %{results: %{}}}
  end

  def handle_cast({:transcribe, file_path}, state) do
    case Whisper.WorkerSupervisor.start_worker(file_path) do
      {:ok, _pid} ->
        {:noreply, state}
      {:error, reason} ->
        Logger.error("Failed to start worker: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  def handle_cast({:transcription_complete, file_path, result}, state) do
    Logger.info("Storing result for #{file_path}: #{result}")
    {:noreply, %{state | results: Map.put(state.results, file_path, result)}}
  end

  def handle_cast({:transcription_error, file_path, error}, state) do
    Logger.error("Storing error for #{file_path}: #{inspect(error)}")
    {:noreply, %{state | results: Map.put(state.results, file_path, {:error, error})}}
  end

  def handle_call({:get_result, path}, _from, state) do
    result = Map.get(state.results, path)
    Logger.info("Getting result for #{path}: #{inspect(result)}")
    {:reply, result, state}
  end
end