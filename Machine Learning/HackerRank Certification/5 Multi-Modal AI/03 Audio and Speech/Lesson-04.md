# Voice Agents y Audio en Producción

## ¿Qué es?

Un **voice agent** es una aplicación conversacional cuya interfaz de entrada y salida es la voz. Encadena tres (o cuatro) sistemas en tiempo real para que un humano pueda hablar con una IA como lo haría con otra persona:

```
Micrófono → VAD → ASR → LLM → TTS → Altavoz
                               ↑
                     (turn-taking + barge-in)
```

Hay **dos arquitecturas** vigentes:

| Arquitectura | Cómo funciona | Latencia típica | Cuándo |
|---|---|---|---|
| **Pipeline clásico** (cascaded) | ASR + LLM + TTS como servicios separados orquestados sobre WebSocket/WebRTC | 1.0 – 2.5 s | control total, modelos intercambiables, bajo costo |
| **Speech-to-speech end-to-end** | un único modelo multimodal que recibe audio y emite audio (GPT-4o audio, Gemini Live) | 0.3 – 0.6 s | menor latencia, preserva emoción y risas, menos partes móviles |

![Pipeline de voice interface mostrando entrada de voz fluyendo por STT, procesamiento y TTS con latencia en cada paso](https://hrcdn.net/ai-engineering/module-5/light/audio-lesson04-voice-interface-pipeline.svg)

### Elementos invisibles pero críticos

- **VAD (Voice Activity Detection)**: para saber cuándo el usuario empieza y termina de hablar.
- **End-pointing**: regla que decide "ya terminó de hablar, puedo responder" (ej. 500 ms de silencio tras habla).
- **Barge-in**: detectar que el usuario interrumpe al agente y cortar la reproducción TTS instantáneamente.
- **Echo cancellation + noise suppression**: evitar que el agente se oiga a sí mismo por el micrófono y "se transcriba" en bucle.
- **Jitter buffer y FEC** (Forward Error Correction): gestionar paquetes perdidos en red sin congelar la voz.

Todo esto lo resuelve **WebRTC** out-of-the-box, por eso es el transporte estándar en voice agents serios.

## ¿Por qué importa?

- **Reemplazo de IVR tradicional.** Los IVR "pulse 1 para…" tienen tasas de abandono del 40-60 %. Un voice agent conversacional las reduce al 10-20 %.
- **Atención 24/7 sin costo lineal.** Un agente humano cuesta $15-30/hora; un voice agent, $0.10-0.50/minuto de llamada.
- **Outbound calling.** Recordatorios de cita, encuestas, cobranza — tareas donde la voz humana es cara y los voice agents escalan.
- **Accesibilidad real.** Interfaces de voz para personas con movilidad reducida o baja alfabetización.
- **Nueva categoría de producto.** Compañeros virtuales, tutores de idiomas (ElevenLabs Conversational AI, Rime, Vapi, Retell), asistentes de campo.

El mercado se está moviendo rápido: en 2024 aparecieron SDKs como **LiveKit Agents**, **Pipecat** (Daily), **Vapi**, **Retell** que empaquetan todo el stack.

### Cuándo NO montar un voice agent

- **Flujos regulatorios estrictos** (banca con requisito de locutor humano, consentimiento verbal explícito registrado).
- **Idiomas con poca cobertura** de ASR/TTS: podrías pasar de 2 % WER humano a 25 % con modelo abierto.
- **Entornos muy ruidosos** sin hardware de captura adecuado (fábricas, obras): el WER se desploma.
- **Casos con muy bajo volumen** donde el costo de infra supera el ahorro.

## ¿Cómo funciona?

### Presupuesto de latencia (budget)

Un turno conversacional "natural" exige respuesta en **~500-800 ms** desde que el usuario termina de hablar. Desglose típico:

| Etapa | Latencia aceptable | Técnica para bajarla |
|---|---|---|
| **End-point detection** | 200 – 500 ms | VAD agresivo, modelos de turn-taking |
| **ASR** (final) | 100 – 500 ms | streaming (Deepgram Nova-3, AssemblyAI Universal-Streaming) |
| **LLM** (TTFT) | 200 – 700 ms | modelos pequeños (gpt-4.1-mini, Llama 3.1 8B), prompt caching |
| **TTS** (TTFB) | 75 – 400 ms | `eleven_flash_v2_5`, Cartesia Sonic, streaming WebSocket |
| **Red + jitter** | 50 – 150 ms | WebRTC regional, edge POP |
| **Total razonable** | **~800 ms – 1.5 s** | pipeline bien afinado |

Para bajar de 500 ms hay que ir a speech-to-speech end-to-end o aceptar menor control sobre partes del pipeline.

### Técnicas de optimización

1. **Streaming en toda la cadena.** No esperes al final de nada. El ASR emite transcripción parcial; el LLM genera tokens; el TTS sintetiza mientras llegan tokens. Idealmente el primer audio sale antes de que termine la respuesta del LLM.
2. **Modelo LLM rápido.** `gpt-4.1-mini` o `claude-haiku` suelen bastar; limita `max_tokens` (voz corta funciona mejor).
3. **Prompt caching.** Si tu system prompt es de 2000 tokens y no cambia, cachéalo (OpenAI y Anthropic lo soportan nativamente).
4. **Pre-generación de frases comunes.** Saludos, muletillas, "déjame ver eso", "un segundo por favor" — caché hit en el 60-80 % del tráfico.
5. **Fillers inteligentes.** Mientras el LLM piensa (si tarda >500 ms), reproduce un "mhm" o "déjame revisar" cacheado. Da la ilusión de pensamiento.
6. **Speculative generation.** Empieza a sintetizar TTS mientras el LLM aún genera, cortando por frases completas.
7. **Collocar servicios.** ASR, LLM y TTS en la misma región; evita round-trips transcontinentales.
8. **Barge-in correcto.** Al detectar voz entrante, mata el TTS en curso (cancela el stream) y limpia el buffer del altavoz.

### Control de concurrencia y backpressure

Audio es costoso en CPU, memoria y rate limits de APIs. Patrones imprescindibles:

- **Semáforos** por tipo de operación: `asyncio.Semaphore(10)` para ASR, `Semaphore(20)` para TTS.
- **Colas con backpressure**: si la cola crece, rechaza nuevas sesiones antes de degradar las existentes.
- **Timeouts duros** por etapa: si el ASR tarda >3 s, cancela y degrada a texto.
- **Circuit breaker** por proveedor: si ElevenLabs falla el 20 % de las llamadas en 1 min, cambia a OpenAI TTS automáticamente.

### Reliability patterns

| Falla | Mitigación |
|---|---|
| ASR tarda mucho | timeout → responder "¿puedes repetir?" o degradar a texto |
| LLM 429 / 5xx | retry exponencial (max 2) → fallback a modelo más chico |
| TTS falla | fallback a otra voz / otro proveedor → último recurso: texto |
| Red inestable | WebRTC con FEC + jitter buffer; reconexión transparente |
| Transcripción vacía | asumir silencio, no empujar al LLM, pedir repetir |
| Alucinación de ASR en silencio | VAD estricto + filtrado por `no_speech_prob` |

### Observabilidad

Qué medir obligatoriamente, por turno:

- Latencias por etapa (STT, LLM, TTS) + total.
- WER estimado (vs transcripción de referencia en muestras).
- Tasa de barge-in exitoso (si el usuario interrumpe, ¿se cortó el TTS en <200 ms?).
- Tasa de completion por intento.
- Costos por llamada ($$ en ASR, LLM, TTS, telefonía).
- Métricas de calidad percibida: MOS, CSAT post-llamada.

Herramientas: **LangFuse / Helicone** para LLM, **Grafana + Prometheus** para latencias, **LiveKit Egress** para grabar llamadas y auditar.

### Stacks completos de referencia

| Stack | Transporte | ASR | LLM | TTS | Orquestador |
|---|---|---|---|---|---|
| LiveKit Agents | WebRTC | Deepgram / Whisper | OpenAI / Anthropic | ElevenLabs / Cartesia | LiveKit |
| Pipecat (Daily) | WebRTC | Deepgram | OpenAI | ElevenLabs | Pipecat |
| Vapi | SIP + WebRTC | Deepgram | elegible | elegible | Vapi hosted |
| Retell | SIP + WebRTC | gestionado | elegible | elegible | Retell hosted |
| OpenAI Realtime | WebSocket | integrado | integrado (gpt-4o audio) | integrado | nativo |
| Twilio + propio | SIP | Deepgram/Google | OpenAI | ElevenLabs | custom |

## Ejemplo con código

### Pipeline voice-agent clásico con medición de latencia

```python
import asyncio, time
from openai import AsyncOpenAI

client = AsyncOpenAI(api_key="API_KEY", base_url="BASE_URL")

class VoiceAgent:
    def __init__(self, voice: str = "nova", system: str = ""):
        self.voice = voice
        self.history = [{"role": "system", "content": system}]
        self.cache: dict[str, bytes] = {}

    async def warm_up(self, phrases: list[str]):
        """Pre-genera audio de frases comunes."""
        for p in phrases:
            r = await client.audio.speech.create(
                model="tts-1", voice=self.voice, input=p, response_format="mp3",
            )
            self.cache[p] = r.content

    async def turn(self, audio_path: str) -> dict:
        t0 = time.perf_counter()

        # ASR
        with open(audio_path, "rb") as f:
            stt = await client.audio.transcriptions.create(
                model="whisper-1", file=f, language="es",
            )
        user_text = stt.text.strip()
        t_stt = time.perf_counter()

        if not user_text:
            return {"skipped": True, "reason": "transcripción vacía"}

        # LLM (streaming para medir TTFT)
        self.history.append({"role": "user", "content": user_text})
        stream = await client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=self.history,
            max_tokens=120,
            stream=True,
        )
        reply, t_ttft = "", None
        async for chunk in stream:
            delta = chunk.choices[0].delta.content or ""
            if delta and t_ttft is None:
                t_ttft = time.perf_counter()
            reply += delta
        reply = reply.strip()
        t_llm = time.perf_counter()
        self.history.append({"role": "assistant", "content": reply})

        # TTS (con caché hit)
        if reply in self.cache:
            audio = self.cache[reply]
        else:
            r = await client.audio.speech.create(
                model="tts-1", voice=self.voice, input=reply, response_format="mp3",
            )
            audio = r.content
        t_tts = time.perf_counter()

        return {
            "user": user_text,
            "reply": reply,
            "audio_bytes": audio,
            "latency_ms": {
                "stt": int((t_stt - t0) * 1000),
                "llm_ttft": int((t_ttft - t_stt) * 1000) if t_ttft else None,
                "llm_total": int((t_llm - t_stt) * 1000),
                "tts": int((t_tts - t_llm) * 1000),
                "total": int((t_tts - t0) * 1000),
            },
        }

async def demo():
    agent = VoiceAgent(system="Eres un agente de soporte conciso. Responde en una frase.")
    await agent.warm_up([
        "Un momento, por favor.",
        "¿En qué más te puedo ayudar?",
        "No te entendí, ¿puedes repetir?",
    ])
    out = await agent.turn("usuario.wav")
    print(out["latency_ms"])

# asyncio.run(demo())
```

### Control de concurrencia por operación

```python
import asyncio

class AudioService:
    def __init__(self, client, stt_concurrency=5, tts_concurrency=20):
        self.client = client
        self.stt_sem = asyncio.Semaphore(stt_concurrency)
        self.tts_sem = asyncio.Semaphore(tts_concurrency)

    async def transcribe(self, path: str, language="es") -> str:
        async with self.stt_sem:
            with open(path, "rb") as f:
                r = await self.client.audio.transcriptions.create(
                    model="whisper-1", file=f, language=language,
                )
            return r.text

    async def speak(self, text: str, voice="nova") -> bytes:
        async with self.tts_sem:
            r = await self.client.audio.speech.create(
                model="tts-1", voice=voice, input=text,
            )
            return r.content
```

### Retries con backoff y fallback de voz

```python
import asyncio, logging
log = logging.getLogger(__name__)

async def transcribe_resiliente(client, path: str, retries: int = 3, lang="es") -> dict:
    last_err = None
    for i in range(retries):
        try:
            with open(path, "rb") as f:
                r = await client.audio.transcriptions.create(
                    model="whisper-1", file=f, language=lang,
                )
            return {"ok": True, "text": r.text, "attempts": i + 1}
        except FileNotFoundError:
            return {"ok": False, "error": "archivo no encontrado"}
        except Exception as e:
            last_err = str(e)
            log.warning("ASR intento %d falló: %s", i + 1, e)
            if i < retries - 1:
                await asyncio.sleep(2 ** i)
    return {"ok": False, "error": last_err, "attempts": retries}

async def speak_con_fallback(client, text: str, voices=("nova", "alloy")) -> dict:
    for v in voices:
        try:
            r = await client.audio.speech.create(model="tts-1", voice=v, input=text)
            return {"ok": True, "voice": v, "audio": r.content}
        except Exception as e:
            log.warning("TTS falló con %s: %s", v, e)
    return {"ok": False, "text_fallback": text}
```

### Streaming TTS con barge-in (patrón)

```python
import asyncio

class BargeInController:
    """Permite cancelar el TTS en curso cuando el usuario empieza a hablar."""

    def __init__(self):
        self._cancel = asyncio.Event()
        self._task: asyncio.Task | None = None

    def notify_user_speaking(self):
        """VAD detectó voz del usuario → corta el TTS."""
        self._cancel.set()
        if self._task and not self._task.done():
            self._task.cancel()

    async def play_tts_stream(self, client, text: str, voice="nova"):
        self._cancel.clear()

        async def _runner():
            async with client.audio.speech.with_streaming_response.create(
                model="tts-1", voice=voice, input=text, response_format="pcm",
            ) as response:
                async for chunk in response.iter_bytes(chunk_size=4096):
                    if self._cancel.is_set():
                        return
                    # enviar chunk al reproductor / websocket
                    await send_to_speaker(chunk)   # placeholder

        self._task = asyncio.create_task(_runner())
        try:
            await self._task
        except asyncio.CancelledError:
            pass

async def send_to_speaker(chunk: bytes):
    ...  # integración con tu player (WebRTC track, pyaudio, etc.)
```

### Voice agent con OpenAI Realtime (speech-to-speech)

```python
# pip install openai websockets
import asyncio, base64, json, websockets

URL = "wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview"

async def realtime_demo(audio_chunks_generator):
    headers = {"Authorization": "Bearer API_KEY", "OpenAI-Beta": "realtime=v1"}
    async with websockets.connect(URL, extra_headers=headers) as ws:
        # Configura sesión: audio in/out, VAD server-side
        await ws.send(json.dumps({
            "type": "session.update",
            "session": {
                "modalities": ["audio", "text"],
                "voice": "alloy",
                "input_audio_format": "pcm16",
                "output_audio_format": "pcm16",
                "input_audio_transcription": {"model": "whisper-1"},
                "turn_detection": {"type": "server_vad",
                                   "threshold": 0.5,
                                   "silence_duration_ms": 500},
                "instructions": "Eres un asistente conciso en español.",
            },
        }))

        async def send_audio():
            async for pcm in audio_chunks_generator:
                await ws.send(json.dumps({
                    "type": "input_audio_buffer.append",
                    "audio": base64.b64encode(pcm).decode(),
                }))

        async def recv_events():
            while True:
                evt = json.loads(await ws.recv())
                if evt["type"] == "response.audio.delta":
                    pcm = base64.b64decode(evt["delta"])
                    await send_to_speaker(pcm)
                elif evt["type"] == "input_audio_buffer.speech_started":
                    # el usuario empezó a hablar → el servidor ya canceló la respuesta
                    print("barge-in detectado")
                elif evt["type"] == "response.done":
                    print("turno terminado")

        await asyncio.gather(send_audio(), recv_events())
```

Con la Realtime API, el **VAD server-side**, la **interrupción** y el **streaming bidireccional** vienen integrados; no necesitas orquestar ASR + LLM + TTS por separado.

### Voice agent con LiveKit Agents

```python
# pip install livekit-agents livekit-plugins-openai livekit-plugins-deepgram livekit-plugins-elevenlabs
from livekit.agents import JobContext, WorkerOptions, cli
from livekit.agents.voice_assistant import VoiceAssistant
from livekit.plugins import openai, deepgram, elevenlabs, silero

async def entrypoint(ctx: JobContext):
    await ctx.connect()

    assistant = VoiceAssistant(
        vad=silero.VAD.load(),
        stt=deepgram.STT(model="nova-3", language="es"),
        llm=openai.LLM(model="gpt-4.1-mini"),
        tts=elevenlabs.TTS(voice="EXAVITQu4vr4xnSDxMaL",
                           model="eleven_flash_v2_5"),
        chat_ctx=openai.ChatContext().append(
            role="system",
            text="Eres un asistente telefónico amable y conciso en español.",
        ),
        interrupt_speech_duration=0.5,  # cuánto habla el usuario para disparar barge-in
        allow_interruptions=True,
    )
    assistant.start(ctx.room)

if __name__ == "__main__":
    cli.run_app(WorkerOptions(entrypoint_fnc=entrypoint))
```

Este patrón, en ~30 líneas, te da un agente conectado a una sala WebRTC con VAD, ASR streaming, LLM, TTS streaming y barge-in bien resueltos.

### Métricas de observabilidad

```python
from dataclasses import dataclass, field
from statistics import median

@dataclass
class TurnMetrics:
    stt_ms: int
    llm_ms: int
    tts_ms: int
    total_ms: int
    tokens_in: int
    tokens_out: int
    cost_usd: float

class MetricsCollector:
    def __init__(self):
        self.turns: list[TurnMetrics] = []

    def record(self, m: TurnMetrics):
        self.turns.append(m)

    def report(self) -> dict:
        if not self.turns:
            return {}
        totals = [t.total_ms for t in self.turns]
        return {
            "turns": len(self.turns),
            "p50_ms": median(totals),
            "p95_ms": sorted(totals)[int(len(totals) * 0.95)],
            "cost_usd": round(sum(t.cost_usd for t in self.turns), 4),
        }
```

## Errores comunes

- **Bloquear en I/O de audio.** Todo el pipeline debe ser `async`. Un `open().read()` síncrono con un archivo de 10 MB congela el event loop y arruina la latencia de los demás turnos.
- **Sin barge-in.** Si el usuario interrumpe y el bot sigue hablando, la conversación se siente robótica. Implementa VAD en el canal de entrada mientras reproduces TTS y cancela el stream al detectar voz.
- **Olvidar el end-pointing.** Si no decides cuándo el usuario "terminó", o esperas demasiado (silencio de 2 s se siente eterno), o cortas antes de tiempo. 300-500 ms de silencio es el sweet spot.
- **Pipeline sin streaming.** Esperar transcripción completa + respuesta completa + audio completo antes de reproducir → latencias de 3-5 s. Stream todo o acepta la lentitud.
- **Modelo LLM pesado.** `gpt-4o` o `claude-opus` generan en 1-2 s el primer token; en voice agents conviene `gpt-4.1-mini`, `gpt-4o-mini` o `claude-haiku` salvo que la tarea lo exija.
- **Respuestas largas.** Si el LLM contesta 500 palabras, el usuario abandona. `max_tokens=120-150` + prompt que pida respuestas de una frase.
- **No cachear frases comunes.** 60-80 % del tráfico de TTS son muletillas; sin caché, es costo y latencia tirados.
- **Sin fallback de proveedor.** Si ElevenLabs tiene incidente, el bot queda mudo. Define fallback (OpenAI TTS, voz interna, texto plano al cliente).
- **Ignorar echo cancellation.** El agente se oye por el micrófono, lo transcribe, el LLM responde a lo que él mismo dijo → bucle. Usa WebRTC con AEC activado o un canal dedicado.
- **Costos sin control.** 5.000 llamadas/día × 4 min × (ASR + LLM + TTS + telefonía) escala rápido. Define budget por sesión y métricas por minuto.
- **Timeouts ausentes.** Si una etapa cuelga 30 s, se cae todo el turno. Timeouts duros (p.ej. ASR 3 s, LLM 5 s, TTS 3 s) con degradación graciosa.
- **Sin observabilidad.** Problemas de calidad de audio no son obvios en logs textuales. Mide p50/p95 por etapa, tasa de barge-in exitoso, WER en muestras, costo por llamada.
- **Grabar sin consentimiento.** Many-party consent es obligatorio en varias jurisdicciones (CA, FL, PA en EE. UU.; UE con GDPR). Anuncia al inicio y audita.

## Resumen

- Un **voice agent** encadena VAD + ASR + LLM + TTS (clásico) o usa un modelo speech-to-speech end-to-end (GPT-4o audio, Gemini Live) para latencia mínima.
- Presupuesto de latencia conversacional natural: **~800 ms – 1.5 s**; speech-to-speech alcanza **~300-600 ms**.
- **Streaming en toda la cadena** (ASR, LLM, TTS) + **caché de frases comunes** + **fillers inteligentes** son las palancas principales de optimización.
- **Barge-in** y **end-pointing** son invisibles pero críticos: sin ellos, el agente se siente robótico.
- Usa **WebRTC** como transporte (echo cancellation, FEC, jitter buffer gratis); **SIP** para telefonía (Twilio, Vonage).
- Stacks maduros: **LiveKit Agents**, **Pipecat**, **Vapi**, **Retell**, **OpenAI Realtime**.
- Patrones productivos imprescindibles: semáforos por operación, timeouts duros, retries con backoff, fallback de voz y proveedor, circuit breaker.
- Observabilidad: p50/p95 por etapa, tasa de barge-in exitoso, WER en muestras, costo por llamada, MOS.
- Errores que más duelen: bloquear I/O, sin barge-in, sin streaming, modelo LLM pesado, respuestas largas, no cachear, sin fallback, sin echo cancellation.
