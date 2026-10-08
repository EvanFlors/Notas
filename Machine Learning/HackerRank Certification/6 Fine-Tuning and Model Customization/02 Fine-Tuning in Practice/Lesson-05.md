# Dinámicas de Entrenamiento y Debugging

## ¿Qué es?

Las **dinámicas de entrenamiento** son el conjunto de métricas y señales que emite el training loop mientras ocurre: training loss, validation loss, learning rate efectivo, gradient norm, perplejidad, memoria GPU, y métricas de tarea (accuracy, F1, BLEU). Interpretarlas en tiempo real te permite **detectar problemas en los primeros 100-500 steps** en vez de descubrirlos cuando el training termine (horas o días después).

El **debugging** es el proceso sistemático de identificar un síntoma (ej. "validation loss sube"), diagnosticar la causa raíz (overfitting, data leak, LR demasiado alto…) y aplicar la corrección mínima que lo resuelva — sin tocar diez cosas a la vez.

Para el **chatbot de soporte** del submódulo, saber leer las curvas y actuar rápido ahorra horas de GPU malgastada y evita entregar un modelo que pasa tests pero falla en producción.

### Métricas que debes monitorizar siempre

| Métrica | Qué dice | Herramienta |
|---|---|---|
| `train_loss` | Qué tan bien ajusta a train | TRL/Trainer, logging automático |
| `eval_loss` | Qué tan bien generaliza | Trainer con `eval_strategy` |
| `learning_rate` | Si el scheduler funciona | Trainer |
| `grad_norm` | Estabilidad numérica | Trainer (`logging_steps`) |
| `perplexity` | Interpretable: `exp(loss)` | Compute manual |
| GPU memory | OOM inminente | `nvidia-smi`, W&B system metrics |
| Task metric | Lo que importa en producción | `compute_metrics` custom |

## ¿Por qué importa?

Un training run de 3 horas que termina con un modelo overfitted es 3 horas tiradas. Si hubieras detectado el divergence de `eval_loss` en el step 300 (de 3,000), habrías podido abortar y relanzar con `dropout=0.15` en 10 minutos.

Además, muchos problemas son **invisibles a la pérdida**: un modelo con `train_loss=0.15` puede generar respuestas repetitivas, mal formateadas o con tokens especiales filtrados. Métricas task-específicas (accuracy en clasificación, BLEU/ROUGE en generación, LLM-as-judge en conversación) atrapan esto.

### Cuándo revisar las métricas

- **Primeros 50-100 steps:** ¿la loss baja? ¿`grad_norm` razonable? Si no, aborta y revisa data/LR.
- **Cada eval (100-500 steps):** ¿train y val caen juntas?
- **Al terminar:** compara best val loss con la del baseline. Si no mejora, no deployees.
- **En producción:** monitorea distribución de outputs y feedback real para detectar drift.

## ¿Cómo funciona?

### Lectura de curvas de loss

Las curvas (train en azul, val en rojo) revelan cuatro patrones principales:

| Patrón | Train | Val | Diagnóstico | Acción |
|---|---|---|---|---|
| **Healthy** | ↓ suave | ↓ suave, cerca | Modelo aprende y generaliza | Continuar |
| **Overfitting** | ↓ sigue bajando | ↓ y luego ↑ | Memoriza train | Más regularización, menos capacidad |
| **Underfitting** | ↓ lento, se estanca alto | ↓ lento, alto | Capacidad o datos insuficientes | Más capacidad, más datos, más epochs |
| **Instability** | ↑↓ erráticos, spikes | ↑↓ erráticos | LR alto, data corrupta, grads explosivos | Bajar LR 10×, gradient clipping, warmup |

### Herramientas de monitoreo

- **TensorBoard:** nativo en HuggingFace Trainer. `tensorboard --logdir=./logs`
- **Weights & Biases (W&B):** industry standard. Dashboards de loss, LR, gradients, system metrics (GPU util, VRAM), sweeps de hiperparámetros, comparación de runs.
- **MLflow:** alternativa open-source enfocada a tracking + registry.
- **Comet, Neptune, ClearML:** otras alternativas.

### Integración con W&B

