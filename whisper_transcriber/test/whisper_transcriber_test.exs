defmodule WhisperTranscriberTest do
  use ExUnit.Case
  doctest WhisperTranscriber

  test "greets the world" do
    assert WhisperTranscriber.hello() == :world
  end
end
