# Speech-to-Text en Producción con Whisper

## ¿Qué es?

**Whisper** es un modelo seq2seq de OpenAI publicado en septiembre de 2022, entrenado con 680.000 horas de audio etiquetado (unas 117.000 multilingües) extraídas de internet. Convierte **audio → texto** y, como subproductos, **detecta idioma** y **traduce** al inglés.

En la práctica usas Whisper por dos caminos:

| Camino | Qué es | Cuándo |
|---|---|---|
| **OpenAI Whisper API** (`whisper-1`, `gpt-4o-transcribe`, `gpt-4o-mini-transcribe`) | endpoint HTTP, cobras por minuto, cero infra | prototipos, volumen bajo-medio, zero-ops |
| **Whisper local / self-hosted** (`openai-whisper`, `faster-whisper`, `whisper.cpp`) | corres el modelo en tu GPU/CPU | volumen alto, latencia controlada, datos sensibles, offline |

Para producción seria, `faster-whisper` (basado en CTranslate2) es la implementación canónica: 4× más rápido que `openai-whisper`, menor consumo de VRAM e integración nativa con VAD de Silero.

### Modelos y variantes

| Modelo | Params | VRAM (fp16) | RTF (A10) | Idiomas |
|---|---|---|---|---|
| tiny / tiny.en | 39 M | 1 GB | ~0.03× | 99 / solo inglés |
| base / base.en | 74 M | 1 GB | ~0.06× | 99 / solo inglés |
| small / small.en | 244 M | 2 GB | ~0.15× | 99 / solo inglés |
| medium / medium.en | 769 M | 5 GB | ~0.4× | 99 / solo inglés |
| **large-v3** | 1550 M | 10 GB | ~1× | 99 (SOTA multilenguaje) |
| **large-v3-turbo** | 809 M | 6 GB | ~0.12× | 99 (destilado, casi mismo WER) |

`RTF` = Real-Time Factor: 0.1× significa que procesa 1 minuto de audio en 6 segundos.

Las variantes `.en` están especializadas en inglés y son más precisas que la versión multilingüe para ese idioma.

### Formatos de respuesta de la API

| `response_format` | Qué devuelve | Útil para |
|---|---|---|
| `text` | string plano | logs rápidos, procesamiento simple |
| `json` | `{ "text": "..." }` | integración programática mínima |
| `verbose_json` | texto + segmentos + timestamps + no_speech_prob + idioma | búsqueda, subtítulos, análisis, filtrado de alucinaciones |
| `srt` | subtítulos SubRip | reproductores de video, YouTube |
| `vtt` | subtítulos WebVTT | HTML5 `<track>` |

Para producción, `verbose_json` casi siempre vale la pena: los metadatos de confianza por segmento permiten descartar texto alucinado.

## ¿Por qué importa?

Transcribir habla con precisión era, hasta 2022, un problema caro: APIs comerciales con WER alto en lenguas que no fueran inglés, modelos propietarios y ajuste manual por acento. Whisper cambió el panorama al liberar un modelo multilenguaje con WER competitivo en decenas de idiomas, bajo licencia MIT.

- **Transcripción de llamadas** a escala para análisis de calidad, compliance (banca, salud) y entrenamiento de agentes.
- **Subtitulado automático** de videos, podcasts y reuniones (Zoom, Teams, Loom lo usan internamente).
- **Búsqueda sobre audio.** Convertir un archivo de 500 h de podcast en texto indexable con pocas horas de cómputo.
- **Entrada de voz** en apps y wearables (dictado, comandos).
- **Pipeline voice-agent**: Whisper es el primer eslabón del clásico ASR → LLM → TTS.
- **Accesibilidad**: closed captions en tiempo real para personas sordas.

Cuando se compara con el error humano (~5 % WER en inglés limpio), Whisper large-v3 está a 2-3 puntos. En español limpio, es casi indistinguible de un humano no entrenado.

### Cuándo NO usar Whisper

- **Streaming de muy baja latencia (<300 ms).** Whisper es *batch* por diseño (procesa ventanas de 30 s). Para dictado en vivo real-time o voice agents con interrupciones, usa Deepgram, AssemblyAI Universal-Streaming o APIs Realtime nativas.
- **Vocabulario muy especializado** (nombres propios internos, SKUs raros). Mejor fine-tune de otro modelo o un ASR comercial con *custom vocabulary*.
- **Audio telefónico mono de 8 kHz con mucho ruido** y necesitas máxima precisión: Deepgram Nova-3 y modelos *telephony-tuned* suelen ganar.
- **Diarización fiable:** Whisper no diariza; necesitas combinarlo con pyannote o usar AssemblyAI/Deepgram que la traen integrada.

