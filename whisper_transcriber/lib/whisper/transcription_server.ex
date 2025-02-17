defmodule Whisper.TranscriptionServer do
@moduledoc """
  The TranscriptionServer is your direct connection to the speech-to-text conversion service. 
  Think of it as a dedicated worker that handles one transcription at a time, perfect for 
  when you need a straightforward, synchronous way to convert audio to text.

  This server takes care of all the communication with the Python script that runs the 
  actual transcription. It's like a translator between your Elixir code and the Python 
  world, making sure everything runs smoothly and handling any problems that might come up.

  When you send an audio file to the server, it will either give you back the transcribed 
  text or let you know if something went wrong. It's designed to be simple to use - you 
  give it an audio file, and it gives you back text.

  Here's how you might use it:

      # Let's try to transcribe an audio file
      case Whisper.TranscriptionServer.transcribe("my_audio.mp3") do
        {:ok, result} ->
          # Great! We got our transcription
          %{"transcription" => text} = result
          IO.puts("Here's what was said: \#{text}")
          
        {:error, error_message} ->
          # Something went wrong
          IO.puts("Oops! \#{inspect(error_message)}")
      end

  Before using the server, make sure you have:
  - A Python virtual environment set up in the '.venv' directory
  - The transcription script in your 'priv/python/transcribe.py'
  - ffmpeg installed on your computer
  """
  
  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def transcribe(file_path) do
    GenServer.call(__MODULE__, {:transcribe, file_path}, :infinity)
  end

  def init(:ok) do
    python_path = Path.join(:code.priv_dir(:whisper_transcriber), "python/transcribe.py")
    {:ok, %{python_path: python_path}}
  end

  def handle_call({:transcribe, file_path}, _from, %{python_path: python_path} = state) do
    venv_python = Path.join([File.cwd!(), ".venv", "bin", "python3"])
    Logger.info("Starting transcription for #{file_path}")
    
    case run_transcription(venv_python, python_path, file_path) do
      {:ok, output} ->
        Logger.debug("Raw output from Python: #{inspect(output)}")
        case Jason.decode(String.trim(output)) do
          {:ok, result} -> 
            Logger.info("Transcription completed successfully")
            {:reply, {:ok, result}, state}
          {:error, decode_error} -> 
            Logger.error("JSON decode error: #{inspect(decode_error)}\nRaw output: #{inspect(output)}")
            {:reply, {:error, "Failed to parse transcription output"}, state}
        end
      {:error, reason} ->
        Logger.error("Transcription error: #{reason}")
        {:reply, {:error, reason}, state}
    end
  end

  defp run_transcription(venv_python, python_path, file_path) do
    try do
      Logger.debug("Running Python script: #{python_path}")
      Logger.debug("With Python interpreter: #{venv_python}")
      
      %Porcelain.Result{out: output, status: status} =
        Porcelain.exec(venv_python, [python_path, file_path])

      Logger.debug("Python script status: #{status}")
      Logger.debug("Python script output: #{inspect(output)}")

      case status do
        0 -> {:ok, output}
        _ -> {:error, "Transcription failed with status #{status}"}
      end
    rescue
      e ->
        Logger.error("Execution error: #{inspect(e)}")
        {:error, "Failed to run transcription"}
    end
  end
end