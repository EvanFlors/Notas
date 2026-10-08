# Text-to-Speech en Producción

## ¿Qué es?

**Text-to-Speech (TTS)** convierte una cadena de texto en una forma de onda de audio que suena como habla humana. Los sistemas TTS modernos (desde WaveNet en 2016 hasta ElevenLabs y OpenAI TTS en 2024) son **neuronales end-to-end**: una red toma texto y produce muestras PCM a 24 kHz sin pipelines manuales de concatenación.

En producción vas a elegir entre tres categorías de proveedor:

| Categoría | Ejemplos | Fortaleza | Debilidad |
|---|---|---|---|
| **API comercial realista** | ElevenLabs, Cartesia, Resemble AI | voces muy naturales, cloning, control emocional | precio por carácter, dependencia externa |
| **API cloud grande** | OpenAI TTS, Google Cloud, AWS Polly, Azure Speech | SLA, integración con el resto del stack cloud, muchas voces | menos expresividad que especialistas |
| **Open source self-hosted** | Coqui XTTS v2, Piper, StyleTTS2, Kokoro | gratis, offline, control total | infra GPU, calidad variable, menos idiomas |

El resultado de un TTS es siempre un buffer de audio en un formato (MP3, Opus, WAV/PCM, FLAC, AAC) que decides a la hora de la llamada. La elección del formato condiciona latencia, ancho de banda y compatibilidad del reproductor.

### Dimensiones de calidad

- **Naturalidad**: ¿suena a persona o a robot? Se mide con MOS (Mean Opinion Score) 1-5; TTS SOTA actuales rondan 4.3-4.6, humanos ~4.5.
- **Expresividad**: entonación, pausas, énfasis, emoción. El salto grande desde 2023.
- **Consistencia**: la misma "voz" debe sonar igual entre llamadas. Clave para branding.
- **Idiomas y acentos**: no todos los modelos cubren latinoamericano vs peninsular, por ejemplo.
- **Latencia de primer byte (TTFB)**: cuánto tarda en empezar a sonar — crítico en voice agents.

## ¿Por qué importa?

- **Elimina el costo de locutor** para cada frase posible. En un IVR o voice agent, grabar manualmente las ~10.000 respuestas que puede dar es inviable.
- **Permite respuestas dinámicas**: leer el nombre del cliente, un número de pedido, un saldo — imposible con audio pregrabado.
- **Accesibilidad**: lectores de pantalla, audiolibros, apps para personas con dislexia o baja visión.
- **Localización rápida**: la misma app en 29 idiomas con el mismo código.
- **Costo decreciente**: OpenAI `tts-1` cuesta ~$0.015 por 1.000 caracteres; una respuesta de 500 chars sale a $0.0075. Un locutor humano cobra decenas de dólares por minuto.
- **Voice cloning con consentimiento** habilita branding sonoro (voz corporativa) y continuidad narrativa en contenidos extensos.

### Cuándo NO usar TTS

- **Contenido altamente emotivo o artístico** donde la actuación humana importa (anuncios premium, cine).
- **Jurisdicciones con restricciones**: ciertos usos regulados exigen locutor humano o disclosure explícito.
- **Dominio con nombres propios muy específicos** que el TTS pronuncia mal y no admite SSML/alias.

## ¿Cómo funciona?

### Pipeline de un TTS neuronal moderno

```
Texto crudo
      ↓
Normalización ("Dr." → "Doctor", "USD 3.14" → "tres dólares con catorce centavos")
      ↓
Tokenización (BPE, caracteres o fonemas IPA)
      ↓
Modelo acústico (Transformer / Diffusion) condicionado por embedding de voz
      ↓
Mel-spectrogram (representación tiempo-frecuencia)
      ↓
Vocoder neuronal (HiFi-GAN, WaveNet, BigVGAN) → PCM 24 kHz
      ↓
Encoding al formato pedido (MP3, Opus, WAV, …)
```

Los sistemas end-to-end más recientes (ElevenLabs, Cartesia, StyleTTS2) fusionan modelo acústico y vocoder en una sola red, bajando latencia y mejorando prosodia.

### SSML (Speech Synthesis Markup Language)

