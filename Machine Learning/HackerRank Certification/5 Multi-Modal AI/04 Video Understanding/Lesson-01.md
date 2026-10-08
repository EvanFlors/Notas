# Entendiendo el Análisis de Video

## ¿Qué es?

**Video Understanding** es la capacidad de un sistema de IA de analizar contenido de video combinando tres dimensiones: **visual** (lo que aparece en cada frame), **temporal** (cómo cambia el contenido a lo largo del tiempo) y **auditiva** (voz, música, efectos). A diferencia del análisis de imagen, aquí los datos son una **secuencia ordenada** `V = (f₁, f₂, ..., fₙ)` donde el orden importa: un video reproducido al revés describe eventos diferentes.

Un video crudo es una matriz tensorial de 4 dimensiones:

```
V ∈ ℝ^(T × H × W × C)
  T = número de frames
  H, W = alto y ancho en pixeles
  C = canales (3 para RGB)
```

Más una pista de audio `A ∈ ℝ^(T_a × C_a)` muestreada típicamente a 16 kHz o 44.1 kHz.

### Capacidades clave

- **Frame analysis:** entender el contenido de frames individuales (objetos, personas, escena).
- **Temporal understanding:** reconocer acciones, movimientos y cambios en el tiempo.
- **Scene detection:** identificar fronteras entre escenas y transiciones.
- **Action recognition:** clasificar acciones (caminar, saltar, cocinar) que ocurren a lo largo de múltiples frames.
- **Object tracking:** seguir el mismo objeto a través de los frames.
- **Video Q&A:** responder preguntas en lenguaje natural sobre el contenido.
- **Video summarization:** generar resúmenes textuales o highlight reels.

### Diferencia con análisis de imagen

| Aspecto | Imagen | Video |
|---|---|---|
| Datos | 1 frame (H×W×C) | T frames + audio |
| Costo | 1 llamada a vision API | T llamadas o contexto gigante |
| Reto | Reconocer objetos | Reconocer **secuencias** y **relaciones causales** |
| Latencia | ms | segundos a minutos |
| Almacenamiento | KB-MB | MB-GB |

## ¿Por qué importa?

Los videos son la fuente de información más rica del internet moderno (YouTube: 500 horas subidas por minuto en 2024), pero **analizarlos manualmente no escala**. Un humano tarda al menos la duración real del video en revisarlo, mientras que un sistema de IA puede procesar miles de videos en paralelo.

Casos de uso del mundo real:

- **Moderación de contenido:** TikTok, YouTube Shorts e Instagram Reels requieren filtrar violencia, desnudez o discurso de odio en millones de uploads diarios antes de que lleguen al feed.
- **Búsqueda dentro de video:** encontrar el momento exacto donde el presentador menciona un tema (`"¿cuándo habla del precio?"`).
- **Accesibilidad:** generar audiodescripciones y subtítulos para usuarios con discapacidad visual o auditiva.
- **Educación y training:** extraer conceptos clave de clases grabadas, generar resúmenes y crear quizzes automáticos.
- **Soporte al cliente:** analizar videos enviados por usuarios para diagnosticar problemas (ej. "mi lavadora hace este ruido").
- **Seguridad y vigilancia:** detectar eventos sospechosos (persona entra y sale rápido) en lugar de solo movimiento.
- **Deportes y broadcasting:** generar highlights automáticos, estadísticas y análisis táctico.

### Contexto 2024

- **Gemini 1.5 Pro** (Google, feb 2024): primer modelo con **native video input** y 2M tokens de contexto, puede procesar hasta ~1 hora de video sin extraer frames manualmente.
- **GPT-4o** (OpenAI, may 2024): procesa frames muestreados; no acepta video nativo pero es muy económico por frame.
- **Claude 3.5 Sonnet** (Anthropic, 2024): procesa video a través de frames enviados como imágenes.
- **Sora** (OpenAI, anuncio feb 2024): modelo de **generación** de video a partir de texto.
- **Runway Gen-3** (jun 2024) y **Luma Dream Machine** (2024): text-to-video y image-to-video de calidad producción.

## ¿Cómo funciona?

El pipeline canónico de video understanding tiene cinco etapas:

```
Video → Frame Extraction → Frame Analysis → Temporal Analysis → Integration → Insight
            ↓
         Audio Extraction → Speech-to-Text (Whisper)
```

