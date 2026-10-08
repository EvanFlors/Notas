# LLMs Multimodales y Técnicas de Personalización

## ¿Qué es?

Esta lección cubre dos ejes complementarios para extender un LLM más allá del uso "caja negra" por API:

1. **Multimodalidad:** modelos que procesan texto, imágenes, audio y video en un espacio de representación compartido, no sólo texto.
2. **Personalización:** técnicas para adaptar modelos a tu dominio — desde el más barato (**in-context learning**) hasta el más costoso (**full fine-tuning**), pasando por **LoRA/QLoRA**, **instruction tuning**, **RLHF/DPO** y **distillation**.

### Multimodal LLMs (MLLMs)

Un **Multimodal LLM** acepta y/o produce señales de más de una modalidad. Arquitectura típica:

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ Vision Enc.  │   │ Audio Enc.   │   │ Text Tokens  │
│ (ViT, CLIP)  │   │ (Whisper-like)│   │ (BPE)        │
└──────┬───────┘   └──────┬───────┘   └──────┬───────┘
       │ embeddings       │ embeddings       │
       └────────┬─────────┴──────────────────┘
                ▼
       ┌─────────────────────┐
       │ Projection layer    │  ← proyecta todo a dim. del LLM
       └──────────┬──────────┘
                  ▼
       ┌─────────────────────┐
       │   LLM (Transformer) │  ← razona sobre el "token stream" unificado
       └─────────────────────┘
                  ▼
            texto generado
            (y en modelos "any-to-any": imagen, audio)
```

### Personalización — espectro de técnicas

| Técnica | Modifica pesos | Datos típicos | Costo | Cuándo usarla |
|---|---|---|---|---|
| **Prompt engineering** | No | 0 | $ | Primer intento, siempre |
| **Few-shot / in-context learning** | No | 3-20 ejemplos en prompt | $ | Formato específico, baja frecuencia |
| **RAG** | No | Corpus externo | $$ | Conocimiento fresco / privado |
| **Prompt tuning / Prefix tuning** | Pocos vectores | 1K-10K ejemplos | $$ | Soft prompts |
| **LoRA / QLoRA (PEFT)** | ~0.1-1% de los pesos | 1K-100K ejemplos | $$ | Estilo, dominio, formato |
| **Full fine-tuning (SFT)** | 100% | 10K-1M ejemplos | $$$ | Dominio muy distinto, control total |
| **RLHF / DPO** | 100% o LoRA | Pares de preferencias | $$$$ | Alineamiento, tono, seguridad |
| **Distillation** | 100% del student | Outputs del teacher | $$$ | Reducir costo/latencia en producción |
| **Continual pre-training** | 100% | Billones de tokens de dominio | $$$$$ | Idioma/dominio totalmente nuevo |

## ¿Por qué importa?

**Multimodalidad** abre categorías de aplicaciones imposibles con texto puro:

- Revisión de código + captura de pantalla del error.
- Moderación de contenido con texto *e* imágenes embebidas.
- Soporte al cliente que acepta audios de voz y screenshots.
- Generación de descripciones de producto a partir de fotos.
- Diagramas, planos, flowcharts, OCR implícito, documentos escaneados.
- Accesibilidad: describir imágenes a usuarios con discapacidad visual.

**Personalización** importa porque:

- Un modelo *generalista* raras veces es óptimo para un dominio con terminología propia (legal, médico, financiero).
- *Few-shot en el prompt* funciona pero gasta tokens cada request. Fine-tuning internaliza el patrón y **reduce tokens de prompt** → ahorro recurrente.
- La **latencia** y el **costo** de un modelo pequeño fine-tuneado pueden vencer a un GPT-4 generalista en tareas específicas.
- Distillation permite migrar un sistema "demo con GPT-4" a producción con un modelo 10× más barato manteniendo 85-95% de la calidad.
- RLHF/DPO es cómo se alinea el *tono*, la *seguridad* y la *persona* de un asistente.

**Importante:** antes de fine-tunear, **agota prompt engineering + RAG + few-shot**. En 70% de los casos resuelven el problema sin la complejidad operacional de mantener un modelo custom.

## ¿Cómo funciona?

### Arquitectura multimodal — el "truco" del espacio compartido

Los MLLMs modernos (GPT-4V/4o, Claude 3+, Gemini, LLaVA, Qwen-VL) comparten una receta:

1. **Encoder específico de modalidad** convierte la señal a embeddings.
   - Imágenes: Vision Transformer (ViT) pre-entrenado (ej. CLIP ViT-L/14) parte la imagen en parches 14×14 y los codifica.
   - Audio: Whisper encoder o similar convierte espectrograma log-Mel a embeddings temporales.
2. **Capa de proyección** (típicamente un MLP de 2 capas) mapea esos embeddings a la dimensión del LLM.
3. **El LLM** recibe la secuencia unificada `[tokens_imagen, tokens_texto]` y la procesa como texto normal.

El entrenamiento multimodal se hace en dos fases: *alignment* (proyección congelando LLM y encoder) e *instruction tuning* multimodal (ejemplos `imagen + instrucción → respuesta`).

Modelos "**any-to-any**" (GPT-4o, Gemini 2.5) además generan imágenes/audio: añaden decoders de modalidad después del LLM.

### In-context learning (ICL) — "aprender" sin cambiar pesos

Descubrimiento clave de GPT-3: si pones ejemplos en el prompt, el modelo generaliza el patrón para la nueva entrada, **sin entrenamiento**:

```
Clasifica el sentimiento:

