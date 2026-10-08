# Construyendo aplicaciones multimodales en producción

## ¿Qué es?

Una **aplicación multimodal** es un sistema que integra múltiples capacidades de IA —visión, audio, texto, video— en un único flujo coherente. En lugar de tratar cada modalidad como un servicio aislado, la aplicación coordina modelos especializados (VLM para imágenes, ASR para voz, LLM para razonamiento, TTS para respuesta hablada, difusión para generar imágenes) y los combina mediante una capa de **orquestación**.

Una app multimodal moderna rara vez usa un solo modelo end-to-end. Combina:

- **Modelos multimodales nativos** (Claude 3.5 Sonnet, GPT-4o, Gemini 2.0) que procesan texto + imagen en un mismo contexto.
- **Modelos especializados** para tareas donde el nativo no basta: Whisper para transcripción, ElevenLabs para TTS, DALL-E/Flux para generación de imágenes, CLIP para embeddings cross-modal.
- **Orquestadores** (LangChain, LlamaIndex, Pipecat, LiveKit) que gestionan el flujo entre modelos.

### Formas típicas de app multimodal

| Patrón | Entrada | Salida | Caso real |
|---|---|---|---|
| **Document AI** | PDF/imagen | JSON estructurado | Facturas, recibos, contratos |
| **Visual search** | Imagen o texto | Imágenes similares | E-commerce (Pinterest Lens, Google Lens) |
| **Voice agent** | Audio streaming | Audio streaming | Soporte telefónico (Vapi, Retell) |
| **Multi-modal RAG** | Pregunta | Texto + imágenes citadas | Soporte técnico con diagramas |
| **Computer use** | Instrucción + screenshot | Acciones (click, type) | Automatización web (Claude, Operator) |
| **Vision-Language-Action** | Cámara + instrucción | Comandos de motor | Robótica (RT-2, π0) |

## ¿Por qué importa?

A finales de 2024 y durante 2025 cambió la forma de construir productos de IA. Hitos clave:

- **Anthropic Computer Use beta** (octubre 2024): Claude 3.5 Sonnet puede ver una pantalla y mover el ratón.
- **OpenAI Operator** (enero 2025): agente que navega la web por el usuario.
- **GPT-4o y Gemini 2.0 Flash Live** (2024-2025): voz-a-voz en tiempo real con latencia <500 ms.
- **Google Project Mariner** (diciembre 2024): agente de navegación en Chrome.

Esto reconfiguró lo que un ingeniero de IA necesita saber: ya no basta con llamar a un LLM, hay que **componer sistemas** que vean, escuchen, hablen y actúen.

### Casos reales en producción

- **Document extraction:** Stripe usa Claude vision para parsear facturas de proveedores con formatos impredecibles. Reemplazó un pipeline OCR + regex con 40% menos errores.
- **Accessibility:** Be My Eyes integra GPT-4o para describir imágenes a personas ciegas en segundos.
- **E-commerce:** Instacart usa visual search con CLIP para que usuarios fotografíen un producto en casa y encuentren el equivalente en catálogo.
- **Voice assistants:** Hume y Sesame construyen agentes de voz con tono emocional para salud mental y customer success.
- **Robótica:** Physical Intelligence (π0) entrena un VLA que mapea cámara + lenguaje → acciones motoras continuas.

## ¿Cómo funciona?

Una app multimodal típica tiene **cuatro capas**:

```
┌─────────────────────────────────────────────────────┐
│ 1. Ingesta: subida/stream (HTTP, WebSocket, SIP)    │
├─────────────────────────────────────────────────────┤
│ 2. Pre-procesamiento por modalidad                  │
│    - Imagen: resize, compresión, OCR opcional       │
│    - Audio: VAD, resampling 16kHz, chunking         │
│    - Video: extracción de frames + audio            │
├─────────────────────────────────────────────────────┤
│ 3. Orquestación (secuencial / paralelo / híbrido)   │
│    - Enrutador de modalidades                       │
│    - Fusión de resultados                           │
│    - Tool calls al LLM                              │
├─────────────────────────────────────────────────────┤
│ 4. Post-procesamiento y entrega                     │
│    - Validación (Pydantic, guardrails)              │
│    - Streaming de respuesta (SSE, WebSocket)        │
└─────────────────────────────────────────────────────┘
```

