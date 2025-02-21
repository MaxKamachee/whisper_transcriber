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
        
        
        # Load the Whisper model with compute_type="int8" for lower memory usage
        model = WhisperModel(
            "base",  # Use tiny model instead of base
            device="cpu",
            compute_type="int8",  # Use int8 quantization
            cpu_threads=2,
            num_workers=1
        )
            
        # Transcribe with lower beam size
        segments, info = model.transcribe(
            file_path,
            beam_size=2,         # Slightly larger beam size for better accuracy
            language="en",
            condition_on_previous_text=True,  # Better context handling
            temperature=0.2,      # Small temperature for minor variations
            no_speech_threshold=0.5,  # More balanced silence detection
            vad_filter=True,
            vad_parameters=dict(
                min_silence_duration_ms=400,  # Balanced silence detection
                speech_pad_ms=150,           # Better context preservation
            ),
            initial_prompt="Convert speech to text accurately."
        )
        
        
        
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