Texto: "Me encantó el producto"      → positivo
Texto: "Tardó un mes y llegó roto"   → negativo
Texto: "Está bien, no es la gran cosa" → neutral
Texto: "Mejor compra del año"        →
```

El modelo responde `positivo` sin que nadie modificara sus pesos. Esto es **few-shot in-context learning**. Variantes:

- **Zero-shot:** sólo la instrucción, 0 ejemplos.
- **Few-shot:** 1-20 ejemplos.
- **Chain-of-thought (CoT):** incluir ejemplos de *razonamiento paso a paso* → mejora drástica en tareas lógicas/matemáticas.

### Fine-tuning — ajustar los pesos

**Supervised Fine-Tuning (SFT):** continuar el pre-training sobre pares `(prompt, respuesta ideal)` curados. Minimiza cross-entropy sólo en los tokens de respuesta.

**Parameter-Efficient Fine-Tuning (PEFT):**

- **LoRA (Low-Rank Adaptation, 2021):** congela los pesos originales `W` y aprende dos matrices chicas `A ∈ ℝ^(d×r)`, `B ∈ ℝ^(r×d)` tales que la actualización es `ΔW = BA`. Con rango `r=8-64`, se entrenan **<1% de los parámetros** con calidad casi igual a full fine-tuning.
- **QLoRA (2023):** combina LoRA con cuantización 4-bit del modelo base. Permite fine-tunear LLaMA 70B en una sola GPU de 48GB.
- **DoRA, AdaLoRA, VeRA:** variantes más recientes con mejoras marginales.

**Instruction tuning:** SFT especializado en seguir instrucciones. Datasets famosos: Alpaca, Dolly, FLAN, OpenAssistant, UltraChat.

### Alineamiento: RLHF, DPO y Constitutional AI

Un modelo post-SFT sigue instrucciones pero puede generar outputs tóxicos, inseguros o poco útiles. El pipeline estándar:

```
1. SFT        Modelo base + 10-100K pares humanos  →  base de instrucciones
2. Reward Model
   Humanos rankean múltiples respuestas al mismo prompt.
   Se entrena un modelo R(prompt, respuesta) → score.
3. RLHF (PPO) Fine-tunea el LLM usando R como recompensa, con PPO (Proximal Policy
              Optimization) y una penalización KL contra el modelo SFT para no
              divergir demasiado.
