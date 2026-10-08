# PEFT: LoRA y QLoRA

## ¿Qué es?

**PEFT (Parameter-Efficient Fine-Tuning)** es la familia de técnicas que **congela los pesos del modelo base** y entrena sólo un pequeño conjunto adicional de parámetros ("adapters") que modifican el comportamiento del modelo para tu tarea. El objetivo: lograr la misma calidad que full fine-tuning con **10-100× menos memoria** y **2-5× menos tiempo**.

Las dos variantes dominantes:

- **LoRA (Low-Rank Adaptation):** añade matrices entrenables de bajo rango `A` y `B` a capas lineales específicas del modelo. El output de la capa se calcula como `h = Wx + BAx`, donde `W` queda congelado.
- **QLoRA (Quantized LoRA):** combina LoRA con **cuantización 4-bit** del modelo base. Reduce aún más la memoria, permitiendo fine-tunear 7B en 8GB VRAM, 70B en 48GB.

Para el **chatbot de soporte** del submódulo (7B, GPU de 16GB), **LoRA es la elección por defecto**. QLoRA entra en juego si bajas a 8GB o si quieres fine-tunear modelos más grandes (13B, 34B, 70B) con hardware modesto.

### Comparación de memoria para un modelo 7B

| Estrategia | Memoria VRAM | Tiempo típico (3 epochs, 2k ejemplos) | Calidad vs full FT |
|---|---|---|---|
| Full fine-tuning | 80-100 GB | 8-12 h | 100% (baseline) |
| LoRA (fp16) | 14-18 GB | 2-3 h | 95-99% |
| QLoRA (4-bit) | 6-10 GB | 2-4 h | 93-97% |
| QLoRA + Unsloth | 5-8 GB | 1-2 h | 93-97% |

## ¿Por qué importa?

Full fine-tuning de un 7B requiere una **A100 de 80GB** (~$3-5/hora en cloud) o un cluster multi-GPU. LoRA y QLoRA democratizan el fine-tuning: puedes entrenar en una **RTX 3090/4090 (24GB)**, una **RTX 3060 (12GB)** con QLoRA, o incluso en una **free Colab T4 (16GB)**.

Además, los adapters pesan **10-50MB** (vs 14GB del modelo completo), lo que permite:

- **Múltiples adapters por modelo base:** uno para clasificación, otro para generación, cambias en runtime sin recargar el base.
- **Deploy barato:** sirves el modelo base compartido + varios adapters pequeños.
- **Experimentación rápida:** probar 10 configuraciones de LoRA cuesta lo mismo que una sola de full FT.

### LoRA es casi gratis en calidad

La investigación original de LoRA (Hu et al., 2021) y confirmaciones posteriores (QLoRA, Dettmers et al., 2023) muestran que para la mayoría de tareas, el gap vs full fine-tuning es **menor al 2%**. En varias benchmarks de instruction tuning, LoRA incluso supera a full FT por efecto regularizador.

## ¿Cómo funciona?

### Intuición matemática de LoRA

Durante fine-tuning, el update de una matriz de pesos `W ∈ ℝ^(d×k)` puede escribirse como `W_nuevo = W + ΔW`. LoRA asume que **`ΔW` es de bajo rango intrínseco** y lo factoriza como:

```
ΔW = B · A    con A ∈ ℝ^(r×k),  B ∈ ℝ^(d×r),  r ≪ min(d, k)
```

En vez de aprender `d·k` parámetros (potencialmente millones por capa), aprende sólo `r·(d+k)`. Para `d=k=4096`, `r=16`:

- Full FT por capa: `4096·4096 = 16.7M` parámetros.
- LoRA por capa: `16·(4096+4096) = 131K` parámetros (**127× menos**).

Durante entrenamiento, `A` se inicializa con una distribución gaussiana y `B` se inicializa en **ceros**, de forma que `BA = 0` inicialmente y el modelo se comporta idénticamente al base en el paso 0 (training estable).