### Document AI (facturas, contratos, formularios)

El patrón dominante en 2025: VLM + schema estructurado + validación con Pydantic.

```python
import base64
import anthropic
from pydantic import BaseModel, Field
from datetime import date
from decimal import Decimal

class LineaFactura(BaseModel):
    descripcion: str
    cantidad: int
    precio_unitario: Decimal
    subtotal: Decimal

class Factura(BaseModel):
    numero: str = Field(description="Número o folio de la factura")
    emisor: str
    receptor: str
    fecha_emision: date
    moneda: str = Field(description="ISO 4217, e.g. MXN, USD")
    lineas: list[LineaFactura]
    subtotal: Decimal
    impuestos: Decimal
    total: Decimal

def extraer_factura(pdf_path: str) -> Factura:
    """Extrae campos estructurados de una factura usando Claude Vision."""
    with open(pdf_path, "rb") as f:
        pdf_data = base64.standard_b64encode(f.read()).decode()

    client = anthropic.Anthropic()
    resp = client.messages.create(
        model="claude-3-5-sonnet-20241022",
        max_tokens=2000,
        messages=[{
            "role": "user",
            "content": [
                {"type": "document", "source": {
                    "type": "base64",
                    "media_type": "application/pdf",
                    "data": pdf_data,
                }},
                {"type": "text", "text": f"""
Extrae los campos de esta factura y devuélvelos como JSON
que valide contra este esquema Pydantic:

{Factura.model_json_schema()}

Reglas:
- Todos los importes como string decimal ("1234.56").
- Fecha en formato ISO (YYYY-MM-DD).
- Si un campo no es visible, usa null.
Devuelve SOLO el JSON, sin markdown.
"""}
            ]
        }]
    )

    import json
    raw_json = resp.content[0].text
    return Factura.model_validate_json(raw_json)
```

### Multi-modal RAG (texto + imágenes con CLIP)

Para buscar en una base que mezcla texto e imágenes se usan embeddings en el mismo espacio. CLIP de OpenAI (o SigLIP de Google) genera vectores comparables entre texto e imagen.

```python
import torch
from PIL import Image
from transformers import CLIPProcessor, CLIPModel
from qdrant_client import QdrantClient
from qdrant_client.models import PointStruct, VectorParams, Distance

model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32")
processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")

def embed_image(path: str) -> list[float]:
    image = Image.open(path).convert("RGB")
    inputs = processor(images=image, return_tensors="pt")
    with torch.no_grad():
        features = model.get_image_features(**inputs)
    return features[0].numpy().tolist()

def embed_text(text: str) -> list[float]:
    inputs = processor(text=[text], return_tensors="pt", padding=True)
    with torch.no_grad():
        features = model.get_text_features(**inputs)
    return features[0].numpy().tolist()

qdrant = QdrantClient(":memory:")
qdrant.create_collection(
    "productos",
    vectors_config=VectorParams(size=512, distance=Distance.COSINE),
)

# Indexar imágenes de productos
for i, img in enumerate(["silla.jpg", "mesa.jpg", "lampara.jpg"]):
    qdrant.upsert("productos", [PointStruct(
        id=i, vector=embed_image(img),
        payload={"path": img},
    )])

# Buscar con texto natural
query_vec = embed_text("una silla de madera estilo escandinavo")
hits = qdrant.search("productos", query_vector=query_vec, limit=3)
for h in hits:
    print(h.payload["path"], h.score)
```

### Voice agent end-to-end (STT → LLM → TTS)

Pipeline clásico: audio del usuario → VAD detecta pausa → transcripción streaming → LLM con tools → TTS streaming → interrupt handling. Frameworks como **LiveKit Agents** y **Pipecat** (Daily) manejan esto.

