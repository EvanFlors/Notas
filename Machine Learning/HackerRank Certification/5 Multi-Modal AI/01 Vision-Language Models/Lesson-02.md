# VLMs Generativos Modernos: GPT-4V, Claude 3.x, Gemini, LLaVA

## ¿Qué es?

Un **VLM generativo** es un modelo que, dado un prompt que mezcla imágenes y texto, **genera texto** como respuesta. Internamente, las imágenes se convierten en **image tokens** que el LLM consume igual que tokens de texto, lo que permite usar la misma API de chat completions con un contenido multimodal.

![Estructura de un request de chat con contenido mixto texto + imagen](https://hrcdn.net/ai-engineering/module-5/light/vision-language-lesson02-vision-api-request-structure.svg)

Los VLMs generativos de uso masivo en producción (octubre de 2026) son:

| Modelo | Proveedor | Lanzamiento | Fortalezas |
|---|---|---|---|
| **GPT-4V / GPT-4o** | OpenAI | Sept 2023 / May 2024 | OCR fuerte, baja latencia, ecosistema maduro |
| **Claude 3.5 Sonnet** | Anthropic | Jun 2024 | OCR denso, razonamiento visual, structured output |
| **Claude 3 Opus / Haiku** | Anthropic | Mar 2024 | Opus = máxima calidad, Haiku = más barato |
| **Gemini 1.5 Pro / Flash** | Google | 2024 | Contexto 1M–2M tokens, video, multidocumento |
| **LLaVA 1.6 / NeXT** | Open source (UW + Microsoft) | 2024 | Self-hosting, fine-tunable con LoRA |
| **Qwen2-VL** | Alibaba | 2024 | Open weights, excelente OCR multilingüe |

## ¿Por qué importa?

Hace tres años, "entender una imagen" requería ensamblar varios modelos. Hoy un VLM comercial resuelve:

- **VQA** (Visual Question Answering) sin fine-tuning.
- **OCR implícito** con razonamiento (ej. "cuál es el total de esta factura y cuánto IVA incluye").
- **Structured extraction** devolviendo JSON válido con `response_format` o Pydantic.
- **UI understanding** para automatización de testing y agentes browser.
- **Document AI** para PDFs mixtos de texto, tablas y gráficos.

Elegir el modelo correcto es una decisión **arquitectónica**: cambia tu factura, tu latencia p95 y tu capacidad de razonamiento. Un error típico es "siempre usar GPT-4o"; muchas veces Haiku o Flash cuestan 10x menos para el mismo caso.

## ¿Cómo funciona?

### Image tokens: tokenización por proveedor

Cada proveedor convierte la imagen en tokens de forma distinta. Entender el detalle es clave para proyectar costos:

#### OpenAI (GPT-4V, GPT-4o, gpt-4.1-mini) — estrategia de tiles

OpenAI usa dos modos:

- **`detail: "low"`:** la imagen se reescala a 512x512 y cuenta como **~85 tokens fijos**. Ideal para comprensión general ("¿aparece un perro?").
- **`detail: "high"`:** se recorta en **tiles de 512x512 pixels** después de un reescalado inicial. Cada tile cuesta ~170 tokens, más 85 tokens base.

Fórmula aproximada:

```
tiles = ceil(ancho/512) * ceil(alto/512)
tokens_openai = 85 + 170 * tiles
```

Ejemplo: una imagen 1024x1024 en `high` = 4 tiles → `85 + 170*4 = 765 tokens`.

#### Anthropic (Claude 3.x) — tokens por área

Claude estima tokens linealmente al área:

```
tokens_claude ≈ (ancho * alto) / 750
```

Ejemplos:
- 500x500 → 333 tokens.
- 1092x1092 → 1590 tokens (~1.6k, el máximo recomendado por Anthropic).
- 1568x1568 → tope duro aproximado.

Claude recomienda imágenes **≤ 1.15 megapíxeles** para evitar reescalado automático.

#### Google (Gemini 1.5 Pro / Flash) — multimodal nativo

Gemini trata las imágenes de forma nativa en el Transformer; no se expone un parámetro `detail`:

- Imágenes ≤ 384x384 cuestan **258 tokens fijos**.
- Imágenes mayores se dividen en tiles de 768x768 y cuestan 258 tokens por tile.

#### LLaVA 1.6 (NeXT) — "AnyRes" patch dinámico

LLaVA 1.6 usa **AnyRes**: según la relación de aspecto, selecciona una grid (1x1, 1x2, 2x2, 2x3, etc.) de tiles de 336x336. Puede llegar a 2880 image tokens para resoluciones altas.

### Cross-attention vs. prefijo

Hay dos formas típicas de fusionar imagen y texto dentro del LLM:

- **Prefijo (LLaVA, GPT-4V):** los image tokens se concatenan al inicio del input del LLM; la atención es la misma self-attention estándar.
- **Cross-attention (Flamingo, Claude multimodal interno):** capas intercaladas en el LLM leen los image tokens vía atención cruzada manteniendo el LLM congelado.

El prefijo es más simple y domina la práctica moderna; cross-attention conserva mejor las capacidades del LLM base.

### Resolution handling y aspect ratio

La mayoría de proveedores recomiendan:

- **Lado largo ≤ 1024 px** si solo necesitas comprensión general.
- **Lado largo ≤ 2048 px** si necesitas OCR fino (recibos, documentos con texto chico).
- Preservar **aspect ratio** (nunca estirar la imagen).
- Convertir **PNG → JPEG** con calidad 85 si no hay transparencia (reduce payload 5–10x sin pérdida visible).

### Latencia aproximada (p50, imagen 1024x1024)

| Modelo | Latencia aprox. | Notas |
|---|---|---|
| gpt-4.1-mini | 1–3 s | Rápido y barato |
| GPT-4o | 2–5 s | Equilibrio calidad/latencia |
| Claude 3.5 Sonnet | 3–7 s | Mejor OCR, algo más lento |
| Claude 3 Haiku | 1–3 s | Opción económica |
| Gemini 1.5 Flash | 1–2 s | El más rápido entre comerciales |
| Gemini 1.5 Pro | 4–8 s | Context masivo pero más lento |
| LLaVA 1.6 (local, A100) | 0.5–2 s | Depende de hardware |

### Tabla comparativa

| Modelo | Max resolución recomendada | Pricing input (USD/1M tok)* | OCR implícito | Bounding boxes | Notas |
|---|---|---|---|---|---|
| GPT-4o | 2048x2048 | ~$2.50 | Muy bueno | Aproximados | ~ $0.00765 por imagen 1024x1024 en `high` |
| gpt-4.1-mini | 2048x2048 | ~$0.40 | Bueno | Aproximados | Opción económica OpenAI |
| Claude 3.5 Sonnet | 1568x1568 | $3.00 | Excelente (denso) | Coords aproximadas | Fuerte en documentos |
| Claude 3 Haiku | 1568x1568 | $0.25 | Bueno | Aproximados | Más barato en Anthropic |
| Gemini 1.5 Pro | 3072x3072 | $1.25 | Muy bueno | Sí (formato normalizado) | Context 1M–2M |
| Gemini 1.5 Flash | 3072x3072 | $0.075 | Bueno | Sí | El más barato para batch |
| LLaVA 1.6 (self-host) | 672x672 por tile | GPU propia | Medio | No nativo | Fine-tune con LoRA |
| Qwen2-VL 72B | 1280x1280 | GPU propia | Excelente multilingüe | Sí | Open weights |

*Precios aproximados vigentes a 2025; verifica siempre la página oficial del proveedor.

## Ejemplo con código

### 1) Claude 3.5 Sonnet con imagen base64

```python
# pip install anthropic pillow
import anthropic, base64, pathlib

client = anthropic.Anthropic()

def cargar_imagen(path: str) -> dict:
    ext = pathlib.Path(path).suffix.lower().lstrip(".")
    media_type = {"jpg": "image/jpeg", "jpeg": "image/jpeg",
                  "png": "image/png", "webp": "image/webp"}[ext]
    data = base64.standard_b64encode(pathlib.Path(path).read_bytes()).decode()
    return {"type": "image",
            "source": {"type": "base64", "media_type": media_type, "data": data}}

msg = client.messages.create(
    model="claude-3-5-sonnet-20240620",
    max_tokens=1024,
    system="Eres un analista visual preciso. Responde en español neutro.",
    messages=[{
        "role": "user",
        "content": [
            cargar_imagen("captura_error.png"),
            {"type": "text",
             "text": "Describe el error mostrado y propón 3 pasos de troubleshooting."},
        ],
    }],
)
print(msg.content[0].text)
print("Tokens:", msg.usage.input_tokens, "→", msg.usage.output_tokens)
```

### 2) OpenAI GPT-4o con URL pública

```python
# pip install openai
from openai import OpenAI

client = OpenAI()

resp = client.chat.completions.create(
    model="gpt-4o",
    messages=[{
        "role": "user",
        "content": [
            {"type": "text", "text": "¿Qué objetos aparecen en esta foto?"},
            {"type": "image_url",
             "image_url": {
                 "url": "https://example.com/foto.jpg",
                 "detail": "high",  # "low" | "high" | "auto"
             }},
        ],
    }],
    max_tokens=400,
)
print(resp.choices[0].message.content)
```

### 3) Múltiples imágenes en un solo request (comparación)

```python
import base64, pathlib
from openai import OpenAI
client = OpenAI()

def b64(path):
    return base64.b64encode(pathlib.Path(path).read_bytes()).decode()

resp = client.chat.completions.create(
    model="gpt-4o",
    messages=[{
        "role": "user",
        "content": [
            {"type": "text",
             "text": "Compara estas dos capturas de la misma pantalla y lista las diferencias visuales."},
            {"type": "image_url",
             "image_url": {"url": f"data:image/png;base64,{b64('v1.png')}", "detail": "high"}},
            {"type": "image_url",
             "image_url": {"url": f"data:image/png;base64,{b64('v2.png')}", "detail": "high"}},
        ],
    }],
    max_tokens=600,
)
print(resp.choices[0].message.content)
```

### 4) Conversación multi-turno con una imagen (Claude)

```python
# La imagen se envía una sola vez; los turnos siguientes la referencian por contexto.
import anthropic, base64, pathlib
client = anthropic.Anthropic()

data = base64.b64encode(pathlib.Path("plano_casa.jpg").read_bytes()).decode()
img_block = {"type": "image",
             "source": {"type": "base64", "media_type": "image/jpeg", "data": data}}

historia = [
    {"role": "user", "content": [img_block,
     {"type": "text", "text": "¿Cuántas habitaciones tiene este plano?"}]},
]
resp1 = client.messages.create(model="claude-3-5-sonnet-20240620",
                               max_tokens=400, messages=historia)
r1 = resp1.content[0].text
historia.append({"role": "assistant", "content": r1})
print("A1:", r1)

historia.append({"role": "user",
                 "content": "¿Cuál habitación es la más grande y qué área estimas en m²?"})
resp2 = client.messages.create(model="claude-3-5-sonnet-20240620",
                               max_tokens=400, messages=historia)
r2 = resp2.content[0].text
historia.append({"role": "assistant", "content": r2})
print("A2:", r2)

historia.append({"role": "user",
                 "content": "¿Dónde ubicarías un escritorio para teletrabajo?"})
resp3 = client.messages.create(model="claude-3-5-sonnet-20240620",
                               max_tokens=400, messages=historia)
print("A3:", resp3.content[0].text)
```

### 5) Few-shot con imágenes (clasificación visual)

```python
# Enseñar al modelo con 2 ejemplos antes de la imagen real.
def ejemplo(path, respuesta):
    data = base64.b64encode(pathlib.Path(path).read_bytes()).decode()
    return [
        {"role": "user", "content": [
            {"type": "image", "source": {"type": "base64",
             "media_type": "image/jpeg", "data": data}},
            {"type": "text", "text": "Clasifica: 'aprobada' o 'rechazada: <razón>'"},
        ]},
        {"role": "assistant", "content": respuesta},
    ]

mensajes = []
mensajes += ejemplo("ok1.jpg", "aprobada")
mensajes += ejemplo("bad1.jpg", "rechazada: fondo con desorden")

data_nueva = base64.b64encode(pathlib.Path("nueva.jpg").read_bytes()).decode()
mensajes.append({"role": "user", "content": [
    {"type": "image", "source": {"type": "base64",
     "media_type": "image/jpeg", "data": data_nueva}},
    {"type": "text", "text": "Clasifica: 'aprobada' o 'rechazada: <razón>'"},
]})

resp = client.messages.create(model="claude-3-5-sonnet-20240620",
                              max_tokens=100, messages=mensajes)
print(resp.content[0].text)
```

### 6) Gemini 1.5 Pro con una o varias imágenes

```python
# pip install google-generativeai
import google.generativeai as genai
import PIL.Image, os

genai.configure(api_key=os.environ["GOOGLE_API_KEY"])
model = genai.GenerativeModel("gemini-1.5-pro")

img = PIL.Image.open("grafica.png")
resp = model.generate_content(
    ["Describe la tendencia principal de esta gráfica y cita cifras concretas.", img]
)
print(resp.text)

# Múltiples imágenes
img1 = PIL.Image.open("antes.png")
img2 = PIL.Image.open("despues.png")
resp = model.generate_content([
    "Compara estas dos imágenes y lista cambios clave.",
    img1, img2,
])
print(resp.text)
```

### 7) Gemini 1.5 Flash con chat multi-turno

```python
model = genai.GenerativeModel("gemini-1.5-flash")
chat = model.start_chat(history=[])

img = PIL.Image.open("ui.png")
print(chat.send_message(["¿Qué elementos UI identificas?", img]).text)
print(chat.send_message("¿Alguno viola accessibility WCAG 2.1?").text)
print(chat.send_message("Sugiere 3 mejoras concretas.").text)
```

### 8) LLaVA local con transformers

```python
# pip install transformers accelerate pillow torch
from transformers import LlavaNextProcessor, LlavaNextForConditionalGeneration
import torch, PIL.Image

model_id = "llava-hf/llava-v1.6-mistral-7b-hf"
processor = LlavaNextProcessor.from_pretrained(model_id)
model = LlavaNextForConditionalGeneration.from_pretrained(
    model_id, torch_dtype=torch.float16, device_map="auto"
)

img = PIL.Image.open("factura.jpg")
prompt = "[INST] <image>\n¿Cuál es el total de esta factura? [/INST]"
inputs = processor(prompt, img, return_tensors="pt").to(model.device)

out = model.generate(**inputs, max_new_tokens=200)
print(processor.decode(out[0], skip_special_tokens=True))
```

### 9) Cost optimization: resize + estimar tokens antes de enviar

```python
from PIL import Image
import io, base64, math

def preparar_imagen(path: str, max_lado: int = 1024, calidad: int = 85) -> str:
    img = Image.open(path)
    img.thumbnail((max_lado, max_lado), Image.Resampling.LANCZOS)
    if img.mode != "RGB":
        img = img.convert("RGB")
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=calidad, optimize=True)
    return base64.b64encode(buf.getvalue()).decode()

def estimar_tokens_openai(ancho: int, alto: int, detail: str = "high") -> int:
    if detail == "low":
        return 85
    tiles = math.ceil(ancho / 512) * math.ceil(alto / 512)
    return 85 + 170 * tiles

def estimar_tokens_claude(ancho: int, alto: int) -> int:
    return int((ancho * alto) / 750)

def estimar_costo(tokens_in: int, modelo: str) -> float:
    precios = {  # USD por 1M tokens de input
        "gpt-4o": 2.50, "gpt-4.1-mini": 0.40,
        "claude-3-5-sonnet": 3.00, "claude-3-haiku": 0.25,
        "gemini-1.5-pro": 1.25, "gemini-1.5-flash": 0.075,
    }
    return tokens_in * precios[modelo] / 1_000_000

# Ejemplo: comparar detail=low vs detail=high para 100k requests/día
print("OpenAI 1024x1024 low: ", estimar_tokens_openai(1024, 1024, "low"), "tokens")
print("OpenAI 1024x1024 high:", estimar_tokens_openai(1024, 1024, "high"), "tokens")
print("Claude 1024x1024:     ", estimar_tokens_claude(1024, 1024), "tokens")

costo_dia = estimar_costo(estimar_tokens_openai(1024, 1024, "high"), "gpt-4o") * 100_000
print(f"GPT-4o high 100k req/día: ${costo_dia:.2f}/día")
```

### 10) Elegir detail dinámicamente según el caso de uso

```python
def elegir_detail(tipo_tarea: str) -> str:
    """Low para visión general; high para OCR, texto pequeño, bounding boxes."""
    tareas_que_requieren_detalle = {
        "ocr", "extraccion_structured", "lectura_recibo",
        "lectura_factura", "lectura_id", "deteccion_texto_pequeño"
    }
    return "high" if tipo_tarea in tareas_que_requieren_detalle else "low"

detail = elegir_detail("ocr")
```

## Errores comunes

- **Imagen demasiado grande = cost explosion.** Una foto de 12 MP enviada en modo `high` puede costar 2000+ tokens por request. Redimensiona siempre a `max_lado=1024` salvo que necesites OCR fino.
- **Usar modo `low` cuando necesitas detalle.** Si tu caso es leer un número de serie, `detail="low"` perderá los caracteres. Usa `high` solo donde haga falta.
- **No considerar aspect ratio.** Si el proveedor hace padding o crop automático en imágenes extremas (ej. 4000x200), el detalle útil se pierde. Recorta tú primero.
- **Mezclar modelos sin medir costo real.** GPT-4o es 10x más caro que gpt-4.1-mini para muchas tareas donde el mini basta. Mide con un dataset golden antes de elegir.
- **Suponer que todos los modelos aceptan el mismo payload.** OpenAI usa `image_url`, Anthropic usa `source.type=base64`, Gemini acepta objetos `PIL.Image` directamente. Adapta por SDK.
- **Olvidar el `media_type` correcto en base64.** Enviar un PNG con `image/jpeg` falla silenciosamente o devuelve errores crípticos.
- **Hardcodear el modelo exacto** (`claude-3-5-sonnet-20240620`). Cuando el proveedor libera una versión nueva, tu código no la toma. Usa alias o variables de entorno.
- **No calcular tokens antes de desplegar a producción.** Haz una estimación con tu volumen real; una app con 100k requests/día de 1024x1024 en `high` puede ser miles de dólares al mes.
- **No cachear.** Si procesas la misma imagen con prompts similares, un cache por `hash(imagen) + hash(prompt)` ahorra el 50–80% de llamadas.
- **Reenviar la imagen en cada turno.** En conversaciones multi-turno, envía la imagen solo una vez (el proveedor la mantiene en contexto); reenviarla duplica el costo por turno.

## Resumen

- Los VLMs generativos modernos convierten imágenes en **image tokens** y los procesan en el mismo Transformer que los tokens de texto.
- **GPT-4o, Claude 3.5 Sonnet, Gemini 1.5 Pro** son los líderes comerciales en 2026; **LLaVA 1.6 y Qwen2-VL** son los líderes open source.
- Cada proveedor tokeniza distinto: OpenAI con tiles 512x512, Claude con `area/750`, Gemini con tiles 768x768, LLaVA con AnyRes.
- La forma de pasar la imagen cambia por SDK: `image_url` en OpenAI, `source.base64` en Anthropic, objetos PIL en Gemini.
- **Redimensionar a 1024px** antes de enviar es la optimización de costo más efectiva.
- Modos `detail=low` o `high` controlan cuántos tiles se generan; úsalos deliberadamente.
- **Few-shot con imágenes** mejora consistencia en tareas subjetivas (calidad, sentimiento, aprobación).
- En **conversaciones multi-turno**, envía la imagen una sola vez; los turnos siguientes la ven por contexto.
- Cross-attention (Flamingo) vs. prefijo (LLaVA, GPT-4V): el prefijo domina la práctica moderna.
- Mide siempre **costo real y calidad** con un dataset golden antes de elegir modelo.
- **Latencia**: Gemini Flash y Haiku son los más rápidos; Claude Sonnet y Gemini Pro los más lentos pero mejores en razonamiento.