En inferencia puedes **fusionar los adapters** en los pesos originales: `W_merged = W + BA`. Resultado: cero overhead de latencia respecto al modelo base.

### Hiperparámetros de LoRA

| Parámetro | Rol | Rango típico | Default razonable |
|---|---|---|---|
| `r` (rank) | Capacidad del adapter | 4-128 | **16** |
| `lora_alpha` | Factor de escala (`BA` se multiplica por `α/r`) | `r` a `4r` | **2·r** (ej. 32 si r=16) |
| `target_modules` | Qué capas adaptar | ver tabla abajo | q_proj + v_proj (mínimo), all-linear (máximo) |
| `lora_dropout` | Regularización en el adapter | 0.0-0.1 | 0.05-0.1 |
| `bias` | Entrenar sesgos | `none`/`lora_only`/`all` | **none** |

### Target modules por arquitectura

| Arquitectura | Mínimo (atención) | Recomendado | Máximo (all-linear) |
|---|---|---|---|
| **Llama / Mistral** | `q_proj, v_proj` | `q_proj, k_proj, v_proj, o_proj` | `+ gate_proj, up_proj, down_proj` |
| **GPT-2 / GPT-NeoX** | `c_attn` | `c_attn, c_proj` | `+ c_fc` |
| **T5** | `q, v` | `q, k, v, o` | `+ wi, wo` |
| **Falcon** | `query_key_value` | `query_key_value, dense` | `+ dense_h_to_4h, dense_4h_to_h` |

Regla práctica: `peft` acepta `target_modules="all-linear"` para auto-detectar.

### Hiperparámetros típicos por tamaño de modelo

| Modelo | `r` | `alpha` | `lr` | `batch` (eff.) | VRAM (LoRA fp16) |
|---|---|---|---|---|---|
| 1-3B (TinyLlama, Phi-2) | 8-16 | 16-32 | 3e-4 | 16-32 | 4-8 GB |
| 7B (Llama 3 8B, Mistral 7B) | 16-32 | 32-64 | 2e-4 | 16 | 14-18 GB |
| 13B (Llama 2 13B) | 16-32 | 32-64 | 1e-4 | 8-16 | 26-32 GB |
| 70B (Llama 3 70B) | 8-16 | 16-32 | 5e-5 | 4-8 | 140 GB (requiere QLoRA) |

### QLoRA: cuantización 4-bit del base

QLoRA guarda los pesos base en **NF4 (NormalFloat 4-bit)**, un formato diseñado específicamente para pesos de redes neuronales, cuya distribución es aproximadamente normal. Durante el forward/backward, los pesos se **dequantizan** on-the-fly a `bfloat16` para computación.

Componentes clave:
- **NF4:** cuantización de 4 bits óptima para distribuciones normales.
- **Double quantization:** cuantiza también las constantes de cuantización (ahorro extra de ~0.4 bits/param).
- **Paged optimizers:** mueve estados del optimizer entre GPU y CPU para evitar OOM en picos.

Los adapters LoRA se mantienen en **fp16/bf16** para preservar calidad de aprendizaje.

### Workflow de entrenamiento con TRL + PEFT (LoRA)

