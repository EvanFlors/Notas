## Quiz: Multi-Modal Applications

Multi-Modal Applications
You are architecting a multi-modal AI assistant for a field service company. Technicians use mobile devices to photograph equipment issues, record voice notes about problems, and receive AI-generated diagnostic guidance with images and spoken instructions. The system processes 2,000 requests daily across vision, audio, and text modalities, with strict requirements for response time (under 5 seconds) and reliability (99.9% uptime).


Your knowledge base contains equipment manuals (PDFs), repair procedure videos, and troubleshooting photos. A technician asks 'How do I replace the filter on model X450?' What retrieval strategy should you use?

Search only text documents since the question is text-based

Search all modalities and return a mix of relevant text, images, and video clips

Return only video results since repair procedures are best shown visually

Generate a new response without retrieval since the question is straightforward
Correct Answer!
Multi-modal retrieval provides comprehensive guidance: text for steps, images/video for visual reference.

A technician sends a photo of a malfunctioning control panel and asks for help. The agent can respond with text, generated diagram, or spoken instructions. What should determine the response modality?

Always respond with the same modality the user used (photo → image response)

Always use text for maximum information density

Consider context: text for detailed steps, audio if hands are busy, images for visual guidance

Let the LLM decide the response modality autonomously
Correct Answer!
Optimal modality depends on content type and technician's situation.

Your system needs to process a request that requires: 1) transcribing a voice note, 2) analyzing an equipment photo, 3) generating a response, 4) converting to speech. What architecture pattern minimizes latency?

Sequential processing: transcribe → analyze → generate → speak

Parallel input processing (transcribe + analyze simultaneously), then generate, then speak

Batch all requests and process them together every 30 seconds

Skip audio transcription and analyze only the image to save time
Correct Answer!
Parallelizing independent operations (STT and vision) reduces total latency significantly.

Your multi-modal system costs are 60% vision API, 25% audio APIs, 15% text generation. Budget needs to be reduced by 30% without major quality impact. What should you optimize first?

Reduce text generation quality since it's the smallest cost component

Optimize vision costs: use low detail where appropriate, cache repeated image analyses

Replace all audio with text-only interfaces

Limit users to 5 requests per day to reduce volume
Correct Answer!
60% of cost means vision optimization has highest impact. Detail tuning and caching help significantly.

During a vision API outage, technicians cannot get photo-based diagnostics. What is the best fallback design?

Show error message and ask technicians to try again later

Fall back to text-based troubleshooting using symptom descriptions instead of photos

Queue photo analysis requests until vision API recovers

Automatically escalate all requests to human support during outages
Correct Answer!
Graceful degradation: text-based diagnosis is less optimal but still provides value.