Markup XML del W3C para controlar prosodia. Soportado por Google, AWS Polly y Azure (no por OpenAI ni ElevenLabs directamente):

```xml
<speak>
  Hola <break time="300ms"/> ¿cómo estás?
  Mi número es <say-as interpret-as="telephone">555-1234</say-as>.
  Esto es <emphasis level="strong">muy importante</emphasis>.
  <prosody rate="slow" pitch="+2st">Habla pausado y agudo.</prosody>
</speak>
```

### Formatos de salida y cuándo usarlos

| Formato | Compresión | Latencia | Ancho de banda | Uso típico |
|---|---|---|---|---|
| **PCM** / `pcm_16000` | ninguna | mínima | alto | pipeline interno, playback inmediato |
| **WAV** | ninguna (header) | mínima | alto | edición, post-proceso |
| **MP3** | con pérdida | media | medio | web, descarga, podcast |
| **Opus** | con pérdida | baja | **bajísimo** | WebRTC, voice agents, streaming |
| **AAC** | con pérdida | media | medio | iOS, broadcasting |
| **FLAC** | sin pérdida | alta | medio | archivado master |

Para voice agents en WebRTC: **Opus** (es lo que la red ya transporta). Para pre-grabar audio para una web: **MP3** (compatible universalmente). Para procesar o mezclar: **WAV/PCM**.

### Modelos comparados

| Proveedor | Modelo | Voces | Cloning | Streaming | Idiomas | TTFB | Precio aprox |
|---|---|---|---|---|---|---|---|
| **ElevenLabs** | `eleven_multilingual_v2` | 1000+ | sí | WS | 29+ | ~800 ms | $0.18/1k chars (creator) |
| **ElevenLabs** | `eleven_turbo_v2_5` | 1000+ | sí | WS | 32 | ~300 ms | $0.09/1k chars |
| **ElevenLabs** | `eleven_flash_v2_5` | 1000+ | sí | WS | 32 | **~75 ms** | $0.09/1k chars |
| **OpenAI** | `tts-1` | 6 (+5 nuevas) | no | sí | 50+ | ~400 ms | $0.015/1k chars |
| **OpenAI** | `tts-1-hd` | 6 | no | sí | 50+ | ~800 ms | $0.030/1k chars |
| **OpenAI** | `gpt-4o-mini-tts` | 11 | no, pero *instructions* | sí | 50+ | ~400 ms | ~$0.015/1k chars |
| **Cartesia Sonic** | varios | 100+ | sí | sí | 15+ | **~90 ms** | de pago |
| **Google Cloud** | Chirp HD / WaveNet | 220+ | custom voice | sí | 50+ | ~500 ms | $0.016/1k chars (WaveNet) |
| **AWS Polly** | neural / generative | 100+ | brand voice | sí | 40+ | ~500 ms | $0.016/1k chars (neural) |
| **Azure Speech** | neural | 400+ | Custom Neural Voice | sí | 140+ | ~400 ms | $0.016/1k chars |
| **Coqui XTTS v2** | open source | plantillas + cloning | sí (6 s) | sí | 17 | depende GPU | gratis (self-host) |
| **Piper** | open source | pre-entrenadas | no | stream a CPU | 30+ | ~150 ms CPU | gratis |
| **Kokoro-82M** | open source (Apache 2) | 54 | no | sí | 8 | muy baja | gratis |

### OpenAI TTS: voces disponibles

| Voz | Carácter | Buena para |
|---|---|---|
| `alloy` | neutra, balanceada | propósito general, educación |
| `echo` | clara, profesional | anuncios, business |
| `fable` | expresiva, cálida | narración, cuentos |
| `onyx` | grave, autoridad | noticias, documentales |
| `nova` | amable, conversacional | atención al cliente, chatbots |
| `shimmer` | suave, pausada | meditación, wellness |

Nuevas con `gpt-4o-mini-tts` (2024): `coral`, `sage`, `ash`, `ballad`, `verse`. Este modelo acepta un parámetro `instructions` tipo "habla con tono preocupado y pausado" que modula la emoción sin fine-tuning.

### ElevenLabs: parámetros clave