```python
import wandb
wandb.init(
    project="chatbot-soporte",
    name="llama3-8b-lora-r16-lr2e4",
    config={
        "model": "llama3-8b",
        "lora_r": 16,
        "lora_alpha": 32,
        "lr": 2e-4,
        "batch_eff": 16,
    },
)

# TRL/Trainer registra automáticamente con report_to="wandb"
# También puedes loguear manualmente:
wandb.log({"custom/accuracy_val": 0.87, "custom/f1_val": 0.84})
```

### Extraer y analizar el log del Trainer

```python
history = trainer.state.log_history

train_losses = [h["loss"]        for h in history if "loss"      in h and "eval_loss" not in h]
val_losses   = [h["eval_loss"]   for h in history if "eval_loss" in h]
lrs          = [h["learning_rate"] for h in history if "learning_rate" in h]
grad_norms   = [h["grad_norm"]   for h in history if "grad_norm" in h]

print(f"Train final: {train_losses[-1]:.4f}")
print(f"Val best:    {min(val_losses):.4f} (step {val_losses.index(min(val_losses))*trainer.args.eval_steps})")
print(f"Grad norm medio: {sum(grad_norms)/len(grad_norms):.3f}")
```

### Perplejidad: la métrica interpretable

Perplejidad `PPL = exp(loss)`. Un modelo con `loss=2.3` tiene `PPL≈10` → en promedio, el modelo considera 10 tokens igualmente probables en cada posición. Para instruction tuning sobre dominios estrechos, buscas PPL `< 3-5`.

```python
import math
val_loss = min(val_losses)
print(f"Perplexity val: {math.exp(val_loss):.2f}")
```

### Evaluación downstream durante training

La loss baja no implica calidad. Añade un callback que evalúe en el task real:

```python
from transformers import TrainerCallback

class EvalDownstreamCallback(TrainerCallback):
    def __init__(self, eval_fn, eval_steps=500):
        self.eval_fn = eval_fn
        self.eval_steps = eval_steps

    def on_step_end(self, args, state, control, **kwargs):
        if state.global_step % self.eval_steps == 0 and state.global_step > 0:
            metrics = self.eval_fn(kwargs["model"], kwargs["tokenizer"])
            for k, v in metrics.items():
                state.log_history.append({"step": state.global_step, f"downstream/{k}": v})
            print(f"[step {state.global_step}] Downstream:", metrics)

def eval_clasificacion(model, tokenizer):
    # ... corre el modelo sobre un set de test de clasificación
    # ... compara contra labels, calcula accuracy / F1
    return {"accuracy": 0.87, "f1_macro": 0.84}

trainer.add_callback(EvalDownstreamCallback(eval_clasificacion, eval_steps=500))
```

### Diagnóstico automatizado de las curvas

```python
import numpy as np

def diagnosticar(train_losses, val_losses, grad_norms=None):
    diag = {"status": "unknown", "issues": [], "recs": []}

    if len(val_losses) < 3:
        return diag

    # Overfitting: train sigue bajando, val subiendo
    if len(val_losses) >= 10:
        trend_train = (train_losses[-1] - train_losses[-10]) / 10
        trend_val   = (val_losses[-1]   - val_losses[-10])   / 10
        if trend_train < -0.005 and trend_val > 0.005:
            diag["status"] = "overfitting"
            diag["issues"].append("val_loss ↑ mientras train_loss ↓")
            diag["recs"] += [
                "Aumenta lora_dropout de 0.05 → 0.15",
                "Reduce rank r (16 → 8) o entrena menos epochs",
                "Añade weight_decay=0.01",
                "Activa early_stopping_patience=3",
            ]

    # Underfitting: ambas altas y estancadas
    if train_losses[-1] > 1.0 and val_losses[-1] > 1.0:
        diag["status"] = "underfitting"
        diag["issues"].append("Ambas losses altas y estancadas")
        diag["recs"] += [
            "Aumenta rank r (8 → 32)",
            "Añade target_modules (sólo q/v → q/k/v/o)",
            "Aumenta learning_rate 2×",
            "Entrena más epochs",
            "Revisa calidad del dataset",
        ]

    # Inestabilidad
    if len(train_losses) >= 20:
        cv = np.std(train_losses[-20:]) / (np.mean(train_losses[-20:]) + 1e-9)
        if cv > 0.3:
            diag["issues"].append(f"Alta varianza en train_loss (CV={cv:.2f})")
            diag["recs"] += [
                "Reduce learning_rate 10× (2e-4 → 2e-5)",
                "Añade max_grad_norm=1.0",
                "Añade warmup_ratio=0.03",
            ]

    # Gradientes explosivos
    if grad_norms and max(grad_norms[-20:]) > 10:
        diag["issues"].append(f"grad_norm pico {max(grad_norms[-20:]):.2f}")
        diag["recs"].append("Activa gradient clipping: max_grad_norm=1.0")

    # Convergencia
    if len(train_losses) >= 20:
        cambio = abs(train_losses[-1] - train_losses[-10]) / (train_losses[-10] + 1e-9)
        if cambio < 0.005:
            diag["status"] = "converged"
            diag["recs"].append("Loss plateau: considera early stopping o reducir LR 10×")

    return diag

d = diagnosticar(train_losses, val_losses, grad_norms)
print(f"Status: {d['status']}")
for i in d["issues"]: print(f"  ⚠️  {i}")
for r in d["recs"]:   print(f"  → {r}")
```

