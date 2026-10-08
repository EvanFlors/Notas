# Aplicaciones Prácticas: Moderación, Búsqueda y Generación de Video

## ¿Qué es?

Esta lección reúne las **aplicaciones de producción** más demandadas construidas sobre video understanding:

1. **Content moderation:** detectar violaciones de política (violencia, contenido adulto, actividad peligrosa) antes de publicar.
2. **Video search:** indexar y buscar dentro de bibliotecas de video por contenido semántico.
3. **Video summarization:** generar resúmenes textuales, capítulos o highlight reels.
4. **Video generation:** crear video nuevo a partir de prompts de texto (Sora, Runway, Pika, Luma).

Cada una comparte el pipeline base de extracción + análisis + agregación, pero añade decisiones específicas: dos-pasadas en moderación, embedding + rank en búsqueda, hierarchical en summarización.

## ¿Por qué importa?

Son los **productos reales** donde las empresas invierten dinero:

- **Moderación:** TikTok, YouTube, Instagram procesan **millones de uploads diarios**. Una moderación lenta deja contenido tóxico publicado; una cara agota el presupuesto. La estrategia de dos pasadas (`quick scan` + `detailed`) ahorra 80-90% de costo asumiendo que el 95% del contenido es seguro.
- **Búsqueda:** una biblioteca con 10,000 videos sin índice es inútil. Un buen índice permite "muéstrame videos donde alguien demuestra una técnica de cocina" sin ver ninguno manualmente.
- **Resúmenes:** YouTube Shorts, TL;DW apps, capítulos automáticos en YouTube Studio: todos usan summarización.
- **Generación:** Sora (OpenAI, feb 2024), Runway Gen-3 (jun 2024), Luma Dream Machine (2024), Pika 1.0: el mercado de text-to-video explotó. Marketing, prototipado y creación de contenido ya usan estos modelos.

Ignorar estas aplicaciones es ignorar donde está la demanda del mercado de 2024-2026.

## ¿Cómo funciona?

### 1. Moderación: estrategia de dos pasadas

```
Video → Quick scan (low detail, pocos frames)
          ├── Safe (95%) → return SAFE  ✓ bajo costo
          └── Concerning → Detailed analysis (high detail, frames flaggeados)
                             → return decisión final
```

Esta arquitectura es económicamente clave: solo el ~5% de videos paga el costo del análisis detallado.

### 2. Búsqueda: índice + ranking

```
Index time:  video → extract frames → VLM → {summary, topics, entities, scenes}
                                               → store(index)

Query time:  query → compare contra entries → rank → return top-K
```

El índice puede ser:
- **Full-text search** (Elasticsearch, OpenSearch) sobre summaries y topics.
- **Vector search** (pgvector, Pinecone, Qdrant) sobre embeddings del resumen.
- **LLM re-ranking:** rápido para prototipos; costoso a escala.

### 3. Summarización: tres sabores

| Tipo | Qué produce | Cuándo usar |
|---|---|---|
| **Text summary** | Párrafo narrativo | Preview, descripciones, email |
| **Chapters** | Marcadores con timestamp + título | Navegación (YouTube chapters) |
| **Highlights** | 3-5 momentos clave | Trailers, teasers, deportes |

### 4. Generación de video

Modelos comparados (2024):

| Modelo | Empresa | Tipo | Resolución | Duración | Acceso |
|---|---|---|---|---|---|
| **Sora** | OpenAI | T2V, I2V | 1080p | hasta 60s | Limitado |
| **Runway Gen-3** | Runway | T2V, I2V, V2V | 1280×768 | 5-10s | API pública |
| **Pika 1.0 / 1.5** | Pika Labs | T2V, I2V | 1080p | 3-10s | Web + API |
| **Luma Dream Machine** | Luma AI | T2V, I2V | 1360×752 | 5s | Web + API |
| **Stable Video Diffusion** | Stability AI | I2V | 576×1024 | 2-4s | Open source |
| **Veo** | Google DeepMind | T2V | 1080p | 60s+ | Limitado |