- `stability` (0-1): consistencia emocional. Bajo = más expresivo pero más errático; alto = plano pero predecible. Default 0.5.
- `similarity_boost` (0-1): fidelidad al timbre original (importante para cloning). Default 0.75.
- `style` (0-1): exageración del estilo del hablante. Útil en voces con personalidad fuerte. Default 0.
- `use_speaker_boost` (bool): refuerza similitud al hablante clonado.
- `model_id`: `eleven_multilingual_v2` (expresivo), `eleven_turbo_v2_5` (balance), `eleven_flash_v2_5` (ultra baja latencia).

### Voice cloning

- **Instant Voice Cloning**: embedding de voz a partir de ~1 min de muestra limpia. Útil para prototipos.
- **Professional Voice Cloning**: muestras largas (~30 min), fine-tune dedicado, calidad indistinguible del original.
- Siempre requiere consentimiento firmado del hablante. Jurisdicciones con regulación emergente (UE AI Act, varios estados de EE. UU.) exigen marcar el output como sintético.

### Streaming TTS

Para voice agents, no quieres esperar al audio completo. Dos niveles de streaming:

1. **HTTP chunked**: la respuesta se recibe en trozos a medida que el modelo los produce. Soportado por OpenAI, ElevenLabs REST, Google, Azure.
2. **WebSocket**: canal bidireccional. Permite enviar texto *mientras se genera por el LLM* (text-input streaming) y recibir audio token a token (audio-output streaming). Soportado por ElevenLabs, Cartesia, OpenAI Realtime.

El modo WebSocket con text-input streaming permite que, mientras tu LLM genera "Hola Juan, tu saldo…", el TTS ya haya sintetizado y empezado a reproducir "Hola Juan". Esto baja la latencia percibida de ~1.5 s a ~400 ms.

## Ejemplo con código

### TTS básico con OpenAI

```python
from openai import OpenAI
from pathlib import Path

client = OpenAI(api_key="API_KEY", base_url="BASE_URL")

response = client.audio.speech.create(
    model="tts-1",                  # tts-1-hd para contenido pre-generado
    voice="nova",
    input="Hola, soy el asistente virtual. ¿En qué te puedo ayudar?",
    response_format="mp3",          # mp3 | opus | aac | flac | wav | pcm
    speed=1.0,                      # 0.25 – 4.0
)
Path("saludo.mp3").write_bytes(response.content)
```

### TTS con control emocional (gpt-4o-mini-tts)

```python
response = client.audio.speech.create(
    model="gpt-4o-mini-tts",
    voice="sage",
    input="Lamento mucho el inconveniente. Vamos a resolverlo ahora mismo.",
    instructions="Habla con tono empático y pausado, como un asesor comprensivo.",
    response_format="opus",
)
Path("empatico.opus").write_bytes(response.content)
```

### TTS con ElevenLabs

```python
# pip install elevenlabs
from elevenlabs.client import ElevenLabs
from elevenlabs import save, VoiceSettings

eleven = ElevenLabs(api_key="XI_API_KEY")

audio = eleven.text_to_speech.convert(
    voice_id="EXAVITQu4vr4xnSDxMaL",       # "Bella"
    model_id="eleven_multilingual_v2",
    text="Tu pedido fue despachado y llegará mañana entre las nueve y las once.",
    output_format="mp3_44100_128",
    voice_settings=VoiceSettings(
        stability=0.45,
        similarity_boost=0.75,
        style=0.15,
        use_speaker_boost=True,
    ),
)
save(audio, "pedido.mp3")
```

### Streaming TTS (OpenAI) — reproduce mientras llega

```python
from openai import OpenAI

client = OpenAI(api_key="API_KEY", base_url="BASE_URL")

with client.audio.speech.with_streaming_response.create(
    model="tts-1",
    voice="nova",
    input="Este audio empieza a reproducirse antes de haberse generado por completo.",
    response_format="pcm",   # pcm 24kHz 16-bit mono para passthrough al speaker
) as response:
    with open("stream.pcm", "wb") as f:
        for chunk in response.iter_bytes(chunk_size=4096):
            f.write(chunk)
            # en un voice agent: enviar chunk al reproductor / websocket aquí
```

### Streaming TTS (ElevenLabs) — WebSocket bidireccional

