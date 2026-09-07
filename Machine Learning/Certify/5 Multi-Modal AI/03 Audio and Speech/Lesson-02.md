## Getting Started with Speech-to-Text
You need to transcribe customer support calls, but manual transcription is expensive and slow. You have audio files in various formats, and you need accurate transcriptions that handle different accents and background noise. How do you use OpenAI Whisper API effectively to transcribe audio at scale?

OpenAI Whisper provides high-quality speech-to-text transcription with support for many languages and excellent accuracy. By the end of this lesson, you will understand how to use Whisper API, preprocess audio files, handle different formats, and build production transcription applications.

Understanding Whisper API
Whisper API accepts audio files and returns transcriptions. The API handles audio preprocessing, feature extraction, and transcription automatically.

Basic API Usage:

```python
from openai import OpenAI

client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

# Transcribe audio file
with open("audio.mp3", "rb") as audio_file:
  transcript = client.audio.transcriptions.create(
      model="whisper-1",
      file=audio_file,
      response_format="text"
  )

print(transcript)
```

Response Formats:

Format	Output Type	Includes Timestamps	Best For
text	Plain text string	No	Simple transcription, text processing
json	JSON object	No	Programmatic access, API integration
verbose_json	JSON with segments	Yes (per segment)	Detailed analysis, search indexing
srt	SubRip subtitle	Yes	Video subtitles, media players
vtt	WebVTT subtitle	Yes	Web video players, HTML5 video

```python
# Get detailed transcription with timestamps
with open("audio.mp3", "rb") as audio_file:
  transcript = client.audio.transcriptions.create(
      model="whisper-1",
      file=audio_file,
      response_format="verbose_json"
  )

# Access segments with timestamps
for segment in transcript.segments:
  print(f"{segment['start']:.2f}s - {segment['end']:.2f}s: {segment['text']}")
```

API Parameters and Options
Whisper API supports several parameters that affect transcription quality:

Language Specification:

```python
# Specify language for better accuracy
with open("audio.mp3", "rb") as audio_file:
  transcript = client.audio.transcriptions.create(
      model="whisper-1",
      file=audio_file,
      language="en",  # English
      response_format="text"
  )
```

Prompt Context:

Providing context improves accuracy for domain-specific terminology:

```python
# Provide context with prompt
with open("audio.mp3", "rb") as audio_file:
  transcript = client.audio.transcriptions.create(
      model="whisper-1",
      file=audio_file,
      prompt="This is a customer support call about product returns.",
      response_format="text"
  )
```

Temperature Control:

```python
# Lower temperature for more consistent results
with open("audio.mp3", "rb") as audio_file:
  transcript = client.audio.transcriptions.create(
      model="whisper-1",
      file=audio_file,
      temperature=0.0,  # More deterministic
      response_format="text"
  )
```

Audio Preprocessing
While Whisper handles various audio formats, preprocessing can significantly improve results and reduce costs.

Format Conversion:

```python
from pydub import AudioSegment

def preprocess_audio(input_path: str, output_path: str) -> str:
  """Preprocess audio for Whisper API."""
  # Load audio
  audio = AudioSegment.from_file(input_path)

  # Convert to mono (Whisper works best with mono)
  audio = audio.set_channels(1)

  # Set sample rate (16kHz is optimal for Whisper)
  audio = audio.set_frame_rate(16000)

  # Export as WAV
  audio.export(output_path, format="wav")

  return output_path
```

Audio Validation:

Always validate audio before sending to the API:

audio_validation.py

```python
import os
from pydub import AudioSegment

def validate_audio(file_path: str) -> dict:
  """Validate audio file before transcription."""
  # Check file exists
  if not os.path.exists(file_path):
      return {"valid": False, "error": "File not found"}

  # Check file size (25MB limit for Whisper API)
  file_size = os.path.getsize(file_path)
  if file_size > 25 * 1024 * 1024:
      return {"valid": False, "error": "File too large (max 25MB)"}

  # Check audio validity
  try:
      audio = AudioSegment.from_file(file_path)
      duration = len(audio) / 1000.0  # Duration in seconds

      return {
          "valid": True,
          "duration": duration,
          "channels": audio.channels,
          "sample_rate": audio.frame_rate
      }
  except Exception as e:
      return {"valid": False, "error": str(e)}
```

Chunking Long Audio:

For audio files longer than 10 minutes, split into chunks:

```python
from pydub import AudioSegment
from typing import List
import tempfile
import os

def chunk_audio(audio_path: str, chunk_minutes: int = 10) -> List[str]:
  """Split long audio into smaller chunks."""
  audio = AudioSegment.from_file(audio_path)
  chunk_ms = chunk_minutes * 60 * 1000

  chunks = []
  for i, start in enumerate(range(0, len(audio), chunk_ms)):
      chunk = audio[start:start + chunk_ms]

      # Save chunk to temp file
      chunk_path = tempfile.mktemp(suffix=".wav")
      chunk.export(chunk_path, format="wav")
      chunks.append(chunk_path)

  return chunks

def transcribe_long_audio(audio_path: str) -> str:
  """Transcribe long audio by chunking."""
  from openai import OpenAI
  client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

  chunks = chunk_audio(audio_path)
  transcripts = []

  for chunk_path in chunks:
      with open(chunk_path, "rb") as f:
          transcript = client.audio.transcriptions.create(
              model="whisper-1",
              file=f,
              response_format="text"
          )
      transcripts.append(transcript)
      os.remove(chunk_path)  # Clean up

  return " ".join(transcripts)
```

Production Implementation Patterns
Batch Processing:

Process multiple audio files concurrently:

```python
import asyncio
from openai import AsyncOpenAI
from typing import List

async def transcribe_audio_async(audio_path: str) -> dict:
  """Transcribe audio asynchronously."""
  client = AsyncOpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

  with open(audio_path, "rb") as audio_file:
      transcript = await client.audio.transcriptions.create(
          model="whisper-1",
          file=audio_file,
          response_format="verbose_json"
      )

  return {"path": audio_path, "transcript": transcript}

async def transcribe_batch(audio_paths: List[str]) -> List[dict]:
  """Transcribe multiple audio files concurrently."""
  tasks = [transcribe_audio_async(path) for path in audio_paths]
  return await asyncio.gather(*tasks)
```

Error Handling with Retries:

```python
from openai import OpenAI, APIError
import time

def transcribe_with_retry(audio_path: str, max_retries: int = 3) -> dict:
  """Transcribe with retry logic."""
  client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

  for attempt in range(max_retries):
      try:
          with open(audio_path, "rb") as audio_file:
              transcript = client.audio.transcriptions.create(
                  model="whisper-1",
                  file=audio_file,
                  response_format="text"
              )
          return {"success": True, "transcript": transcript}

      except APIError as e:
          if e.status_code in [400, 401, 403]:
              return {"success": False, "error": f"API error: {e.message}"}
          wait_time = 2 ** attempt
          time.sleep(wait_time)

      except Exception as e:
          return {"success": False, "error": str(e)}

  return {"success": False, "error": "Failed after retries"}
```

Caching Transcriptions:

```python
import hashlib
import json

class TranscriptionCache:
  """Cache transcriptions to avoid redundant API calls."""

  def __init__(self, storage_backend):
      self.storage = storage_backend

  def get_cache_key(self, audio_path: str, language: str, prompt: str) -> str:
      """Generate cache key from audio hash and parameters."""
      with open(audio_path, "rb") as f:
          file_hash = hashlib.sha256(f.read()).hexdigest()

      key_data = json.dumps({
          'hash': file_hash,
          'language': language,
          'prompt': prompt
      }, sort_keys=True)

      return hashlib.sha256(key_data.encode()).hexdigest()

  def get(self, audio_path: str, language: str = None, prompt: str = None):
      """Get cached transcription."""
      key = self.get_cache_key(audio_path, language, prompt)
      return self.storage.get(key)

  def set(self, audio_path: str, language: str, prompt: str, transcript: str):
      """Cache transcription."""
      key = self.get_cache_key(audio_path, language, prompt)
      self.storage.set(key, transcript)
```

Common Pitfalls
File Size Limits: Whisper API has a 25MB file size limit. Always validate and compress audio before sending.

Language Detection: While Whisper auto-detects language, explicitly specifying it improves accuracy, especially for accented speech.

Missing Context: Without domain-specific prompts, technical terms and proper nouns may be transcribed incorrectly.

Ignoring Timestamps: For applications like subtitles or searchable archives, always request verbose_json format to get timing information.

Summary
OpenAI Whisper API provides high-quality speech-to-text transcription with support for multiple languages and response formats. Proper audio preprocessing, validation, and chunking ensure reliable results even with diverse audio sources.

Production applications benefit from batch processing, caching, and robust error handling. Understanding API parameters like language hints and context prompts helps achieve better transcription accuracy.

Key concepts to remember
Whisper API supports multiple response formats including timestamps for subtitles
Preprocess audio to mono 16kHz for optimal results
Use context prompts to improve accuracy for domain-specific terminology
Chunk long audio files to stay within API limits
Implement caching to avoid redundant transcriptions of the same audio