## Getting Started with Text-to-Speech
You need to generate voice responses for your application, but hiring voice actors for every possible response is impractical. You want natural-sounding speech that matches your brand voice, with control over pronunciation, speed, and clarity. How do you use OpenAI TTS API effectively?

OpenAI Text-to-Speech API generates high-quality, natural-sounding speech from text. By the end of this lesson, you will understand how to use TTS API, select appropriate voices, control speech parameters, and build production applications that generate speech reliably.

Understanding TTS API
OpenAI TTS API converts text to speech and returns audio files. The API supports multiple voices, languages, and output formats.

Basic API Usage:

```python
from openai import OpenAI

client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

response = client.audio.speech.create(
  model="tts-1",
  voice="alloy",
  input="Hello, this is a test of text-to-speech."
)

# Save audio file
response.stream_to_file("output.mp3")
```

Available Voices:

| Voice	| Characteristics	| Best For
| --- | --- | ---
| alloy	| Balanced, neutral	| General purpose, educational content
| echo	| Clear, professional	| Business presentations, announcements
| fable	| Expressive, engaging	| Storytelling, creative content
| onyx	| Deep, authoritative	| News, documentaries, formal content
| nova	| Warm, friendly	| Customer support, conversational apps
| shimmer	| Soft, gentle	| Meditation, wellness, children content

Model Selection
OpenAI offers two TTS models with different quality and latency trade-offs:

| Model	| Quality	| Latency	| Best For
| --- | --- | --- | ---
| tts-1	| Standard	| Low (optimized for speed)	| Real-time applications, voice assistants
| tts-1-hd	| High Definition	| Higher	| Pre-generated content, podcasts, audiobooks

```python
response = client.audio.speech.create(
  model="tts-1",
  voice="alloy",
  input="Quick response for real-time use."
)

# HD model for pre-generated content
response = client.audio.speech.create(
  model="tts-1-hd",
  voice="alloy",
  input="High-quality audio for important content."
)
```

Voice Selection and Speech Parameters
Selecting the right voice and parameters significantly impacts user experience.

Voice Selection Strategy:

```python
class VoiceSelector:
  """Select appropriate voice for use case."""

  VOICE_MAP = {
      'customer_support': 'nova',
      'professional': 'echo',
      'educational': 'alloy',
      'creative': 'fable',
      'authoritative': 'onyx',
      'friendly': 'shimmer'
  }

  VOICE_DESCRIPTIONS = {
      'alloy': 'Balanced and neutral',
      'echo': 'Clear and professional',
      'fable': 'Expressive and engaging',
      'onyx': 'Deep and authoritative',
      'nova': 'Warm and friendly',
      'shimmer': 'Soft and gentle'
  }

  def select_voice(self, use_case: str) -> str:
      """Select voice based on use case."""
      return self.VOICE_MAP.get(use_case, 'alloy')

  def get_description(self, voice: str) -> str:
      """Get voice description."""
      return self.VOICE_DESCRIPTIONS.get(voice, 'Unknown voice')
```

Speed Control:

```python
# Control speech speed (0.25x to 4.0x)
response = client.audio.speech.create(
  model="tts-1",
  voice="alloy",
  input="This is spoken at normal speed.",
  speed=1.0  # Normal speed
)

# Slower for accessibility
response = client.audio.speech.create(
  model="tts-1",
  voice="alloy",
  input="This is spoken more slowly for clarity.",
  speed=0.85
)

# Faster for summaries
response = client.audio.speech.create(
  model="tts-1",
  voice="alloy",
  input="Quick summary at faster pace.",
  speed=1.25
)
```

Output Format Options:

```python
def generate_speech(text: str, voice: str, format: str = "mp3") -> bytes:
  """Generate speech in specified format."""
  client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

  # Supported formats: mp3, opus, aac, flac, wav, pcm
  response = client.audio.speech.create(
      model="tts-1",
      voice=voice,
      input=text,
      response_format=format
  )

  return response.content

# MP3 for web delivery (smallest, widely supported)
mp3_audio = generate_speech("Hello world", "alloy", "mp3")

# WAV for editing and processing
wav_audio = generate_speech("Hello world", "alloy", "wav")

# OPUS for streaming (excellent compression)
opus_audio = generate_speech("Hello world", "alloy", "opus")
```

Streaming Audio
For real-time applications, stream audio as it generates:

```python
def stream_speech(text: str, voice: str):
  """Stream speech generation for real-time playback."""
  client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

  response = client.audio.speech.create(
      model="tts-1",
      voice=voice,
      input=text
  )

  # Stream to file
  response.stream_to_file("output.mp3")

def stream_to_bytes(text: str, voice: str) -> bytes:
  """Stream speech to bytes for API responses."""
  client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

  response = client.audio.speech.create(
      model="tts-1",
      voice=voice,
      input=text
  )

  # Collect all chunks
  audio_chunks = []
  for chunk in response.iter_bytes():
      audio_chunks.append(chunk)

  return b"".join(audio_chunks)
```

Production Implementation Patterns
Batch Generation:

```python
import asyncio
from openai import AsyncOpenAI
from pathlib import Path

async def generate_speech_async(text: str, voice: str, output_path: str) -> str:
  """Generate speech asynchronously."""
  client = AsyncOpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

  response = await client.audio.speech.create(
      model="tts-1",
      voice=voice,
      input=text
  )

  # Save to file
  Path(output_path).write_bytes(response.content)
  return output_path

async def generate_batch(items: list[dict], output_dir: str) -> list[str]:
  """Generate multiple audio files concurrently."""
  Path(output_dir).mkdir(parents=True, exist_ok=True)

  tasks = [
      generate_speech_async(
          item["text"],
          item.get("voice", "alloy"),
          f"{output_dir}/audio_{i}.mp3"
      )
      for i, item in enumerate(items)
  ]
  return await asyncio.gather(*tasks)
```

Caching TTS Output:

```python
import hashlib
from pathlib import Path

class TTSCache:
  """Cache TTS audio files to avoid redundant generation."""

  def __init__(self, cache_dir: str = "./tts_cache"):
      self.cache_dir = Path(cache_dir)
      self.cache_dir.mkdir(parents=True, exist_ok=True)

  def get_cache_key(self, text: str, voice: str, speed: float) -> str:
      """Generate cache key from parameters."""
      key_data = f"{text}:{voice}:{speed}"
      return hashlib.sha256(key_data.encode()).hexdigest()

  def get(self, text: str, voice: str, speed: float = 1.0) -> bytes | None:
      """Get cached audio if exists."""
      key = self.get_cache_key(text, voice, speed)
      cache_file = self.cache_dir / f"{key}.mp3"

      if cache_file.exists():
          return cache_file.read_bytes()
      return None

  def set(self, text: str, voice: str, speed: float, audio_data: bytes):
      """Cache audio data."""
      key = self.get_cache_key(text, voice, speed)
      cache_file = self.cache_dir / f"{key}.mp3"
      cache_file.write_bytes(audio_data)
```

Error Handling:

```python
from openai import OpenAI, APIError
import time

def generate_speech_with_retry(text: str, voice: str, max_retries: int = 3) -> dict:
  """Generate speech with retry logic."""
  client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

  for attempt in range(max_retries):
      try:
          response = client.audio.speech.create(
              model="tts-1",
              voice=voice,
              input=text
          )
          return {"success": True, "audio": response.content}

      except APIError as e:
          if e.status_code in [400, 401, 403]:
              return {"success": False, "error": f"API error: {e.message}"}
          wait_time = 2 ** attempt
          time.sleep(wait_time)

      except Exception as e:
          return {"success": False, "error": str(e)}

  return {"success": False, "error": "Failed after retries"}
```

Common Pitfalls
Text Length Limits: Very long text may hit API limits. Break long content into paragraphs and generate separately.

Inconsistent Voice: Mixing voices within a single application creates a jarring experience. Establish voice guidelines.

Ignoring Speed: Default speed may not suit all contexts. Accessibility content benefits from slower speech.

No Caching: Regenerating the same text wastes API credits. Implement caching for frequently used phrases.

Summary
OpenAI TTS API provides high-quality text-to-speech with multiple voice options and flexible parameters. Selecting appropriate voices based on use case, controlling speed and quality, and implementing caching are essential for production applications.

Key concepts to remember
Choose voices based on your use case and brand personality
Use tts-1 for real-time applications, tts-1-hd for pre-generated content
Adjust speed for accessibility (slower) or summaries (faster)
Cache generated audio to reduce costs and latency
Handle errors with retry logic for production reliability