## ¿Cómo funciona?

### Pipeline interno de Whisper

```
Audio arbitrario
      ↓ (ffmpeg)
PCM 16-bit mono 16 kHz
      ↓
Padding/truncado a ventanas de 30 s
      ↓
Log-Mel spectrogram (80 bandas, hop 10 ms → 3000 frames por ventana)
      ↓
Encoder Transformer (bloques self-attention) → embeddings acústicos
      ↓
Decoder Transformer autoregresivo:
  tokens especiales [<|startoftranscript|> <|es|> <|transcribe|> <|notimestamps|>]
  + predice siguiente token hasta <|endoftext|>
      ↓
Post-proceso: puntuación, truecase, timestamps interpolados
```

Datos clave:

- La ventana fija de **30 segundos** es la razón de que audios largos deban trocearse.
- El decoder genera tokens de texto *condicionado* a los embeddings del encoder, con tokens especiales que seleccionan tarea (`<|transcribe|>` vs `<|translate|>`) e idioma.
- La probabilidad `no_speech_prob` por segmento viene de un clasificador auxiliar y es tu mejor señal para filtrar alucinaciones.

### Parámetros clave de la API

| Parámetro | Qué hace | Recomendación |
|---|---|---|
| `model` | `whisper-1`, `gpt-4o-transcribe`, `gpt-4o-mini-transcribe` | gpt-4o-transcribe para mayor precisión; whisper-1 para costo bajo |
| `language` | ISO-639-1 (`es`, `en`, `zh`) | **siempre pásalo si lo conoces**; mejora WER y latencia |
| `prompt` | hasta 224 tokens de contexto previo | pasa jerga de dominio, nombres propios, estilo deseado |
| `response_format` | ver tabla arriba | `verbose_json` por default |
| `temperature` | 0.0 – 1.0, fallback cuando falla la decodificación | **0.0** para determinismo; sube solo si ves fallback repetidos |
| `timestamp_granularities` | `["segment"]` o `["word"]` | `word` para karaoke/alineación precisa |

### Prompt engineering para Whisper

El `prompt` **no es una instrucción** como en un LLM; es una continuación falsa del audio anterior. Whisper lo usa para sesgar vocabulario y estilo.

Ejemplos efectivos:

```python
prompt="OpenAI, GPT-4, Anthropic Claude, Llama, embeddings, RAG."
# → fija ortografía de marcas y jerga técnica

prompt="— ¿Cómo está? — Muy bien, gracias."
# → sesga a diálogo con guiones y puntuación cuidada

prompt="Dr. García, Lic. Pérez, Sra. López."
# → preserva abreviaturas de títulos
```

Lo que **no** funciona: "transcribe en mayúsculas", "ignora groserías". No es un LLM.

### Chunking de audio largo

Whisper API limita a **25 MB** por request (~25 min de MP3 a 128 kbps). Para audio más largo:

1. Cargar y segmentar con **solape** (típicamente 1-2 s) para no cortar palabras.
2. Transcribir cada chunk, pasando el final del transcript anterior como `prompt` (preserva contexto).
3. Reconstruir timestamps sumando el offset del chunk.
4. Fusionar texto eliminando duplicados en la zona de solape.

Alternativa más limpia: usar VAD para cortar en silencios y mandar segmentos naturales.

### Diarización combinada con Whisper

Whisper no sabe quién habla. Patrón estándar:

```
Audio
  ├─→ Whisper → segmentos (start, end, text)
  └─→ pyannote.audio → segmentos (start, end, SPEAKER_xx)

Luego: para cada segmento Whisper, asignar el speaker que más solapa en el tiempo.
```

Librería `whisperX` empaqueta este flujo (whisper + VAD + alineación forzada con wav2vec2 + diarización pyannote).

### Streaming "parcial" con Whisper

Whisper no es nativamente streaming, pero hay patrones aproximados:

- **Micro-batching**: acumula ~2-5 s de audio con VAD, procesa, muestra resultado parcial, repite. Latencia ~2-5 s.
- **Sliding window**: procesa ventanas superpuestas de 10-15 s y re-emite el texto estabilizado. Es la base de `whisper_streaming` (Macháček et al. 2023).
- Para streaming real (<300 ms), cambia a Deepgram, AssemblyAI Streaming, o la OpenAI Realtime API (que internamente usa un modelo diferente).

