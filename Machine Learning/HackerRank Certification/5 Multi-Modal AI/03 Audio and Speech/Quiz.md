## Quiz: Audio and Speech Processing

Audio and Speech Processing
You are building a voice-enabled customer support system for a telecommunications company. The system needs to transcribe customer calls, generate spoken responses, and provide real-time voice interaction. You handle 5,000 calls daily averaging 4 minutes each, with customers speaking various accents and often having background noise from busy environments.


Your system serves customers who speak English, Spanish, and Mandarin. Whisper can auto-detect language, but your transcription accuracy for Spanish speakers is lower than expected. What should you do?

Trust auto-detection - it's designed to handle multiple languages

Ask the customer to select their language preference and pass it to the language parameter

Transcribe in all three languages and pick the most confident result

Fine-tune Whisper on Spanish audio samples
Correct Answer!
Explicit language specification improves accuracy, especially for accented speech.

A customer call recording is 25 minutes long and exceeds Whisper's file size limit. How should you handle this?

Compress the audio to lower bitrate until it fits the size limit

Split into 10-minute chunks with small overlaps, transcribe each, then combine

Transcribe only the first 10 minutes as a representative sample

Speed up the audio 2x to fit within the limit
Correct Answer!
Chunking with overlaps handles long audio while maintaining context at boundaries.

You need to generate voice responses for: 1) Friendly greetings, 2) Account balance information, 3) Urgent fraud alerts. How should you select voices?

Use one consistent voice for brand recognition across all scenarios

Use warm voice (nova/shimmer) for greetings, neutral voice (alloy) for information, authoritative voice (onyx) for alerts

Let customers choose their preferred voice in settings

Use the fastest-generating voice to minimize latency
Correct Answer!
Match voice characteristics to message tone: warm for service, clear for data, authoritative for urgency.

Your voice assistant has total round-trip latency of 3 seconds (STT: 800ms, LLM: 1500ms, TTS: 700ms). Users report it feels 'robotic and slow'. What is the most effective optimization?

Use tts-1-hd for higher quality audio that sounds more natural

Pre-generate common responses and stream TTS output as it generates

Add filler phrases like 'Let me check that for you' during processing

Switch to a faster LLM model even if responses are lower quality
Correct Answer!
Caching common phrases and streaming reduces perceived latency significantly.

Your TTS service occasionally fails during peak hours, leaving customers with no audio response. What is the best reliability pattern?

Retry failed requests up to 5 times with exponential backoff

Implement retry with backoff plus text fallback when TTS fails

Queue requests and process them when the service recovers

Pre-generate all possible responses to avoid runtime generation
Correct Answer!
Retry handles transient issues; text fallback ensures customers always get a response.