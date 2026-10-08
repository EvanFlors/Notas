# Procesando Contenido de Video

## ¿Qué es?

Procesar video es la **implementación práctica** del pipeline conceptual: extraer frames eficientemente desde archivos (mp4, mov, webm), enviarlos a vision APIs, agregar las respuestas temporalmente y generar artefactos útiles (resúmenes, timelines, moderaciones). A diferencia de la lección anterior que explicó el "qué", aquí construimos el "cómo" con código ejecutable.

El bloque mínimo de procesamiento es:

```
VideoFile → VideoProcessor → list[Frame] → VideoAnalyzer → list[FrameAnalysis]
                                                                  ↓
                                                          TemporalAnalyzer
                                                                  ↓
                                                         VideoSummary / Timeline
```

### Componentes del pipeline

- **VideoProcessor:** maneja la decodificación con OpenCV / ffmpeg y produce frames muestreados.
- **VideoAnalyzer:** empaqueta frames en base64 y los envía a la vision API.
- **TemporalAnalyzer:** agrupa resultados por timestamp y detecta patrones, escenas y acciones.
- **VideoSummarizer:** combina análisis de frames con un LLM de texto para generar resúmenes.

## ¿Por qué importa?

Un prototipo en Jupyter que extrae frames y los imprime es muy diferente de un servicio que procesa 1,000 videos diarios. En producción debes preocuparte por:

- **Memoria:** un video de 1 h a 30 fps son 108,000 frames; cargarlos todos a RAM revienta cualquier proceso.
- **Costo de API:** cada frame enviado cuesta tokens. Un pipeline mal diseñado puede gastar miles de dólares al día.
- **Latencia:** los usuarios no esperan 10 min por un análisis. Hay que paralelizar y cachear.
- **Fiabilidad:** videos corruptos, formatos raros (HEVC/VP9), archivos sin audio: todo debe fallar grácilmente.
- **Reproducibilidad:** el mismo video debe producir el mismo análisis (hash-based cache).

Dominar estos patrones diferencia un notebook de un sistema de producción.

## ¿Cómo funciona?

### 1. Extracción de frames: uniform sampling

Es el método base, útil para la mayoría de tareas:

### 2. Extracción de keyframes por scene detection

Se compara cada frame con el anterior y se guarda solo cuando el cambio supera un umbral.

### 3. Análisis con Vision API

Cada frame se codifica a base64 y se envía como `image_url` en el mensaje del usuario.

### 4. Análisis temporal

Las respuestas se ordenan por timestamp y se buscan patrones: cambios de escena, acciones, repeticiones.

