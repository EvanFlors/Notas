# Full Fine-Tuning

## ¿Qué es?

**Full fine-tuning (FFT)** es la forma clásica de ajuste supervisado: en cada paso de entrenamiento se actualizan **todos** los parámetros del modelo. Para un 7B, eso significa actualizar los 7 mil millones de pesos — frente a los ~8 millones (0.1%) de un LoRA típico.

Pese a que PEFT (LoRA/QLoRA) domina la práctica actual, full fine-tuning sigue siendo relevante en varios casos:

- Modelos pequeños (≤1-3B) donde la memoria no es cuello de botella.
- Dominios con **mucho shift** respecto al pre-entrenamiento (ej. código ensamblador, idiomas de baja representación).
- Cuando necesitas **cambiar embeddings** (ampliar vocabulario, nuevos tokens especiales).
- Investigación donde requieres el último 1-2% de calidad.
- Continual pre-training (CPT) sobre dominios enteros antes de hacer SFT.

Para el **chatbot de soporte** del submódulo con GPU de 16GB, full FT **no es viable** sobre un 7B; necesitarías una A100/H100 de 80GB o un cluster multi-GPU. Esta lección te prepara para cuando el presupuesto o la calidad lo justifiquen.

### Comparación rápida FFT vs PEFT

| Dimensión | Full FT | LoRA | QLoRA |
|---|---|---|---|
| Parámetros entrenables (7B) | 7,000M | ~8M | ~8M |
| VRAM (7B, bf16, batch 1) | 80-100 GB | 14-18 GB | 6-10 GB |
| Learning rate típico | 1e-5 a 5e-5 | 1e-4 a 3e-4 | 1e-4 a 3e-4 |
| Tiempo relativo | 1.0× | 0.3-0.5× | 0.4-0.6× |
| Checkpoint size (7B) | 14 GB | 10-50 MB | 10-50 MB |
| Calidad relativa | 100% | 95-99% | 93-97% |
| Puede cambiar embeddings | ✅ | ❌ (sin trucos) | ❌ |

## ¿Por qué importa?

Full FT es la **referencia de calidad** contra la cual se mide todo lo demás. Si tu caso de uso tiene las siguientes propiedades, FFT puede ser la mejor opción:

- El modelo base **no cubre bien tu dominio** (ej. historia clínica en español médico, código assembly ARM).
- Necesitas que el modelo **olvide** parcialmente comportamientos del base (ej. censura muy agresiva que estorba al caso de uso).
- Vas a servir **un único modelo durante años** y el costo de entrenamiento se amortiza frente al costo de inferencia.
- Operas en entornos donde los **últimos puntos de calidad** justifican costos 5-10×.

Por el otro lado, usar FFT cuando LoRA basta es un **desperdicio directo de dinero**: con el mismo presupuesto de compute podrías entrenar 5-10 LoRAs distintos y encontrar el mejor.

## ¿Cómo funciona?

### Memoria: desglose de los 80-100 GB para un 7B

Entrenar en `fp16/bf16` con el optimizer AdamW requiere mantener en VRAM:

| Componente | Fórmula | Tamaño (7B) |
|---|---|---|
| Pesos del modelo | `N · 2 bytes` (fp16) | 14 GB |
| Gradientes | `N · 2 bytes` | 14 GB |
| Momentum (AdamW m) | `N · 4 bytes` (fp32) | 28 GB |
| Varianza (AdamW v) | `N · 4 bytes` (fp32) | 28 GB |
| Pesos master (fp32) | `N · 4 bytes` | 28 GB |
| Activaciones | depende de batch × seq_len | 10-40 GB |
| **Total** | | **~80-120 GB** |

Técnicas estándar para reducir memoria:

- **Mixed precision (bf16/fp16):** forward/backward en 16-bit, pesos master en 32-bit.
- **Gradient checkpointing:** no almacena activaciones intermedias, las recomputa en el backward. Ahorra ~30-50% a cambio de +25% tiempo.
- **8-bit optimizer (`bitsandbytes.AdamW8bit`):** reduce `m` y `v` a 8-bit → ahorra 40 GB en un 7B.
- **ZeRO (DeepSpeed) o FSDP:** shardean pesos, gradientes y optimizer states entre GPUs.
- **CPU offloading:** paginar optimizer states a RAM (más lento pero evita OOM).

### Hiperparámetros típicos por tamaño (full FT)

| Modelo | `lr` | `batch` eff. | Warmup | Epochs | VRAM (bf16 + 8-bit optim) |
|---|---|---|---|---|---|
| 125M-1B | 1e-4 a 5e-4 | 32-128 | 100 steps | 3-5 | 4-16 GB |
| 1B-3B | 5e-5 a 2e-4 | 32-64 | 100-500 | 3 | 16-32 GB |
| 7B | 1e-5 a 5e-5 | 16-32 | 500-1000 | 2-3 | 60-80 GB |
| 13B | 1e-5 a 3e-5 | 16-32 | 1000 | 2-3 | 100-130 GB |
| 70B | 5e-6 a 2e-5 | 16-64 | 2000 | 1-2 | 500-800 GB (multi-GPU) |

