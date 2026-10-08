# Prompt Engineering para Imágenes

## ¿Qué es?

El **prompt engineering para imágenes** es la disciplina de construir descripciones textuales que guían a un modelo generativo (DALL-E 3, Stable Diffusion, Flux, Midjourney) a producir exactamente la imagen que tienes en mente. Combina:

- **Vocabulario visual estructurado** (términos de fotografía, pintura, diseño).
- **Fórmulas de composición** cinematográfica y gráfica.
- **Control de estilo, iluminación y mood**.
- **Negative prompts** para excluir artefactos.
- **Técnicas avanzadas**: ControlNet, LoRA, img2img, seed control.

A diferencia del prompt de texto para LLMs (donde pides *tareas*), aquí describes *cómo debería verse* una escena: eres a la vez el director de cine, el director de fotografía y el art director.

### La fórmula canónica

```
Prompt = Subject + Style + Composition + Lighting + Quality
          │        │        │              │          │
          │        │        │              │          └─ "8k, high detail, award-winning"
          │        │        │              └──────────── "golden hour, soft rim light"
          │        │        └─────────────────────────── "centered, close-up, rule of thirds"
          │        └──────────────────────────────────── "photorealistic, 85mm, film grain"
          └───────────────────────────────────────────── "a red fox walking through snow"
```

## ¿Por qué importa?

El prompt es el **90% del resultado**. Un mismo modelo, misma seed, misma config: cambiar el prompt de `"a dog"` a un prompt estructurado puede subir la calidad percibida de 3/10 a 9/10. En producción:

- **Consistencia de marca**: templates garantizan que todos los banners del e-commerce tengan el mismo look.
- **Costo**: menos iteraciones = menos requests = menos dinero. Un prompt bien hecho acierta a la primera.
- **Control sin fine-tuning**: ControlNet + prompt experto evita re-entrenar modelos.
- **A/B testing creativo**: variar un solo bloque (lighting) manteniendo todo lo demás permite experimentos controlados.
- **Debugging**: entender por qué un prompt falla te ahorra reclamos de usuarios.

Dos equipos con el mismo modelo pueden producir calidades radicalmente distintas según su dominio del prompting.

## ¿Cómo funciona?

### 1. Anatomía detallada

| Bloque | Qué controla | Ejemplos de términos |
|---|---|---|
| **Subject** | QUÉ aparece | "a golden retriever puppy", "a vintage brass compass" |
| **Style** | CÓMO se ve | "photorealistic", "watercolor", "cyberpunk anime", "oil painting" |
| **Composition** | CÓMO se enmarca | "centered", "rule of thirds", "close-up", "wide angle", "bird's eye view" |
| **Lighting** | Luz y mood | "golden hour", "rim light", "studio softbox", "dramatic chiaroscuro" |
| **Quality** | Fidelidad técnica | "8k", "high detail", "sharp focus", "award-winning photography" |

### 2. Estilos fotográficos

```
"photorealistic, 85mm lens, f/1.8, shallow DoF, Kodak Portra 400"
"documentary photography, candid, Leica M11, 35mm"
"cinematic still, anamorphic lens, teal and orange grading"
"street photography, high contrast black and white, Henri Cartier-Bresson style"
"macro photography, 100mm, extreme detail, bokeh background"
```

### 3. Estilos artísticos

```
"watercolor painting, soft washes, visible paper texture"
"oil painting, impasto technique, rich colors, museum quality"
"ukiyo-e woodblock print, bold outlines, flat colors"
"isometric 3D illustration, pastel palette, soft shadows"
"pencil sketch, loose linework, hatching shading"
```

### 4. Composición cinematográfica

| Término | Efecto visual |
|---|---|
| **Rule of thirds** | Sujeto desplazado a 1/3 (dinámico) |
| **Centered** | Sujeto al medio (formal, simétrico) |
| **Close-up / medium / wide** | Distancia aparente |
| **Low angle / high angle** | Cámara abajo/arriba (poder/vulnerabilidad) |
| **Dutch angle** | Cámara inclinada (tensión, caos) |
| **Over-the-shoulder** | POV conversacional |
| **Leading lines** | Líneas que guían la mirada |
| **Negative space** | Vacío intencional alrededor del sujeto |

### 5. Iluminación como lenguaje emocional