```

**Alternativas modernas:**

- **DPO (Direct Preference Optimization, Rafailov et al. 2023):** elimina el reward model y optimiza una loss cerrada sobre pares `(elegido, rechazado)`. Más estable y barato. Usado por LLaMA 3, Mistral, Qwen, etc.
- **IPO, KTO, ORPO, SimPO:** variantes posteriores con distintas asunciones.
- **Constitutional AI (Anthropic):** el modelo critica y revisa sus propias respuestas guiado por una "constitución" de principios. Reduce dependencia de labels humanos.
- **RLAIF:** reemplaza humanos con otro LLM como juez.

### Distillation — modelos grandes enseñan a modelos chicos

Dos sabores:

- **Response distillation (soft/hard):** el teacher genera respuestas sobre un corpus de prompts; el student se entrena vía SFT sobre esos pares. Simple, muy usado (Alpaca se destiló de GPT-3.5, Zephyr de GPT-4).
- **Logit distillation:** el student minimiza KL contra la distribución *completa* de logits del teacher. Más eficiente estadísticamente pero requiere acceso a logits (solo con modelos abiertos o APIs que los expongan — OpenAI lo ofrece desde 2024).

Resultado típico: student 5-10× más chico, 80-95% de la calidad del teacher en el dominio objetivo, 10× más barato en producción.

### Elegir la técnica correcta — árbol de decisión

```
¿El modelo generalista resuelve el problema con buen prompt?
├─ SÍ → úsalo
└─ NO
   ├─ ¿Falta conocimiento específico/fresco?
   │  └─ SÍ → RAG
   ├─ ¿Falta formato/estilo/persona?
   │  └─ SÍ → few-shot primero, LoRA si es alto volumen
   ├─ ¿Costo o latencia inaceptables en producción?
   │  └─ SÍ → distillation a modelo más chico
   └─ ¿Dominio radicalmente distinto (ej. SQL propietario, idioma raro)?
      └─ SÍ → fine-tuning o continual pre-training
```

## Ejemplo con código

### 1. GPT-4o con imagen (multimodal input)

```python
import base64
from openai import OpenAI
oai = OpenAI()

with open("factura.jpg", "rb") as f:
    img_b64 = base64.b64encode(f.read()).decode()

r = oai.chat.completions.create(
    model="gpt-4o-mini",
    messages=[{
        "role": "user",
        "content": [
            {"type": "text", "text": "Extrae total, fecha e emisor de la factura. Devuelve JSON."},
            {"type": "image_url",
             "image_url": {"url": f"data:image/jpeg;base64,{img_b64}"}},
        ],
    }],
    max_tokens=300,
    temperature=0,
)
print(r.choices[0].message.content)
```

### 2. Claude 3.5 con imagen

```python
from anthropic import Anthropic
ant = Anthropic()

r = ant.messages.create(
    model="claude-3-5-sonnet-latest",
    max_tokens=400,
    messages=[{
        "role": "user",
        "content": [
            {"type": "image",
             "source": {"type": "base64", "media_type": "image/jpeg", "data": img_b64}},
            {"type": "text", "text": "¿Qué objetos hay y en qué posiciones?"},
        ],
    }],
)
print(r.content[0].text)
```

### 3. Audio: transcripción con Whisper

```python
with open("audio.mp3", "rb") as f:
    transcript = oai.audio.transcriptions.create(
        model="whisper-1",
        file=f,
        language="es",
    )
print(transcript.text)
```

### 4. Fine-tuning con LoRA (QLoRA) en HuggingFace

```python
# pip install transformers peft trl bitsandbytes accelerate datasets
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from peft import LoraConfig, get_peft_model
from trl import SFTTrainer, SFTConfig
from datasets import load_dataset

modelo_base = "meta-llama/Llama-3.1-8B-Instruct"

# Cuantización 4-bit (QLoRA)
bnb = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype="bfloat16",
    bnb_4bit_use_double_quant=True,
)

tok = AutoTokenizer.from_pretrained(modelo_base)
model = AutoModelForCausalLM.from_pretrained(modelo_base, quantization_config=bnb, device_map="auto")

# Adaptadores LoRA: solo ~0.5% de los pesos se entrenan
lora_cfg = LoraConfig(
    r=16, lora_alpha=32, lora_dropout=0.05,
    target_modules=["q_proj","k_proj","v_proj","o_proj"],
    bias="none", task_type="CAUSAL_LM",
)
model = get_peft_model(model, lora_cfg)
model.print_trainable_parameters()  # p.ej. 20M / 8B