![Video understanding pipeline](https://hrcdn.net/ai-engineering/module-5/light/video-lesson01-video-understanding-pipeline.svg)

### 1. Representación del video (frames, fps, keyframes)

- **FPS (frames per second):** típicamente 24, 30 o 60. Un video de 1 min a 30 fps tiene **1,800 frames**.
- **Keyframes (I-frames):** frames completos codificados independientemente (en MPEG/H.264 ocurren cada ~1-2 s).
- **Delta frames (P/B-frames):** solo contienen la **diferencia** respecto al frame anterior; son más ligeros.

Enviar los 1,800 frames a un VLM es inviable: con `~1,000 tokens por frame` serían **1.8M tokens** por minuto. La solución es **frame sampling**.

### 2. Fórmula de costo

```
cost ≈ frames_enviados × tokens_por_frame × precio_input + tokens_output × precio_output
```

Para un video de `D` segundos muestreado a `fps_sample`:

```
frames_enviados = D × fps_sample
```

**Regla práctica:** `1 fps` cubre la mayoría de tareas descriptivas. Para acciones rápidas (deportes) sube a `2-4 fps`. Para resúmenes largos usa `0.1-0.5 fps` o solo keyframes.

### 3. Estrategias de frame sampling

![Estrategias de muestreo de frames](https://hrcdn.net/ai-engineering/module-5/light/video-lesson01-frame-sampling-strategies.svg)

| Estrategia | Cómo funciona | Pros | Contras | Ideal para |
|---|---|---|---|---|
| **Uniform sampling** | 1 frame cada `k` segundos (ej. 1 fps) | Simple, costo predecible | Puede perder eventos entre muestras | Análisis general, contenido estático |
| **Keyframe detection** | Frames en cambios de escena | Captura transiciones, eficiente | Requiere algoritmo adicional | Resúmenes, capítulos |
| **Adaptive sampling** | Más frames en acción, menos en estático | Cobertura óptima vs costo | Implementación compleja | Deportes, variabilidad alta |

### 4. Enfoques de modelos: native vs frame-sampling

| Modelo | Entrada de video | Capacidad | Mejor para |
|---|---|---|---|
| **Gemini 1.5 Pro / 2.0** | **Native video** (archivo mp4) | Hasta ~1 h a 1 fps en 2M context | Videos largos, Q&A, resúmenes |
| **GPT-4o / GPT-4.1-mini** | Frames como imágenes base64 | ~50-100 frames prácticos | Pipelines personalizados |
| **Claude 3.5 Sonnet** | Frames como imágenes base64 | Hasta 20 imágenes por request | Moderación detallada por frame |

### 5. Temporal modeling

Para capturar la dimensión temporal hay tres enfoques:

- **Frame-level + agrupación:** analiza cada frame y agrupa resultados por timestamp. Simple pero pierde dinámica.
- **Video embeddings (CLIP per-frame + promedio o LSTM):** vectoriza cada frame con CLIP y agrega la secuencia.
- **Video transformers (VideoMAE, ViViT, TimeSformer):** modelos entrenados con atención espacio-temporal nativa.

### 6. Audio: la mitad olvidada

El audio aporta ~50% de la información en muchos videos (voz, narración, música, efectos). El pipeline debe:

1. Extraer la pista de audio (`ffmpeg -i video.mp4 -vn audio.wav`).
2. Transcribir con Whisper o similar.
3. Alinear timestamps de la transcripción con los frames visuales.

## Ejemplo con código

Pipeline conceptual completo de video understanding:

```python
# ============================================================
# Pipeline conceptual de video understanding
# ============================================================
import cv2
from pathlib import Path

def extract_frames(video_path: str, fps_sample: float = 1.0) -> list[dict]:
    """Extrae frames a `fps_sample` cuadros por segundo."""
    cap = cv2.VideoCapture(video_path)
    fps_video = cap.get(cv2.CAP_PROP_FPS)
    interval = int(fps_video / fps_sample)

    frames, idx = [], 0
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        if idx % interval == 0:
            timestamp = idx / fps_video
            frames.append({"idx": idx, "ts": timestamp, "img": frame})
        idx += 1
    cap.release()
    return frames


def extract_audio(video_path: str, out_path: str = "audio.wav") -> str:
    """Extrae la pista de audio con ffmpeg."""
    import subprocess
    subprocess.run(
        ["ffmpeg", "-y", "-i", video_path, "-vn", "-ac", "1",
         "-ar", "16000", out_path],
        check=True, capture_output=True
    )
    return out_path


def understand_video(video_path: str, vlm_client, whisper_client) -> dict:
    """Pipeline end-to-end."""
    # 1. Extraer frames a 1 fps
    frames = extract_frames(video_path, fps_sample=1.0)
    print(f"Frames extraídos: {len(frames)}")

    # 2. Analizar cada frame con VLM
    frame_descs = [vlm_client.describe(f["img"]) for f in frames]

    # 3. Extraer y transcribir audio
    audio_path = extract_audio(video_path)
    transcript = whisper_client.transcribe(audio_path)

    # 4. Análisis temporal: agrupar observaciones
    timeline = [
        {"ts": f["ts"], "visual": d}
        for f, d in zip(frames, frame_descs)
    ]

    # 5. Integración final: resumen con LLM
    summary = vlm_client.summarize(timeline, transcript)
    return {
        "timeline": timeline,
        "transcript": transcript,
        "summary": summary,
    }
```

### Estimación de costo con fórmula

```python
def estimate_video_cost(
    duration_s: float,
    fps_sample: float = 1.0,
    tokens_per_frame: int = 1000,
    price_in_per_mtok: float = 0.40,   # gpt-4.1-mini input
    price_out_per_mtok: float = 1.60,
    output_tokens: int = 1000,
) -> dict:
    """Estima el costo en USD de analizar un video."""
    frames = int(duration_s * fps_sample)
    input_tokens = frames * tokens_per_frame + 500  # +prompt
    cost = (input_tokens * price_in_per_mtok +
            output_tokens * price_out_per_mtok) / 1_000_000
    return {
        "frames": frames,
        "input_tokens": input_tokens,
        "cost_usd": round(cost, 4),
    }

# Un video de 10 min a 1 fps
print(estimate_video_cost(600))
# {'frames': 600, 'input_tokens': 600500, 'cost_usd': 0.2418}

# Si por error muestreas a 30 fps:
print(estimate_video_cost(600, fps_sample=30))
# {'frames': 18000, 'input_tokens': 18000500, 'cost_usd': 7.2018}
# ¡30× más caro!
```

### Scene detection básico con OpenCV

```python
def detect_scene_changes(video_path: str, threshold: float = 0.3) -> list[float]:
    """Detecta cambios de escena por diferencia absoluta en grayscale."""
    cap = cv2.VideoCapture(video_path)
    fps = cap.get(cv2.CAP_PROP_FPS)
    prev, scenes, idx = None, [], 0
    while True:
        ret, frame = cap.read()
        if not ret:
            break
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        if prev is not None:
            diff = cv2.absdiff(gray, prev).mean() / 255.0
            if diff > threshold:
                scenes.append(idx / fps)
        prev = gray
        idx += 1
    cap.release()
    return scenes
```

## Errores comunes

- **Muestrear a 30 fps "para no perder nada".** Explota el costo: un video de 10 min a 30 fps son 18,000 frames (~$7 USD en gpt-4.1-mini vs $0.24 a 1 fps). Casi siempre `1 fps` es suficiente.
- **No reducir resolución antes de enviar.** Un frame 4K ocupa ~2,000 tokens; redimensionar a 512×512 lo baja a ~250. Usa `cv2.resize()` antes de encodear a base64.
- **Ignorar el audio.** El audio aporta narración, diálogo y contexto temporal. Pipelines solo-visuales pierden la mitad de la información en videos tipo tutorial o entrevista.
- **No agrupar frames temporalmente.** Enviar cada frame por separado y pegar las respuestas pierde la relación temporal. Mejor enviar un batch con prompt "estos son frames en orden; describe la secuencia".
- **Usar modelos sin capacidad de video/imagen.** Llamar `gpt-3.5-turbo` con imágenes lanza `TypeError`. Verifica siempre que el modelo soporte vision (`gpt-4o`, `gpt-4.1-mini`, `claude-3-5-sonnet`, `gemini-1.5-pro`).
- **Confiar en timestamps exactos del VLM.** La precisión temporal está limitada por el `fps_sample`. A 1 fps no puedes decir "ocurre en el segundo 3.47", solo "entre el frame 3 y el 4".
- **Procesar videos sincrónicamente.** Un video de 10 min puede tardar 30-60 s en analizarse; bloquear el request HTTP causa timeouts. Usa colas (Celery, SQS) y procesamiento async.
- **No cachear.** El mismo video analizado dos veces debería devolver el resultado cacheado. Usa hash SHA-256 del archivo como clave.

## Resumen

- **Video understanding** combina análisis visual, temporal y de audio sobre una secuencia ordenada de frames.
- La fórmula clave es `cost ≈ frames × tokens_por_frame`; muestrea a **1 fps** por defecto.
- Hay tres estrategias de sampling: **uniform**, **keyframe detection** y **adaptive**. Elige según el tipo de contenido.
- Dos enfoques de modelo: **nativo** (Gemini 1.5 Pro acepta mp4 directo) o **frame-sampling** (GPT-4o, Claude, procesan frames como imágenes).
- El **audio** no es opcional: Whisper transcribe, el VLM describe lo visual, un LLM integra ambas pistas.
- Casos de uso: **moderación**, **búsqueda**, **accesibilidad**, **educación**, **soporte**, **seguridad**, **broadcasting**.
- Errores más caros: muestrear a 30 fps, no reducir resolución, ignorar audio, no cachear.
- En producción: async + duración máxima + límite de frames + cache + manejo de errores.
