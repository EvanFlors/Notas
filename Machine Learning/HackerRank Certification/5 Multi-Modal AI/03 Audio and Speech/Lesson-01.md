# Introducción a Audio y Voz

## ¿Qué es?

El **procesamiento de audio y voz con IA** es el conjunto de técnicas que permiten a una aplicación **entender el habla humana** (speech-to-text) y **generar habla sintética** (text-to-speech). Entre ambas direcciones se construye la capa que convierte interfaces de texto en experiencias conversacionales por voz.

Hay tres grandes familias de capacidades:

| Capacidad | Dirección | Salida |
|---|---|---|
| **ASR** (Automatic Speech Recognition) / STT | audio → texto | transcripción, posiblemente con timestamps y hablantes |
| **TTS** (Text-to-Speech) | texto → audio | onda de audio reproducible (WAV, MP3, Opus, PCM) |
| **Speech-to-Speech** | audio → audio | modelo end-to-end que recibe y emite voz sin pasar por texto intermedio (GPT-4o audio, Gemini Live) |

Alrededor de esas tres patas aparecen tareas auxiliares que determinan la calidad de un sistema real: **VAD** (detectar cuándo hay voz y cuándo silencio), **diarización** (saber *quién* habló cuando hay varios hablantes), **voice cloning** (reproducir el timbre de una persona a partir de unos segundos de muestra) y **streaming en tiempo real** (procesar audio parcial mientras llega, no al final del archivo).

> **Audio en la práctica es señal, no texto.** Un archivo de audio es una secuencia de muestras numéricas que representa la presión del aire en el tiempo. Antes de entrar a un modelo, esa señal debe estar en el formato correcto (WAV/PCM, mono, 16 kHz) o el modelo producirá basura silenciosamente.

### Formatos de audio: WAV vs MP3 vs OGG vs FLAC

| Formato | Compresión | Pérdida | Tamaño típico (1 min, mono 16 kHz) | Uso |
|---|---|---|---|---|
| **WAV / PCM** | ninguna | sin pérdida | ~1.9 MB | ASR local, procesamiento DSP, entrada canónica a Whisper |
| **FLAC** | sin pérdida | sin pérdida | ~1.0 MB | archivado, music datasets |
| **MP3** | con pérdida | sí | ~0.5 MB | distribución, podcasts, APIs |
| **OGG / Vorbis** | con pérdida | sí | ~0.5 MB | web, streaming, libre de patentes |
| **Opus** | con pérdida | sí | ~0.3 MB | VoIP, WebRTC, voz en tiempo real (el mejor para voz) |
| **AAC** | con pérdida | sí | ~0.5 MB | iOS, broadcasting |

### Sample rate y canales

El **sample rate** (frecuencia de muestreo) indica cuántas muestras por segundo describen la señal. Valores típicos:

| Sample rate | Dónde se usa |
|---|---|
| **8 kHz** | telefonía clásica (PSTN, G.711) — calidad "teléfono" |
| **16 kHz** | **estándar para ASR** (Whisper, Deepgram, pyannote) — captura voz humana completa |
| **22.05 kHz** | legacy, algunos TTS antiguos |
| **24 kHz** | **estándar para TTS neuronal moderno** (ElevenLabs, OpenAI TTS, salida natural) |
| **44.1 / 48 kHz** | música, broadcasting, audio profesional |

Los **canales** son el número de pistas simultáneas:

- **Mono** (1 canal): obligatorio para ASR; mezclar estéreo a mono antes de transcribir.
- **Estéreo** (2 canales): típico en música y grabaciones de llamadas duales (un canal por hablante — útil para diarización trivial).

> Enviar audio de 44.1 kHz estéreo a Whisper funciona (lo re-samplea), pero gastas ancho de banda, memoria y a veces calidad. Convertir a 16 kHz mono *antes* es la práctica correcta.

## ¿Por qué importa?

La voz es la interfaz **más antigua y natural** del ser humano. Hasta hace poco era imposible usarla como entrada/salida fiable en software; con los modelos actuales se volvió una capa más del stack, al nivel de un `fetch()` HTTP.

