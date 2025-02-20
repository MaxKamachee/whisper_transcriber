"""
Transcribes audio files using the faster-whisper implementation.
"""

from faster_whisper import WhisperModel
import os
import json
import sys
import gc

# Add this to resolve the OpenMP library issue
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

def transcribe_audio(file_path):
    try:
        # Force garbage collection before starting
        gc.collect()
        
        # Load the Whisper model with compute_type="int8" for lower memory usage
        model = WhisperModel(
            "tiny",  # Use tiny model instead of base
            device="cpu",
            compute_type="int8"  # Use int8 quantization
        )
            
        # Transcribe with lower beam size
        segments, info = model.transcribe(
            file_path,
            beam_size=1,  # Reduced from 5
            language="en",
            condition_on_previous_text=False,
            no_speech_threshold=0.6
        )
        
        # Clean up model explicitly
        del model
        gc.collect()
        
        # Convert segments to list for JSON serialization
        transcription = " ".join(segment.text for segment in segments)
        
        # Return single JSON object with all information
        result = {
            "status": "success",
            "transcription": transcription.strip(),
            "language": info.language,
            "duration": info.duration
        }
        
        print(json.dumps(result), flush=True)
        
    except Exception as e:
        error_msg = str(e).replace('"', '\\"')  # Escape quotes for JSON
        error_result = {
            "status": "error",
            "error": f"Error processing {file_path}: {error_msg}"
        }
        print(json.dumps(error_result), flush=True)
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(json.dumps({
            "status": "error",
            "error": "No audio file path provided"
        }), flush=True)
        sys.exit(1)
        
    audio_file = sys.argv[1]
    transcribe_audio(audio_file)