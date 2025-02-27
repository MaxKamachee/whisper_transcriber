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
      console.log('Starting upload process');
      const formData = new FormData();
      formData.append('file', file);
      
      //do the upload
      const uploadResponse = await fetch(`${API_URL}/upload`, {
        method: 'POST',
        body: formData,
        headers: {
          'Accept': 'application/json',
        },
      });
      
      if (!uploadResponse.ok) {
        throw new Error(`Upload failed with status: ${uploadResponse.status}`);
      }
  
      const uploadResult = await uploadResponse.json();
      console.log('Upload successful:', uploadResult);
  
      if (!uploadResult.path) {
        throw new Error('No path received from upload');
      }
  
      // Start transcription
      const transcribeResponse = await fetch(`${API_URL}/transcribe`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: JSON.stringify({ path: uploadResult.path }),
      });
  
      if (!transcribeResponse.ok) {
        throw new Error(`Transcription request failed: ${transcribeResponse.status}`);
      }
  
      const transcribeResult = await transcribeResponse.json();
      console.log('Transcription response:', transcribeResult);
      
      if (transcribeResult.status === "processing") {
        setTranscription("Transcription is being processed...");
        startPolling(uploadResult.path);
      }
    } catch (error) {
      console.error('Error in sendToServer:', error);
      setTranscription(`Error: ${error.message}`);
    } finally {
      setIsProcessing(false);
    }
  };

  const startPolling = (path, attempt = 0, startTime = Date.now()) => {
    const maxAttempts = 60;
    const initialDelay = 500;    // Start with 500ms
    const maxDelay = 2000;       // Cap at 2 seconds instead of 5
    let currentDelay = Math.min(initialDelay * Math.pow(1.2, attempt), maxDelay); // Slower increase (1.2 instead of 1.5)
    
    const elapsedTime = (Date.now() - startTime) / 1000;
    console.log(`Polling attempt ${attempt} (delay: ${currentDelay}ms) - Time elapsed: ${elapsedTime.toFixed(1)}s`);
    
    setTimeout(async () => {
      try {
        const response = await fetch(`${API_URL}/status?path=${encodeURIComponent(path)}`, {
          headers: {
            'Accept': 'application/json'
          }
        });
        
        const data = await response.json();
        const currentElapsed = ((Date.now() - startTime) / 1000).toFixed(1);
        console.log(`Received status at ${currentElapsed}s:`, data);
        
        if (data.status === "completed" && data.transcription) {
          const finalTime = ((Date.now() - startTime) / 1000).toFixed(1);
          console.log(`Transcription completed in ${finalTime}s`);
          setTranscription(data.transcription);
        } else if (data.status === "error") {
          const errorTime = ((Date.now() - startTime) / 1000).toFixed(1);
          console.log(`Error at ${errorTime}s:`, data.error);
          setTranscription(`Error: ${data.error}`);
        } else if (attempt >= maxAttempts) {
          const timeoutTime = ((Date.now() - startTime) / 1000).toFixed(1);
          console.log(`Timeout at ${timeoutTime}s`);
          setTranscription("Timeout: Transcription took too long");
        } else if (data.status === "processing") {
          startPolling(path, attempt + 1, startTime);
        }
      } catch (error) {
        const errorTime = ((Date.now() - startTime) / 1000).toFixed(1);
        console.error(`Polling error at ${errorTime}s:`, error);
        setTranscription("Error checking transcription status");
      }
    }, currentDelay);
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