## Ejemplo con código

### Transcripción básica con la API

```python
from openai import OpenAI

client = OpenAI(api_key="API_KEY", base_url="BASE_URL")

with open("audio.mp3", "rb") as f:
    transcript = client.audio.transcriptions.create(
        model="whisper-1",
        file=f,
        response_format="text",
    )

print(transcript)
```

### Transcripción con timestamps y filtrado de alucinaciones

```python
from openai import OpenAI

client = OpenAI(api_key="API_KEY", base_url="BASE_URL")

with open("llamada.mp3", "rb") as f:
    result = client.audio.transcriptions.create(
        model="whisper-1",
        file=f,
        language="es",
        prompt="Soporte técnico de fibra óptica. Mencionan router, ONT, latencia, Mbps.",
        response_format="verbose_json",
        temperature=0.0,
        timestamp_granularities=["segment"],
    )

# Filtra segmentos probablemente alucinados en silencios
LIMPIO = []
for seg in result.segments:
    if seg["no_speech_prob"] > 0.6:
        continue
    if seg["avg_logprob"] < -1.0:        # muy baja confianza
        continue
    if seg["compression_ratio"] > 2.4:    # texto repetitivo/alucinado
        continue
    LIMPIO.append(seg)

for s in LIMPIO:
    print(f"[{s['start']:6.2f} → {s['end']:6.2f}] {s['text'].strip()}")
```

Los tres filtros (`no_speech_prob`, `avg_logprob`, `compression_ratio`) son los umbrales recomendados por el propio paper de Whisper para detectar y descartar segmentos degenerados.

### Preprocesamiento canónico

```python
# pip install pydub && brew install ffmpeg
import os
from pydub import AudioSegment

def validar_y_normalizar(src: str, dst: str) -> dict:
    if not os.path.exists(src):
        return {"ok": False, "error": "no existe"}

    audio = AudioSegment.from_file(src)
    duracion_s = len(audio) / 1000.0

    # Normaliza a mono 16 kHz 16-bit WAV
    audio = audio.set_channels(1).set_frame_rate(16000).set_sample_width(2)
    audio.export(dst, format="wav")

    size_mb = os.path.getsize(dst) / 1024 / 1024
    return {
        "ok": True,
        "duracion_s": duracion_s,
        "size_mb": size_mb,
        "demasiado_grande": size_mb > 25,
    }

print(validar_y_normalizar("entrada.m4a", "entrada_norm.wav"))
```

### Chunking con solape y prompt encadenado

```python
import tempfile, os
from pydub import AudioSegment
from openai import OpenAI

client = OpenAI(api_key="API_KEY", base_url="BASE_URL")

def transcribir_largo(audio_path: str, chunk_s: int = 600, overlap_s: int = 2) -> str:
    audio = AudioSegment.from_file(audio_path).set_channels(1).set_frame_rate(16000)
    chunk_ms = chunk_s * 1000
    hop_ms = (chunk_s - overlap_s) * 1000

    full_text, carry_prompt = [], ""
    for start in range(0, len(audio), hop_ms):
        chunk = audio[start:start + chunk_ms]
        tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
        chunk.export(tmp.name, format="wav")

        try:
            with open(tmp.name, "rb") as f:
                t = client.audio.transcriptions.create(
                    model="whisper-1",
                    file=f,
                    language="es",
                    prompt=carry_prompt[-800:],  # últimos ~800 chars como contexto
                    response_format="text",
                )
            full_text.append(t)
            carry_prompt = (carry_prompt + " " + t).strip()
        finally:
            os.unlink(tmp.name)

    return " ".join(full_text)
```

### Whisper local con `faster-whisper` + VAD

```python
# pip install faster-whisper
from faster_whisper import WhisperModel

model = WhisperModel(
    "large-v3-turbo",
    device="cuda",          # usa "cpu" + compute_type="int8" si no hay GPU
    compute_type="float16",
)

segments, info = model.transcribe(
    "entrevista.wav",
    language="es",
    vad_filter=True,                                    # Silero VAD integrado
    vad_parameters={"min_silence_duration_ms": 500,
                    "threshold": 0.5},
    beam_size=5,
    best_of=5,
    temperature=[0.0, 0.2, 0.4],                        # fallback progresivo
    initial_prompt="Entrevista técnica sobre machine learning.",
    word_timestamps=True,
    condition_on_previous_text=False,                   # evita cascada de alucinaciones
)

print(f"Idioma: {info.language} ({info.language_probability:.2f})")
for seg in segments:
    print(f"[{seg.start:6.2f} → {seg.end:6.2f}] {seg.text}")
```