```python
import asyncio, websockets, json, base64

ELEVEN_WS = (
    "wss://api.elevenlabs.io/v1/text-to-speech/{voice_id}/stream-input"
    "?model_id=eleven_turbo_v2_5&output_format=pcm_16000"
)

async def say_streaming(voice_id: str, text_chunks):
    uri = ELEVEN_WS.format(voice_id=voice_id)
    async with websockets.connect(uri, extra_headers={"xi-api-key": "XI_API_KEY"}) as ws:
        await ws.send(json.dumps({
            "text": " ",
            "voice_settings": {"stability": 0.5, "similarity_boost": 0.75},
            "generation_config": {"chunk_length_schedule": [120, 160, 250, 290]},
        }))

        async def send_text():
            for chunk in text_chunks:        # viene del LLM en streaming
                await ws.send(json.dumps({"text": chunk, "try_trigger_generation": True}))
            await ws.send(json.dumps({"text": ""}))  # EOS

        async def recv_audio():
            with open("salida.pcm", "wb") as f:
                while True:
                    msg = await ws.recv()
                    data = json.loads(msg)
                    if data.get("audio"):
                        f.write(base64.b64decode(data["audio"]))
                    if data.get("isFinal"):
                        break

        await asyncio.gather(send_text(), recv_audio())

# asyncio.run(say_streaming("EXAVITQu4vr4xnSDxMaL", iter_del_llm))
```

Este patrón, alimentando `text_chunks` desde el streaming del LLM, es lo que permite tiempos de respuesta end-to-end por debajo de 500 ms en voice agents.

### Caché por hash para frases repetidas

```python
import hashlib
from pathlib import Path
from openai import OpenAI

client = OpenAI(api_key="API_KEY", base_url="BASE_URL")
CACHE = Path("./tts_cache"); CACHE.mkdir(exist_ok=True)

def key(text: str, voice: str, speed: float, model: str, fmt: str) -> str:
    raw = f"{model}|{voice}|{speed}|{fmt}|{text}"
    return hashlib.sha256(raw.encode()).hexdigest()

def speak_cached(text: str, voice="nova", speed=1.0, model="tts-1", fmt="mp3") -> bytes:
    k = key(text, voice, speed, model, fmt)
    f = CACHE / f"{k}.{fmt}"
    if f.exists():
        return f.read_bytes()

    r = client.audio.speech.create(
        model=model, voice=voice, input=text, speed=speed, response_format=fmt,
    )
    f.write_bytes(r.content)
    return r.content

# Warm-up al arrancar el servicio con frases que vas a repetir mucho
FRASES_COMUNES = [
    "Un momento, por favor.",
    "¿En qué más te puedo ayudar?",
    "Gracias por tu paciencia.",
    "No logré entenderte, ¿puedes repetir?",
]
for frase in FRASES_COMUNES:
    speak_cached(frase)
```

En un centro de atención, 70 %+ del tráfico de TTS suele ser frases repetidas; un caché bien hecho recorta facturas a la mitad.

### Batch concurrente con límite

```python
import asyncio
from openai import AsyncOpenAI
from pathlib import Path

client = AsyncOpenAI(api_key="API_KEY", base_url="BASE_URL")
SEM = asyncio.Semaphore(10)

async def speak(text: str, out_path: str, voice="nova") -> str:
    async with SEM:
        r = await client.audio.speech.create(model="tts-1", voice=voice, input=text)
    Path(out_path).write_bytes(r.content)
    return out_path

async def batch(items):
    tasks = [speak(it["text"], it["path"], it.get("voice", "nova")) for it in items]
    return await asyncio.gather(*tasks)
```

### Fallback automático de voz / proveedor

```python
import asyncio, logging
log = logging.getLogger(__name__)

async def speak_resiliente(text: str, voices=("nova", "alloy")):
    for v in voices:
        try:
            r = await client.audio.speech.create(model="tts-1", voice=v, input=text)
            return {"ok": True, "voice": v, "audio": r.content}
        except Exception as e:
            log.warning("TTS falló con %s: %s", v, e)
    # último recurso: devolver texto plano para que la app lo muestre
    return {"ok": False, "text_fallback": text}
```