- **T2V:** text-to-video. **I2V:** image-to-video. **V2V:** video-to-video.

### 5. Consideraciones de producción

- Límites de duración máxima para controlar costo.
- Control de concurrencia (`asyncio.Semaphore`) para no exceder rate limits.
- Estimación previa de costo antes de aceptar el job.
- Manejo de errores (video corrupto, formato no soportado).
- Privacidad: caras, matrículas, información sensible.

## Ejemplo con código

### Servicio de moderación con dos pasadas

```python
from dataclasses import dataclass
from enum import Enum
import json

class ModerationCategory(Enum):
    SAFE = "safe"
    VIOLENCE = "violence"
    ADULT_CONTENT = "adult_content"
    HATE_SPEECH = "hate_speech"
    DANGEROUS_ACTIVITY = "dangerous_activity"
    NEEDS_REVIEW = "needs_review"

@dataclass
class ModerationResult:
    decision: ModerationCategory
    confidence: float
    flagged_frames: list[int]
    reasoning: str
    requires_human_review: bool


class VideoModerationService:
    """Moderación de video por dos pasadas."""

    def __init__(self, client, policy: dict | None = None):
        self.client = client
        self.policy = policy or {
            "categories": ["violence", "adult_content",
                           "dangerous_activity", "hate_symbols"],
            "confidence_threshold": 0.7,
            "frames_to_analyze": 10,
        }

    def moderate(self, video_path: str) -> ModerationResult:
        frames = extract_frames_by_count(
            video_path, self.policy["frames_to_analyze"]
        )
        quick = self._quick_scan(frames)
        if quick["likely_safe"]:
            return ModerationResult(
                decision=ModerationCategory.SAFE,
                confidence=quick["confidence"],
                flagged_frames=[],
                reasoning="Sin contenido preocupante detectado",
                requires_human_review=False,
            )
        return self._detailed(frames, quick["concerning_frames"])

    def _quick_scan(self, frames: list) -> dict:
        """Pasada rápida con detail='low'."""
        content = [{
            "type": "text",
            "text": """
            Escanea rápido estos frames por contenido preocupante.
            Categorías: violencia, adulto, actividades peligrosas,
            símbolos de odio.

            Para cada frame marca: safe | concerning | violation.

            JSON: {
              "frame_assessments": [{"frame": 1, "status": "safe"}],
              "likely_safe": true,
              "confidence": 0.0-1.0,
              "concerning_frames": [números]
            }
            """
        }]
        for ts, frame in frames:
            content.append({
                "type": "image_url",
                "image_url": {
                    "url": f"data:image/jpeg;base64,{frame_to_base64(frame)}",
                    "detail": "low",  # barato
                },
            })
        resp = self.client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=[{"role": "user", "content": content}],
            response_format={"type": "json_object"},
            max_tokens=500,
        )
        return json.loads(resp.choices[0].message.content)

    def _detailed(self, frames: list, concerning_idx: list) -> ModerationResult:
        """Pasada detallada con detail='high' solo en frames flaggeados."""
        if not concerning_idx:
            return ModerationResult(
                ModerationCategory.SAFE, 0.9, [], "Sin violaciones", False
            )
        flagged = [frames[i-1] for i in concerning_idx if i <= len(frames)]
        content = [{
            "type": "text",
            "text": """
            Analiza con detalle estos frames flaggeados.
            Determina: categoría, severidad (minor/moderate/severe),
            contexto (educativo/noticioso/artístico), confianza.

            JSON: {
              "category": "...",
              "severity": "...",
              "confidence": 0.0-1.0,
              "reasoning": "...",
              "requires_human_review": true/false
            }
            """
        }]
        for ts, frame in flagged:
            content.append({
                "type": "image_url",
                "image_url": {
                    "url": f"data:image/jpeg;base64,{frame_to_base64(frame)}",
                    "detail": "high",  # caro pero preciso
                },
            })
        resp = self.client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=[{"role": "user", "content": content}],
            response_format={"type": "json_object"},
            max_tokens=500,
        )
        r = json.loads(resp.choices[0].message.content)
        cmap = {
            "safe": ModerationCategory.SAFE,
            "violence": ModerationCategory.VIOLENCE,
            "adult_content": ModerationCategory.ADULT_CONTENT,
            "hate_speech": ModerationCategory.HATE_SPEECH,
            "dangerous_activity": ModerationCategory.DANGEROUS_ACTIVITY,
        }
        return ModerationResult(
            decision=cmap.get(r.get("category", "safe"),
                              ModerationCategory.NEEDS_REVIEW),
            confidence=r.get("confidence", 0.5),
            flagged_frames=concerning_idx,
            reasoning=r.get("reasoning", ""),
            requires_human_review=r.get("requires_human_review", True),
        )
```