```python
# Pipecat: pipeline de voice agent con interrupt handling
from pipecat.pipeline.pipeline import Pipeline
from pipecat.services.deepgram import DeepgramSTTService
from pipecat.services.openai import OpenAILLMService
from pipecat.services.elevenlabs import ElevenLabsTTSService
from pipecat.transports.network.daily import DailyTransport
from pipecat.processors.aggregators.llm_response import (
    LLMAssistantResponseAggregator, LLMUserResponseAggregator,
)

transport = DailyTransport(room_url="https://your.daily.co/room", token=TOKEN,
                           bot_name="Asistente")

stt = DeepgramSTTService(api_key=DEEPGRAM_KEY)      # ASR streaming
llm = OpenAILLMService(api_key=OPENAI_KEY, model="gpt-4o-mini")
tts = ElevenLabsTTSService(api_key=ELEVENLABS_KEY,
                           voice_id="21m00Tcm4TlvDq8ikWAM")  # Rachel

user_resp = LLMUserResponseAggregator()
asst_resp = LLMAssistantResponseAggregator()

pipeline = Pipeline([
    transport.input(),   # audio del usuario
    stt,                 # audio -> texto parcial
    user_resp,           # agrega tokens al mensaje de usuario
    llm,                 # llama GPT-4o-mini con historial
    tts,                 # texto -> audio streaming
    transport.output(),  # audio al usuario
    asst_resp,           # cierra el turno
])

# Pipecat maneja automáticamente la interrupción:
# si el usuario habla mientras el bot responde, se cancela el TTS
```

**Latencias objetivo** para voice UX natural:

| Etapa | Latencia aceptable | Herramienta típica |
|---|---|---|
| VAD (end-of-speech) | 200-400 ms | Silero VAD |
| STT (primer token) | 150-300 ms | Deepgram Nova-2, Whisper streaming |
| LLM (primer token) | 300-600 ms | GPT-4o-mini, Claude Haiku, Groq |
| TTS (primer audio) | 100-250 ms | ElevenLabs Flash, Cartesia Sonic |
| **Total end-to-end** | **<800 ms** | ideal <500 ms |

### Computer use (Claude, Operator, Mariner)

Los **agentes de uso de computadora** reciben screenshots y devuelven acciones (click en coordenadas, teclear, scroll). Comparativa 2024-2025:

| Agente | Lanzamiento | Modelo base | Entrega | Mejor caso | Limitaciones |
|---|---|---|---|---|---|
| **Anthropic Computer Use** | Oct 2024 (beta) | Claude 3.5 Sonnet / Sonnet 4 | API + SDK, corre en tu VM | Automatización en tu máquina, tareas de dev | Latente (varios segundos por acción) |
| **OpenAI Operator** | Ene 2025 | CUA (basado en GPT-4o) | Producto hosted (ChatGPT Pro) | Reservas, compras, formularios web | Cerrado, requiere aprobación en pasos sensibles |
| **Google Project Mariner** | Dic 2024 | Gemini 2.0 | Extensión Chrome | Navegación en Chrome, scraping | Preview limitado |
| **Browser Use (open source)** | 2024 | Cualquier LLM con vision | Librería Python | DIY, control total | Debes orquestar tú |

```python
# Demo computer use con Anthropic (loop simplificado)
import anthropic, subprocess, base64

client = anthropic.Anthropic()

def tomar_screenshot() -> str:
    subprocess.run(["screencapture", "/tmp/s.png"], check=True)
    with open("/tmp/s.png", "rb") as f:
        return base64.standard_b64encode(f.read()).decode()

messages = [{"role": "user", "content": "Abre el navegador y busca 'clima CDMX'"}]
while True:
    resp = client.beta.messages.create(
        model="claude-sonnet-4-5",
        max_tokens=1024,
        tools=[{
            "type": "computer_20250124",
            "name": "computer",
            "display_width_px": 1920,
            "display_height_px": 1080,
        }],
        messages=messages,
        betas=["computer-use-2025-01-24"],
    )
    if resp.stop_reason == "end_turn":
        break
    for block in resp.content:
        if block.type == "tool_use" and block.name == "computer":
            # Ejecutar acción: click, type, screenshot...
            action = block.input["action"]
            # ... implementar cada acción con pyautogui ...
            screenshot_b64 = tomar_screenshot()
            messages.append({"role": "assistant", "content": resp.content})
            messages.append({"role": "user", "content": [{
                "type": "tool_result", "tool_use_id": block.id,
                "content": [{"type": "image", "source": {
                    "type": "base64", "media_type": "image/png", "data": screenshot_b64,
                }}],
            }]})
```

### Evaluación multimodal

Evaluar sistemas multimodales es más difícil que texto puro. Dimensiones:

| Dimensión | Métrica | Herramienta |
|---|---|---|
| Extracción (Document AI) | field-level accuracy, F1 por campo | Dataset etiquetado |
| Visual QA | Exact match, LLM-as-judge | DocVQA, MMMU |
| Voice latency | TTFB, end-to-end latency, interrupt rate | LiveKit Analytics, custom logs |
| Voice quality | WER (transcripción), MOS (síntesis) | humans + whisper-eval |
| Agent success | task completion rate, pasos innecesarios | OSWorld, WebArena, VisualWebArena |
| Fairness | accuracy por género/etnia/acento | Fairlearn, holistic AI |

**LLM-as-judge multimodal**: pasa la imagen + respuesta del modelo + rúbrica a un VLM "jurado" (Claude Sonnet 4) que puntúa. Es la práctica estándar en 2025 para evaluar outputs visuales.

### Cross-modal retrieval y fusión

- **Early fusion:** concatenar embeddings y pasar al modelo (CLIP, Flamingo).
- **Late fusion:** procesar cada modalidad por separado y combinar scores.
- **Hybrid fusion:** cross-attention entre modalidades (BLIP-2, LLaVA, Qwen2-VL).

En apps prácticas: usa embeddings multimodales (CLIP, SigLIP, Nomic Embed Vision) + reranker (Cohere Rerank 3.5 multimodal, lanzado 2024).

### Agentes multimodales

Un agente multimodal combina **percepción** (ver, escuchar), **razonamiento** (LLM) y **acción** (hablar, generar imagen, ejecutar tool). Patrones comunes:

- **Assistant personal**: elige modalidad de salida según contexto (texto si lee, voz si va caminando).
- **Monitoring agent**: analiza frames de cámara y alerta en eventos relevantes.
- **Field service agent**: técnico sube foto + nota de voz → agente devuelve pasos + diagrama anotado.

## Ejemplo con código

Mini-app de **field service**: el técnico envía una foto del equipo averiado y una nota de voz. El sistema transcribe, analiza la foto, consulta el manual (RAG), genera diagnóstico y devuelve texto + audio.

```python
import asyncio, base64, anthropic
from openai import OpenAI
from pydantic import BaseModel

claude = anthropic.Anthropic()
openai = OpenAI()

class Diagnostico(BaseModel):
    sintoma: str
    causa_probable: str
    pasos_reparacion: list[str]
    nivel_riesgo: str  # bajo | medio | alto

async def transcribir(audio_path: str) -> str:
    with open(audio_path, "rb") as f:
        r = openai.audio.transcriptions.create(
            model="whisper-1", file=f, language="es"
        )
    return r.text

async def analizar_foto(img_path: str, contexto: str) -> str:
    with open(img_path, "rb") as f:
        img_b64 = base64.standard_b64encode(f.read()).decode()
    resp = claude.messages.create(
        model="claude-3-5-sonnet-20241022",
        max_tokens=800,
        messages=[{"role": "user", "content": [
            {"type": "image", "source": {
                "type": "base64", "media_type": "image/jpeg", "data": img_b64}},
            {"type": "text", "text":
                f"Un técnico reporta: '{contexto}'. "
                "Describe el componente visible, su estado y cualquier anomalía."}
        ]}])
    return resp.content[0].text

async def diagnosticar(sintoma: str, analisis_visual: str) -> Diagnostico:
    resp = claude.messages.create(
        model="claude-3-5-sonnet-20241022",
        max_tokens=1000,
        messages=[{"role": "user", "content": f"""
Síntoma reportado: {sintoma}
Observación visual: {analisis_visual}

Devuelve JSON válido para este schema:
{Diagnostico.model_json_schema()}
Solo el JSON, sin markdown.
"""}])
    return Diagnostico.model_validate_json(resp.content[0].text)

async def sintetizar_voz(texto: str, out: str = "respuesta.mp3"):
    resp = openai.audio.speech.create(
        model="tts-1", voice="nova", input=texto
    )
    resp.stream_to_file(out)
    return out

async def pipeline(audio_path: str, foto_path: str) -> dict:
    """Procesa foto y audio en paralelo, luego diagnostica."""
    # Paralelo: STT y análisis visual son independientes
    sintoma_task = asyncio.create_task(transcribir(audio_path))
    # necesitamos el síntoma para contextualizar la foto, así que esperamos
    sintoma = await sintoma_task
    analisis = await analizar_foto(foto_path, sintoma)

    # Diagnóstico y TTS pueden paralelizarse una vez tenemos el texto
    diag = await diagnosticar(sintoma, analisis)
    texto_voz = f"{diag.causa_probable}. Primer paso: {diag.pasos_reparacion[0]}"
    audio_out = await sintetizar_voz(texto_voz)

    return {
        "sintoma": sintoma,
        "diagnostico": diag.model_dump(),
        "audio_respuesta": audio_out,
    }

if __name__ == "__main__":
    r = asyncio.run(pipeline("nota_tecnico.m4a", "equipo.jpg"))
    print(r)
```