```python
import torch
from datasets import load_dataset
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments
from peft import LoraConfig
from trl import SFTTrainer, SFTConfig

model_id = "meta-llama/Meta-Llama-3-8B-Instruct"
tokenizer = AutoTokenizer.from_pretrained(model_id)
tokenizer.pad_token = tokenizer.eos_token

model = AutoModelForCausalLM.from_pretrained(
    model_id,
    torch_dtype=torch.bfloat16,
    device_map="auto",
    attn_implementation="flash_attention_2",  # si está disponible
)

lora_cfg = LoraConfig(
    r=16,
    lora_alpha=32,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],
    lora_dropout=0.05,
    bias="none",
    task_type="CAUSAL_LM",
)

ds = load_dataset("json", data_files={
    "train": "data/soporte_train.jsonl",
    "val":   "data/soporte_val.jsonl",
})

sft_cfg = SFTConfig(
    output_dir="./ckpt_chatbot_lora",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=4,     # batch efectivo = 16
    learning_rate=2e-4,
    lr_scheduler_type="cosine",
    warmup_ratio=0.03,
    logging_steps=10,
    eval_strategy="steps",
    eval_steps=100,
    save_steps=200,
    save_total_limit=3,
    bf16=True,
    gradient_checkpointing=True,
    max_seq_length=2048,
    packing=False,                     # con chat templates mejor sin packing
    report_to="wandb",
)

trainer = SFTTrainer(
    model=model,
    args=sft_cfg,
    train_dataset=ds["train"],
    eval_dataset=ds["val"],
    peft_config=lora_cfg,
    tokenizer=tokenizer,
)

trainer.train()
trainer.save_model("./ckpt_chatbot_lora/final")  # guarda SOLO el adapter (~20MB)
```

### Workflow con QLoRA (4-bit)

```python
from transformers import BitsAndBytesConfig
from peft import prepare_model_for_kbit_training

bnb = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)

model = AutoModelForCausalLM.from_pretrained(
    model_id,
    quantization_config=bnb,
    device_map="auto",
    attn_implementation="flash_attention_2",
)
model = prepare_model_for_kbit_training(model, use_gradient_checkpointing=True)

# El resto es idéntico a LoRA; sólo cambia la carga del modelo.
```

## Ejemplo con código

### 1. Verificación de parámetros entrenables

```python
from peft import get_peft_model

model = get_peft_model(model, lora_cfg)
trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
total     = sum(p.numel() for p in model.parameters())
print(f"Entrenables: {trainable:,} ({100*trainable/total:.3f}%)")
# Ejemplo típico para 7B con r=16 en q/k/v/o:
# Entrenables: 8,388,608 (0.11%)
```

### 2. Integración con Weights & Biases

```python
import wandb
wandb.init(project="chatbot-soporte", name="llama3-8b-lora-r16")

# W&B se enlaza automáticamente si report_to="wandb" en SFTConfig.
# Loguea loss, lr, grad_norm, memoria GPU, y curvas eval_loss.
```

### 3. Cargar un adapter LoRA para inferencia

```python
from peft import PeftModel

base = AutoModelForCausalLM.from_pretrained(model_id, torch_dtype=torch.bfloat16, device_map="auto")
model_lora = PeftModel.from_pretrained(base, "./ckpt_chatbot_lora/final")
model_lora.eval()

prompt = "Clasifica este ticket: Mi pedido #99 no llegó y era urgente."
msgs = [{"role": "user", "content": prompt}]
texto = tokenizer.apply_chat_template(msgs, tokenize=False, add_generation_prompt=True)
inputs = tokenizer(texto, return_tensors="pt").to(model_lora.device)
out = model_lora.generate(**inputs, max_new_tokens=150, do_sample=False)
print(tokenizer.decode(out[0], skip_special_tokens=True))
```

### 4. Merge del adapter y push a HuggingFace Hub

```python
from huggingface_hub import login
login()  # pide tu token

merged = model_lora.merge_and_unload()
merged.save_pretrained("./chatbot-merged", safe_serialization=True, max_shard_size="2GB")
tokenizer.save_pretrained("./chatbot-merged")

merged.push_to_hub("tu_usuario/chatbot-soporte-llama3-8b", private=True)
tokenizer.push_to_hub("tu_usuario/chatbot-soporte-llama3-8b", private=True)
```

### 5. Múltiples adapters en el mismo base model

```python
from peft import PeftModel

base = AutoModelForCausalLM.from_pretrained(model_id, torch_dtype=torch.bfloat16, device_map="auto")

model = PeftModel.from_pretrained(base, "./adapter_clasificacion", adapter_name="clasif")
model.load_adapter("./adapter_generacion", adapter_name="gen")
model.load_adapter("./adapter_extraccion", adapter_name="extract")

model.set_adapter("clasif")   # ahora usa el adapter de clasificación
# ... después:
model.set_adapter("gen")      # cambio instantáneo, sin recargar el base
```

