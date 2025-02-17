defmodule Whisper.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @opts Whisper.Router.init([])

  setup do
    test_file = Path.join(System.tmp_dir!(), "test_audio.mp3")
    File.write!(test_file, "test audio data")
    on_exit(fn -> File.rm(test_file) end)
    %{test_file: test_file}
  end

  test "POST /transcribe with valid path", %{test_file: test_file} do
    conn = conn(:post, "/transcribe", %{path: test_file})
           |> put_req_header("content-type", "application/json")
           |> Whisper.Router.call(@opts)

    assert conn.state == :sent
    assert conn.status == 202  # Accepted
    response = Jason.decode!(conn.resp_body)
    assert response["status"] == "processing"
  end

  test "POST /transcribe without path" do
    conn = conn(:post, "/transcribe", %{})
           |> put_req_header("content-type", "application/json")
           |> Whisper.Router.call(@opts)

    assert conn.state == :sent
    assert conn.status == 400
    assert Jason.decode!(conn.resp_body) == %{"error" => "Missing path parameter"}
  end

  test "404 on unknown route" do
    conn = conn(:get, "/unknown")
           |> Whisper.Router.call(@opts)

    assert conn.state == :sent
    assert conn.status == 404
  end
end