# Dataset en formato chat
ds = load_dataset("json", data_files="mis_ejemplos.jsonl")["train"]

trainer = SFTTrainer(
    model=model,
    train_dataset=ds,
    args=SFTConfig(
        output_dir="./llama3-lora-soporte",
        per_device_train_batch_size=4,
        gradient_accumulation_steps=4,
        num_train_epochs=3,
        learning_rate=2e-4,
        bf16=True,
        logging_steps=10,
        save_steps=200,
    ),
)
trainer.train()
model.save_pretrained("./llama3-lora-soporte")
```

### 5. DPO (preference optimization) con TRL

```python
from trl import DPOTrainer, DPOConfig
# dataset con columnas: prompt, chosen, rejected
ds_pref = load_dataset("json", data_files="preferencias.jsonl")["train"]

dpo = DPOTrainer(
    model=model,
    ref_model=None,       # usa una copia congelada automáticamente
    args=DPOConfig(
        output_dir="./llama3-dpo",
        per_device_train_batch_size=2,
        num_train_epochs=1,
        beta=0.1,          # fuerza del regularizador KL
        learning_rate=5e-7,
    ),
    train_dataset=ds_pref,
    tokenizer=tok,
)
dpo.train()
```

### 6. Fine-tuning gestionado por OpenAI

```python
# 1. Preparar JSONL con formato chat:
# {"messages":[{"role":"system","content":"..."},{"role":"user","content":"..."},{"role":"assistant","content":"..."}]}

