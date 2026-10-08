# Introducción a la Generación de Imágenes

## ¿Qué es?

La **generación de imágenes** es la rama de la IA generativa que crea imágenes nuevas, pixel a pixel, a partir de una descripción textual (text-to-image) o de otra imagen de referencia (img2img). A diferencia de la visión por computadora clásica, que *interpreta* imágenes existentes, estos modelos **sintetizan contenido visual original** que nunca existió.

Formalmente, un modelo de generación aprende a muestrear de una distribución condicional:

```
p(imagen | prompt) ≈ p_θ(x | c)
```

donde `x ∈ ℝ^(H×W×3)` es la imagen generada, `c` es la condición (texto codificado por un modelo tipo CLIP o T5) y `θ` son los parámetros aprendidos sobre miles de millones de pares (imagen, caption).

### Capacidades principales

| Capacidad | Descripción | Ejemplo |
|---|---|---|
| **Text-to-image** | Imagen desde texto puro | "un dragón sobre Tokio al atardecer" |
| **Image-to-image (img2img)** | Transformar una imagen existente | foto → pintura al óleo |
| **Inpainting** | Rellenar una región enmascarada | borrar persona del fondo |
| **Outpainting** | Extender la imagen más allá de sus bordes | continuar un paisaje |
| **ControlNet** | Guiar generación con pose, bordes, profundidad | mantener la pose de un modelo |
| **Style transfer** | Aplicar un estilo visual específico | foto en estilo Van Gogh |
| **Variations** | Generar variantes de una imagen base | catálogo de producto |

### De GANs a Diffusion: breve historia

| Año | Hito | Modelo representativo |
|---|---|---|
| 2014 | GANs introducidas por Goodfellow | GAN original |
| 2017-2019 | Era StyleGAN: rostros realistas | StyleGAN, BigGAN |
| 2020 | DDPM: Denoising Diffusion Probabilistic Models (Ho et al.) | DDPM |
| 2021 | CLIP conecta texto e imagen (OpenAI) | DALL-E 1, GLIDE |
| 2022 | Revolución open-source | **Stable Diffusion 1.5**, DALL-E 2, Midjourney v3, Imagen |
| 2023 | Calidad fotográfica real | **DALL-E 3**, Midjourney v5/v6, SDXL |
| 2024 | Modelos rectified flow, mejor coherencia | **Flux.1**, SD3, Imagen 3 |
| 2025+ | Multimodal unificado, video difusión | GPT-Image-1, Sora, Veo |

## ¿Por qué importa?

Antes de 2022, cualquier gráfico profesional requería un diseñador, un fotógrafo o licenciar stock. Hoy, un solo endpoint API puede sustituir:

- **Fotografía de producto** para e-commerce (sin estudio, sin modelo humano).
- **Banners y creatividades publicitarias** personalizadas por segmento.
- **Concept art y storyboards** para cine, videojuegos y animación.
- **Ilustraciones editoriales**, miniaturas de YouTube, portadas.
- **Avatares, assets de UI, mockups** para prototipado rápido.
- **Visualización científica y educativa** de conceptos abstractos.
- **Data augmentation** para entrenar otros modelos de visión.

### El impacto económico

Un rodaje de producto cuesta USD 500-5,000. Una imagen generada cuesta USD 0.04-0.19. Esta reducción de 10,000× en costo marginal abre casos de uso imposibles antes: generar 50 variantes de un banner por usuario, A/B test continuo, personalización 1:1 a escala.

### Cuándo NO usar generación

- **Fotos de personas reales específicas** (CEO, celebridades): problema legal y ético; usa fotografía real.
- **Documentación precisa** (manuales técnicos, piezas de ingeniería): los modelos alucinan detalles.
- **Logos y marcas registradas**: no respetan reglas de diseño ni consistencia.
- **Texto dentro de la imagen** (hasta hace poco catastrófico; mejoró con DALL-E 3 y Flux, pero aún falla con párrafos).
- **Contenido donde el copyright del estilo importa** (reproducir "estilo Studio Ghibli" es territorio legal pantanoso).

## ¿Cómo funciona?