`condition_on_previous_text=False` es un flag clave: cuando Whisper usa el texto anterior como contexto puede entrar en bucles alucinatorios ("gracias, gracias, gracias…"). Desactivarlo evita esa cascada a costa de un poco de coherencia entre segmentos.

### Streaming ASR con WebSocket (Deepgram)

Para latencia real (<500 ms), Whisper no es el camino. Deepgram es el reemplazo típico:

```python
# pip install deepgram-sdk
import asyncio
from deepgram import DeepgramClient, LiveTranscriptionEvents, LiveOptions

async def stream_micro(audio_source):
    dg = DeepgramClient("DEEPGRAM_API_KEY")
    conn = dg.listen.asyncwebsocket.v("1")

    async def on_transcript(_, result, **kw):
        alt = result.channel.alternatives[0]
        prefix = "FINAL" if result.is_final else "parcial"
        if alt.transcript:
            print(f"[{prefix}] {alt.transcript}")

    conn.on(LiveTranscriptionEvents.Transcript, on_transcript)

    options = LiveOptions(
        model="nova-3",
        language="es",
        encoding="linear16",
        sample_rate=16000,
        channels=1,
        interim_results=True,       # resultados parciales
        endpointing=300,             # ms de silencio para marcar final
        smart_format=True,           # puntuación + números
        vad_events=True,
    )
    await conn.start(options)

    async for chunk in audio_source:      # cada chunk = bytes PCM 16-bit
        await conn.send(chunk)

    await conn.finish()

# asyncio.run(stream_micro(mi_generador_audio()))
```

### Diarización con pyannote + alineación con Whisper

```python
# pip install pyannote.audio faster-whisper
from pyannote.audio import Pipeline
from faster_whisper import WhisperModel

HF_TOKEN = "hf_..."   # requiere aceptar la licencia en huggingface.co

diar = Pipeline.from_pretrained("pyannote/speaker-diarization-3.1", use_auth_token=HF_TOKEN)
asr = WhisperModel("large-v3", device="cuda", compute_type="float16")

audio = "reunion.wav"
diarization = diar(audio)   # anotación con tramos y speaker labels
segments, _ = asr.transcribe(audio, language="es", vad_filter=True)
segments = list(segments)

def mejor_speaker(start: float, end: float) -> str:
    """Devuelve el speaker que más solapa con el intervalo dado."""
    mejor, mejor_dur = "SPEAKER_??", 0.0
    for turn, _, spk in diarization.itertracks(yield_label=True):
        inicio = max(start, turn.start)
        fin = min(end, turn.end)
        dur = max(0.0, fin - inicio)
        if dur > mejor_dur:
            mejor, mejor_dur = spk, dur
    return mejor

for seg in segments:
    spk = mejor_speaker(seg.start, seg.end)
    print(f"[{seg.start:6.2f}] {spk}: {seg.text.strip()}")
```

### Batch concurrente con control de rate limit

```python
import asyncio
from openai import AsyncOpenAI

client = AsyncOpenAI(api_key="API_KEY", base_url="BASE_URL")
SEM = asyncio.Semaphore(5)   # máximo 5 requests simultáneas

async def transcribir(path: str) -> dict:
    async with SEM:
        with open(path, "rb") as f:
            r = await client.audio.transcriptions.create(
                model="whisper-1", file=f, language="es",
                response_format="verbose_json",
            )
    return {"path": path, "text": r.text, "duration": r.duration}

async def main(paths):
    return await asyncio.gather(*(transcribir(p) for p in paths))

# resultados = asyncio.run(main(["a.mp3", "b.mp3", "c.mp3"]))
```

### Caché por hash de contenido

```python
import hashlib, json
from pathlib import Path

CACHE = Path("./cache_asr"); CACHE.mkdir(exist_ok=True)

def hash_params(audio_path: str, lang: str, prompt: str) -> str:
    h = hashlib.sha256()
    with open(audio_path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    h.update(json.dumps({"lang": lang, "prompt": prompt}, sort_keys=True).encode())
    return h.hexdigest()

def transcribir_cacheado(audio_path: str, lang: str = "es", prompt: str = "") -> str:
    key = hash_params(audio_path, lang, prompt)
    cached = CACHE / f"{key}.txt"
    if cached.exists():
        return cached.read_text()

    from openai import OpenAI
    client = OpenAI(api_key="API_KEY", base_url="BASE_URL")
    with open(audio_path, "rb") as f:
        t = client.audio.transcriptions.create(
            model="whisper-1", file=f, language=lang, prompt=prompt,
            response_format="text",
        )
    cached.write_text(t)
    return t
```