| Lighting | Mood típico | Ejemplo de uso |
|---|---|---|
| **Golden hour** | Cálido, nostálgico | Lifestyle, bodas |
| **Blue hour** | Calmo, melancólico | Paisajes urbanos |
| **Hard noon** | Dramático, crudo | Documental |
| **Softbox / diffused** | Limpio, comercial | E-commerce |
| **Rim light / backlight** | Épico, heroico | Posters |
| **Chiaroscuro** | Teatral, Caravaggio | Retratos artísticos |
| **Neon / cyberpunk** | Futurista, nocturno | Sci-fi |

### 6. Negative prompts (Stable Diffusion / Flux)

Los **negative prompts** indican qué NO quieres. En DALL-E 3 no existen directamente; debes expresarlo en positivo (`"clean composition without text"`).

Negative prompt universal para fotorrealismo:

```
blurry, low quality, low resolution, pixelated, jpeg artifacts,
watermark, signature, text, logo,
deformed, disfigured, extra limbs, extra fingers, mutated hands,
bad anatomy, bad proportions, cross-eyed,
oversaturated, undersaturated, overexposed, underexposed,
cartoon, anime, drawing, sketch, painting
```

### 7. Técnicas avanzadas

#### ControlNet

Guía la generación con una **señal estructural** adicional: pose, bordes Canny, mapa de profundidad, segmentación.

```
Prompt: "a woman jogging on the beach at sunset"
+ ControlNet pose: skeleton OpenPose de una modelo
→ Imagen con la pose exacta pero cualquier escena
```

Útil para:
- Mantener el **mismo layout** cambiando el estilo.
- Reproducir **poses específicas** para personajes.
- Preservar **arquitectura** cambiando iluminación/texturas.

#### LoRA (Low-Rank Adaptation)

Mini-adaptadores entrenados sobre un modelo base (SD, Flux) para enseñarle un **concepto, personaje o estilo específico** usando solo 10-50 imágenes.

```python
pipe.load_lora_weights("my-brand-lora.safetensors")
image = pipe(
    "a <my-brand> sneaker on a wooden shelf, product photography",
    cross_attention_kwargs={"scale": 0.8},  # intensidad del LoRA
).images[0]
```

#### img2img

Genera a partir de una **imagen de referencia** más un prompt. El parámetro `strength ∈ [0, 1]` controla cuánto se desvía del original.

#### Seed control

Fija la aleatoriedad para resultados reproducibles. Útil para iterar prompts manteniendo la "semilla visual".

### 8. Patrones por caso de uso

**E-commerce producto (studio):**
```
"{producto}, studio product photography, pure white background,
soft diffused lighting from top-left, slight reflection on surface,
centered composition, 85mm lens, f/8, tack-sharp focus,
commercial quality, 4k"
```

**E-commerce producto (lifestyle):**
```
"{producto} being used by a young adult in a modern loft,
natural morning light through large windows, candid moment,
shallow depth of field, warm color grading, Kodak Portra aesthetic"
```

**Social media hero:**
```
"{tema} concept, bold flat illustration, {paleta} color palette,
geometric composition, negative space for text overlay,
modern graphic design, {platform} aspect ratio"
```

**Concept visualization educativo:**
```
"isometric illustration of {concepto}, clean vector style,
labeled components, pastel colors, white background,
infographic quality, clear and simple"
```

## Ejemplo con código

### Builder de prompts estructurado