### Clonación de voz con XTTS v2 (open source)

```python
# pip install TTS
from TTS.api import TTS

tts = TTS("tts_models/multilingual/multi-dataset/xtts_v2").to("cuda")

tts.tts_to_file(
    text="Hola, esta voz fue clonada a partir de seis segundos de audio tuyo.",
    speaker_wav="muestra_6s.wav",
    language="es",
    file_path="clon.wav",
)
```

## Errores comunes

- **No cachear TTS para frases repetidas** → factura hinchada y latencia innecesaria. Hash de `(texto, voz, velocidad, modelo, formato)` → blob en disco/S3/Redis.
- **Elegir el modelo HD por default.** `tts-1-hd` suena mejor pero es 2× más caro y lento. Solo úsalo para contenido pre-generado (audiolibros, cursos, podcasts), nunca para voice agents.
- **Formato equivocado.** Mandar MP3 a un pipeline WebRTC obliga a transcodear a Opus — añade latencia. Si vas a WebRTC, pide Opus directamente; si vas a reproductor web, MP3.
- **Mezclar varias voces en el mismo producto** sin plan: cada botón habla distinto → se siente inconsistente. Define voice guidelines por rol (asistente, alertas, narrador).
- **Pasar texto sin normalizar.** `"$3.14"`, `"Dr. García"`, `"10/05/25"` suelen leerse literalmente ("dólar tres punto catorce", "doctor punto garcía"). Preprocesa con reglas o usa SSML donde esté soportado.
- **Ignorar el límite de longitud.** OpenAI acepta ~4.096 caracteres por request. Textos largos deben trocearse por frase/párrafo y concatenarse en el cliente respetando pausas.
- **No manejar interrupciones** en voice agents. Si el usuario habla mientras el bot está hablando y no cortas la reproducción, el usuario siente que no lo escuchan.
- **Streaming mal implementado.** Pedir streaming pero bufferear todo el audio antes de reproducirlo anula la ventaja. El reproductor debe empezar al primer chunk.
- **Clonar voces sin consentimiento.** Más allá de la ética, es ilegal en varias jurisdicciones y las APIs lo prohíben por ToS. Firma, auditoría y disclosure.
- **Depender de un solo proveedor** sin fallback. Si ElevenLabs tiene incidente, tu bot queda mudo. Define un fallback (otra API, voz TTS más simple, o texto plano).
- **No monitorizar costos y rate limits.** TTS por carácter se descontrola rápido con usuarios generando contenido. Pon límites por usuario y métricas por endpoint.
- **Olvidar el acento regional.** La misma voz "española" puede sonar peninsular y chocarle al usuario mexicano. Elige modelos y voces por mercado.

## Resumen

- **TTS neuronal** moderno es una red end-to-end que convierte texto en audio PCM; proveedores van desde los especialistas (ElevenLabs, Cartesia) hasta cloud grandes (OpenAI, Google, AWS, Azure) y open source (XTTS, Piper, Kokoro).
- **OpenAI TTS**: `tts-1` (rápido, ~$0.015/1k chars) para tiempo real, `tts-1-hd` (más caro y lento) para contenido pre-generado, `gpt-4o-mini-tts` para control emocional vía `instructions`.
- **ElevenLabs** lidera naturalidad y voice cloning; su modo `eleven_flash_v2_5` baja TTFB a ~75 ms sobre WebSocket.
- Formatos: **Opus** para WebRTC/voice agents, **MP3** para web, **WAV/PCM** para procesamiento interno.
- **Streaming** (HTTP chunked o WebSocket con text-input streaming) es la clave para latencia percibida baja en voice agents.
- **Caché por hash** reduce costos y latencia dramáticamente: ~70 % de las frases suelen repetirse.
- Usa **SSML** donde esté soportado (Google, AWS, Azure) para pausas, énfasis y pronunciación precisa; en OpenAI/ElevenLabs se usa `instructions` o parámetros de voice settings.
- **Voice cloning** exige consentimiento firmado y disclosure según jurisdicción.
- Errores que más duelen: no cachear, modelo HD por default, formato equivocado, voces inconsistentes, texto sin normalizar, no manejar interrupciones, sin fallback de proveedor.