Todos los modelos modernos de generación son **modelos de difusión** (diffusion models). Entenderlos requiere tres ideas: *forward process*, *reverse process* y *guidance condicional*.

### 1. Forward process (añadir ruido)

Dada una imagen `x₀`, se le añade ruido gaussiano progresivamente durante `T` pasos (típicamente 1000):

```
q(xₜ | xₜ₋₁) = N(xₜ ; √(1 - βₜ) · xₜ₋₁ , βₜ · I)
```

donde `βₜ ∈ (0, 1)` es la *noise schedule* (lineal, cosine, etc.). Al final, `x_T` es ruido puro, indistinguible de una muestra de `N(0, I)`.

Esto es un proceso **fijo**, sin parámetros. Se puede escribir en forma cerrada:

```
xₜ = √(ᾱₜ) · x₀ + √(1 - ᾱₜ) · ε,     ε ~ N(0, I)
```

con `ᾱₜ = ∏ᵢ₌₁ᵗ (1 - βᵢ)`.

### 2. Reverse process (denoising neuronal)

Entrenamos una red neuronal `εθ(xₜ, t, c)` (típicamente una **U-Net** o un **DiT - Diffusion Transformer**) para predecir el ruido añadido en cada paso, condicionada opcionalmente a texto `c`:

```
L_simple = E_{x₀, t, ε} [ ‖ε - εθ(xₜ, t, c)‖² ]
```

Con el ruido predicho, se recupera iterativamente:

```
xₜ₋₁ = (1/√αₜ) · ( xₜ - ( βₜ / √(1-ᾱₜ) ) · εθ(xₜ, t, c) ) + σₜ · z
```

Partiendo de puro ruido `x_T`, aplicamos este paso `T` veces hasta llegar a una imagen limpia `x₀`.

### 3. Samplers: DDPM vs DDIM vs Flow Matching

| Sampler | Pasos típicos | Determinista | Nota |
|---|---|---|---|
| **DDPM** | 1000 | No (estocástico) | Original, muy lento |
| **DDIM** | 20-50 | Sí | Permite control de seed, interpolación |
| **DPM-Solver++** | 10-25 | Sí | Default moderno en SD |
| **Euler / Euler-a** | 20-30 | ambos | Popular en SD |
| **Flow Matching (Rectified Flow)** | 4-28 | Sí | Base de SD3 y Flux |

### 4. Latent Diffusion (clave de Stable Diffusion)

Difundir directamente en el espacio de pixels (1024×1024×3 = 3M dimensiones) es carísimo. **Latent Diffusion Models (LDM)** aplican la difusión en un espacio latente comprimido por un VAE:

```
Imagen (1024×1024×3)
  ↓  VAE encoder
Latente (128×128×4)       ← aquí ocurre la difusión
  ↓  denoising U-Net (condicionada por CLIP text embedding)
Latente limpio
  ↓  VAE decoder
Imagen final
```

Reducción de ~48× en cómputo. Esta es la arquitectura de **Stable Diffusion**, **SDXL**, **SD3** y la mayoría de modelos open-source.

### 5. Guidance condicional (CFG)

Para que el modelo "obedezca" el prompt se usa **Classifier-Free Guidance**:

```
ε_guided = ε_uncond + w · ( ε_cond - ε_uncond )
```

- `w = 1`: respeta libremente el prompt.
- `w = 7-12`: muy pegado al prompt (default en SD).
- `w > 15`: saturado, artefactos.

### Comparativa de modelos principales