## Errores comunes

- **No controlar la latencia end-to-end en voice agents.** Si STT + LLM + TTS suma >1 s el usuario siente la pausa como "congelada". Solución: streaming en todas las etapas, modelos pequeños (Haiku, GPT-4o-mini, Groq), TTS de baja latencia (ElevenLabs Flash, Cartesia Sonic ~90 ms).
- **No manejar interrupciones.** Si el bot sigue hablando cuando el usuario interrumpe la conversación se siente robótica. Pipecat/LiveKit traen `interrupt handling` por defecto; úsalo.
- **No tener fallback cuando el modelo multimodal falla.** Si la API de visión está caída, degrada a texto ("describe el problema por favor") en vez de devolver 500.
- **Costos sin control.** Una sola imagen a Claude Sonnet 4 con detalle alto son ~1500 tokens de input. Multiplicado por 10k requests/día = cuentas de 4 cifras. Mitigación: resize a 1024px máximo, caché por hash de imagen, usar modelos pequeños para pre-filtro.
- **No hacer privacy review de imágenes y audio.** Las fotos pueden tener rostros, placas, direcciones, documentos. El audio puede capturar conversaciones de terceros. Antes de producir: PII redaction (Presidio para texto, FaceAlign/blur para rostros), consentimiento explícito, retención corta.
- **Mezclar embeddings de distintos modelos.** Si indexas con CLIP y consultas con SigLIP los resultados son basura. Fija el modelo de embedding y versiónalo.
- **Confiar en el VLM para OCR exacto.** Para texto denso (facturas con muchas columnas) combina OCR tradicional (AWS Textract, Tesseract, Mistral OCR) + VLM para interpretación semántica.
- **Ignorar accesibilidad.** Si tu app genera imágenes, genera también alt-text con el mismo LLM. Es un diferenciador real y a veces un requisito legal (EAA en UE desde junio 2025).
- **Sobre-usar tools en el agente.** Más de 10-15 tools degradan el rendimiento del LLM. Agrupa tools relacionados o usa routing por capacidad.
- **No instrumentar.** Sin trazas por modalidad no sabes dónde falla. Instrumenta con OpenTelemetry + Langfuse o Arize Phoenix (ambos soportan multimodal en 2025).

## Resumen

- Una app multimodal **compone** varios modelos (VLM, STT, TTS, generación de imagen, agente) y los coordina con una capa de orquestación.
- Patrones productivos en 2025: **Document AI** con VLM + Pydantic, **multi-modal RAG** con CLIP, **voice agents** end-to-end con LiveKit/Pipecat, **computer use** con Claude/Operator/Mariner.
- Para voice UX natural el presupuesto total es **<800 ms**; cada etapa (VAD, STT, LLM, TTS) debe ser streaming.
- La **arquitectura por capas** (ingesta → preprocesamiento → orquestación → entrega) permite escalar y degradar con gracia.
- El agente multimodal añade **tool use** y **percepción activa** (ver cámara, escuchar micrófono, actuar).
- Evaluación multimodal combina métricas clásicas (WER, F1 por campo), latencia y **LLM-as-judge** sobre outputs visuales.
- Los errores más caros no son del modelo sino de ingeniería: **latencia descontrolada**, **costo descontrolado**, **sin fallback**, **sin privacy review**.
- Lo que viene: agentes autónomos de nivel OSWorld, modelos vision-language-action para robótica, y voice agents indistinguibles de humanos para soporte de alta frecuencia.