- **Accesibilidad real.** Personas con discapacidad visual, motora o baja alfabetización pueden operar un producto que antes requería teclear.
- **Manos y ojos ocupados.** Conducir, cocinar, operar maquinaria: contextos donde el teclado no existe.
- **Latencia percibida menor.** Hablar es ~3× más rápido que teclear (~150 ppm vs ~40 wpm).
- **Datos sin explotar.** Horas de llamadas de soporte, reuniones, podcasts: oro para análisis, resumen y búsqueda, pero inútil mientras siga siendo audio opaco.
- **Agentes de voz.** La combinación ASR + LLM + TTS es la base de los nuevos "voice agents" (atención al cliente, outbound calling, tutoría) que están reemplazando IVRs tradicionales.

### Contexto histórico (modelos modernos)

| Año | Hito |
|---|---|
| 2016 | WaveNet (DeepMind) — primer TTS neuronal realmente natural |
| 2017 | Tacotron, Tacotron 2 — encoder-decoder para TTS |
| 2020 | Facebook wav2vec 2.0 — pre-entrenamiento autosupervisado para ASR |
| **2022** | **Whisper** de OpenAI — ASR multilenguaje de alta calidad, open source |
| 2023 | ElevenLabs populariza voice cloning realista con pocos segundos de muestra |
| 2024 | **Whisper v3** (nov 2023, estabilizado en 2024), **GPT-4o audio** (mayo 2024), **Gemini Live** — speech-to-speech end-to-end sin pipeline intermedio |
| 2025 | APIs Realtime (OpenAI Realtime, Ultravox, Kyutai Moshi) — streaming full-duplex con interrupciones naturales |

## ¿Cómo funciona?

### ASR (Automatic Speech Recognition)

El pipeline clásico de un modelo tipo Whisper:

```
Audio PCM (16 kHz)
      ↓
VAD opcional (recorta silencios, segmenta en ~30 s)
      ↓
Mel-spectrogram (80 bandas, ventana ~25 ms, hop 10 ms)
      ↓
Encoder (Transformer): convierte espectrograma en embeddings acústicos
      ↓
Decoder (Transformer autoregresivo): genera tokens de texto condicionado al encoder
      ↓
Post-proceso: puntuación, timestamps, truecase, filtrado de alucinaciones
```

Whisper fue entrenado como *seq2seq multitarea*: con tokens especiales se le indica `<transcribe>` o `<translate>`, idioma, y presencia de timestamps. Por eso un mismo modelo transcribe, traduce y detecta idioma.

### Whisper

Modelo abierto publicado por OpenAI en septiembre de 2022, entrenado con **680.000 horas** de audio multilingüe (de las cuales ~117.000 son multilingüe/traducción). Tamaños disponibles:

| Modelo | Parámetros | VRAM mínima | Velocidad relativa | Uso |
|---|---|---|---|---|
| tiny | 39 M | ~1 GB | ~32× realtime | pruebas, dispositivos muy limitados |
| base | 74 M | ~1 GB | ~16× | comandos cortos, prototipos |
| small | 244 M | ~2 GB | ~6× | balance decente para muchas lenguas |
| medium | 769 M | ~5 GB | ~2× | producción local con buena calidad |
| **large-v3** | 1550 M | ~10 GB | ~1× | **estado del arte open**; multilingüe fuerte |
| large-v3-turbo | 809 M | ~6 GB | ~8× | large-v3 destilado, casi misma calidad |

También existe la API hospedada (`whisper-1` y los nuevos `gpt-4o-transcribe` / `gpt-4o-mini-transcribe`), que evita manejar GPU pero cobra por minuto.

### TTS (Text-to-Speech)

Un sistema TTS neuronal moderno hace, en orden:

1. **Normalización de texto.** `Dr.` → `Doctor`, `3.14` → `tres punto catorce`, URLs, siglas.
2. **Grafema → fonema** (opcional en modelos end-to-end).
3. **Modelo acústico.** Genera una representación intermedia (mel-spectrogram) a partir del texto, condicionado por el embedding de voz.
4. **Vocoder.** Convierte el mel-spectrogram en forma de onda PCM (24 kHz típico). HiFi-GAN y WaveNet son los más comunes.

Los sistemas end-to-end (VITS, StyleTTS2, los modelos de ElevenLabs y OpenAI) fusionan 3 y 4 en una sola red.

### ElevenLabs

Proveedor de referencia para TTS realista y **voice cloning**:

- **Pre-made voices** (varias docenas de voces listas, multilenguaje).
- **Instant Voice Cloning**: clona timbre a partir de ~1 minuto de audio limpio.
- **Professional Voice Cloning**: muestras más largas, fine-tune dedicado, calidad mucho mayor.
- **Streaming API** por WebSocket, latencia ~400 ms al primer chunk con el modelo `eleven_turbo_v2_5`.
- Modelos de dos ejes: `multilingual_v2` (29+ idiomas, mejor expresión) vs `turbo_v2_5` (baja latencia, menos expresivo).

### OpenAI TTS

API comercial sencilla, 6 voces fijas pre-entrenadas y dos modelos:

| Modelo | Calidad | Latencia | Precio aprox |
|---|---|---|---|
| `tts-1` | estándar | baja (~200-400 ms) | ~$0.015 / 1k chars |
| `tts-1-hd` | alta | mayor | ~$0.030 / 1k chars |
| `gpt-4o-mini-tts` | nuevo, controlable con "instructions" (tono, emoción) | baja | variable |

Voces: `alloy`, `echo`, `fable`, `onyx`, `nova`, `shimmer`, más las nuevas `coral`, `sage`, `ash`, `ballad`, `verse` del modelo 4o-mini-tts.

### Voice cloning

Clonar una voz es entrenar o condicionar un TTS para que el timbre coincida con un hablante dado.

- **Zero-shot / few-shot:** el modelo acepta un embedding de voz calculado desde unos segundos de audio y lo usa como condicionamiento (ElevenLabs Instant, OpenVoice, XTTS v2 de Coqui).
- **Fine-tuning dedicado:** se entrena un modelo o adapter con horas del hablante — mayor fidelidad, pero más costoso.

Implicaciones éticas y legales son enormes: **siempre** se necesita consentimiento explícito. Muchas jurisdicciones (UE AI Act, varios estados de EE. UU.) exigen marcas de agua auditivas y disclosure.

### Speaker diarización

Responde "¿quién habló cuándo?" cuando hay múltiples hablantes. Pipeline típico:

```
Audio → VAD → segmentar en ventanas → extraer embeddings de hablante
     → clustering (ej. agglomerative, spectral) → asignar etiquetas (SPEAKER_00, SPEAKER_01, …)
```

Herramienta de facto: **pyannote.audio** (open source, modelos en HuggingFace). Alternativas gestionadas: Deepgram, AssemblyAI y Azure Speech la ofrecen como flag en la API.

### VAD (Voice Activity Detection)

Un VAD decide, trama por trama (típicamente cada 10-30 ms), si hay voz humana o no. Para qué sirve:

- **Recortar silencios** antes de enviar a Whisper — evita que el modelo "invente" texto en silencios (alucinaciones típicas: "subtítulos por la comunidad", "gracias por ver"…).
- **Segmentar** audio largo en chunks respetando pausas naturales.
- **Detectar turnos** de habla en una conversación (end-pointing: saber que el usuario terminó de hablar).

Herramientas: **Silero VAD** (ONNX, muy rápido en CPU), **WebRTC VAD** (clásico, menos preciso), VAD integrado de `faster-whisper`.

### Streaming de audio en tiempo real (WebRTC)

Para experiencias conversacionales no basta con "subir archivo, esperar respuesta". Se necesita **flujo bidireccional** de audio con muy baja latencia.

- **WebRTC** es el estándar de facto para transportar audio/video entre navegador y servidor. Transporta Opus comprimido sobre UDP, con corrección de jitter y echo cancellation.
- **WebSockets** son el fallback simple: binario PCM o Opus en frames.
- Servicios/SDKs maduros: **LiveKit** (voice agents con WebRTC), **Daily**, **Twilio Voice**, **Agora**.
- Las APIs modernas (OpenAI Realtime, Gemini Live) exponen WebSocket que acepta audio en streaming y devuelve audio en streaming — con **interrupciones** (el usuario puede cortar al modelo, el modelo deja de hablar).

### Audio tokens y modelos speech-to-speech

Los modelos más nuevos tratan audio como **tokens discretos**, igual que texto. Un codec neuronal (EnCodec de Meta, SNAC, Mimi de Kyutai) convierte audio en una secuencia de códigos discretos a ~50-75 Hz. Esos códigos son el "vocabulario" que un Transformer puede modelar nativamente.

