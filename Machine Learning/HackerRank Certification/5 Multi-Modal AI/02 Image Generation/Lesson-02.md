# Uso de la API de Generación de Imágenes de OpenAI

## ¿Qué es?

La **API de imágenes de OpenAI** (`client.images`) expone tres modelos de generación bajo una interfaz común: **DALL-E 2**, **DALL-E 3** y **GPT-Image-1** (y su versión económica `gpt-image-1-mini`). A través de un único endpoint `generate` recibes el prompt, decides tamaño, calidad, cantidad y formato de respuesta, y la API devuelve la imagen lista para servir o almacenar.

Esta API cubre tres operaciones principales:

| Operación | Endpoint | Qué hace |
|---|---|---|
| `generate` | `client.images.generate(...)` | Text-to-image puro |
| `edit` | `client.images.edit(...)` | Inpainting con máscara + prompt |
| `create_variation` | `client.images.create_variation(...)` | Variantes de una imagen existente (solo DALL-E 2) |

### Comparación de modelos OpenAI

| Feature | DALL-E 2 | DALL-E 3 | GPT-Image-1 |
|---|---|---|---|
| **Tamaños** | 256², 512², 1024² | 1024², 1792×1024, 1024×1792 | 1024², 1536×1024, 1024×1536, `auto` |
| **Calidad** | única | `standard` / `hd` | `low` / `medium` / `high` / `auto` |
| **n máx.** | 10 | 1 | múltiple |
| **Variations** | sí | no | no |
| **Edit (inpaint)** | sí | no | sí |
| **Response format** | `url` o `b64_json` | `url` o `b64_json` | solo `b64_json` |
| **Prompt revision** | no | sí (`revised_prompt`) | sí |
| **Precio aprox.** | $0.016-0.02 | $0.04-0.12 | $0.011-0.19 |

> **Clave:** `response_format` **solo existe en DALL-E**. GPT-Image siempre devuelve base64 y debes decodificarlo tú.

## ¿Por qué importa?

Integrar correctamente la API es la diferencia entre un prototipo que funciona en Jupyter y un producto que:

- No pierde imágenes porque descargó la URL antes de que expire (~1 hora).
- No gasta USD 10,000 al mes por no cachear prompts repetidos.
- No bloquea el hilo principal esperando 15 segundos de generación.
- Reintenta inteligentemente ante rate limits en lugar de fallar al usuario.
- Elige el modelo correcto por caso de uso (DALL-E 3 para marketing, GPT-Image low para thumbnails, DALL-E 2 para variations baratas).

Un diseño ingenuo falla en producción por: expiración de URLs, falta de retries, base64 no decodificado, mezclar parámetros incompatibles entre modelos.

## ¿Cómo funciona?

### Flujo request-response

```
Prompt (str) ──► OpenAI API ──► {data: [{url o b64_json, revised_prompt?}], created: ts}
                     │
                     ├─► Cola interna
                     ├─► Modelo de difusión
                     ├─► Moderación de contenido (safety filter)
                     └─► Hosting temporal (si url) o encoding (si b64)
```

### Parámetros disponibles

| Parámetro | Tipo | Modelos | Descripción |
|---|---|---|---|
| `model` | str | todos | `"dall-e-2"`, `"dall-e-3"`, `"gpt-image-1"`, `"gpt-image-1-mini"` |
| `prompt` | str | todos | Máx. 1000 chars (DALL-E 2), 4000 (DALL-E 3), 32000 (GPT-Image) |
| `size` | str | todos | ver tabla arriba |
| `n` | int | DALL-E 2, GPT-Image | número de imágenes |
| `quality` | str | DALL-E 3, GPT-Image | granularidad del render |
| `style` | str | DALL-E 3 | `"natural"` o `"vivid"` |
| `response_format` | str | solo DALL-E | `"url"` o `"b64_json"` |
| `user` | str | todos | ID de usuario final (para abuse monitoring) |

### Elegir modelo por caso de uso

```
¿Necesitas múltiples imágenes baratas (n>1)?            → DALL-E 2
¿Necesitas text-to-image de alta calidad?                → DALL-E 3
¿Necesitas inpainting con máscara?                       → GPT-Image-1
¿Necesitas variations de una imagen?                     → DALL-E 2
¿Necesitas lo máximo en fotorrealismo y texto legible?   → GPT-Image-1 high
¿Thumbnails en volumen a bajo costo?                     → GPT-Image-1 low
```

## Ejemplo con código

### 1. Setup y request básico

```python
from openai import OpenAI
import os

client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

response = client.images.generate(
    model="dall-e-3",
    prompt="a futuristic cityscape at sunset with flying cars, cinematic, 8k",
    size="1792x1024",
    quality="hd",
    style="vivid",
    n=1,
    response_format="url",
)

print("URL:", response.data[0].url)
print("Revised prompt:", response.data[0].revised_prompt)
```