```python
from dataclasses import dataclass, field
from typing import Literal

Style = Literal["photorealistic", "watercolor", "cinematic", "3d_render",
                "minimalist", "cyberpunk", "oil_painting"]

STYLE_LIB = {
    "photorealistic": "photorealistic, 85mm lens, shallow depth of field, "
                      "natural colors, Kodak Portra 400 film",
    "watercolor":     "watercolor painting, soft washes, visible paper texture, "
                      "delicate color bleeds",
    "cinematic":      "cinematic still, anamorphic lens, teal and orange grading, "
                      "film grain, letterbox framing",
    "3d_render":      "3d render, octane, subsurface scattering, "
                      "studio HDRI lighting, 8k",
    "minimalist":     "minimalist composition, lots of negative space, "
                      "muted palette, clean lines",
    "cyberpunk":      "cyberpunk aesthetic, neon pink and cyan, rainy night, "
                      "reflections, Blade Runner mood",
    "oil_painting":   "oil painting, impasto brushstrokes, rich saturated colors, "
                      "museum quality, chiaroscuro lighting",
}

LIGHTING_LIB = {
    "golden":   "golden hour, warm backlight, long shadows",
    "studio":   "studio softbox lighting, even illumination, no harsh shadows",
    "dramatic": "dramatic chiaroscuro, single key light, deep shadows",
    "natural":  "soft natural daylight, overcast diffusion",
    "neon":     "neon lighting, pink and blue glow, wet reflections",
}

COMPOSITION_LIB = {
    "closeup":    "extreme close-up, tight framing, shallow DoF",
    "wide":       "wide angle shot, environmental context, deep DoF",
    "centered":   "centered composition, symmetrical, balanced",
    "thirds":     "rule of thirds, subject at left intersection, dynamic",
    "birdseye":   "bird's eye view, top-down, flat lay",
    "lowangle":   "low angle shot, heroic perspective",
}

@dataclass
class ImagePrompt:
    subject: str
    style: Style = "photorealistic"
    composition: str = "centered"
    lighting: str = "natural"
    extras: list[str] = field(default_factory=list)
    quality: str = "high detail, 8k, sharp focus"

    def build(self) -> str:
        parts = [
            self.subject,
            STYLE_LIB[self.style],
            COMPOSITION_LIB[self.composition],
            LIGHTING_LIB[self.lighting],
            *self.extras,
            self.quality,
        ]
        return ", ".join(p for p in parts if p)

prompt = ImagePrompt(
    subject="a vintage brass compass on an antique leather map",
    style="cinematic",
    composition="closeup",
    lighting="dramatic",
    extras=["aged texture", "mysterious mood"],
).build()
print(prompt)
```

### Negative prompt reutilizable (SD/Flux)

```python
BASE_NEG = (
    "blurry, low quality, low resolution, pixelated, jpeg artifacts, "
    "watermark, signature, text, logo, "
    "deformed, extra fingers, mutated hands, bad anatomy, "
    "oversaturated, overexposed"
)

ARTISTIC_NEG = BASE_NEG + ", photorealistic, 3d render"
PHOTO_NEG    = BASE_NEG + ", cartoon, anime, drawing, painting"
```

### ControlNet con pose (diffusers)

```python
import torch
from diffusers import StableDiffusionXLControlNetPipeline, ControlNetModel
from controlnet_aux import OpenposeDetector
from PIL import Image

openpose = OpenposeDetector.from_pretrained("lllyasviel/Annotators")
pose_map = openpose(Image.open("reference_pose.jpg"))

controlnet = ControlNetModel.from_pretrained(
    "thibaud/controlnet-openpose-sdxl-1.0",
    torch_dtype=torch.float16,
)
pipe = StableDiffusionXLControlNetPipeline.from_pretrained(
    "stabilityai/stable-diffusion-xl-base-1.0",
    controlnet=controlnet,
    torch_dtype=torch.float16,
).to("cuda")

image = pipe(
    prompt="a professional ballet dancer, stage lighting, dramatic",
    negative_prompt=PHOTO_NEG,
    image=pose_map,
    num_inference_steps=30,
    guidance_scale=7.5,
    controlnet_conditioning_scale=0.9,
    generator=torch.Generator("cuda").manual_seed(42),
).images[0]

image.save("ballet.png")
```

### Cargar un LoRA

```python
from diffusers import StableDiffusionXLPipeline
import torch

pipe = StableDiffusionXLPipeline.from_pretrained(
    "stabilityai/stable-diffusion-xl-base-1.0", torch_dtype=torch.float16,
).to("cuda")

# LoRA entrenado con el estilo de nuestra marca
pipe.load_lora_weights("./brand_style_lora.safetensors", adapter_name="brand")
pipe.set_adapters(["brand"], adapter_weights=[0.8])

image = pipe(
    prompt="<brand> sneakers on marble, product photography, soft light",
    num_inference_steps=28,
).images[0]
```

### img2img con control de strength

```python
from diffusers import StableDiffusionXLImg2ImgPipeline
from PIL import Image
import torch

pipe = StableDiffusionXLImg2ImgPipeline.from_pretrained(
    "stabilityai/stable-diffusion-xl-base-1.0", torch_dtype=torch.float16,
).to("cuda")

init = Image.open("photo_original.jpg").resize((1024, 1024))

for strength in [0.3, 0.5, 0.75]:
    out = pipe(
        prompt="oil painting style, impasto, Van Gogh inspired",
        image=init,
        strength=strength,          # 0 = igual al original, 1 = ignora original
        guidance_scale=7.5,
        num_inference_steps=40,
    ).images[0]
    out.save(f"painted_strength_{strength}.png")
```

