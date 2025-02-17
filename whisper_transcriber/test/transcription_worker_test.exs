defmodule Whisper.TranscriptionWorkerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  import Whisper.TestHelpers

  setup do
    test_file = Path.join(System.tmp_dir!(), "test_audio.mp3")
    create_test_audio(test_file)
    on_exit(fn -> File.rm(test_file) end)
    %{test_file: test_file}
  end

  test "worker handles transcription process", %{test_file: test_file} do
    {:ok, pid} = Whisper.TranscriptionWorker.start_link(test_file)
    ref = Process.monitor(pid)
    
    # Worker should eventually terminate
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 5000
  end

  test "worker handles missing file gracefully" do
    log = capture_log(fn ->
      {:ok, pid} = Whisper.TranscriptionWorker.start_link("nonexistent.mp3")
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, _}, 5000
    end)

    assert log =~ "error"
  end
end