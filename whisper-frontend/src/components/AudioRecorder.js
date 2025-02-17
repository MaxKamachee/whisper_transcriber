import React, { useState, useRef } from 'react';
import { Mic, Square, Loader2 } from 'lucide-react';

const AudioRecorder = () => {
  const [isRecording, setIsRecording] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [transcription, setTranscription] = useState('');
  const mediaRecorder = useRef(null);
  const audioChunks = useRef([]);

  const startRecording = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      mediaRecorder.current = new MediaRecorder(stream);
      audioChunks.current = [];

      mediaRecorder.current.ondataavailable = (event) => {
        audioChunks.current.push(event.data);
      };

      mediaRecorder.current.onstop = async () => {
        const audioBlob = new Blob(audioChunks.current, { type: 'audio/wav' });
        const file = new File([audioBlob], 'recording.wav', { type: 'audio/wav' });
        await sendToServer(file);
      };

      mediaRecorder.current.start();
      setIsRecording(true);
    } catch (error) {
      console.error('Error accessing microphone:', error);
      setTranscription('Error: Could not access microphone');
    }
  };

  const stopRecording = () => {
    if (mediaRecorder.current && isRecording) {
      mediaRecorder.current.stop();
      setIsRecording(false);
      mediaRecorder.current.stream.getTracks().forEach(track => track.stop());
    }
  };

  const sendToServer = async (file) => {
    setIsProcessing(true);
    try {
      // First save the file and get its path
      const formData = new FormData();
      formData.append('file', file);
      
      // Save file endpoint (you'll need to implement this)
      const uploadResponse = await fetch('http://localhost:4000/upload', {
        method: 'POST',
        body: formData,
      });
      
      const { path } = await uploadResponse.json();

      // Now send the path to the transcription endpoint
      const transcribeResponse = await fetch('http://localhost:4000/transcribe', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ path }),
      });

      const data = await transcribeResponse.json();
      
      if (data.status === "processing") {
        setTranscription("Transcription is being processed...");
        startPolling(path);
      }
    } catch (error) {
      console.error('Error:', error);
      setTranscription('Error processing audio');
    } finally {
      setIsProcessing(false);
    }
  };

  const startPolling = (path) => {
    let attempts = 0;
    const maxAttempts = 60; // 15 seconds maximum polling time
    console.log("Starting polling for path:", path);
    
    const pollInterval = setInterval(async () => {
      try {
        console.log("Polling attempt", attempts);
        const response = await fetch(`http://localhost:4000/status?path=${path}`);
        const data = await response.json();
        console.log("Received status:", data);
        
        if (data.status === "completed" && data.transcription) {
          setTranscription(data.transcription);
          clearInterval(pollInterval);
        } else if (data.status === "error") {
          setTranscription("Error: " + data.error);
          clearInterval(pollInterval);
        } else if (attempts >= maxAttempts) {
          setTranscription("Timeout: Transcription took too long");
          clearInterval(pollInterval);
        }
        
        attempts++;
      } catch (error) {
        console.error('Polling error:', error);
        setTranscription("Error connecting to server");
        clearInterval(pollInterval);
      }
    }, 500); // Poll every half second
    
    // Cleanup the interval if component unmounts
    return () => clearInterval(pollInterval);
  };

  return (
    <div className="p-6 max-w-md mx-auto bg-white rounded-xl shadow-md">
      <div className="space-y-4">
        <div className="text-center mb-4">
          <h2 className="text-xl font-semibold text-gray-800">Audio Recorder</h2>
          <p className="text-sm text-gray-600">
            {isRecording ? 'Recording in progress...' : 'Click to start recording'}
          </p>
        </div>

        <div className="flex justify-center">
          <button
            onClick={isRecording ? stopRecording : startRecording}
            className={`p-4 rounded-full ${
              isRecording 
                ? 'bg-red-500 hover:bg-red-600' 
                : 'bg-blue-500 hover:bg-blue-600'
            } text-white transition-colors`}
            disabled={isProcessing}
          >
            {isRecording ? (
              <Square className="w-6 h-6" />
            ) : (
              <Mic className="w-6 h-6" />
            )}
          </button>
        </div>

        {isProcessing && (
          <div className="flex justify-center items-center space-x-2">
            <Loader2 className="w-6 h-6 animate-spin text-blue-500" />
            <span className="text-sm text-gray-600">Processing audio...</span>
          </div>
        )}

        {transcription && (
          <div className="mt-4 p-4 bg-gray-50 rounded-lg">
            <h3 className="text-lg font-medium mb-2">Transcription:</h3>
            <p className="text-gray-700">{transcription}</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default AudioRecorder;