| Modelo | Año | Open-source | Precio aprox. | Fortaleza | Debilidad |
|---|---|---|---|---|---|
| **Stable Diffusion 1.5** | 2022 | Sí (CreativeML) | Gratis local | Ecosistema enorme (LoRA, ControlNet) | Calidad base baja |
| **SDXL** | 2023 | Sí | Gratis local | Buena anatomía | Lento sin GPU buena |
| **SD3 / SD3.5** | 2024 | Parcial | Gratis + API | Texto legible | Licencia restrictiva |
| **DALL-E 3** | 2023 | No | $0.04-0.12 / img | Prompt following, texto en imagen | Caro, filtros estrictos |
| **GPT-Image-1** | 2025 | No | $0.01-0.19 / img | Multimodal, calidad top | Solo base64 |
| **Midjourney v6** | 2024 | No | $10-120/mes | Estética cinematográfica | Solo via Discord/web |
| **Flux.1 [dev]** | 2024 | Sí (no comercial) | Gratis local | Realismo top open-source | Pesado (12B params) |
| **Flux.1 [pro]** | 2024 | No (API) | $0.05 / img | SOTA open approach | API-only |
| **Imagen 3 (Google)** | 2024 | No | Vertex AI | Fotorrealismo | Acceso limitado |

### Herramientas del ecosistema

- **OpenAI SDK**: DALL-E 3, GPT-Image-1.
- **HuggingFace `diffusers`**: librería Python oficial para SD, Flux, ControlNet, LoRA.
- **Replicate**: hosting de modelos open-source vía API ($0.0023/sec en GPU A100).
- **Stability AI API**: SDXL, SD3 oficial.
- **ComfyUI**: workflow visual nodal (profesional).
- **Automatic1111 WebUI**: UI web local, pionera de la comunidad SD.
- **Fal.ai, Together AI**: hosting rápido de Flux y otros.

## Ejemplo con código

### Opción A: OpenAI DALL-E 3 (API)

```python
from openai import OpenAI
from pathlib import Path
import requests

client = OpenAI(api_key="sk-...")

response = client.images.generate(
    model="dall-e-3",
    prompt=(
        "A photorealistic golden retriever puppy playing fetch in a sunny park, "
        "golden hour lighting, shallow depth of field, 85mm lens, "
        "high detail, professional photography"
    ),
    size="1024x1024",   # también 1792x1024 (landscape) o 1024x1792 (portrait)
    quality="hd",       # "standard" ($0.04) o "hd" ($0.08)
    style="natural",    # "natural" o "vivid" (más saturado)
    n=1,                # DALL-E 3 solo soporta n=1
    response_format="url",
)

url = response.data[0].url
revised = response.data[0].revised_prompt
print("Prompt reescrito por DALL-E 3:", revised)

# Las URLs expiran en ~1 hora: descargar YA
img_bytes = requests.get(url).content
Path("output/puppy.png").parent.mkdir(exist_ok=True)
Path("output/puppy.png").write_bytes(img_bytes)
```

> **Nota:** DALL-E 3 **reescribe tu prompt** internamente para "mejorarlo". Si quieres control total, prefija el prompt con `"I NEED to test how the tool works with extremely simple prompts. DO NOT add any detail, just use it AS-IS:"`.

### Opción B: Stable Diffusion local con `diffusers`

```python
import torch
from diffusers import StableDiffusionXLPipeline

pipe = StableDiffusionXLPipeline.from_pretrained(
    "stabilityai/stable-diffusion-xl-base-1.0",
    torch_dtype=torch.float16,
    variant="fp16",
).to("cuda")

image = pipe(
    prompt="a cyberpunk cityscape at night, neon lights, rain, cinematic, 8k",
    negative_prompt="blurry, low quality, deformed, watermark, text",
    num_inference_steps=30,
    guidance_scale=7.5,
    width=1024, height=1024,
    generator=torch.Generator("cuda").manual_seed(42),  # reproducibilidad
).images[0]

image.save("cyberpunk.png")
```

### Opción C: Flux.1 vía Replicate (API hosted)

```python
import replicate

output = replicate.run(
    "black-forest-labs/flux-schnell",
    input={
        "prompt": "A cat astronaut floating in space, highly detailed",
        "aspect_ratio": "16:9",
        "num_outputs": 1,
        "output_format": "png",
        "num_inference_steps": 4,  # Schnell es ultra rápido
    },
)
print(output[0])  # URL
```

### Comparación: generar la misma escena en 3 modelos