**Regla:** learning rate más bajo cuanto más grande el modelo (los pesos son más sensibles).

### Checkpointing: estrategia

- `save_strategy="steps"` con `save_steps=500` para checkpoints frecuentes.
- `save_total_limit=3` para no llenar disco (cada checkpoint pesa ~14GB en un 7B).
- Guarda el **mejor** checkpoint según `eval_loss`: `load_best_model_at_end=True, metric_for_best_model="eval_loss"`.
- Resumible: `trainer.train(resume_from_checkpoint=True)` reanuda tras OOM o reinicio.

### Workflow completo con HuggingFace Trainer

```python
import torch
from datasets import load_dataset
from transformers import (
    AutoModelForCausalLM, AutoTokenizer,
    TrainingArguments, Trainer, DataCollatorForLanguageModeling,
)

model_id = "meta-llama/Meta-Llama-3-8B-Instruct"
tokenizer = AutoTokenizer.from_pretrained(model_id)
tokenizer.pad_token = tokenizer.eos_token

model = AutoModelForCausalLM.from_pretrained(
    model_id,
    torch_dtype=torch.bfloat16,
    attn_implementation="flash_attention_2",
)

ds = load_dataset("json", data_files={
    "train": "data/soporte_train.jsonl",
    "val":   "data/soporte_val.jsonl",
})

def formatear(batch):
    textos = [
        tokenizer.apply_chat_template(m, tokenize=False, add_generation_prompt=False)
        for m in batch["messages"]
    ]
    return tokenizer(textos, truncation=True, max_length=2048)

ds = ds.map(formatear, batched=True, remove_columns=ds["train"].column_names)

args = TrainingArguments(
    output_dir="./ckpt_full_ft",
    num_train_epochs=3,
    per_device_train_batch_size=1,         # memoria crítica
    gradient_accumulation_steps=16,        # batch efectivo = 16
    learning_rate=2e-5,                    # 10× menor que LoRA
    lr_scheduler_type="cosine",
    warmup_steps=500,
    weight_decay=0.01,
    max_grad_norm=1.0,                     # gradient clipping
    bf16=True,
    gradient_checkpointing=True,
    optim="adamw_bnb_8bit",                # ahorra ~40GB
    logging_steps=10,
    eval_strategy="steps",
    eval_steps=200,
    save_steps=500,
    save_total_limit=3,
    load_best_model_at_end=True,
    metric_for_best_model="eval_loss",
    report_to="wandb",
    run_name="chatbot-soporte-full-ft",
)

trainer = Trainer(
    model=model,
    args=args,
    train_dataset=ds["train"],
    eval_dataset=ds["val"],
    tokenizer=tokenizer,
    data_collator=DataCollatorForLanguageModeling(tokenizer, mlm=False),
)

trainer.train()
trainer.save_model("./ckpt_full_ft/final")
tokenizer.save_pretrained("./ckpt_full_ft/final")
```

### Entrenamiento distribuido

Para un 7B+ en GPUs menores a 80GB necesitas sharding:

**FSDP (PyTorch nativo):**

```python
# accelerate config  → eliges FSDP
# accelerate launch --num_processes 4 train.py

args = TrainingArguments(
    # ...
    fsdp="full_shard auto_wrap offload",
    fsdp_transformer_layer_cls_to_wrap="LlamaDecoderLayer",
)
```

**DeepSpeed ZeRO-3:**

```python
# archivo ds_config.json
{
  "zero_optimization": {
    "stage": 3,
    "offload_optimizer": {"device": "cpu"},
    "offload_param": {"device": "cpu"}
  },
  "bf16": {"enabled": true},
  "gradient_clipping": 1.0
}

# TrainingArguments(... deepspeed="ds_config.json")
# deepspeed --num_gpus=4 train.py
```

ZeRO-3 + CPU offload permite full FT de **70B en 8× A100 40GB** (algo imposible sin sharding).

## Ejemplo con código

### Script completo con monitoreo y push al Hub