f = oai.files.create(file=open("train.jsonl","rb"), purpose="fine-tune")
job = oai.fine_tuning.jobs.create(
    training_file=f.id,
    model="gpt-4o-mini-2024-07-18",
    hyperparameters={"n_epochs": 3},
)
print(job.id)   # polling con oai.fine_tuning.jobs.retrieve(job.id)
```

### 7. Distillation con OpenAI (stored completions)

```python
# 1. Marcar completions del teacher para almacenarlas
r_teacher = oai.chat.completions.create(
    model="gpt-4o",
    messages=[...],
    store=True,                 # ← guarda la respuesta
    metadata={"task": "classify_tickets"},
)
# 2. Lanzar un fine-tune del student (gpt-4o-mini) usando esas completions
job = oai.fine_tuning.jobs.create(
    model="gpt-4o-mini-2024-07-18",
    training_file=None,
    method={
        "type": "supervised",
        "supervised": {
            "hyperparameters": {"n_epochs": 2},
        },
    },
    # ...filtros para seleccionar las stored completions
)
```

### 8. Correr un modelo local destilado (Ollama)

```bash
# instalar ollama (https://ollama.com)
ollama pull llama3.1:8b
ollama run llama3.1:8b "¿Qué es LoRA?"
```

```python
import requests
r = requests.post("http://localhost:11434/api/generate", json={
    "model": "llama3.1:8b",
    "prompt": "Resume la técnica DPO en 3 frases.",
    "stream": False,
    "options": {"temperature": 0.3},
})
print(r.json()["response"])
```

## Comparativa rápida: Fine-tuning vs. Distillation vs. RAG

| Dimensión | RAG | Fine-tuning (LoRA) | Distillation |
|---|---|---|---|
| Modifica pesos | No | Sí (parcial) | Sí (del student) |
| Conocimiento fresco | ✅ fácil | ❌ reentrenar | ❌ |
| Costo setup | Bajo | Medio | Alto |
| Costo ongoing | Medio (más tokens input) | Igual al base | **Mucho menor** |
| Mejora estilo/formato | Parcial | ✅ | ✅ (si teacher ya lo tiene) |
| Puede superar al modelo base | ❌ | ✅ en dominio | ❌ (acotado por teacher) |
| Explicabilidad | ✅ (ves las fuentes) | ❌ | ❌ |

Patrón recomendado en producción: **RAG + fine-tuning ligero + distillation** si el volumen lo justifica.

## Errores comunes

- **Fine-tunear cuando bastaba un buen prompt o RAG.** Agrega complejidad operacional (versioning, retraining, drift) sin beneficio. Siempre agota prompt engineering + few-shot + RAG primero.
- **Dataset de fine-tuning demasiado chico o inconsistente.** <500 ejemplos rara vez ayuda. Inconsistencia en formato enseña inconsistencia al modelo.
- **Catastrophic forgetting.** Full fine-tuning con pocos datos y alto learning rate hace que el modelo "olvide" habilidades generales. Mitigación: LoRA (congela base), learning rates bajos (1e-5 a 2e-4 para LoRA), mezclar datos generales.
- **Overfitting al dataset de fine-tuning.** El modelo repite literalmente el training. Monitorea loss en validación y para temprano.
- **Entrenar el reward model con datos sesgados.** El RLHF amplifica cualquier sesgo de los anotadores. Audita demografía de etiquetadores.
- **Enviar imágenes de alta resolución sin resize.** GPT-4V y Claude cobran por "tiles": una imagen 4096×4096 puede costar 10× más que una 1024×1024 con calidad igual para OCR.
- **Mezclar modalidades sin pensar en el orden.** En Claude y GPT, el orden `imagen → texto` suele dar mejores resultados que `texto → imagen`.
- **Confiar en la "visión" para texto denso.** Para extraer texto de documentos complejos, un OCR tradicional (Tesseract, Textract, Document AI) + LLM texto suele vencer al LLM multimodal puro.
- **Distillation sin dataset diverso.** Si el teacher sólo vio prompts fáciles, el student falla fuera de distribución. Genera prompts adversariales también.
- **No evaluar el modelo fine-tuneado contra el base.** A veces el fine-tune empeora. Compara en un *holdout* representativo.
- **No versionar datasets ni modelos.** Reproducir un entrenamiento de hace 6 meses es imposible sin DVC/MLflow/W&B.
- **Olvidar costos de GPU.** QLoRA de LLaMA 70B necesita ~48GB VRAM; alquilar una A100 cuesta ~$1-2/hora. Un entrenamiento típico son 10-100 horas.
- **No usar las APIs gestionadas cuando aplica.** OpenAI/Anthropic/Google ofrecen fine-tuning sin que gestiones GPUs. Si tus datos no son sensibles y el volumen es moderado, es más barato que self-host.
- **Multimodal con tokens multimodales no contados.** Una imagen puede equivaler a 85-1700 tokens según el modelo y la resolución. Súmalos a tu presupuesto.

## Resumen

- Los **MLLMs** proyectan imagen, audio y texto en un espacio común para que un Transformer único razone sobre todo junto. Habilita Q&A visual, OCR implícito, análisis de audio, descripción de escenas.
- La personalización de LLMs es un **espectro** que va de prompt engineering (gratis) a continual pre-training (millones de dólares). Elige lo más barato que resuelva el problema.
- **In-context learning** (zero/few-shot, chain-of-thought) te deja "programar" el modelo sin cambiar pesos — ideal para iterar rápido.
- **RAG** suele ser el *primer* paso cuando falta conocimiento específico o fresco; es más fácil de mantener que fine-tuning.
- **LoRA / QLoRA** entrenan <1% de los pesos y logran calidad cercana a full fine-tuning con 10-100× menos cómputo. Es el estándar actual.
- **SFT → Reward Model → RLHF (PPO)** es el pipeline clásico de alineamiento; **DPO** lo simplifica eliminando el reward model y es ahora el default en modelos abiertos.
- **Distillation** (teacher grande → student chico) es la vía para llevar un sistema demo con GPT-4 a producción con un modelo 10× más barato manteniendo 85-95% de calidad.
- **No fine-tunees sin antes agotar prompt + RAG + few-shot.** El 70% de los casos se resuelven ahí.
- Las APIs gestionadas (OpenAI/Anthropic/Google fine-tuning) ahorran operaciones; el ecosistema abierto (HuggingFace + PEFT + TRL + Axolotl + Unsloth + vLLM + Ollama) ofrece control total.
- Siempre **evalúa el modelo custom contra el base** en un holdout representativo antes de desplegar — a veces la personalización empeora el resultado.