### Correcciones típicas

**Overfitting:**

```python
lora_cfg = LoraConfig(
    r=8,                 # reducir capacidad
    lora_alpha=16,
    lora_dropout=0.15,   # más regularización
    target_modules=["q_proj", "v_proj"],  # menos capas
)

args = TrainingArguments(
    num_train_epochs=2,          # entrenar menos
    weight_decay=0.01,
    learning_rate=1e-4,          # LR más conservador
)

from transformers import EarlyStoppingCallback
trainer.add_callback(EarlyStoppingCallback(early_stopping_patience=3))
```

**Underfitting:**

```python
lora_cfg = LoraConfig(
    r=32,
    lora_alpha=64,
    target_modules=["q_proj","k_proj","v_proj","o_proj","gate_proj","up_proj","down_proj"],
    lora_dropout=0.05,
)
args = TrainingArguments(num_train_epochs=5, learning_rate=3e-4)
```

**Inestabilidad / NaN:**

```python
args = TrainingArguments(
    learning_rate=2e-5,          # 10× menor
    warmup_steps=500,
    warmup_ratio=0.03,
    max_grad_norm=1.0,           # clip gradients
    gradient_accumulation_steps=4,
    bf16=True,                   # bf16 más estable que fp16
)
```

### Workflow de debugging sistemático

1. **Observa síntomas** desde W&B/TensorBoard.
2. **Diagnostica** con la tabla de patrones (overfitting / underfitting / instability).
3. **Aplica una sola corrección** a la vez.
4. **Re-entrena** y compara contra el run anterior.
5. **Documenta** el experimento en una tabla (hyperparams, best val loss, task metric).

## Ejemplo con código

### Script integrado: training + diagnóstico + corrección automática

```python
import math, numpy as np, torch, wandb
from datasets import load_dataset
from transformers import AutoModelForCausalLM, AutoTokenizer, EarlyStoppingCallback
from trl import SFTTrainer, SFTConfig
from peft import LoraConfig

wandb.init(project="chatbot-soporte", name="run-con-diagnostico")

model_id = "meta-llama/Meta-Llama-3-8B-Instruct"
tok = AutoTokenizer.from_pretrained(model_id); tok.pad_token = tok.eos_token
model = AutoModelForCausalLM.from_pretrained(model_id, torch_dtype=torch.bfloat16, device_map="auto")
ds = load_dataset("json", data_files={"train":"data/soporte_train.jsonl","val":"data/soporte_val.jsonl"})

lora = LoraConfig(r=16, lora_alpha=32, target_modules=["q_proj","k_proj","v_proj","o_proj"],
                  lora_dropout=0.05, bias="none", task_type="CAUSAL_LM")

cfg = SFTConfig(
    output_dir="./ckpt",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=4,
    learning_rate=2e-4,
    lr_scheduler_type="cosine",
    warmup_ratio=0.03,
    bf16=True,
    gradient_checkpointing=True,
    max_grad_norm=1.0,
    logging_steps=10,
    eval_strategy="steps", eval_steps=100,
    save_steps=200, save_total_limit=3,
    load_best_model_at_end=True, metric_for_best_model="eval_loss",
    report_to="wandb",
)

trainer = SFTTrainer(
    model=model, args=cfg,
    train_dataset=ds["train"], eval_dataset=ds["val"],
    peft_config=lora, tokenizer=tok,
    callbacks=[EarlyStoppingCallback(early_stopping_patience=3)],
)

trainer.train()

# Diagnóstico post-training
h = trainer.state.log_history
train_losses = [x["loss"] for x in h if "loss" in x and "eval_loss" not in x]
val_losses   = [x["eval_loss"] for x in h if "eval_loss" in x]
grad_norms   = [x["grad_norm"] for x in h if "grad_norm" in x]

d = diagnosticar(train_losses, val_losses, grad_norms)
print(f"\nDiagnóstico: {d['status']}")
print(f"Best val loss: {min(val_losses):.4f}  |  PPL: {math.exp(min(val_losses)):.2f}")

wandb.log({
    "final/train_loss": train_losses[-1],
    "final/val_loss_best": min(val_losses),
    "final/perplexity": math.exp(min(val_losses)),
    "diagnostico": d["status"],
})
```

