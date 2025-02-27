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
            "tiny",  # Use tiny model instead of base
            device="cpu",
            compute_type="int8",  # Use int8 quantization
            cpu_threads=4,
            num_workers=2
        )
            
        # Transcribe with lower beam size
        segments, info = model.transcribe(
            file_path,
            beam_size=3,        # Moderate beam size for accuracy
            language="en",
            initial_prompt="Transcribe the following audio accurately:",
            condition_on_previous_text=True,  # Important for accuracy
            temperature=0.0,    # Deterministic for speed
            vad_filter=True,    # Use VAD for efficiency
            vad_parameters=dict(
                min_silence_duration_ms=250,  # Shorter for speed
                speech_pad_ms=100,           # Enough padding for accuracy
            ),
            word_timestamps=False  # Disable for speed
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