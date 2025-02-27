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

def preprocess_audio(input_path):
    """Quick preprocessing to reduce file size"""
    import subprocess
    import os
    
    output_path = input_path + ".optimized.wav"
    
    try:
        subprocess.run([
            "ffmpeg", "-y", "-i", input_path,
            "-ar", "16000",  # 16kHz is optimal for Whisper
            "-c:a", "pcm_s16le",  # Use lossless PCM format
            output_path
        ], stderr=subprocess.PIPE, stdout=subprocess.PIPE)
        
        # Return the new path if successful
        if os.path.exists(output_path):
            return output_path
            
    except Exception as e:
        print(f"Preprocessing error: {str(e)}")
        
    return input_path


    

def transcribe_audio(file_path):
    try:
        
        
        # Load the Whisper model with compute_type="int8" for lower memory usage
        model = WhisperModel(
            "tiny.en",  # Use tiny model instead of base w english as language
            device="cpu",
            compute_type="int8",  # Use int8 quantization
            cpu_threads=2,
            num_workers=1
        )
            
        # Transcribe with lower beam size
        segments, info = model.transcribe(
            file_path,
            beam_size=1,        # Moderate beam size for accuracy
            language="en",
            best_of=1,
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
    optimized_file = preprocess_audio(audio_file)
    transcribe_audio(optimized_file)