### Video search: index + query

```python
@dataclass
class VideoIndexEntry:
    video_id: str
    video_path: str
    duration: float
    summary: str
    topics: list[str]
    entities: list[str]
    scenes: list[dict]


class VideoSearchService:
    def __init__(self, client, index_store):
        self.client = client
        self.index = index_store

    def index_video(self, video_id: str, video_path: str) -> VideoIndexEntry:
        info = get_video_info(video_path)
        frames = extract_frames_by_count(video_path, 10)
        prompt = """
        Crea un índice de búsqueda. Extrae:
        1. Resumen de un párrafo.
        2. Temas principales (lista).
        3. Entidades (personas, productos, lugares).
        4. Escenas con timestamp aproximado.

        JSON:
        {
          "summary": "...",
          "topics": [...],
          "entities": [...],
          "scenes": [{"timestamp": 0, "description": "..."}]
        }
        """
        content = _build(prompt, frames)
        resp = self.client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=[{"role": "user", "content": content}],
            response_format={"type": "json_object"},
            max_tokens=1000,
        )
        d = json.loads(resp.choices[0].message.content)
        entry = VideoIndexEntry(
            video_id=video_id, video_path=video_path,
            duration=info["duration_seconds"],
            summary=d.get("summary", ""),
            topics=d.get("topics", []),
            entities=d.get("entities", []),
            scenes=d.get("scenes", []),
        )
        self.index.store(entry)
        return entry

    def search(self, query: str, limit: int = 10) -> list[dict]:
        entries = self.index.get_all()
        text = "\n".join(
            f"ID: {e.video_id}\nResumen: {e.summary}\n"
            f"Temas: {', '.join(e.topics)}\n---"
            for e in entries
        )
        resp = self.client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=[{"role": "user", "content": f"""
                Query: "{query}"
                Videos:
                {text}
                Devuelve IDs rankeados por relevancia.
                JSON: {{"results": ["id1", "id2"]}}
            """}],
            response_format={"type": "json_object"},
            max_tokens=200,
        )
        ids = json.loads(resp.choices[0].message.content).get("results", [])
        return [{"video_id": i, "entry": self.index.get(i)}
                for i in ids[:limit] if self.index.get(i)]
```

### Summarización: texto, capítulos y highlights

