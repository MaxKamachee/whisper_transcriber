import React, { useState, useRef } from 'react';
import { Mic, Square, Loader2 } from 'lucide-react';

const AudioRecorder = () => {
  const [isRecording, setIsRecording] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [transcription, setTranscription] = useState('');
  const mediaRecorder = useRef(null);
  const audioChunks = useRef([]);
  const API_URL = process.env.REACT_APP_API_URL || 'http://localhost:4000';

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
      console.log('Attempting to upload to:', `${API_URL}/upload`);
      
      const formData = new FormData();
      formData.append('file', file);
      
      const uploadResponse = await fetch(`${API_URL}/upload`, {
        method: 'POST',
        body: formData,
        credentials: 'include',  // Changed from 'same-origin'
        headers: {
          'Accept': 'application/json',
        },
      });
      
      if (!uploadResponse.ok) {
        const errorText = await uploadResponse.text();
        throw new Error(`Upload failed: ${uploadResponse.status} - ${errorText}`);
      }
      
      const uploadData = await uploadResponse.json();
      console.log('Upload response:', uploadData);
      
      if (!uploadData.path) {
        throw new Error('No path received from upload');
      }
  
      const transcribeResponse = await fetch(`${API_URL}/transcribe`, {
        method: 'POST',
        credentials: 'include',  // Changed from 'same-origin'
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify({ path: uploadData.path }),
      });
  
      if (!transcribeResponse.ok) {
        throw new Error(`Transcription request failed: ${transcribeResponse.status}`);
      }
  
      const data = await transcribeResponse.json();
      
      if (data.status === "processing") {
        setTranscription("Transcription is being processed...");
        startPolling(uploadData.path);
      }
    } catch (error) {
      console.error('Error in sendToServer:', error);
      setTranscription(`Error: ${error.message}`);
    } finally {
      setIsProcessing(false);
    }
  };

  const startPolling = (path) => {
    let attempts = 0;
    const maxAttempts = 60; // 30 seconds maximum polling time
    console.log("Starting polling for path:", path);
    
    const pollInterval = setInterval(async () => {
      try {
        console.log("Polling attempt", attempts);
        const response = await fetch(`${API_URL}/status?path=${encodeURIComponent(path)}`, {
          method: 'GET',
          credentials: 'same-origin',
          headers: {
            'Accept': 'application/json',
          },
        });
  
        if (!response.ok) {
          throw new Error(`Status check failed with status: ${response.status}`);
        }
  
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
        setTranscription(`Error: ${error.message || 'Failed to connect to server'}`);
        clearInterval(pollInterval);
      }
    }, 500); // Poll every half second
    
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