Resultado: **GPT-4o audio** (mayo 2024) y **Gemini Live** no transcriben a texto, no generan texto, y no sintetizan. Entrenan un único Transformer que lee tokens de audio del usuario y predice tokens de audio de respuesta. Ventajas:

- Latencia end-to-end mucho menor (~320 ms promedio en GPT-4o audio vs ~1-3 s en pipeline clásico).
- Preserva emoción, risas, suspiros, tono — información que el STT descarta.
- Permite interrupciones naturales y "backchannel" ("mhm", "ya veo").

Costo: solo accesible por API; modelos abiertos equivalentes (Kyutai Moshi, Ultravox) están emergiendo.

### Modelos ASR comparados

| Modelo | Tipo | Idiomas | Fortaleza | Debilidad |
|---|---|---|---|---|
| **Whisper (OpenAI)** | batch, local o API | 99+ | precisión multilenguaje, abierto | lento sin GPU, alucinaciones en silencio |
| **faster-whisper (CTranslate2)** | batch local | 99+ | **4× más rápido** que whisper original, menos VRAM | mismas limitaciones del modelo base |
| **Deepgram Nova-3** | streaming + batch, API | 36+ | latencia muy baja, streaming maduro | de pago, menos abierto |
| **AssemblyAI Universal-2** | batch + streaming | 99+ | diarización, chapters, sentiment integrados | de pago |
| **Azure Speech** | streaming + batch | 100+ | custom models, enterprise SLA | configuración densa |
| **Google Speech-to-Text** | streaming + batch | 125+ | integración GCP, auto-puntuación | precio |
| **AWS Transcribe** | streaming + batch | 100+ | integración AWS, medical/call analytics | precisión variable |
| **gpt-4o-transcribe** | API | multi | precisión superior a whisper-1 | solo API |

### Modelos TTS comparados

| Proveedor | Modelo | Voice cloning | Streaming | Idiomas | Precio aprox |
|---|---|---|---|---|---|
| **ElevenLabs** | multilingual_v2, turbo_v2_5 | sí (instant + pro) | WebSocket | 29+ | ~$0.18/1k chars (creator) |
| **OpenAI** | tts-1, tts-1-hd, gpt-4o-mini-tts | no | sí | 50+ | $0.015 – $0.030/1k chars |
| **Google Cloud TTS** | Chirp HD, Neural2, WaveNet | custom voice (Studio) | sí | 50+ | ~$0.016/1k chars (WaveNet) |
| **AWS Polly** | Neural, Generative | Brand Voice (enterprise) | sí | 40+ | ~$0.016/1k chars (neural) |
| **Azure TTS** | Neural, Custom Neural Voice | sí (gated) | sí | 140+ | ~$0.016/1k chars |
| **Coqui XTTS v2** | open source | sí (6 s de muestra) | sí | 17 | gratis (self-host) |
| **Cartesia Sonic** | muy baja latencia (<90 ms) | sí | sí | 15+ | de pago |

### Métrica clave: WER (Word Error Rate)

Para evaluar ASR, el estándar es **Word Error Rate**:

```
WER = (S + D + I) / N
```

Donde `S` = sustituciones, `D` = eliminaciones, `I` = inserciones y `N` = número de palabras en la referencia. Es análogo a la *edit distance* a nivel de palabra.

- WER = 0 → transcripción perfecta.
- WER = 1 → tantos errores como palabras hay.
- WER de referencia: humano profesional ~4-5 %, Whisper large-v3 en inglés limpio ~2-4 %, en español ~5-8 %, en audio ruidoso o con acento fuerte puede subir a 15-30 %.

Variantes: **CER** (character error rate, útil para chino/japonés), **MER**, **WIL**.

## Ejemplo con código

Pipeline mínimo end-to-end: cargar audio → transcribir con Whisper → responder con LLM → sintetizar respuesta con TTS. Primero las versiones directas, luego el pipeline unido.

### ASR con Whisper local (`faster-whisper`)