```python
def generate_summary(
    video_path: str, client,
    summary_type: str = "text", length: str = "medium",
) -> dict:
    frames = extract_frames_by_count(video_path, 12)
    info = get_video_info(video_path)
    length_map = {
        "brief": "2-3 oraciones máximo",
        "medium": "Un párrafo (4-6 oraciones)",
        "detailed": "Varios párrafos cubriendo todos los puntos",
    }

    if summary_type == "text":
        prompt = (
            f"Resume este video en {length_map[length]}. "
            f"Duración: {info['duration_seconds']:.0f}s"
        )
    elif summary_type == "chapters":
        prompt = f"""
        Crea marcadores de capítulo. Duración: {info['duration_seconds']:.0f}s
        JSON: {{"chapters": [
          {{"timestamp": secs, "title": "...", "description": "..."}}
        ]}}
        """
    elif summary_type == "highlights":
        prompt = f"""
        Identifica 3-5 momentos clave del video.
        Duración: {info['duration_seconds']:.0f}s
        JSON: {{"highlights": [
          {{"timestamp": secs, "description": "...", "importance": "..."}}
        ]}}
        """

    content = _build(prompt, frames)
    rf = ({"type": "json_object"}
          if summary_type in ("chapters", "highlights") else None)
    resp = client.chat.completions.create(
        model="gpt-4.1-mini",
        messages=[{"role": "user", "content": content}],
        response_format=rf,
        max_tokens=1000,
    )
    text = resp.choices[0].message.content
    return {"summary": text} if summary_type == "text" else json.loads(text)
```

### Generación de video: Runway Gen-3 via Replicate

```python
import replicate

def generate_video_runway(prompt: str, duration: int = 5) -> str:
    """Genera video con Runway Gen-3 Alpha Turbo."""
    output = replicate.run(
        "runwayml/gen3-alpha-turbo",
        input={
            "prompt": prompt,
            "duration": duration,          # 5 o 10 segundos
            "aspect_ratio": "16:9",
            "watermark": False,
        },
    )
    return output   # URL del mp4 generado

url = generate_video_runway(
    "Un gato astronauta flotando en la luna, estilo cinemático"
)
print(f"Video generado: {url}")
```

### Luma Dream Machine via API

```python
import requests, time, os

def generate_luma(prompt: str) -> str:
    api_key = os.environ["LUMAAI_API_KEY"]
    headers = {"Authorization": f"Bearer {api_key}",
               "Content-Type": "application/json"}
    r = requests.post(
        "https://api.lumalabs.ai/dream-machine/v1/generations",
        headers=headers,
        json={"prompt": prompt, "aspect_ratio": "16:9"},
    )
    gen_id = r.json()["id"]
    # Poll hasta completar
    while True:
        s = requests.get(
            f"https://api.lumalabs.ai/dream-machine/v1/generations/{gen_id}",
            headers=headers,
        ).json()
        if s["state"] == "completed":
            return s["assets"]["video"]
        if s["state"] == "failed":
            raise RuntimeError(s.get("failure_reason", "unknown"))
        time.sleep(5)
```

### OpenAI Sora (API cuando esté disponible)

```python
from openai import OpenAI
client = OpenAI()

# Interfaz hipotética basada en el anuncio de Sora
response = client.videos.generate(
    model="sora-1",
    prompt="A stylish woman walks down a Tokyo street filled with "
           "warm glowing neon and animated city signage.",
    duration_seconds=10,
    resolution="1080p",
)
video_url = response.url
```

### Servicio de producción con control de costo y concurrencia

```python
import asyncio

class ProductionVideoService:
    def __init__(self, client, max_concurrent: int = 3,
                 max_duration: float = 3600, max_frames: int = 20):
        self.client = client
        self.sem = asyncio.Semaphore(max_concurrent)
        self.max_duration = max_duration
        self.max_frames = max_frames

    async def analyze(self, video_path: str) -> dict:
        info = get_video_info(video_path)
        if info["duration_seconds"] > self.max_duration:
            return {"success": False,
                    "error": f"Excede {self.max_duration}s"}
        dur = info["duration_seconds"]
        n = min(self.max_frames, max(5, int(dur / 10)))
        async with self.sem:
            try:
                frames = extract_frames_by_count(video_path, n)
                result = await self._analyze_async(frames, info)
                return {"success": True, "result": result,
                        "metadata": {"frames": n, "duration": dur}}
            except Exception as e:
                return {"success": False, "error": str(e)}

    def estimate_cost(self, duration: float) -> dict:
        n = min(self.max_frames, max(5, int(duration / 10)))
        in_tok = n * 1000 + 500
        out_tok = 1000
        cost = (in_tok * 0.40 + out_tok * 1.60) / 1_000_000
        return {"frames": n, "input_tokens": in_tok,
                "output_tokens": out_tok, "cost_usd": round(cost, 4)}
```