## Errores comunes

- **No usar VAD y transcribir silencio** → Whisper alucina texto reciclado del training ("subtítulos realizados por la comunidad", "music", frases de outro de YouTube). Siempre filtra con VAD o descarta segmentos con `no_speech_prob > 0.6`.
- **Modelo demasiado pequeño para la calidad real del audio.** `tiny` y `base` colapsan en llamadas telefónicas, acentos marcados o code-switching. Mínimo `small` en producción; `medium`/`large-v3` para castellano latino con ruido.
- **No pasar `language`** cuando lo conoces. Whisper gasta tokens detectando y, en audios cortos o ruidosos, se equivoca. `language="es"` reduce WER y latencia.
- **Sample rate incorrecto.** Enviar 44.1 kHz estéreo funciona pero resamplea internamente, cuesta tiempo y a veces calidad. Normaliza a 16 kHz mono con pydub/ffmpeg.
- **`condition_on_previous_text=True` por default** → bucles de alucinación tipo "gracias gracias gracias" cuando un segmento sale mal. Para audio potencialmente ruidoso, desactívalo.
- **Confiar en la auto-detección de idioma en audios de code-switching** (ES/EN mezclado). Mejor segmentar con VAD y detectar por tramo o forzar el idioma dominante.
- **Chunking sin solape** → palabras cortadas en los bordes. Usa 1-2 s de solape y encadena `prompt` entre chunks.
- **Enviar archivos de 25 MB+ y recibir 413.** La API corta sin aviso. Valida tamaño antes de subir.
- **Omitir el `prompt` para dominios con jerga.** Sin contexto, "LangChain" se transcribe como "lang chain", "RAG" como "rag" o "rack". Un prompt corto con los términos los fija.
- **Usar `temperature > 0` por default.** Introduce variabilidad y, si el seed cambia, hace imposible reproducir bugs. Deja `0.0` y confía en el fallback automático.
- **Pedir Whisper para streaming de muy baja latencia.** No es su caso de uso. Usa Deepgram, AssemblyAI o la Realtime API.
- **Querer diarización pura con Whisper.** No la hace; combina con pyannote (open) o AssemblyAI/Deepgram (gestionadas).
- **No cachear por hash de contenido.** Volver a transcribir el mismo audio tras un retry desperdicia dinero y tiempo. Hash SHA-256 del archivo + parámetros → caché local o S3.
- **Olvidar costos acumulados.** 5.000 llamadas de 4 min a $0.006/min ≈ **$120/día**. Monitoriza desde el día 1.

## Resumen

- **Whisper** es el ASR de referencia desde 2022; `large-v3` y `large-v3-turbo` (2024) son el estado del arte open source.
- Dos caminos: **API de OpenAI** (zero-ops, $0.006/min para `whisper-1`) o **self-hosted** con `faster-whisper` (4× más rápido que el original, mejor control de costo y privacidad).
- Formatos de respuesta: `verbose_json` da timestamps y señales de confianza (`no_speech_prob`, `avg_logprob`, `compression_ratio`) imprescindibles para filtrar alucinaciones.
- Normaliza audio a **mono 16 kHz 16-bit WAV** antes de enviar. Para archivos >25 MB, trocea con solape de 1-2 s.
- El **`prompt`** no es una instrucción, es una continuación falsa: úsalo para fijar jerga, nombres propios y estilo.
- **VAD** (Silero, WebRTC) elimina silencios y previene alucinaciones. **`condition_on_previous_text=False`** evita bucles.
- Para **diarización**, combina Whisper con `pyannote.audio`; para **streaming de baja latencia**, usa Deepgram/AssemblyAI o la Realtime API, no Whisper.
- Patrones productivos imprescindibles: **concurrencia con semáforo**, **caché por hash**, **retries con backoff exponencial**, filtrado por confianza.
- Métrica para medir calidad: **WER**. Humano profesional ~5 %, Whisper large-v3 en español limpio ~5-8 %, en audio ruidoso puede subir a 15-30 %.