```python
# pip install faster-whisper
from faster_whisper import WhisperModel

# int8 permite correr large-v3 en CPU decentemente; en GPU usa compute_type="float16"
model = WhisperModel("large-v3", device="cpu", compute_type="int8")

segments, info = model.transcribe(
    "llamada_cliente.wav",
    language="es",            # fijar idioma mejora precisión y velocidad
    vad_filter=True,          # usa Silero VAD interno: evita alucinaciones en silencios
    vad_parameters={"min_silence_duration_ms": 500},
    beam_size=5,
    word_timestamps=True,
)

print(f"Idioma detectado: {info.language} (prob {info.language_probability:.2f})")
for seg in segments:
    print(f"[{seg.start:6.2f} → {seg.end:6.2f}] {seg.text}")
```

### ASR con la API de OpenAI

```python
from openai import OpenAI

client = OpenAI(api_key="API_KEY", base_url="BASE_URL")

with open("llamada_cliente.mp3", "rb") as f:
    transcript = client.audio.transcriptions.create(
        model="whisper-1",            # o "gpt-4o-transcribe" para mayor precisión
        file=f,
        language="es",                 # ISO-639-1
        response_format="verbose_json",# incluye segmentos y timestamps
        temperature=0.0,               # determinista
        prompt="Conversación de soporte técnico sobre internet de fibra óptica.",
    )

for seg in transcript.segments:
    print(f"{seg['start']:.1f}s  {seg['text']}")
```

### TTS con ElevenLabs

```python
# pip install elevenlabs
from elevenlabs.client import ElevenLabs
from elevenlabs import save

eleven = ElevenLabs(api_key="XI_API_KEY")

audio = eleven.text_to_speech.convert(
    voice_id="EXAVITQu4vr4xnSDxMaL",   # "Bella" (pre-made)
    model_id="eleven_multilingual_v2",
    text="Hola, soy el asistente virtual. ¿En qué puedo ayudarte hoy?",
    output_format="mp3_44100_128",
    voice_settings={"stability": 0.5, "similarity_boost": 0.75, "style": 0.0},
)

save(audio, "respuesta.mp3")
```

### TTS con OpenAI

```python
from openai import OpenAI
from pathlib import Path

client = OpenAI(api_key="API_KEY", base_url="BASE_URL")

response = client.audio.speech.create(
    model="tts-1",         # usa "tts-1-hd" para contenido pre-generado
    voice="nova",          # alloy, echo, fable, onyx, nova, shimmer
    input="Tu saldo actual es de doscientos cincuenta pesos.",
    response_format="mp3",
    speed=1.0,
)

Path("saldo.mp3").write_bytes(response.content)
```

### Pipeline voz-a-voz completo (latencia medida)

```python
import time
from openai import OpenAI

client = OpenAI(api_key="API_KEY", base_url="BASE_URL")

def voice_turn(audio_in: str, system: str) -> dict:
    """Un turno: audio del usuario → texto de respuesta → audio de respuesta."""
    t0 = time.perf_counter()

    # 1) ASR
    with open(audio_in, "rb") as f:
        stt = client.audio.transcriptions.create(model="whisper-1", file=f, language="es")
    t_stt = time.perf_counter()

    # 2) LLM
    chat = client.chat.completions.create(
        model="gpt-4.1-mini",
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": stt.text},
        ],
        max_tokens=120,  # mantener respuestas cortas en voz
    )
    reply_text = chat.choices[0].message.content
    t_llm = time.perf_counter()

    # 3) TTS
    tts = client.audio.speech.create(model="tts-1", voice="nova", input=reply_text)
    with open("respuesta.mp3", "wb") as f:
        f.write(tts.content)
    t_tts = time.perf_counter()

    return {
        "user_text": stt.text,
        "reply_text": reply_text,
        "latency_ms": {
            "stt": round((t_stt - t0) * 1000),
            "llm": round((t_llm - t_stt) * 1000),
            "tts": round((t_tts - t_llm) * 1000),
            "total": round((t_tts - t0) * 1000),
        },
    }

print(voice_turn("usuario.wav", "Eres un agente de soporte conciso."))
```

Un turno completo con `gpt-4.1-mini` y `tts-1` suele quedar entre **1.5 y 3 segundos**. Para bajar de ahí hay que ir a modelos speech-to-speech o streaming (lo cubre la Lesson 04).

### Preprocesamiento canónico (mono 16 kHz WAV)

