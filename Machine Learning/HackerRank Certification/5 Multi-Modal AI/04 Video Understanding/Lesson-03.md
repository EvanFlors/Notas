# Entendiendo Eventos a lo Largo del Tiempo

## ¿Qué es?

El **temporal reasoning** sobre video es la capacidad de razonar no solo sobre frames individuales, sino sobre **cómo se relacionan** en el tiempo: qué ocurrió antes, qué viene después, qué causa qué. Es la diferencia entre "veo una persona en la puerta" (análisis de frame) y "la persona entró a las 00:02 y salió a las 00:05, duración 3 segundos" (razonamiento temporal).

Hay cuatro primitivas temporales fundamentales:

| Primitiva | Definición | Ejemplo |
|---|---|---|
| **Sequence** | Orden de eventos | A entra, luego recoge, luego sale |
| **Duration** | Longitud de un evento | Gesto rápido (0.5s) vs acción sostenida (10s) |
| **Causation** | Un evento provoca otro | Bola golpea pinos → pinos caen |
| **Simultaneity** | Eventos concurrentes | Uno habla mientras otro gesticula |

![Relaciones temporales en video](https://hrcdn.net/ai-engineering/module-5/light/video-lesson03-temporal-relationships.svg)

### Modelo de datos para eventos de video

```python
from dataclasses import dataclass
from typing import Optional

@dataclass
class VideoEvent:
    event_type: str
    description: str
    start_time: float
    end_time: float
    confidence: float
    subjects: list[str]
    location_in_frame: Optional[str] = None

@dataclass
class TemporalRelation:
    event_a: VideoEvent
    event_b: VideoEvent
    relation_type: str   # before | after | during | causes | caused_by
    description: str
```

## ¿Por qué importa?

Muchas aplicaciones del mundo real **no se resuelven con análisis de frame independiente**:

- **Seguridad y vigilancia:** distinguir "persona entra y se queda" (normal) de "persona entra e inmediatamente sale" (sospechoso) requiere comparar posiciones a lo largo de frames ordenados. Un contador de personas por frame nunca detectaría la diferencia.
- **Análisis deportivo:** una canasta de tres puntos es una secuencia (recibe, dribla, salta, lanza); un frame suelto solo muestra un jugador.
- **Investigación de incidentes:** entender un accidente requiere la cadena causal (frenó tarde → golpeó al que iba adelante → tercero chocó por detrás).
- **Interacciones humanas:** detectar un apretón de manos requiere observar que dos personas se acercan, se tocan y se separan.
- **Soporte técnico:** diagnosticar "la lavadora empieza a vibrar después de llenar de agua" requiere orden temporal entre dos observaciones.

Sin razonamiento temporal, tu sistema está condenado a describir frames en lugar de **entender videos**.

## ¿Cómo funciona?

### 1. Multi-frame prompting con orden explícito

La técnica base es enviar múltiples frames en una sola llamada al VLM, **marcando el orden** y timestamps en el prompt. El modelo entonces puede razonar sobre la secuencia.

```
Frame 1 (t=0.0s): [imagen]
Frame 2 (t=2.5s): [imagen]
Frame 3 (t=5.0s): [imagen]
```

### 2. Entity tracking

Seguir la misma entidad (persona, objeto, vehículo) a través de los frames. Vision-language models pueden hacer tracking **conceptual** aunque no sean trackers especializados (ByteTrack, DeepSORT lo hacen a nivel de bounding boxes).

### 3. Temporal queries

Preguntas sobre **cuándo** sucede algo:
- "¿En qué segundo aparece el producto por primera vez?"
- "¿Cuánto dura la demostración?"
- "¿Qué pasa después de que entra el auto?"

### 4. Event detection

Clasificar frames (o secuencias) en categorías predefinidas: `PERSON_ENTERS`, `PERSON_EXITS`, `OBJECT_MOVED`, `ANOMALY`, etc. Útil para alertas automáticas.

### 5. Cause-effect analysis

Encontrar cadenas causales (A causa B, B causa C) para explicar incidentes o predecir consecuencias.

### Precisión temporal: una advertencia

La precisión máxima de tus timestamps está limitada por el **frame sampling**:

```
precisión_temporal ≈ 1 / fps_sample
```

Si muestreas a 1 fps, no puedes afirmar "ocurre a los 3.47s", solo "entre 3.0s y 4.0s". No reclames más precisión de la que el sampling permite.

## Ejemplo con código

### Analizar secuencia temporal con prompt multi-frame

```python
def analyze_temporal_sequence(
    video_path: str,
    client,
    focus_query: str | None = None,
) -> dict:
    """Razona sobre la secuencia temporal del video."""
    frames = extract_frames_by_count(video_path, 12)

    prompt = """
    Analiza la secuencia temporal de estos frames de video.

    Para cada evento significativo:
    1. ¿Cuál es el evento?
    2. ¿Cuándo empieza y termina (por número de frame)?
    3. ¿Qué lo causa o qué causa él?
    4. ¿Quién o qué participa?

    Luego describe la estructura temporal general:
    - ¿Qué pasa primero, luego, finalmente?
    - ¿Hay relaciones causa-efecto?
    - ¿Hay eventos simultáneos?
    """
    if focus_query:
        prompt += f"\nEnfócate especialmente en: {focus_query}"

    content = [{"type": "text", "text": prompt}]
    for i, (ts, frame) in enumerate(frames, 1):
        content.append({"type": "text", "text": f"Frame {i} ({ts:.1f}s):"})
        content.append({
            "type": "image_url",
            "image_url": {
                "url": f"data:image/jpeg;base64,{frame_to_base64(frame)}"
            },
        })

    resp = client.chat.completions.create(
        model="gpt-4.1-mini",
        messages=[{"role": "user", "content": content}],
        max_tokens=1500,
    )
    return {
        "temporal_analysis": resp.choices[0].message.content,
        "frame_count": len(frames),
        "duration": frames[-1][0] if frames else 0,
    }
```

### Entity tracking a través de frames

```python
import json

def track_entity(
    video_path: str,
    entity_description: str,
    client,
    num_frames: int = 10,
) -> dict:
    """Rastrea una entidad específica a través del video."""
    frames = extract_frames_by_count(video_path, num_frames)

    prompt = f"""
    Rastrea esta entidad a través de los frames: "{entity_description}"

    Para cada frame reporta:
    1. ¿La entidad es visible? (sí/no/parcial)
    2. ¿Dónde en el frame? (izq/centro/der, cerca/medio/lejos)
    3. ¿Qué está haciendo?
    4. Cambios notables respecto al frame anterior.

    Resume también el recorrido:
    - ¿Cuándo aparece y desaparece?
    - ¿Cómo se mueve?
    - ¿Qué acciones realiza?

    Devuelve JSON:
    {{
      "entity": "{entity_description}",
      "frame_observations": [
         {{"frame": 1, "visible": "yes/no/partial",
           "location": "...", "action": "...", "changes": "..."}}
      ],
      "journey_summary": "descripción general"
    }}
    """
    content = [{"type": "text", "text": prompt}]
    for i, (ts, frame) in enumerate(frames, 1):
        content.append({"type": "text", "text": f"Frame {i} ({ts:.1f}s):"})
        content.append({"type": "image_url", "image_url": {
            "url": f"data:image/jpeg;base64,{frame_to_base64(frame)}"}})

    resp = client.chat.completions.create(
        model="gpt-4.1-mini",
        messages=[{"role": "user", "content": content}],
        response_format={"type": "json_object"},
        max_tokens=1500,
    )
    return json.loads(resp.choices[0].message.content)
```

### Interacciones entre dos entidades

```python
def find_interactions(
    video_path: str, entity_a: str, entity_b: str, client
) -> dict:
    """Encuentra interacciones entre dos entidades."""
    frames = extract_frames_by_count(video_path, 12)

    prompt = f"""
    Analiza interacciones entre:
      Entidad A: "{entity_a}"
      Entidad B: "{entity_b}"

    Para cada frame indica:
    1. ¿Ambas entidades son visibles?
    2. Relación espacial (cerca, lejos, se tocan).
    3. ¿Interactúan? ¿Cómo?

    Resume:
    - ¿Cuándo interactúan?
    - ¿Qué tipos de interacción ocurren?
    - ¿Cómo cambia su relación?
    """
    content = _build_frames_content(prompt, frames)
    resp = client.chat.completions.create(
        model="gpt-4.1-mini",
        messages=[{"role": "user", "content": content}],
        max_tokens=1000,
    )
    return {"entity_a": entity_a, "entity_b": entity_b,
            "interactions": resp.choices[0].message.content}
```

### Temporal queries: responder "¿cuándo?"

```python
def answer_temporal_query(
    video_path: str, query: str, client, num_frames: int = 12
) -> dict:
    """
    Ejemplos:
      "¿Cuándo empieza a hablar sobre precio?"
      "¿Cuánto dura la demostración?"
      "¿Qué pasa después de que el auto entra?"
    """
    frames = extract_frames_by_count(video_path, num_frames)
    info = get_video_info(video_path)
    prompt = f"""
    Duración del video: {info['duration_seconds']:.1f} s

    Responde esta pregunta: {query}

    Devuelve:
    1. Respuesta directa.
    2. Estimación de timestamp (si aplica).
    3. Nivel de confianza (alto/medio/bajo).
    4. Observaciones de los frames que respaldan la respuesta.

    Si no puede responderse con los frames, explica qué info falta.
    """
    content = _build_frames_content(prompt, frames)
    resp = client.chat.completions.create(
        model="gpt-4.1-mini",
        messages=[{"role": "user", "content": content}],
        max_tokens=500,
    )
    return {
        "query": query,
        "answer": resp.choices[0].message.content,
        "video_duration": info["duration_seconds"],
        "frames_analyzed": num_frames,
    }
```

### Buscar un momento específico (coarse / fine)

```python
def find_moment(
    video_path: str, moment_description: str,
    client, precision: str = "coarse"
) -> dict:
    """Encuentra un momento específico en el video."""
    num_frames = 8 if precision == "coarse" else 20
    frames = extract_frames_by_count(video_path, num_frames)
    prompt = f"""
    Encuentra este momento: "{moment_description}"

    Analiza los frames e identifica:
    1. ¿En qué frame(s) ocurre?
    2. Timestamp estimado (segundos).
    3. Confianza (alta/media/baja).
    4. Descripción de lo que ves en ese momento.
    """
    content = _build_frames_content(prompt, frames)
    resp = client.chat.completions.create(
        model="gpt-4.1-mini",
        messages=[{"role": "user", "content": content}],
        max_tokens=500,
    )
    return {
        "searching_for": moment_description,
        "result": resp.choices[0].message.content,
        "precision": precision,
        "frames_searched": num_frames,
    }
```

### Event detection con tipos predefinidos

```python
from enum import Enum

class EventType(Enum):
    PERSON_ENTERS = "person_enters"
    PERSON_EXITS = "person_exits"
    OBJECT_MOVED = "object_moved"
    ACTIVITY_STARTED = "activity_started"
    ACTIVITY_ENDED = "activity_ended"
    ANOMALY = "anomaly"

def detect_events(
    video_path: str, event_types: list[EventType],
    client, num_frames: int = 10,
) -> list[dict]:
    """Detecta eventos específicos en el video."""
    frames = extract_frames_by_count(video_path, num_frames)
    info = get_video_info(video_path)
    descriptions = {
        EventType.PERSON_ENTERS: "Una persona entrando a la escena",
        EventType.PERSON_EXITS: "Una persona saliendo de la escena",
        EventType.OBJECT_MOVED: "Un objeto siendo movido",
        EventType.ACTIVITY_STARTED: "Una actividad que comienza",
        EventType.ACTIVITY_ENDED: "Una actividad que termina",
        EventType.ANOMALY: "Algo inusual o inesperado",
    }
    watching = "\n".join(f"- {descriptions[e]}" for e in event_types)
    prompt = f"""
    Analiza este video para los eventos:
    {watching}

    Para cada evento detectado reporta:
    - event_type
    - timestamp aproximado (duración total {info['duration_seconds']:.1f}s)
    - descripción
    - confianza (high/medium/low)

    Devuelve JSON:
    {{"events": [
      {{"event_type": "type", "timestamp": secs,
        "description": "...", "confidence": "level"}}
    ]}}
    """
    content = _build_frames_content(prompt, frames)
    resp = client.chat.completions.create(
        model="gpt-4.1-mini",
        messages=[{"role": "user", "content": content}],
        response_format={"type": "json_object"},
        max_tokens=1000,
    )
    result = json.loads(resp.choices[0].message.content)
    return result.get("events", [])
```

### Análisis causa-efecto

```python
def analyze_cause_effect(
    video_path: str, client, focus_event: str | None = None,
) -> dict:
    """Analiza relaciones causa-efecto en el video."""
    frames = extract_frames_by_count(video_path, 12)
    prompt = """
    Analiza las relaciones causa-efecto en esta secuencia.

    Para cada evento significativo:
    1. ¿Qué lo causó? (eventos o condiciones previas)
    2. ¿Qué efectos tuvo? (eventos o cambios posteriores)
    3. ¿Qué tan confiado estás en la relación causal?

    Identifica cadenas (A causa B, B causa C).
    """
    if focus_event:
        prompt += f"\nEnfócate en causas y efectos de: {focus_event}"
    prompt += """
    Devuelve JSON:
    {
      "causal_chains": [
        {"cause": "...", "effect": "...",
         "confidence": "high/medium/low",
         "evidence": "qué del video lo respalda"}
      ],
      "summary": "descripción general"
    }
    """
    content = _build_frames_content(prompt, frames)
    resp = client.chat.completions.create(
        model="gpt-4.1-mini",
        messages=[{"role": "user", "content": content}],
        response_format={"type": "json_object"},
        max_tokens=1000,
    )
    return json.loads(resp.choices[0].message.content)
```

### Helper reutilizable

```python
def _build_frames_content(prompt: str, frames: list) -> list:
    content = [{"type": "text", "text": prompt}]
    for i, (ts, frame) in enumerate(frames, 1):
        content.append({"type": "text", "text": f"Frame {i} ({ts:.1f}s):"})
        content.append({"type": "image_url", "image_url": {
            "url": f"data:image/jpeg;base64,{frame_to_base64(frame)}"}})
    return content
```

## Errores comunes

- **Asumir causación por secuencia.** Que B ocurra después de A no implica que A cause B. Es la falacia *post hoc ergo propter hoc*. Verifica con contexto adicional o audio antes de inferir causalidad.
- **Perder eventos entre frames.** A 1 fps un evento de 0.3s puede ocurrir completo entre dos muestras y volverse invisible. Para eventos rápidos (deportes, incidentes) usa `2-4 fps` o adaptive sampling.
- **Ignorar eventos fuera de frame.** Causas o efectos pueden ocurrir fuera del encuadre. El audio aporta pistas (sonido de puerta, grito, bocina). No descartes la pista de audio.
- **Sobre-confiar en precisión temporal.** Con 1 fps no puedes decir "0.47s", solo "entre 0s y 1s". Reporta rangos, no puntos.
- **Enviar frames sin orden explícito.** Si no numeras `Frame 1`, `Frame 2`, el modelo puede confundir el orden. Siempre etiqueta y añade timestamps.
- **Usar modelos sin capacidad temporal entrenada.** VLMs razonan sobre secuencias pero no son tan precisos como modelos de acción recognition entrenados (SlowFast, VideoMAE). Para producción crítica combina ambos.
- **No validar JSON de salida.** Modelos con `response_format={"type": "json_object"}` a veces devuelven arrays o claves inesperadas. Envuelve el `json.loads` en try/except y maneja ambos casos.

## Resumen

- El razonamiento temporal maneja cuatro primitivas: **sequence**, **duration**, **causation** y **simultaneity**.
- Técnica base: **multi-frame prompting** con orden explícito (`Frame 1 (t=0.0s): ...`).
- **Entity tracking** sigue personas u objetos a través de frames; útil para análisis de comportamiento.
- **Temporal queries** responden "¿cuándo?" con timestamps estimados; precisión limitada por el fps de sampling.
- **Event detection** clasifica frames en tipos predefinidos (`PERSON_ENTERS`, `ANOMALY`, etc.) para alertas.
- **Cause-effect analysis** encuentra cadenas causales; útil para investigación de incidentes.
- Precisión máxima: `1 / fps_sample`. A 1 fps, no reclames segundos decimales.
- Pitfall número uno: confundir secuencia con causalidad.