### 6. QLoRA con Unsloth (2× velocidad, 50% menos VRAM)

```python
from unsloth import FastLanguageModel

model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="unsloth/Meta-Llama-3.1-8B-Instruct-bnb-4bit",
    max_seq_length=2048,
    load_in_4bit=True,
)

model = FastLanguageModel.get_peft_model(
    model,
    r=16,
    target_modules=["q_proj","k_proj","v_proj","o_proj","gate_proj","up_proj","down_proj"],
    lora_alpha=32,
    lora_dropout=0,
    bias="none",
    use_gradient_checkpointing="unsloth",
)
# De aquí en adelante, usas SFTTrainer normalmente.
```

### 7. Multi-GPU con FSDP (para 70B)

```python
# accelerate config con FSDP, luego:
# accelerate launch --config_file fsdp.yaml train.py
# TRL + Accelerate manejan sharding automáticamente.
```

## Errores comunes

- **Rank demasiado bajo (`r=4`) para tareas complejas:** underfitting; aumenta a `r=16` o `r=32`.
- **Rank demasiado alto (`r=128`) para tareas simples:** overfitting y desperdicio de parámetros.
- **`alpha` mal escalado:** si no usas la regla `alpha = 2·r`, el update efectivo es demasiado débil o demasiado fuerte. Alternativa: `use_rslora=True` normaliza por `sqrt(r)`.
- **Adaptar sólo `q_proj`:** suficiente para tareas de estilo, insuficiente para razonamiento complejo. Adapta al menos `q_proj, k_proj, v_proj, o_proj`.
- **Olvidar `prepare_model_for_kbit_training` en QLoRA:** sin esto, el `gradient_checkpointing` rompe el grafo computacional.
- **Learning rate copiado de full FT:** full FT usa `1e-5 ~ 5e-5`; LoRA requiere `1e-4 ~ 3e-4` (10× mayor) porque los adapters son pequeños.
- **Guardar sin merge y después olvidar cargar el adapter:** cargas sólo el base model → el modelo "no aprendió nada".
- **Entrenar sin `gradient_checkpointing`** con batch grande → OOM.
- **Mezclar precisiones (`bf16` + `fp16`)** en una misma GPU vieja (sin soporte bf16) → NaN loss.
- **Flash Attention sin verificar soporte GPU:** sólo Ampere+ (A100, A6000, 3090, 4090, H100). En T4/V100 usa `attn_implementation="sdpa"`.
- **No fijar `use_double_quant=True` en QLoRA:** ahorro gratis que mucha gente omite.

## Resumen

- **PEFT** entrena un pequeño conjunto de parámetros manteniendo congelado el modelo base, reduciendo memoria 10-100× y tiempo 2-5×.
- **LoRA** aprende factorizaciones de bajo rango `BA` por capa; `r=16, alpha=32, target q/k/v/o` es un default sólido.
- **QLoRA** añade cuantización 4-bit del base model, permitiendo 7B en 8GB y 70B en una A100.
- Los adapters pesan **10-50MB**, se pueden **mergear** para cero latencia o cargar **múltiples** sobre el mismo base.
- Herramientas estándar: **HuggingFace TRL + PEFT + bitsandbytes**, con alternativas de velocidad como **Unsloth** (2× más rápido) y **Axolotl** (configs YAML).
- Para multi-GPU usa **Accelerate + FSDP** o **DeepSpeed**; para servicios serverless, **Modal** o **Lambda Labs**.
- Para el chatbot de soporte del submódulo: Llama 3 8B + LoRA (`r=16, alpha=32, q/k/v/o`), `lr=2e-4`, 3 epochs, batch efectivo 16, con W&B para monitoreo.
- Mergea sólo cuando vayas a hacer deploy único; para servir muchas tareas con el mismo base, mantén adapters separados.