### Checkpointing resumible

```python
# Si el run cae por OOM o reinicio, reanuda sin perder progreso
trainer.train(resume_from_checkpoint=True)
```

### Push al Hub con las mejores métricas en el model card

```python
trainer.push_to_hub(
    commit_message=f"Best val_loss={min(val_losses):.4f}, PPL={math.exp(min(val_losses)):.2f}",
)
```

## Errores comunes

- **Mirar sólo train loss:** la métrica que importa es `eval_loss` + métrica downstream.
- **Cambiar varios hiperparámetros a la vez:** imposible aislar qué funcionó. Cambia uno, evalúa, repite.
- **No guardar checkpoints:** un crash a mitad del training te manda al step 0.
- **No usar `load_best_model_at_end=True`:** terminas con el modelo del último step, que puede estar overfitted frente al mejor checkpoint.
- **Olvidar early stopping:** sigues entrenando después de que val loss ya empezó a subir.
- **Confundir `grad_norm` enorme con problema de datos:** suele ser LR alto + sin warmup + sin clipping.
- **Perplejidad baja ≠ outputs buenos:** siempre complementa con eval downstream (clasificación, generación, LLM-as-judge).
- **Ignorar system metrics:** picos de VRAM al 99% presagian OOM. Baja batch o activa gradient checkpointing.
- **No fijar seeds (`torch.manual_seed`, `set_seed(42)`):** resultados no reproducibles → debugging imposible.
- **Entrenar sin W&B/TensorBoard:** sin dashboards no detectas la divergencia hasta que es tarde.
- **No versionar el config:** 6 meses después no recuerdas con qué LR y rank entrenaste. Loguea el config en W&B o en Hub model card.

## Resumen

- Las **dinámicas de entrenamiento** se leen de 4-5 métricas: `train_loss`, `eval_loss`, `learning_rate`, `grad_norm`, perplejidad y métrica downstream.
- Las curvas de loss revelan 4 patrones: **healthy, overfitting, underfitting, instability** — cada uno con fix estándar.
- **Overfitting →** más dropout, menos rank, menos epochs, early stopping.
- **Underfitting →** más rank, más target modules, más epochs, mejor data.
- **Inestabilidad →** bajar LR 10×, warmup, `max_grad_norm=1.0`, `bf16` en vez de `fp16`.
- Monitoriza con **Weights & Biases** (industry default) o TensorBoard; añade **callbacks downstream** para medir calidad real, no sólo loss.
- Usa **early stopping**, `load_best_model_at_end=True`, checkpointing cada 200-500 steps y push al Hub como seguro.
- Debugging = **un cambio a la vez**, re-entrena, compara, documenta.
- Para el chatbot de soporte: baseline `r=16, alpha=32, dropout=0.05, lr=2e-4`, 3 epochs; si overfitting → `r=8, dropout=0.15`; si underfitting → `r=32, all-linear`.
- Reproducibilidad siempre: `set_seed(42)`, log del config, versiona dataset.