![Temporal analysis timeline](https://hrcdn.net/ai-engineering/module-5/light/video-lesson02-temporal-analysis-timeline.svg)

### 5. Resumen con LLM

Las descripciones por frame se concatenan en un prompt para un LLM de texto, que genera un resumen coherente.

### Herramientas típicas

| Tarea | Herramienta | Nota |
|---|---|---|
| Decodificar video | OpenCV, moviepy, ffmpeg | OpenCV es el estándar en Python |
| Extraer audio | ffmpeg | `ffmpeg -i video.mp4 -vn audio.wav` |
| Scene detection | PySceneDetect, OpenCV | PySceneDetect es más robusto |
| Vision API | OpenAI, Anthropic, Google | GPT-4o, Claude 3.5, Gemini 1.5 |
| Transcripción | Whisper (OpenAI/local) | `whisper-1` o `faster-whisper` |
| Procesamiento async | asyncio, Celery | Para producción |

## Ejemplo con código

### VideoProcessor: extracción eficiente

```python
import cv2
from pathlib import Path
from dataclasses import dataclass

@dataclass
class Frame:
    path: Path
    timestamp: float
    frame_number: int
    change_score: float | None = None


class VideoProcessor:
    """Extrae frames de un video con dos estrategias."""

    def extract_uniform(
        self, video_path: str, output_dir: str, interval_s: float = 1.0
    ) -> list[Frame]:
        """Un frame cada `interval_s` segundos."""
        cap = cv2.VideoCapture(video_path)
        fps = cap.get(cv2.CAP_PROP_FPS)
        step = max(int(fps * interval_s), 1)

        Path(output_dir).mkdir(parents=True, exist_ok=True)
        frames, idx = [], 0
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            if idx % step == 0:
                ts = idx / fps
                # Reducir resolución para abaratar la API
                frame = cv2.resize(frame, (512, 512))
                p = Path(output_dir) / f"frame_{ts:.2f}.jpg"
                cv2.imwrite(str(p), frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
                frames.append(Frame(p, ts, idx))
            idx += 1
        cap.release()
        return frames

    def extract_keyframes(
        self, video_path: str, output_dir: str, threshold: float = 0.3
    ) -> list[Frame]:
        """Guarda solo frames donde la diferencia supera `threshold`."""
        cap = cv2.VideoCapture(video_path)
        fps = cap.get(cv2.CAP_PROP_FPS)
        Path(output_dir).mkdir(parents=True, exist_ok=True)

        prev_gray, frames, idx = None, [], 0
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            if prev_gray is not None:
                diff = cv2.absdiff(gray, prev_gray).mean() / 255.0
                if diff > threshold:
                    ts = idx / fps
                    p = Path(output_dir) / f"keyframe_{ts:.2f}.jpg"
                    cv2.imwrite(str(p), cv2.resize(frame, (512, 512)))
                    frames.append(Frame(p, ts, idx, diff))
            prev_gray = gray
            idx += 1
        cap.release()
        return frames
```

### Scene detection robusto con PySceneDetect

```python
from scenedetect import detect, ContentDetector

def detect_scenes(video_path: str, threshold: float = 27.0) -> list[tuple]:
    """Detecta escenas usando el detector por contenido (HSV)."""
    scenes = detect(video_path, ContentDetector(threshold=threshold))
    # scenes: lista de (start_timecode, end_timecode)
    return [(s.get_seconds(), e.get_seconds()) for s, e in scenes]

for start, end in detect_scenes("tutorial.mp4"):
    print(f"Escena: {start:.2f}s - {end:.2f}s")
```

### VideoAnalyzer: enviar frames a Vision API

```python
from openai import OpenAI
import base64

class VideoAnalyzer:
    def __init__(self, api_key: str, base_url: str | None = None):
        self.client = OpenAI(api_key=api_key, base_url=base_url)

    def _encode(self, path: Path) -> str:
        return base64.b64encode(path.read_bytes()).decode("utf-8")

    def analyze_frame(self, frame: Frame, prompt: str) -> str:
        """Analiza un frame individual."""
        img64 = self._encode(frame.path)
        resp = self.client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=[{
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url",
                     "image_url": {
                         "url": f"data:image/jpeg;base64,{img64}",
                         "detail": "low",  # low = ~85 tokens vs high = ~765
                     }},
                ],
            }],
            max_tokens=300,
        )
        return resp.choices[0].message.content

    def analyze_batch_single_call(
        self, frames: list[Frame], prompt: str
    ) -> str:
        """Envía todos los frames en una sola llamada (preserva orden temporal)."""
        content = [{"type": "text", "text": prompt}]
        for i, f in enumerate(frames, 1):
            img64 = self._encode(f.path)
            content.append({"type": "text",
                            "text": f"Frame {i} (t={f.timestamp:.1f}s):"})
            content.append({"type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{img64}",
                                "detail": "low"}})
        resp = self.client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=[{"role": "user", "content": content}],
            max_tokens=1500,
        )
        return resp.choices[0].message.content
```

### Enviar frames a Claude (Anthropic)

```python
from anthropic import Anthropic

def analyze_with_claude(frames: list[Frame], prompt: str) -> str:
    client = Anthropic()  # ANTHROPIC_API_KEY del env
    content = [{"type": "text", "text": prompt}]
    for i, f in enumerate(frames[:20], 1):  # Claude: max 20 imágenes
        img64 = base64.b64encode(f.path.read_bytes()).decode("utf-8")
        content.append({"type": "text",
                        "text": f"Frame {i} ({f.timestamp:.1f}s):"})
        content.append({
            "type": "image",
            "source": {"type": "base64",
                       "media_type": "image/jpeg", "data": img64},
        })
    msg = client.messages.create(
        model="claude-3-5-sonnet-latest",
        max_tokens=1500,
        messages=[{"role": "user", "content": content}],
    )
    return msg.content[0].text
```

### Gemini: entrada de video nativa

```python
import google.generativeai as genai

def analyze_with_gemini_native(video_path: str, prompt: str) -> str:
    """Gemini 1.5 Pro acepta el archivo mp4 completo."""
    genai.configure()  # GOOGLE_API_KEY del env
    video_file = genai.upload_file(path=video_path)
    # Esperar a que termine el procesamiento del upload
    import time
    while video_file.state.name == "PROCESSING":
        time.sleep(2)
        video_file = genai.get_file(video_file.name)

    model = genai.GenerativeModel("gemini-1.5-pro")
    response = model.generate_content([video_file, prompt])
    return response.text

# Resume un video de 30 min sin extraer frames manualmente
resumen = analyze_with_gemini_native(
    "lecture.mp4",
    "Resume esta clase en 5 puntos con timestamps."
)
```

### Video embeddings con CLIP por frame

```python
import clip
import torch
from PIL import Image

device = "cuda" if torch.cuda.is_available() else "cpu"
model, preprocess = clip.load("ViT-B/32", device=device)

def video_embedding(frames: list[Frame]) -> torch.Tensor:
    """Embedding del video = promedio de embeddings CLIP por frame."""
    vecs = []
    for f in frames:
        img = preprocess(Image.open(f.path)).unsqueeze(0).to(device)
        with torch.no_grad():
            vecs.append(model.encode_image(img))
    return torch.stack(vecs).mean(dim=0)  # [1, 512]

# Comparar dos videos por similitud semántica
v1 = video_embedding(frames_a)
v2 = video_embedding(frames_b)
sim = torch.cosine_similarity(v1, v2).item()
```

### Resumen de video completo

```python
class VideoSummarizer:
    def __init__(self, client):
        self.client = client

    def summarize(self, frame_analyses: list[dict]) -> str:
        timeline = "\n".join(
            f"[{a['ts']:.1f}s] {a['desc']}" for a in frame_analyses
        )
        resp = self.client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=[
                {"role": "system",
                 "content": "Eres un resumidor de video. "
                            "Genera resúmenes concisos y estructurados."},
                {"role": "user",
                 "content": f"Resume el video basándote en estas "
                            f"observaciones por frame:\n\n{timeline}"},
            ],
            max_tokens=500,
        )
        return resp.choices[0].message.content
```

### Servicio de producción con cache y manejo de errores

```python
import hashlib, logging
logger = logging.getLogger(__name__)

class ProductionVideoService:
    def __init__(self, processor, analyzer, summarizer):
        self.processor = processor
        self.analyzer = analyzer
        self.summarizer = summarizer
        self.cache: dict[str, dict] = {}

    def _video_hash(self, path: str) -> str:
        h = hashlib.sha256()
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                h.update(chunk)
        return h.hexdigest()

    def process(self, video_path: str) -> dict:
        key = self._video_hash(video_path)
        if key in self.cache:
            logger.info(f"Cache hit {key[:8]}")
            return self.cache[key]
        try:
            frames = self.processor.extract_uniform(video_path, "/tmp/frames")
            analyses = [
                {"ts": f.timestamp,
                 "desc": self.analyzer.analyze_frame(
                     f, "Describe esta escena en 2 oraciones.")}
                for f in frames
            ]
            result = {
                "frames_analyzed": len(frames),
                "summary": self.summarizer.summarize(analyses),
                "timeline": analyses,
            }
            self.cache[key] = result
            return result
        except Exception as e:
            logger.error(f"Falló procesamiento: {e}")
            raise
```

## Errores comunes

- **Cargar todo el video a RAM.** `cv2.VideoCapture.read()` iterativo es correcto; no acumules todos los frames en una lista si no caben. Procesa en streaming y guarda a disco.
- **No reducir resolución antes de encodear base64.** Un frame 1920×1080 ocupa ~2,000 tokens en modo `high` o 85 en `low`. Pasa `cv2.resize(frame, (512, 512))` y `detail="low"` para abaratar 20×.
- **Enviar frames en llamadas separadas cuando necesitas orden temporal.** Si vas a razonar sobre secuencia, mándalos todos en un solo mensaje con `Frame 1`, `Frame 2`, ... Así el modelo ve el orden.
- **No cachear por hash del archivo.** Un hash SHA-256 del binario garantiza que el mismo video reutilice el resultado anterior sin reprocesarlo.
- **Olvidar `cap.release()`.** OpenCV mantiene descriptors abiertos; sin `release()` acabas con "too many open files" en producción.
- **Umbral de scene detection fijo.** El umbral correcto depende del contenido: tutoriales con transiciones suaves necesitan `0.1`, videos de acción pueden tolerar `0.4`. Calibra con muestras reales.
- **No validar formato antes de procesar.** Soporta mp4, mov, webm; rechaza formatos exóticos (ProRes, DNxHR) o reconviértelos con ffmpeg antes.
- **Procesar sincrónicamente en el request HTTP.** 10 min de video pueden tardar 60 s de análisis; devuelve `202 Accepted` + job_id y procesa en worker async (Celery, SQS, Cloud Tasks).

## Resumen

- Un pipeline de procesamiento tiene cuatro bloques: **extracción**, **análisis por frame**, **análisis temporal** y **síntesis**.
- Usa **uniform sampling** por defecto; cambia a **keyframe** o **PySceneDetect** cuando necesites capítulos o resúmenes.
- Para enviar frames: **reduce resolución a ~512×512**, usa `detail="low"` y encodea en base64.
- Envía los frames en **una sola llamada** cuando necesites razonar sobre la secuencia temporal.
- Para videos largos, considera **Gemini 1.5 Pro con native video**: evita toda la gimnasia de extracción manual.
- **Cachea por hash del archivo**; nunca reproceses el mismo video dos veces.
- En producción: async (Celery/SQS), límites de duración, manejo de errores y liberación de recursos (`cap.release()`).
- Herramientas base del stack: **OpenCV**, **ffmpeg**, **PySceneDetect**, **OpenAI/Anthropic/Google SDK**, **Whisper**, **CLIP** para embeddings.
