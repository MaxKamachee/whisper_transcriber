"""
Memory-efficient transcription script optimized for Render free tier.
"""
from faster_whisper import WhisperModel
import os
import json
import sys
from pathlib import Path

# Add this to resolve the OpenMP library issue
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

def transcribe_audio(file_path):
    try:
        # Use the smallest possible model with minimal settings
        model = WhisperModel(
            "tiny",
            device="cpu",
            compute_type="int8",
        )
            
        # Optimize memory usage during transcription
        segments, info = model.transcribe(
            file_path,
            beam_size=1,
            language="en",
            vad_filter=True,          # Enable voice activity detection
            vad_parameters=dict(
                min_silence_duration_ms=500,
                speech_pad_ms=100,
            ),
            condition_on_previous_text=False,
            initial_prompt="Convert speech to text.",
            temperature=0.0,          # Deterministic decoding
            compression_ratio_threshold=2.4,
            logprob_threshold=-1.0,
            no_speech_threshold=0.6
        )
        
        # Process segments with minimal memory
        try:
            transcription = []
            for segment in segments:
                transcription.append(segment.text)
        finally:
            # Clean up explicitly after processing
            del segments
        
        # Create minimal result object
        result = {
            "status": "success",
            "transcription": " ".join(transcription).strip()
        }
        
        print(json.dumps(result), flush=True)
        
    except Exception as e:
        print(json.dumps({
            "status": "error",
            "error": str(e)
        }), flush=True)
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(json.dumps({
            "status": "error",
            "error": "No audio file path provided"
        }), flush=True)
        sys.exit(1)
    
    # Verify file exists and is readable
    audio_path = Path(sys.argv[1])
    if not audio_path.is_file():
        print(json.dumps({
            "status": "error",
            "error": f"File not found: {audio_path}"
        }), flush=True)
        sys.exit(1)
        
    transcribe_audio(str(audio_path))