### Hierarchical analysis para videos largos (2h+)

```python
def hierarchical_analyze(video_path: str, client,
                         segment_minutes: int = 10) -> str:
    """Analiza en segmentos y luego sintetiza."""
    info = get_video_info(video_path)
    total = info["duration_seconds"]
    seg_s = segment_minutes * 60

    segment_summaries = []
    for start in range(0, int(total), seg_s):
        end = min(start + seg_s, total)
        seg = extract_frames_range(video_path, start, end, num_frames=10)
        summary = analyze_segment(seg, client)
        segment_summaries.append(
            f"[{start}-{end}s]: {summary}"
        )

    # Síntesis final
    final = client.chat.completions.create(
        model="gpt-4.1-mini",
        messages=[{"role": "user", "content":
            f"Sintetiza estos resúmenes de segmento en uno coherente:\n"
            + "\n".join(segment_summaries)}],
        max_tokens=1500,
    )
    return final.choices[0].message.content
```

## Errores comunes

- **Procesar videos sincrónicamente.** El análisis puede tomar 30-120 s; bloquear el request causa timeouts. Siempre async + job queue.
- **Sin límite de duración máxima.** Un usuario puede subir un video de 10 horas; sin límite el costo explota. Define `max_duration = 3600` y rechaza con mensaje claro.
- **Sin manejo de errores de formato.** Videos corruptos, codecs raros (ProRes, DNxHR), archivos sin audio: envuelve todo en try/except y devuelve códigos de error legibles.
- **Ignorar privacidad.** Videos pueden contener caras identificables, matrículas, documentos. Si no es necesario, difumina antes de almacenar o usa face anonymization (OpenCV + Haar cascades o MediaPipe).
- **Sobre-analizar.** No todo video necesita 20 frames detallados. Ajusta `n_frames` según la tarea: moderación rápida = 5-8, resumen = 10-12, análisis fino = 15-20.
- **Un solo pase para moderación.** Si el 95% del contenido es seguro y haces análisis caro siempre, pagas 20× de más. Implementa quick-scan + detailed.
- **Sin rate limiting del generador.** Sora/Runway/Luma tienen cuotas estrictas; sin backoff exponencial, tus requests fallan en cascada. Usa `tenacity` o similar.
- **No validar prompts de generación.** T2V con prompts tóxicos puede generar contenido prohibido por ToS del proveedor. Modera el prompt antes de enviarlo.

## Resumen

- **Moderación de video:** usa estrategia de **dos pasadas** (quick scan en `detail=low` + detailed en `detail=high` solo si hay sospecha). Ahorra 80-90% del costo.
- **Búsqueda:** indexa cada video con `{summary, topics, entities, scenes}` y rankea por relevancia (LLM, full-text o vector search).
- **Summarización** tiene tres sabores: `text`, `chapters` (marcadores con timestamp) y `highlights` (3-5 momentos clave).
- **Generación de video 2024:** Sora (OpenAI), Runway Gen-3, Pika, Luma Dream Machine, SVD (open source), Veo (Google). Diferencias en resolución, duración y acceso.
- Para videos largos (2h+): usa **hierarchical analysis** → segmentos de 10 min + síntesis final.
- Producción obligatoria: **async + concurrency control + duration limits + cache + error handling + privacy**.
- Estima costo **antes** de aceptar el job con la fórmula `frames × tokens_per_frame × precio`.

Esto completa el submódulo de Video Understanding. En el siguiente submódulo trabajarás con **Multi-Modal Applications**: combinar visión, audio y lenguaje en soluciones integrales.