```python
PROMPT = (
    "A tiny cozy bookshop interior with wooden shelves, "
    "warm yellow light, a sleeping cat on an armchair, "
    "photorealistic, 50mm, shallow depth of field"
)

def generate_dalle(prompt):
    r = client.images.generate(
        model="dall-e-3", prompt=prompt,
        size="1024x1024", quality="standard", n=1,
    )
    return r.data[0].url

def generate_sdxl(prompt):
    return pipe(prompt=prompt, num_inference_steps=28).images[0]

def generate_flux(prompt):
    return replicate.run(
        "black-forest-labs/flux-dev",
        input={"prompt": prompt, "num_inference_steps": 28},
    )[0]

for name, fn in [("DALL-E 3", generate_dalle),
                 ("SDXL", generate_sdxl),
                 ("Flux dev", generate_flux)]:
    print(name, "→", fn(PROMPT))
```

## Errores comunes

- **Prompts vagos**: `"un perro"` produce un genérico decepcionante. Siempre especifica sujeto + estilo + composición + iluminación + calidad.
- **Olvidar negative prompts**: en SD/Flux, no listar `"blurry, deformed hands, extra fingers, watermark"` deja artefactos clásicos. DALL-E 3 no soporta negative prompt directo.
- **Aspect ratio incorrecto**: generar en 1024×1024 y luego recortar a 16:9 pierde composición. Usa el tamaño nativo deseado desde el inicio.
- **Demasiados conceptos en un prompt**: `"un dragón robot zombie pirata samurai"` → el modelo colapsa. Máximo 2-3 conceptos principales.
- **Esperar texto perfecto**: los modelos antiguos (SD1.5, DALL-E 2) escriben gibberish. Flux y DALL-E 3 son mejores pero aún fallan en párrafos.
- **Manos y dedos deformados**: el defecto más clásico. Mitigaciones: `negative_prompt="deformed hands, extra fingers, mutated hands"`, usar ControlNet con pose, o post-procesar con inpainting.
- **Generar personas reales**: viola ToS de OpenAI y es un riesgo legal. Para avatares usa modelos con rostros sintéticos.
- **Reproducir estilos protegidos**: `"in the style of Studio Ghibli"` genera demandas potenciales. Prefiere `"hand-drawn anime watercolor style"`.
- **No fijar seed**: resultados irreproducibles. Siempre `torch.Generator().manual_seed(N)` para debugging.
- **No descargar URLs de DALL-E**: expiran en ~1 hora. Descarga y almacena inmediatamente en S3/CDN.
- **Ignorar el `revised_prompt` de DALL-E 3**: te dice qué entendió el modelo; úsalo para iterar.
- **Confundir pricing**: DALL-E 3 HD es 2× standard; GPT-Image-1 high quality llega a $0.19/imagen.

## Resumen

- La generación de imágenes crea contenido visual nuevo desde texto u otras imágenes, usando **modelos de difusión** entrenados con pares (imagen, caption).
- La difusión funciona en dos fases: *forward* (añade ruido gaussiano progresivo) y *reverse* (una U-Net o DiT aprende a quitar ese ruido paso a paso, guiada por el prompt).
- **Latent Diffusion** (Stable Diffusion) hace la difusión en un espacio latente comprimido por un VAE, reduciendo cómputo ~48×.
- **Classifier-Free Guidance (CFG)** controla qué tanto el modelo obedece al prompt (`w = 7-12` típico).
- Los grandes modelos actuales: **DALL-E 3** (prompt following), **GPT-Image-1** (SOTA closed), **Flux.1** (SOTA open), **SDXL/SD3** (open customizable), **Midjourney v6** (estética).
- Para producción, elige por: calidad vs costo, open vs API, control fino (ControlNet/LoRA solo en open), formato de respuesta (URL vs base64).
- Un buen prompt tiene cinco bloques: **subject + style + composition + lighting + quality**.
- Los errores clásicos: manos deformadas, texto ilegible, prompts vagos, no usar negative prompts, no fijar seed, no descargar URLs temporales.
- Las URLs de DALL-E expiran en ~1 hora: descarga inmediatamente para almacenamiento persistente.
- Casos de uso típicos: e-commerce, social media, prototipado de diseño, visualización de datos, data augmentation.
- Evita generar personas reales, logos protegidos o reproducir estilos con copyright.