### 2. Descargar inmediatamente (las URLs expiran)

```python
import requests
from pathlib import Path

def save_from_url(url: str, path: str) -> str:
    r = requests.get(url, timeout=30)
    r.raise_for_status()
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_bytes(r.content)
    return path

save_from_url(response.data[0].url, "output/city.png")
```

### 3. GPT-Image-1 devuelve base64

```python
import base64
from pathlib import Path

def save_from_b64(b64: str, path: str) -> str:
    data = base64.b64decode(b64)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_bytes(data)
    return path

resp = client.images.generate(
    model="gpt-image-1",
    prompt="a cozy minimalist bedroom, morning light, 35mm",
    size="1024x1024",
    quality="high",
    # ⚠️ NO pasar response_format aquí: GPT-Image lo rechaza
)
save_from_b64(resp.data[0].b64_json, "output/bedroom.png")
```

### 4. Prompt engineering estructurado

Un buen prompt sigue la fórmula **sujeto + estilo + composición + iluminación + calidad**:

```python
def build_prompt(subject: str, *, style: str, composition: str,
                 lighting: str, quality: str = "high detail, 8k") -> str:
    return f"{subject}, {style}, {composition}, {lighting}, {quality}"

prompt = build_prompt(
    subject="a golden retriever puppy playing fetch",
    style="photorealistic, 85mm lens, shallow depth of field",
    composition="centered, rule of thirds, close-up",
    lighting="golden hour, warm backlight",
    quality="high detail, professional photography, 8k",
)
```

Comparación lado a lado:

```
Pobre:     "a dog"
Medio:     "a golden retriever puppy playing in a sunny park"
Excelente: "a photorealistic golden retriever puppy playing fetch in a sunny park
            during golden hour, 85mm lens, shallow depth of field, vibrant green
            grass, blue sky with soft clouds, joyful mood, 8k, professional"
```

### 5. Reintentos con backoff exponencial

```python
import time, logging
from openai import OpenAI, APIError, RateLimitError, BadRequestError

logger = logging.getLogger(__name__)

def generate_with_retry(prompt: str, *, model="dall-e-3",
                        size="1024x1024", max_retries=4) -> dict:
    params = {"model": model, "prompt": prompt, "size": size, "n": 1}
    if model.startswith("dall-e"):
        params["response_format"] = "url"
    if model == "dall-e-3":
        params["quality"] = "standard"

    for attempt in range(max_retries):
        try:
            r = client.images.generate(**params)
            if model.startswith("dall-e"):
                return {"ok": True, "url": r.data[0].url,
                        "revised": r.data[0].revised_prompt}
            return {"ok": True, "b64": r.data[0].b64_json}

        except BadRequestError as e:
            # 400 = content policy / prompt inválido → no reintentar
            return {"ok": False, "error": f"bad_request: {e}"}

        except RateLimitError:
            wait = 2 ** attempt
            logger.warning(f"Rate limit, esperando {wait}s")
            time.sleep(wait)

        except APIError as e:
            if e.status_code in (401, 403):
                return {"ok": False, "error": f"auth: {e}"}
            time.sleep(2 ** attempt)

    return {"ok": False, "error": "max retries exceeded"}
```

### 6. Edición con máscara (inpainting)

La máscara debe ser un PNG **del mismo tamaño** que la imagen, con **píxeles transparentes** marcando la región a editar.

```python
with open("sneaker_white_bg.png", "rb") as img, \
     open("sneaker_mask.png", "rb") as mask:
    r = client.images.edit(
        model="gpt-image-1",
        image=img,
        mask=mask,
        prompt="replace the background with a sunny beach, soft golden light",
        size="1024x1024",
        n=1,
    )
save_from_b64(r.data[0].b64_json, "output/sneaker_beach.png")
```

### 7. Variaciones (solo DALL-E 2)

```python
with open("product.png", "rb") as img:
    r = client.images.create_variation(
        model="dall-e-2",
        image=img,
        n=4,
        size="1024x1024",
        response_format="url",
    )
urls = [d.url for d in r.data]
```

### 8. Async para alto throughput

```python
import asyncio
from openai import AsyncOpenAI

aclient = AsyncOpenAI()
sem = asyncio.Semaphore(10)   # máx. 10 requests paralelos

async def gen_one(prompt: str) -> str:
    async with sem:
        r = await aclient.images.generate(
            model="dall-e-3", prompt=prompt,
            size="1024x1024", n=1, response_format="url",
        )
        return r.data[0].url

async def gen_many(prompts: list[str]) -> list[str]:
    return await asyncio.gather(*(gen_one(p) for p in prompts))

urls = asyncio.run(gen_many([
    "a red apple on wooden table",
    "a blue vase with sunflowers",
    "a vintage camera on marble",
]))
```