```python
# pip install pydub && brew install ffmpeg
from pydub import AudioSegment

def to_whisper_format(src: str, dst: str) -> None:
    audio = AudioSegment.from_file(src)   # autodetecta mp3/ogg/m4a/flac/wav
    audio = audio.set_channels(1).set_frame_rate(16000).set_sample_width(2)  # 16-bit PCM
    audio.export(dst, format="wav")

to_whisper_format("grabacion.m4a", "grabacion_16k_mono.wav")
```

## Errores comunes

- **Sample rate incorrecto.** Enviar 44.1 kHz a un modelo entrenado en 16 kHz obliga a resampleo (lento) o degrada calidad silenciosamente. Normaliza a 16 kHz mono para ASR, 24 kHz para TTS.
- **No usar VAD y transcribir silencio.** Whisper, en silencio puro o música de fondo, alucina frases enteras: "subtítulos por la comunidad", "gracias por ver", "music". Siempre filtra con VAD antes.
- **Modelo Whisper demasiado pequeño para audio ruidoso o con acento.** `tiny` y `base` colapsan con llamadas telefónicas, acentos marcados o ruido. Para producción, mínimo `small`; para castellano latino con ruido, `medium` o `large-v3`.
- **No cachear TTS para frases repetidas.** Si tu bot dice "¿en qué puedo ayudarte?" 10.000 veces al día, generarlo cada vez es tirar dinero y añadir latencia. Hash del texto + voz + velocidad → blob en S3/Redis.
- **No manejar interrupciones en tiempo real.** En un voice agent, el usuario interrumpe al bot. Si no cortas la reproducción al detectar voz entrante, la conversación se siente robótica. Esto exige VAD en el canal de entrada *mientras* reproduces TTS.
- **Formato de audio no soportado.** Muchas APIs rechazan `.m4a`, `.webm`, `.aac` o archivos sin header. Convierte a WAV/MP3/FLAC canónico antes de subir.
- **Estéreo cuando el modelo espera mono.** Algunos modelos solo miran el canal izquierdo y pierden información; otros fallan directamente. Mezcla con `set_channels(1)`.
- **Enviar el archivo entero cuando pasa del límite.** Whisper API limita a 25 MB. Para audio largo, trocea con solape de 1-2 s para no cortar palabras.
- **Confiar en auto-detección de idioma con audios cortos o code-switching.** Pasa `language=` explícito cuando lo sepas; mejora WER y latencia.
- **Olvidar consentimiento y legalidad.** Grabar llamadas sin aviso es ilegal en muchos países (two-party consent). Clonar voz sin permiso del hablante es tema de litigio activo.
- **Ignorar costos acumulados.** 5.000 llamadas de 4 min diarias a `whisper-1` ($0.006/min) ≈ **$120/día** solo en ASR, sin contar LLM ni TTS. Monitorea.

## Resumen

- Audio y voz en IA se reducen a tres capacidades: **ASR** (voz→texto), **TTS** (texto→voz) y **speech-to-speech** (voz→voz end-to-end, como GPT-4o audio y Gemini Live).
- El audio es señal, no texto: **formato, sample rate y canales** determinan si tu modelo funciona o alucina. Normaliza a WAV mono 16 kHz para ASR y 24 kHz para TTS.
- **Whisper** (OpenAI, 2022; v3 en 2024) es el ASR open source de referencia; `faster-whisper` lo hace 4× más rápido. Alternativas gestionadas: Deepgram, AssemblyAI, Azure, Google.
- **ElevenLabs** lidera TTS realista y voice cloning; **OpenAI TTS** es el camino sencillo (6 voces, 2 modelos); **Coqui XTTS** es la alternativa abierta.
- La **diarización** (pyannote.audio) y el **VAD** (Silero) son piezas auxiliares críticas para producción real.
- Para experiencias conversacionales se usa **streaming** sobre **WebRTC/WebSocket** (LiveKit, OpenAI Realtime, Gemini Live) y se manejan **interrupciones**.
- Métrica clave de ASR: **WER** (Word Error Rate). Humano profesional ~5 %, Whisper large-v3 en español limpio ~5-8 %.
- La latencia de un pipeline clásico ASR+LLM+TTS ronda 1.5-3 s; los modelos speech-to-speech la bajan a ~300 ms.
- Errores que más duelen en producción: no usar VAD, modelo demasiado pequeño, no cachear TTS, no manejar interrupciones, costos no monitorizados.
