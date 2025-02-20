defmodule Whisper.Router do
@moduledoc """
  The Router is the front door to our transcription service. It provides a simple HTTP 
  interface that lets users submit audio files for transcription and check on their status.

  When you send a request to the service, the Router:
  - Makes sure your request is valid
  - Passes it along to the TranscriptionCoordinator
  - Sends back a response to let you know what's happening

  To use it, you can send a POST request to /transcribe with the path to your audio file:

      POST /transcribe
      {
        "path": "/path/to/your/audio.mp3"
      }

  The Router will let you know right away that your request was accepted and is being 
  processed. This is like dropping off a document for transcription and getting a 
  receipt - you know your request is in the system and being handled.
  """

  use Plug.Router
  require Logger
  
  plug CORSPlug, 
    origin: ["https://whisper-frontend.onrender.com"],
    methods: ["GET", "POST", "OPTIONS"],
    headers: ["Authorization", "Content-Type", "Accept", "Origin"],
    expose: ["content-type", "content-length"],
    credentials: true,
    max_age: 86400

  plug :match
  plug Plug.Parsers,
    parsers: [:multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason,
    length: 100_000_000

  plug :dispatch

  # Add OPTIONS handlers for all your endpoints
  options "/upload" do
    send_resp(conn, 204, "")
  end

  options "/transcribe" do
    send_resp(conn, 204, "")
  end

  options "/status" do
    send_resp(conn, 204, "")
  end


  # Add a new route for file uploads
  post "/upload" do
    Logger.info("POST /upload route hit")
    case conn.body_params do
      %{"file" => upload} ->
        # Generate unique filename
        filename = "recording-#{:os.system_time(:millisecond)}.wav"
        path = Path.join("priv/uploads", filename)
        
        # Ensure uploads directory exists
        File.mkdir_p!("priv/uploads")
        
        # Save the file
        File.write!(path, File.read!(upload.path))
        
        # Return the path for transcription
        send_resp(conn, 200, Jason.encode!(%{path: path}))
      
      _ ->
        send_resp(conn, 400, Jason.encode!(%{error: "No file uploaded"}))
    end
  end

  # Your existing transcribe endpoint
  post "/transcribe" do
    Logger.debug("Received transcription request: #{inspect(conn.body_params)}")
    
    case conn.body_params do
      %{"path" => path} ->
        case Whisper.TranscriptionCoordinator.transcribe(path) do
          :ok -> 
            Logger.info("Transcription initiated")
            send_resp(conn, 202, Jason.encode!(%{status: "processing"}))
          other -> 
            Logger.error("Unexpected response: #{inspect(other)}")
            send_resp(conn, 500, Jason.encode!(%{error: "Internal server error"}))
        end
      _ ->
        Logger.warning("Missing path parameter", error_type: :missing_parameter)
        send_resp(conn, 400, Jason.encode!(%{error: "Missing path parameter"}))
    end
  end

  get "/status" do
    case conn.params do
      %{"path" => path} ->
        Logger.info("Checking status for path: #{path}")
        result = Whisper.TranscriptionCoordinator.get_result(path)
        Logger.info("Got result from coordinator: #{inspect(result)}")
        
        response = case result do
          nil ->
            %{status: "processing"}
          {:error, reason} ->
            %{status: "error", error: reason}
          result when is_binary(result) ->
            %{status: "completed", transcription: result}
        end
        
        Logger.info("Sending response: #{inspect(response)}")
        send_resp(conn, 200, Jason.encode!(response))
      _ ->
        send_resp(conn, 400, Jason.encode!(%{error: "Missing path parameter"}))
    end
  end

  get "/health" do
    send_resp(conn, 200, "OK")
  end

  

  match _ do
    send_resp(conn, 404, "Not found")
  end

  
end