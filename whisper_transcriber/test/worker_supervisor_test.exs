defmodule Whisper.WorkerSupervisorTest do
  use ExUnit.Case
  import Whisper.TestHelpers

  test "supervisor can start and stop workers" do
    test_file = Path.join(System.tmp_dir!(), "test_audio.mp3")
    create_test_audio(test_file)

    assert {:ok, pid} = Whisper.WorkerSupervisor.start_worker(test_file)
    assert Process.alive?(pid)

    # Clean up
    File.rm(test_file)
  end

  test "supervisor handles worker crashes" do
    {:ok, pid} = Whisper.WorkerSupervisor.start_worker("nonexistent.mp3")
    ref = Process.monitor(pid)
    
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 5000
  end
end