```python
import os, torch, wandb
from datasets import load_dataset
from transformers import (
    AutoModelForCausalLM, AutoTokenizer,
    TrainingArguments, Trainer, EarlyStoppingCallback,
    DataCollatorForLanguageModeling,
)
from huggingface_hub import login

login(token=os.environ["HF_TOKEN"])
wandb.init(project="chatbot-soporte", name="llama3-8b-full-ft")

model_id = "meta-llama/Meta-Llama-3-8B-Instruct"
tokenizer = AutoTokenizer.from_pretrained(model_id)
tokenizer.pad_token = tokenizer.eos_token

model = AutoModelForCausalLM.from_pretrained(
    model_id,
    torch_dtype=torch.bfloat16,
    attn_implementation="flash_attention_2",
)

ds = load_dataset("json", data_files={
    "train": "data/soporte_train.jsonl",
    "val":   "data/soporte_val.jsonl",
})

def tok_fn(batch):
    textos = [tokenizer.apply_chat_template(m, tokenize=False) for m in batch["messages"]]
    return tokenizer(textos, truncation=True, max_length=2048)

ds = ds.map(tok_fn, batched=True, remove_columns=ds["train"].column_names)

args = TrainingArguments(
    output_dir="./ckpt_full",
    num_train_epochs=3,
    per_device_train_batch_size=1,
    gradient_accumulation_steps=16,
    learning_rate=2e-5,
    lr_scheduler_type="cosine",
    warmup_ratio=0.03,
    weight_decay=0.01,
    max_grad_norm=1.0,
    bf16=True,
    gradient_checkpointing=True,
    optim="adamw_bnb_8bit",
    logging_steps=10,
    eval_strategy="steps",
    eval_steps=100,
    save_steps=500,
    save_total_limit=3,
    load_best_model_at_end=True,
    metric_for_best_model="eval_loss",
    greater_is_better=False,
    report_to="wandb",
    push_to_hub=True,
    hub_model_id="tu_usuario/chatbot-soporte-llama3-8b-full",
    hub_private_repo=True,
)

trainer = Trainer(
    model=model,
    args=args,
    train_dataset=ds["train"],
    eval_dataset=ds["val"],
    tokenizer=tokenizer,
    data_collator=DataCollatorForLanguageModeling(tokenizer, mlm=False),
    callbacks=[EarlyStoppingCallback(early_stopping_patience=3)],
)

trainer.train()
trainer.push_to_hub("Final model")
```

### Evaluación durante training (métricas task-específicas)

```python
import numpy as np

def compute_metrics(eval_pred):
    preds, labels = eval_pred
    # Perplejidad desde la loss
    loss = eval_pred.metrics.get("eval_loss", None)
    ppl = float(np.exp(loss)) if loss else None
    return {"perplexity": ppl}

# Añadir al Trainer:
# trainer = Trainer(..., compute_metrics=compute_metrics)
```

### Push a HuggingFace Hub manualmente

```python
model.push_to_hub("tu_usuario/chatbot-soporte-llama3-8b-full", private=True)
tokenizer.push_to_hub("tu_usuario/chatbot-soporte-llama3-8b-full", private=True)
```

## Errores comunes

- **OOM por olvidar `gradient_checkpointing=True`:** sin checkpointing, las activaciones consumen 20-40 GB extra.
- **Learning rate copiado de LoRA (`2e-4`) a full FT:** destruye el modelo base. Full FT exige `1e-5 a 5e-5`.
- **No usar warmup:** los primeros steps con LR completo producen gradientes enormes y NaN. Usa `warmup_ratio=0.03` o `warmup_steps=500`.
- **Olvidar `max_grad_norm=1.0`:** sin clipping, un batch raro puede explotar gradientes.
- **Batch size muy grande para la GPU:** siempre valida con una iteración antes del training completo.
- **No usar `adamw_bnb_8bit` o `adafactor`:** AdamW tradicional en 7B consume 56GB sólo para `m` y `v`.
- **Overfitting agresivo:** full FT tiene más capacidad, así que es más fácil memorizar. Usa `weight_decay=0.01-0.1`, early stopping y val set frecuente.
- **No cambiar `attn_implementation` a `flash_attention_2` o `sdpa`:** la implementación por defecto puede ser 2-3× más lenta.
- **Mezclar `fp16=True` con `bf16=True`:** sólo uno; elige `bf16` si tu GPU es Ampere+.
- **No versionar checkpoints:** sin MLflow/W&B/HF Hub, perder el ordenador = perder el modelo. Push al Hub de inmediato.
- **No validar en el conjunto correcto:** eval en train contaminado = métricas infladas. Siempre split limpio.

## Resumen

- **Full fine-tuning** actualiza los 100% de parámetros; es el estándar de calidad pero exige **80-100 GB** VRAM para 7B.
- Costos: 5-10× más caro que LoRA en compute y 100-500× más en checkpoint storage.
- Usar FFT cuando: necesitas máxima calidad, dispones de ≥80GB VRAM, el modelo es pequeño (≤3B), o necesitas cambiar embeddings/vocabulario.
- Técnicas de ahorro de memoria obligatorias: **gradient checkpointing**, **mixed precision (bf16)**, **optimizer de 8 bits**, **FSDP/DeepSpeed ZeRO** para multi-GPU, **CPU offloading** como última línea.
- Hiperparámetros: `lr=2e-5`, `warmup=500 steps`, `weight_decay=0.01`, `max_grad_norm=1.0`, `batch efectivo 16-32`.
- Herramientas: **HuggingFace Trainer + Accelerate + bitsandbytes**, **DeepSpeed**, **FSDP**, infra en **Lambda Labs**, **Modal**, **RunPod**.
- Para el **chatbot de soporte** en GPU de 16GB, PEFT es la elección correcta. FFT entraría en escena si pasaras a una A100 80GB y necesitaras ese último 1-2% de calidad.
- Siempre monitoriza con W&B, guarda el mejor checkpoint y pushea al Hub como seguro de versionado.
