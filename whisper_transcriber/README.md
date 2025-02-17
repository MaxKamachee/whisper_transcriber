# WhisperTranscriber

WhisperTranscriber is an Elixir application that provides a fault-tolerant, concurrent API wrapper around OpenAI's Whisper speech-to-text model using the faster-whisper implementation. It leverages Elixir's supervision trees and concurrency model to handle multiple transcription requests efficiently.

## Features

- Concurrent transcription processing using worker pools
- Fault-tolerant with automatic worker recovery
- HTTP API endpoint for transcription requests
- Efficient Python interop using Porcelain
- Comprehensive logging and error handling
- Built-in monitoring capabilities

## Prerequisites

- Elixir 1.14 or later
- Python 3.8 or later
- ffmpeg (for audio processing)
- sox (for testing)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/MaxKamachee/whisper_transcriber.git
cd whisper_transcriber
```

2. Install Elixir dependencies:
```bash
mix deps.get
```

3. Set up Python virtual environment and install requirements:
```bash
python3 -m venv .venv
source .venv/bin/activate  # Or `.venv\Scripts\activate` on Windows
pip install -r requirements.txt
```

## Configuration

The application can be configured through `config/config.exs`:

```elixir
import Config

config :porcelain,
  driver: Porcelain.Driver.Basic

# Add any additional configuration here
```

## Usage

1. Start the application:
```bash
iex -S mix
```

2. Monitor the application (optional):
```elixir
:observer.start()
```

3. Make a transcription request:

Using curl:
```bash
curl -X POST http://localhost:4000/transcribe \
  -H "Content-Type: application/json" \
  -d '{"path":"/path/to/your/audio/file.mp3"}'
```

Using Elixir:
```elixir
Whisper.TranscriptionCoordinator.transcribe("/path/to/your/audio/file.mp3")
```

## Testing

The project includes a comprehensive test suite. To run the tests:

```bash
mix test
```

For development, you might want to run tests with increased verbosity:
```bash
mix test --trace
```

## Monitoring and Debugging

1. Use the Observer to monitor the system:
```elixir
:observer.start()
```

2. Enable tracing for specific components:
```elixir
:sys.trace(Whisper.TranscriptionCoordinator, true)
```

3. Check the number of active workers:
```elixir
DynamicSupervisor.count_children(Whisper.WorkerSupervisor)
```

## Architecture

The application uses a supervisor tree with the following structure:

```
Whisper.Supervisor
├── Plug.Cowboy (HTTP Server)
├── Whisper.WorkerSupervisor (DynamicSupervisor)
├── Whisper.TranscriptionCoordinator
└── Registry
```

- `Whisper.WorkerSupervisor`: Manages transcription worker processes
- `Whisper.TranscriptionCoordinator`: Coordinates transcription requests and responses
- `Whisper.TranscriptionWorker`: Handles individual transcription tasks

## Frontend Integration

The WhisperTranscriber service provides a RESTful API that can be easily integrated with any frontend framework. Here's how to connect it with common frontend frameworks:

API Endpoints

The service exposes the following endpoint:

CopyPOST /transcribe
Content-Type: application/json

{
    "path": "/path/to/audio/file.mp3"
}
Response codes:

202: Request accepted (includes processing status)
400: Bad request (missing parameters)
404: Endpoint not found
500: Server error

## Deployment

### Local Development Deployment

1. **Environment Setup**
```bash
# Clone and setup
git clone https://github.com/MaxKamachee/whisper_transcriber.git
cd whisper_transcriber
mix deps.get
mix compile

# Setup Python environment
python3 -m venv .venv
source .venv/bin/activate  # or `.venv\Scripts\activate` on Windows
pip install -r requirements.txt

# Start the application
mix phx.server  # or `iex -S mix` for interactive mode
```

### Production Deployment

#### Using Releases

1. **Create a Release**
```bash
# Add release configuration to mix.exs
MIX_ENV=prod mix release.init
MIX_ENV=prod mix release
```

2. **Configure Production Settings**
Create `config/prod.exs`:
```elixir
import Config

config :whisper_transcriber,
  port: String.to_integer(System.get_env("PORT") || "4000")

config :logger,
  level: :info,
  backends: [:console]

config :porcelain,
  driver: Porcelain.Driver.Basic
```

3. **Deploy on Linux Server**
```bash
# Copy release to server
scp _build/prod/rel/whisper_transcriber.tar.gz user@your-server:/opt/whisper_transcriber/

# On server
cd /opt/whisper_transcriber
tar xzf whisper_transcriber.tar.gz
./bin/whisper_transcriber start
```

#### Using Docker

1. **Create Dockerfile**
```dockerfile
# Build stage
FROM elixir:1.14-alpine AS builder

# Install build dependencies
RUN apk add --no-cache build-base git python3-dev py3-pip

# Prepare build directory
WORKDIR /app

# Install Mix dependencies
COPY mix.exs mix.lock ./
RUN mix do deps.get, deps.compile

# Build release
COPY . .
RUN MIX_ENV=prod mix release

# Runtime stage
FROM python:3.8-slim

# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y ffmpeg && \
    rm -rf /var/lib/apt/lists/*

# Copy release from builder
COPY --from=builder /app/_build/prod/rel/whisper_transcriber ./whisper_transcriber
COPY requirements.txt .
COPY priv/python ./priv/python

# Install Python dependencies
RUN python -m pip install -r requirements.txt

# Set environment variables
ENV PORT=4000

# Start the application
CMD ["./whisper_transcriber/bin/whisper_transcriber", "start"]
```

2. **Build and Run Docker Container**
```bash
# Build image
docker build -t whisper_transcriber .

# Run container
docker run -p 4000:4000 whisper_transcriber
```

#### Using Kubernetes

1. **Create Kubernetes Deployment**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whisper-transcriber
spec:
  replicas: 3
  selector:
    matchLabels:
      app: whisper-transcriber
  template:
    metadata:
      labels:
        app: whisper-transcriber
    spec:
      containers:
      - name: whisper-transcriber
        image: whisper_transcriber:latest
        ports:
        - containerPort: 4000
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
```

2. **Create Service**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: whisper-transcriber-service
spec:
  selector:
    app: whisper-transcriber
  ports:
  - port: 80
    targetPort: 4000
  type: LoadBalancer
```

3. **Deploy to Kubernetes**
```bash
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml
```

### Monitoring in Production

1. **Enable Telemetry**
Add to `config/prod.exs`:
```elixir
config :whisper_transcriber, WhisperTranscriber.Telemetry,
  enabled: true,
  statsd_host: "localhost",
  statsd_port: 8125
```

2. **Set Up Logging**
```elixir
config :logger,
  backends: [:console, {LogstashJson.Console, :json}],
  level: :info
```

3. **Health Checks**
Add to your router:
```elixir
get "/health" do
  send_resp(conn, 200, "OK")
end
```

### Performance Tuning

1. **BEAM Settings**
```bash
BEAM_FLAGS="+SDio 1 +A30 +Q65536 +S 2:2"
```

2. **Worker Pool Configuration**
```elixir
config :whisper_transcriber,
  max_workers: 10,
  worker_timeout: 300_000
```

### Backup and Recovery

1. **Backup Strategy**
- Regular backups of configuration
- Monitoring data persistence
- Log rotation and archival

2. **Recovery Procedures**
- Service restart protocol
- Data recovery steps
- Rollback procedures

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- OpenAI for the Whisper model
- Guillaume Klein for the faster-whisper implementation