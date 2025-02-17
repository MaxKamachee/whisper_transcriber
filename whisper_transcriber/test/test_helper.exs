ExUnit.start()

# Start application for all tests
Application.ensure_all_started(:whisper_transcriber)

defmodule Whisper.TestHelpers do
@moduledoc """
Provides helper functions for testing the WhisperTranscriber application.

Functions:
- create_test_audio/1: Creates test audio files
- wait_for_supervisor_start/0: Ensures supervisor initialization
- Other test utilities

Usage in tests:
    use ExUnit.Case
    import Whisper.TestHelpers
"""
  def create_test_audio(path) do
    File.write!(path, "test audio data")
    path
  end

  def wait_for_supervisor_start do
    Process.sleep(100)
  end
end