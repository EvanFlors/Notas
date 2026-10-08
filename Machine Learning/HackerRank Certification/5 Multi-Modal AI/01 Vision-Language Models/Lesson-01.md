# Fundamentos de Vision-Language Models (VLMs)

## ¿Qué es?

Un **Vision-Language Model (VLM)** es un modelo que procesa **imágenes y texto en un espacio de representación compartido**, de modo que puede responder preguntas sobre lo que ve, describir contenido visual, comparar texto con imágenes y razonar sobre ambas modalidades a la vez. Formalmente, un VLM aprende un mapeo:

```
f: (Imagen, Texto) → Representación_conjunta → Salida (texto, embedding o score)
```

A diferencia de un modelo de visión tradicional (ej. ResNet para clasificación) que solo mapea `Imagen → clase`, o de un LLM puro que solo mapea `Texto → Texto`, un VLM **unifica ambos canales** en un único Transformer o en dos encoders cuyas salidas se alinean (contrastive learning).

![Arquitectura two-stream: encoder visual + encoder de texto fusionados por atención cruzada](https://hrcdn.net/ai-engineering/module-5/light/vision-language-lesson01-two-stream-overview.svg)

### Dos familias principales

| Familia | Objetivo de entrenamiento | Ejemplo | Caso de uso típico |
|---|---|---|---|
| **Contrastive (dual-encoder)** | Alinear embeddings de imagen y texto | CLIP, SigLIP, ALIGN, EVA-CLIP | Búsqueda semántica, clasificación zero-shot |
| **Generativo (fusionado en LLM)** | Generar texto condicionado a imágenes | GPT-4V, Claude 3.5 Sonnet, LLaVA, Flamingo, Gemini | VQA, OCR, extracción structured, agentes |

### Contexto histórico

- **2021:** OpenAI publica **CLIP** (Radford et al., *Learning Transferable Visual Models From Natural Language Supervision*). Entrenado con 400M pares (imagen, texto) de la web.
- **2021:** Google publica **ALIGN** con 1.8B pares ruidosos, demostrando que la escala vence a la curación.
- **2022:** DeepMind publica **Flamingo**, el primer VLM few-shot con cross-attention sobre un LLM congelado.
- **2023:** Aparece **OpenCLIP** (LAION) con reproducciones open-source entrenadas en LAION-5B.
- **Septiembre 2023:** OpenAI libera **GPT-4V** (`gpt-4-vision-preview`), primer VLM generativo masivo en API comercial.
- **2023:** Google publica **SigLIP** (sigmoid loss en vez de softmax), mejor en batches pequeños.
- **Marzo 2024:** Anthropic libera **Claude 3** (Opus, Sonnet, Haiku) con visión nativa.
- **Junio 2024:** Anthropic libera **Claude 3.5 Sonnet** con mejores capacidades de OCR y razonamiento visual.
- **2024:** Google libera **Gemini 1.5 Pro** con ventana de contexto de 1M–2M tokens incluyendo imágenes y video.

## ¿Por qué importa?

Hasta 2021, construir una aplicación que "entendiera" una imagen requería un pipeline frágil:

1. Detector de objetos (YOLO, Faster R-CNN) → bounding boxes.
2. OCR por separado (Tesseract) → strings.
3. Clasificador de intención.
4. Lógica manual para unir todo.

Cada paso tenía su propio modelo, su propio dataset de entrenamiento y acumulaba error. Un **VLM moderno elimina ese pipeline**: le pasas la imagen y una instrucción en lenguaje natural, y obtienes una respuesta estructurada.

### Casos donde un VLM gana sin discusión

- **Screenshots de errores de usuarios** en soporte técnico (interpretar UI, stack traces visibles).
- **Facturas, recibos, tickets** con layouts variables (donde reglas regex se rompen).
- **Testing automatizado de UI** (comparar screenshot esperado vs. real, detectar regresiones visuales).
- **Accessibility:** generar `alt text` para imágenes dinámicas.
- **Document AI:** extracción semántica de PDFs con tablas, gráficos y texto mixto.
- **E-commerce:** búsqueda por imagen, catalogación automática.

### Cuándo NO usar un VLM

- **OCR masivo de texto denso** (libros escaneados, millones de páginas): Tesseract o AWS Textract son mucho más baratos y suficientemente precisos.
- **Detección de objetos en video en tiempo real** (>30 fps): YOLO corre en milisegundos; un VLM tarda segundos.
- **Clasificación con millones de imágenes/día** y clases fijas: un ResNet fine-tuned es 100x más barato por inferencia.
- **Compliance estricto** donde necesitas trazabilidad por pixel (ej. diagnóstico médico regulado).

## ¿Cómo funciona?

### ViT: convertir imágenes en tokens

Casi todos los VLMs modernos usan un **Vision Transformer (ViT)** como encoder visual (Dosovitskiy et al., 2020). La imagen de `H x W x 3` se divide en **parches** de `P x P` (típicamente 14x14 o 16x16 pixels), cada parche se aplana y se proyecta linealmente a un vector de dimensión `D`:

```
Entrada: Imagen 224 x 224 x 3
Parches: (224/16)² = 196 parches de 16x16 x 3 = 768 valores cada uno
Proyección: cada parche → vector de dimensión D = 768
Token [CLS]: se antepone un token especial aprendible
Positional embedding: se suma información posicional
```

#### Patch size y resolución

El **patch size P** controla el trade-off entre resolución efectiva y costo computacional. Patches más pequeños (ej. 14x14) producen más tokens, lo que aumenta la calidad en detalles pero cuadratifica el costo de self-attention (`O(N²)` con N = número de tokens):

| Variante | Patch | Tokens (imagen 224x224) | Costo relativo attention |
|---|---|---|---|
| ViT-B/32 | 32x32 | 49 | 1x |
| ViT-B/16 | 16x16 | 196 | ~16x |
| ViT-L/14 | 14x14 | 256 | ~27x |
| ViT-H/14 | 14x14 | 256 | ~27x (más params) |

#### Class token y positional embeddings

Dos piezas aprendibles clave además de los patches:

- **[CLS] token:** vector aprendible añadido al inicio de la secuencia. Tras pasar por el Transformer, su salida se usa como representación global de toda la imagen para tareas de clasificación o similitud (es el que CLIP compara contra el embedding de texto).
- **Positional embeddings (`E_pos`):** vectores aprendibles sumados a cada token para informar su posición en la grid. Sin esto, el Transformer trataría los patches como un conjunto, perdiendo toda noción espacial.

La fórmula compacta del embedding de entrada al ViT (notación del paper original):

```
z_0 = [x_class; x_p^1 · E; x_p^2 · E; ...; x_p^N · E] + E_pos
```

Donde:
- `x_p^i` es el parche i-ésimo aplanado.
- `E ∈ R^((P²·C) x D)` es la matriz de proyección lineal.
- `E_pos ∈ R^((N+1) x D)` son los positional embeddings.
- `x_class` es el token [CLS] cuya salida final se usa como representación global de la imagen.

Luego, `z_0` pasa por L capas de Transformer idénticas a las de BERT/GPT (self-attention multi-cabeza + MLP + LayerNorm residual).

### CLIP: aprendizaje contrastivo imagen-texto

CLIP entrena **dos encoders** (uno visual, uno de texto) para que, dado un batch de `N` pares `(imagen_i, texto_i)`, los embeddings de pares correctos tengan **alta similitud coseno** y los de pares incorrectos **baja similitud**.

**Similitud coseno:**

```
sim(u, v) = (u · v) / (||u|| · ||v||)
```

**InfoNCE loss** (symmetric contrastive loss, el corazón de CLIP):

```
L_i2t = -(1/N) · Σ_i log( exp(sim(I_i, T_i) / τ) / Σ_j exp(sim(I_i, T_j) / τ) )
L_t2i = -(1/N) · Σ_i log( exp(sim(T_i, I_i) / τ) / Σ_j exp(sim(T_j, I_i) / τ) )
L_total = (L_i2t + L_t2i) / 2
```

Donde `τ` es un parámetro de temperatura aprendido. El efecto es que **texto e imagen que describen lo mismo acaban cerca** en el espacio de embeddings.

#### Importancia del batch size

El denominador del softmax recorre los `N` ejemplos del batch como negativos. Con **batch pequeño (ej. 64)**, el modelo tiene pocos negativos y la señal contrastiva es débil. CLIP original entrenó con **batch size = 32,768** usando sharding entre GPUs; cada ejemplo compite contra ~32k negativos. Esto es por qué CLIP necesita infraestructura considerable para entrenarse desde cero.

#### Temperatura τ

`τ` es un escalar aprendido (parametrizado como `exp(logit_scale)` para forzarlo positivo). Su rol:

- **τ pequeño (≈ 0.01):** picos muy marcados en el softmax; el modelo exige que el par correcto sea mucho más similar que todos los negativos. Más estricto, más riesgo de inestabilidad.
- **τ grande (≈ 1.0):** softmax casi uniforme; señal débil, el modelo no aprende.

CLIP inicializa `τ = 0.07` y lo deja aprender; típicamente converge entre 0.01 y 0.05. En inferencia, los logits se multiplican por `1/τ ≈ 100`, por eso aparece la escala 100 en el código de clasificación zero-shot.

#### Hard negatives

Los **negativos "difíciles"** (textos similares pero incorrectos) aceleran el entrenamiento. CLIP los obtiene gratis gracias al batch grande (es probable que haya conceptos relacionados), pero variantes posteriores (ej. **NegCLIP**) añaden hard negatives sintéticos (frases perturbadas) para mejorar razonamiento composicional.

### Zero-shot classification con CLIP y prompt templates

Una vez entrenado, CLIP puede clasificar imágenes **sin ningún fine-tuning**: codificas la imagen, codificas cada clase candidata como texto ("una foto de un gato", "una foto de un perro", ...), y eliges la clase con mayor similitud coseno al embedding de la imagen.

El paper de CLIP demostró que **prompt templates** mejoran drásticamente la precisión. En vez de usar la etiqueta cruda `"gato"`, se usa `"una foto de un gato"` o incluso un ensemble de 80 templates (`"una foto borrosa de un {}"`, `"un dibujo de un {}"`, ...) promediando sus embeddings. Esto puede subir el accuracy en ImageNet de ~64% a ~76%.

### Familia de modelos CLIP-like

| Modelo | Autor | Datos | Diferenciador |
|---|---|---|---|
| **CLIP (ViT-L/14)** | OpenAI, 2021 | 400M pares WIT | Original, cerrado |
| **OpenCLIP** | LAION, 2022+ | LAION-400M / LAION-2B | Open weights, reproducible |
| **ALIGN** | Google, 2021 | 1.8B pares ruidosos | Escala sobre curación |
| **SigLIP** | Google, 2023 | WebLI (~10B) | Sigmoid loss (no softmax), batch pequeño |
| **EVA-CLIP** | BAAI, 2023 | LAION-2B + COYO | Inicialización MIM, mejor en zero-shot |
| **MetaCLIP** | Meta, 2023 | CommonCrawl curado | Receta de curación de datos abierta |

**SigLIP** merece mención especial: reemplaza el softmax global por una **pérdida sigmoide por par**, lo que elimina la necesidad de que todos los negativos del batch estén en una sola GPU. Permite entrenar con batches más pequeños y es más estable.

## Ejemplo con código

### 1) CLIP con `sentence-transformers`: búsqueda imagen ↔ texto

```python
# pip install sentence-transformers pillow torch
from sentence_transformers import SentenceTransformer, util
from PIL import Image

# Modelo CLIP multimodal (acepta imágenes y texto)
model = SentenceTransformer("clip-ViT-B-32")

# Codificar imágenes locales
imagenes = [Image.open(f"foto_{i}.jpg") for i in range(1, 5)]
emb_imgs = model.encode(imagenes, convert_to_tensor=True, normalize_embeddings=True)

# Codificar queries de texto (zero-shot)
queries = [
    "un gato durmiendo en un sofá",
    "una pizza con pepperoni",
    "un atardecer en la playa",
    "una laptop con código en pantalla",
]
emb_txt = model.encode(queries, convert_to_tensor=True, normalize_embeddings=True)

# Similitud coseno: cada query vs. cada imagen
scores = util.cos_sim(emb_txt, emb_imgs)
for i, q in enumerate(queries):
    best = scores[i].argmax().item()
    print(f"Query: {q!r} → foto_{best + 1}.jpg (score={scores[i][best]:.3f})")
```

### 2) Zero-shot classification manual con prompt templates

```python
import torch

clases = ["gato", "perro", "pájaro", "coche", "pizza"]

# Ensemble de prompts (recomendado por el paper de CLIP)
templates = [
    "una foto de un {}",
    "una foto nítida de un {}",
    "una foto borrosa de un {}",
    "un dibujo de un {}",
    "una ilustración de un {}",
    "una foto de un {} pequeño",
    "una foto de un {} grande",
]

# Promediamos los embeddings de todos los templates por clase
emb_clases = []
for c in clases:
    prompts = [t.format(c) for t in templates]
    emb = model.encode(prompts, convert_to_tensor=True, normalize_embeddings=True)
    emb_promedio = emb.mean(dim=0)
    emb_promedio = emb_promedio / emb_promedio.norm()  # renormalizar
    emb_clases.append(emb_promedio)
emb_clases = torch.stack(emb_clases)

# Clasificar imagen
imagen = Image.open("mascota.jpg")
emb_img = model.encode([imagen], convert_to_tensor=True, normalize_embeddings=True)

# Logits con escala 100 (equivalente a 1/τ aprendido ≈ 0.01)
logits = (emb_img @ emb_clases.T) * 100.0
probs = torch.softmax(logits, dim=-1).squeeze()

for clase, p in sorted(zip(clases, probs.tolist()), key=lambda x: -x[1]):
    print(f"{clase:10s} {p*100:5.1f}%")
```

### 3) Retrieval imagen → texto en una colección grande

```python
# Dado un corpus de descripciones, encontrar la que mejor describe una imagen
descripciones = [
    "un perro corriendo por un prado al atardecer",
    "una ciudad vista desde un rascacielos de noche",
    "un plato de pasta con salsa boloñesa humeante",
    "una montaña nevada reflejada en un lago",
    # ... miles más
]
emb_desc = model.encode(descripciones, convert_to_tensor=True,
                        normalize_embeddings=True, batch_size=64)

query_img = Image.open("foto_misteriosa.jpg")
emb_q = model.encode([query_img], convert_to_tensor=True, normalize_embeddings=True)

top_k = util.semantic_search(emb_q, emb_desc, top_k=5)[0]
for hit in top_k:
    print(f"{hit['score']:.3f} → {descripciones[hit['corpus_id']]}")
```

### 4) Describir una imagen con un VLM generativo (Claude 3.5 Sonnet)

```python
# pip install anthropic
import anthropic, base64, pathlib

client = anthropic.Anthropic()  # usa ANTHROPIC_API_KEY

def img_a_base64(path: str) -> tuple[str, str]:
    ext = pathlib.Path(path).suffix.lower().lstrip(".")
    media_type = {"jpg": "image/jpeg", "jpeg": "image/jpeg",
                  "png": "image/png", "gif": "image/gif", "webp": "image/webp"}[ext]
    data = base64.standard_b64encode(pathlib.Path(path).read_bytes()).decode()
    return media_type, data

media_type, data = img_a_base64("diagrama.png")

msg = client.messages.create(
    model="claude-3-5-sonnet-20240620",
    max_tokens=512,
    messages=[{
        "role": "user",
        "content": [
            {"type": "image",
             "source": {"type": "base64", "media_type": media_type, "data": data}},
            {"type": "text",
             "text": "Describe el diagrama en español, listando componentes y conexiones."},
        ],
    }],
)
print(msg.content[0].text)
```

### 5) Fine-tuning rápido de CLIP sobre un dataset propio

```python
# Esquema simplificado: congelar backbone, añadir una capa de proyección sobre tus clases
import torch, torch.nn as nn

class ClipClassifier(nn.Module):
    def __init__(self, clip_backbone, dim=512, num_classes=10):
        super().__init__()
        self.backbone = clip_backbone  # congelado
        for p in self.backbone.parameters():
            p.requires_grad = False
        self.head = nn.Linear(dim, num_classes)

    def forward(self, image):
        with torch.no_grad():
            feats = self.backbone.encode_image(image)
        return self.head(feats.float())
```

### Limitaciones conocidas de CLIP

Aunque CLIP revolucionó el campo, tiene debilidades bien documentadas:

- **Razonamiento composicional débil:** confunde "un cubo rojo sobre una esfera azul" con "una esfera roja sobre un cubo azul". La atención del encoder de texto es "bag of concepts" más que estructural.
- **Counting pobre:** "tres gatos" vs. "cinco gatos" produce embeddings casi idénticos.
- **Negación ignorada:** "una foto sin gatos" se parece mucho a "una foto con gatos".
- **Sesgos de datos:** la web usada para entrenar refleja sesgos culturales (ej. "doctor" sesgado a hombre blanco).
- **Resolución fija pequeña (224x224):** detalles finos se pierden. Variantes posteriores (ViT-L/14 a 336px, SigLIP a 384px) mitigan esto parcialmente.

## Errores comunes

- **Confiar en OCR implícito de un VLM para texto denso.** Un VLM puede leer una factura, pero para 10,000 páginas de libros usa **Tesseract** o **AWS Textract**: son 10–100x más baratos y predecibles.
- **Olvidar que las imágenes consumen tokens.** Una imagen de 2048x2048 en modo `high` puede costar >1000 tokens de input. Multiplicado por millones de requests, la factura explota.
- **No redimensionar imágenes.** Subir fotos de 12 MP sin resize desperdicia tokens y dinero. Casi siempre `1024px` en el lado largo es suficiente.
- **Confundir CLIP con un modelo generativo.** CLIP devuelve embeddings y similitudes, no genera texto. Para describir imágenes necesitas LLaVA, GPT-4V, Claude 3, etc.
- **Entrenar un VLM desde cero.** Casi nunca tiene sentido: fine-tunear CLIP o LLaVA con LoRA sobre tu dominio es 1000x más barato.
- **Comparar embeddings sin normalizar.** La similitud coseno asume vectores unitarios; sin `normalize_embeddings=True` los scores son inconsistentes.
- **Suponer que el VLM entiende coordenadas pixel-perfect.** Los modelos actuales dan bounding boxes aproximados. Para pixel-perfect usa un detector dedicado (YOLO, SAM).
- **Pasar imágenes con texto en idiomas no latinos sin probar.** El soporte de OCR implícito varía mucho por idioma. Prueba primero.
- **Usar la etiqueta cruda en zero-shot CLIP.** Siempre usa prompt templates (`"una foto de un {}"`); el salto de accuracy es significativo.
- **Entrenar contrastive con batch pequeño.** Sin suficientes negativos, la señal es débil; considera SigLIP si no puedes escalar el batch.

## Resumen

- Un **VLM** procesa imágenes y texto en un espacio compartido para habilitar VQA, descripción, extracción structured y razonamiento multimodal.
- Dos familias: **contrastive** (CLIP, SigLIP, EVA-CLIP) para búsqueda/zero-shot, y **generativos** (GPT-4V, Claude 3.x, Gemini, LLaVA) para generar texto condicionado a imágenes.
- El **ViT** divide la imagen en parches, los proyecta linealmente, añade [CLS] token y suma positional embeddings: `z_0 = [x_class; x_p^1 E; ...; x_p^N E] + E_pos`.
- El **patch size** controla el trade-off resolución efectiva vs. costo cuadrático de self-attention.
- **CLIP** entrena con **InfoNCE** para alinear pares (imagen, texto) correctos vía similitud coseno; `sim(u,v) = u·v / (||u||·||v||)`.
- La **temperatura τ** controla la "dureza" del softmax; CLIP la aprende, inicializada en 0.07.
- Los **batches grandes** (32k en CLIP original) son clave; **SigLIP** usa sigmoid loss para permitir batches pequeños.
- **Prompt templates** mejoran drásticamente zero-shot classification (ensemble de 80 templates da +12 pts en ImageNet).
- Los VLMs generativos convierten la imagen en **image tokens** que el LLM consume junto a los tokens de texto, por eso las imágenes cuestan tokens.
- Hitos: CLIP (2021), Flamingo (2022), GPT-4V (Sept 2023), Claude 3 (Mar 2024), Claude 3.5 Sonnet (Jun 2024), Gemini 1.5 (2024).
- **Cuándo NO usar VLM:** OCR masivo barato, detección en tiempo real a alto fps, clasificación de clases fijas a gran escala.
- Limitaciones de CLIP: composición débil, counting pobre, negación ignorada, sesgos de datos web.
- Preprocesamiento (resize, formato, detail level) es la palanca principal para controlar costo y latencia.