### 9. Cache por hash del prompt

```python
import hashlib, json

class PromptCache:
    def __init__(self, backend: dict | None = None):
        self.backend = backend if backend is not None else {}

    def _key(self, prompt: str, size: str, quality: str, model: str) -> str:
        payload = json.dumps({"p": prompt, "s": size, "q": quality, "m": model},
                             sort_keys=True)
        return hashlib.sha256(payload.encode()).hexdigest()

    def get(self, prompt, size, quality, model):
        return self.backend.get(self._key(prompt, size, quality, model))

    def set(self, prompt, size, quality, model, value):
        self.backend[self._key(prompt, size, quality, model)] = value

cache = PromptCache()
key_args = ("a red fox in snow", "1024x1024", "standard", "dall-e-3")
if (hit := cache.get(*key_args)) is None:
    hit = generate_with_retry(key_args[0])
    cache.set(*key_args, hit)
```

### 10. Prompt templates reutilizables

```python
class PromptTemplate:
    PRODUCT_STUDIO = (
        "{subject}, studio product photography, "
        "clean white background, soft diffused lighting, "
        "centered composition, high detail, commercial quality"
    )
    SOCIAL_HERO = (
        "{subject}, modern graphic design, {palette} palette, "
        "bold typography-free composition, {platform} optimized, "
        "eye-catching, 4k"
    )

    @classmethod
    def render(cls, name: str, **kwargs) -> str:
        return getattr(cls, name).format(**kwargs)

prompt = PromptTemplate.render(
    "PRODUCT_STUDIO",
    subject="wireless over-ear headphones in matte black",
)
```

## Errores comunes

- **Pasar `response_format` a GPT-Image** → `BadRequestError`. Solo DALL-E lo acepta.
- **Esperar `n > 1` en DALL-E 3** → error. DALL-E 3 solo genera 1 imagen por request.
- **No descargar la URL en 1 hora** → URL expira, imagen perdida. Descarga inmediatamente a S3/CDN.
- **No decodificar base64** → guardar el string como `.png` produce basura. Siempre `base64.b64decode(...)`.
- **Ignorar `revised_prompt`** → DALL-E 3 reescribe tu prompt silenciosamente. Loggéalo para debuggear discrepancias.
- **Prompts > 4000 chars en DALL-E 3** → truncados sin aviso.
- **No manejar rate limits (429)** → fallos cascada en producción. Implementa backoff exponencial.
- **Usar `edit` sin máscara PNG transparente** → la API rechaza o edita toda la imagen.
- **Enviar máscara de distinto tamaño que la imagen** → error. Deben ser idénticas en dimensiones.
- **No validar el prompt contra content policy** → tasas de rechazo altas. Pre-filtra términos obviamente problemáticos.
- **Pedir calidad `hd` cuando basta `standard`** → gasto 2× sin beneficio visible en thumbnails.
- **No limitar concurrencia** (sin `asyncio.Semaphore`) → saturar rate limits y acelerar el bloqueo.
- **Generar personas reales específicas** → DALL-E rechaza y GPT-Image puede marcar la cuenta.
- **No pasar `user=user_id`** → OpenAI no puede correlacionar abuso al usuario final de tu app.
- **Hardcodear la API key en el código** → leak en Git. Usa variables de entorno o secret managers.

## Resumen

- La API de OpenAI unifica tres modelos (DALL-E 2, DALL-E 3, GPT-Image-1) bajo `client.images.generate / .edit / .create_variation`.
- **DALL-E devuelve URL o base64; GPT-Image solo base64**. No pases `response_format` a GPT-Image.
- Las **URLs expiran en ~1 hora**: descarga y persiste inmediatamente a S3/CDN.
- Parámetros clave: `model`, `prompt`, `size`, `n`, `quality`, `style`, `response_format`.
- Un buen prompt sigue: **sujeto + estilo + composición + iluminación + calidad**.
- DALL-E 3 reescribe tu prompt (`revised_prompt`); úsalo para iterar.
- **Reintentos con backoff exponencial** son obligatorios para RateLimitError (429) y 5xx; NO reintentes 400/401/403.
- Para alto throughput: `AsyncOpenAI` + `asyncio.Semaphore(N)` + cola de tareas.
- **Cachea por hash** de (prompt, size, quality, model) para evitar gastos duplicados.
- Para inpainting: máscara PNG del mismo tamaño con píxeles transparentes marcando la región editable.
- `create_variation` solo existe en DALL-E 2.
- Elige modelo por caso: DALL-E 2 (variations baratas, n grande), DALL-E 3 (text-to-image calidad), GPT-Image (SOTA + inpaint).
- Pre-valida prompts contra content policy y maneja `BadRequestError` sin reintentar.
- Pasa `user=user_id` para que OpenAI pueda rastrear abuso al usuario final.
