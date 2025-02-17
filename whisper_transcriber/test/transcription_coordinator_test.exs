defmodule Whisper.TranscriptionCoordinatorTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  setup do
    test_file = Path.join(System.tmp_dir!(), "test_audio.mp3")
    File.write!(test_file, "test audio data")
    on_exit(fn -> File.rm(test_file) end)
    %{test_file: test_file}
  end

  test "coordinator handles transcription request", %{test_file: test_file} do
    result = Whisper.TranscriptionCoordinator.transcribe(test_file)
    # The coordinator returns :ok when request is accepted
    assert result == :ok
  end

  test "coordinator handles multiple concurrent requests", %{test_file: test_file} do
    tasks = for _ <- 1..3 do
      Task.async(fn ->
        Whisper.TranscriptionCoordinator.transcribe(test_file)
      end)
    end

    results = Task.await_many(tasks, 10000)
    # All requests should be accepted
    assert Enum.all?(results, fn result -> result == :ok end)
  end

  test "coordinator handles invalid file path" do
    result = Whisper.TranscriptionCoordinator.transcribe("nonexistent_file.mp3")
    # For invalid files, we still return :ok as the worker will handle the error
    assert result == :ok
  end
end