### Workflow de iteración sistemática

```python
PROMPTS = []

# Paso 1: base simple
PROMPTS.append("a coffee shop interior")

# Paso 2: añadir estilo
PROMPTS.append(PROMPTS[-1] + ", photorealistic, 35mm lens")

# Paso 3: composición
PROMPTS.append(PROMPTS[-1] + ", wide angle, rule of thirds")

# Paso 4: iluminación
PROMPTS.append(PROMPTS[-1] + ", warm morning light through windows")

# Paso 5: detalles y mood
PROMPTS.append(PROMPTS[-1] + ", wooden furniture, plants, steaming cups, cozy mood")

# Paso 6: calidad
PROMPTS.append(PROMPTS[-1] + ", 8k, high detail, award-winning photography")

for i, p in enumerate(PROMPTS):
    url = generate_dalle(p)      # tu wrapper de la API
    print(f"V{i+1}: {url}")
```

## Errores comunes

- **Prompt vago**: `"un gato"` → genérico. Añade raza, pose, entorno, estilo.
- **Instrucciones conflictivas**: `"realistic and cartoon, day and night"` → el modelo colapsa en algo mediocre.
- **Demasiados conceptos**: más de 3 sujetos principales confunde al modelo. Divide en imágenes separadas y compón.
- **No usar negative prompts** en SD/Flux: dejas pasar artefactos clásicos (manos deformes, texto basura).
- **Negative prompts gigantes**: >50 términos empieza a dañar calidad. Prioriza los 10 más importantes.
- **Olvidar la calidad al final**: sin `"high detail, 8k"` el modelo asume calidad media.
- **No fijar seed al iterar**: comparas prompts bajo distinta aleatoriedad; conclusiones inválidas. Fija seed, varía UNA cosa.
- **Palabras ambiguas**: `"orange"` ¿fruta o color? Sé explícito: `"the color orange"` o `"an orange fruit"`.
- **Modifiers mágicos sin control**: `"trending on artstation, octane render, unreal engine"` eran útiles en SD1.5 pero sobran en SDXL/Flux/DALL-E 3.
- **Reproducir estilos protegidos** (Studio Ghibli, Disney, artistas vivos nombrados) → riesgo legal + algunos modelos lo filtran.
- **Pedir texto específico sin modelo adecuado** → SD1.5 produce gibberish. Para texto legible usa DALL-E 3, Flux o GPT-Image.
- **Aspect ratio incoherente con la escena**: pedir un retrato vertical en 1792×1024 (landscape) → recorte raro.
- **No leer el `revised_prompt` de DALL-E 3**: la API te dice qué entendió; ignóralo y debuggear es ciego.
- **Templates sin variación**: generar 100 productos con el mismo template exacto → social media aburrida. Rota 3-5 templates.

## Resumen

- Un buen prompt sigue la fórmula **Subject + Style + Composition + Lighting + Quality**.
- **Style**: elige entre fotográfico (`photorealistic, 85mm`), artístico (`watercolor, oil painting`), diseño (`minimalist, cyberpunk`).
- **Composition**: usa vocabulario cinematográfico (close-up, rule of thirds, bird's eye, low angle).
- **Lighting** es el 50% del mood: golden hour (cálido), blue hour (calmo), chiaroscuro (dramático), softbox (comercial).
- **Negative prompts** (SD/Flux) excluyen artefactos: `blurry, deformed hands, extra fingers, watermark`. DALL-E 3 no soporta negative directo.
- **ControlNet** guía con pose, bordes, profundidad; útil para preservar layout cambiando estilo.
- **LoRA** enseña conceptos propios al modelo con 10-50 imágenes y ~1 hora de entreno.
- **img2img** transforma una imagen base; `strength` controla cuánto cambia (0 = idéntico, 1 = ignora original).
- **Seed control** (`torch.manual_seed(N)`) es obligatorio para iterar prompts justamente.
- Flujo de iteración: empieza simple y añade un bloque por versión (style → composition → lighting → details → quality).
- Casos de uso tienen patrones de prompt distintos: e-commerce studio, e-commerce lifestyle, social media hero, concept visualization.
- Errores clásicos: vaguedad, conceptos conflictivos, más de 3 sujetos, olvidar negative, no fijar seed, reproducir estilos protegidos.
- Lee siempre el `revised_prompt` de DALL-E 3; es feedback gratuito del modelo.
- Mantén **templates reutilizables** pero rota 3-5 variantes para no saturar la estética.
