# Prompting vs RAG vs Fine-Tuning

## ¿Qué es?

El **espectro de personalización de modelos** describe las cuatro técnicas que un ingeniero de IA puede combinar para que un LLM resuelva una tarea específica. De menor a mayor complejidad:

1. **Prompt engineering** — redactar instrucciones y ejemplos cuidadosamente para guiar al modelo *sin modificarlo*.
2. **Retrieval-Augmented Generation (RAG)** — recuperar documentos relevantes de una base externa e inyectarlos en el prompt como contexto.
3. **PEFT (Parameter-Efficient Fine-Tuning)** — entrenar un subconjunto pequeño de parámetros nuevos (LoRA, adapters) sobre un modelo base congelado.
4. **Full fine-tuning** — actualizar *todos* los pesos del modelo con tus datos.

La decisión no es "cuál es mejor" sino **cuál es la más barata y mantenible que resuelve tu problema**. La regla heurística es *la escalera de personalización*: empieza en el escalón 1 y sube solo cuando tengas evidencia medible de que el nivel actual no alcanza.

> **Insight clave:** la mayoría de los equipos saltan directo a fine-tuning por *hype* y descubren después que un prompt bien escrito + RAG resolvía el 90% del problema a 1/100 del costo.

### El eje "conocimiento vs capacidad"

Toda falla de un LLM cae en una de dos categorías:

| Tipo de brecha | Síntoma | Solución |
|---|---|---|
| **Brecha de conocimiento** | El modelo no sabe un dato específico (política interna, documentación reciente, catálogo de productos) | **RAG** |
| **Brecha de capacidad** | El modelo no sabe *cómo* responder (tono, formato, dominio, razonamiento específico) | **Fine-tuning** |

**Prueba práctica:** si pudieras resolver el problema entregándole al modelo un PDF con la información correcta, es brecha de conocimiento → RAG. Si necesitas que *aprenda un patrón nuevo de comportamiento*, es brecha de capacidad → fine-tuning.

## ¿Por qué importa?

Elegir el nivel equivocado tiene costos reales:

- **Sobre-ingeniería (ir muy alto):** gastar $5,000 en una corrida de fine-tuning cuando un prompt de 50 líneas te daba 92% de accuracy. Más deuda técnica, más mantenimiento, menos agilidad.
- **Sub-ingeniería (quedarse muy bajo):** forzar prompts gigantes de 10,000 tokens cuando un LoRA entrenado una tarde hubiera reducido latencia a la mitad y mejorado consistencia.
- **Confundir las herramientas:** usar fine-tuning para *memorizar* la lista de precios (cambia semanalmente → tendrías que re-entrenar cada semana). Lo correcto es RAG.
- **Costo de oportunidad:** cada semana que un ingeniero pasa curando un dataset de fine-tuning es una semana que no está midiendo el producto con usuarios reales.

En producción, el error típico no es técnico sino **estratégico**: no distinguir qué está roto antes de elegir cómo arreglarlo.

## ¿Cómo funciona?

### Nivel 1: Prompt Engineering

El modelo base ya sabe clasificar, extraer y generar. El prompt le indica *qué* y *cómo*. Técnicas estándar:

- **Zero-shot:** solo instrucción.
- **Few-shot:** instrucción + 2-10 ejemplos (`in-context learning`, Brown et al. 2020, GPT-3).
- **Chain-of-thought (CoT):** pedir razonamiento paso a paso (Wei et al. 2022).
- **Structured output:** forzar JSON schema o function calling.

**Ventajas:** cero infraestructura, iteración en segundos, cambios en caliente.
**Límites:** no cambia el estilo del modelo, consume tokens de contexto en cada request, techo de desempeño.

### Nivel 2: RAG (Retrieval-Augmented Generation)

Agrega una capa externa de conocimiento. El flujo típico:

```
pregunta → embed → búsqueda semántica → top-k docs → prompt enriquecido → modelo
```

**Cuándo usar:** información que cambia (docs, precios, políticas), fuentes citables, bases propietarias que no quieres meter al modelo.
**Costo extra:** vector DB (Pinecone, Weaviate, Qdrant, pgvector) + 100-500 ms de latencia por request.

### Nivel 3: PEFT (LoRA, QLoRA, Adapters)

En vez de actualizar los **d² parámetros** de una matriz de atención, LoRA aprende dos matrices pequeñas `A ∈ ℝ^(d×r)` y `B ∈ ℝ^(r×d)` tales que:

```
W' = W + ΔW  donde  ΔW = B·A    (rango r ≪ d)
```

**Parámetros entrenables:** `2·r·d` en lugar de `d²`.

Ejemplo con `d = 4096` y `r = 8`:
- Full: `4096² = 16,777,216` parámetros por matriz.
- LoRA: `2 · 8 · 4096 = 65,536` → **reducción ~256x** (y hasta ~1000x con `r = 4`).

**QLoRA** (Dettmers et al. 2023) añade cuantización 4-bit al modelo base congelado: permite entrenar un modelo de 65B en una sola GPU de 48 GB.

### Nivel 4: Full Fine-Tuning

Se actualizan todos los pesos. Modalidades principales:

- **SFT (Supervised Fine-Tuning):** pares `(prompt, respuesta esperada)`. Loss = cross-entropy sobre la respuesta.
- **Continued pre-training:** más tokens no supervisados del dominio (código legal, biomédico) para inyectar conocimiento profundo.
- **Instruction tuning:** SFT sobre un dataset grande y variado de instrucciones (ej. Alpaca, Dolly, FLAN).
- **DPO (Direct Preference Optimization):** aprende de pares `(preferida, rechazada)` sin modelo de recompensa (Rafailov et al. 2023; alternativa simplificada a RLHF).
- **RLHF (Reinforcement Learning from Human Feedback):** reward model + PPO. Caro pero fue la receta de ChatGPT (Ouyang et al. 2022).

### Decision tree completo

```
┌─────────────────────────────────────────────────────┐
│ 1. ¿El modelo base entiende la tarea?               │
│    NO → mejor prompt (CoT, ejemplos, system msg)    │
│    SÍ ↓                                             │
│                                                     │
│ 2. ¿La brecha es de CONOCIMIENTO o CAPACIDAD?       │
│    Conocimiento → RAG                               │
│    Capacidad    ↓                                   │
│                                                     │
│ 3. ¿Tienes 500-5,000 ejemplos de calidad?           │
│    NO → vuelve a prompt + few-shot                  │
│    SÍ ↓                                             │
│                                                     │
│ 4. ¿Basta con ajuste de estilo/formato?             │
│    SÍ → PEFT (LoRA / QLoRA)                         │
│    NO ↓                                             │
│                                                     │
│ 5. ¿Tienes 10K+ ejemplos y GPUs grandes?            │
│    SÍ → Full fine-tuning (SFT + DPO)                │
│    NO → quédate en PEFT y mejora el dataset         │
└─────────────────────────────────────────────────────┘
```

### Comparativa resumen

| Nivel | Costo inicial | Costo por request | Latencia | Flexibilidad | Cambio que logra |
|---|---|---|---|---|---|
| Prompt | $0 | Alto (muchos tokens) | Alta | Máxima | Guiar comportamiento existente |
| RAG | $200-500/mes (vector DB) | Alto + infra | +100-500 ms | Alta | Agregar conocimiento |
| PEFT (LoRA) | $10-200 por run | Casi $0 self-hosted | Baja | Media (varios adapters) | Estilo, formato, tareas nuevas |
| Full FT | $500-50K por run | Casi $0 self-hosted | Baja | Baja (un artefacto) | Capacidades profundas |

## Ejemplo con código

### 1. Estimador de costo: ¿me conviene fine-tunear?

```python
# ============================================================
# ¿Vale la pena hacer fine-tuning vs seguir pagando API?
# ============================================================
from dataclasses import dataclass

@dataclass
class CostoAPI:
    nombre: str
    usd_por_1k_input: float
    usd_por_1k_output: float

@dataclass
class CostoSelfHosted:
    nombre: str
    gpu_usd_por_hora: float   # A10G ~$1, A100 ~$3, H100 ~$8
    horas_entrenamiento: float
    gpu_inferencia_usd_mes: float  # infra siempre encendida

def costo_api_mensual(api: CostoAPI, requests_mes: int,
                      tokens_in: int = 500, tokens_out: int = 200) -> float:
    costo_req = (tokens_in / 1000) * api.usd_por_1k_input + \
                (tokens_out / 1000) * api.usd_por_1k_output
    return costo_req * requests_mes

def costo_self_hosted_mensual(sh: CostoSelfHosted, meses_amortizacion: int = 6) -> float:
    costo_entrenamiento = sh.gpu_usd_por_hora * sh.horas_entrenamiento
    return sh.gpu_inferencia_usd_mes + (costo_entrenamiento / meses_amortizacion)

# Escenario: 500K requests/mes, dataset de 2000 ejemplos
gpt4o = CostoAPI("GPT-4o", 2.50/1000, 10.00/1000)   # $2.50/1M input
llama_lora = CostoSelfHosted(
    nombre="Llama-3-8B + LoRA",
    gpu_usd_por_hora=3.0,          # A100 en Modal/Together
    horas_entrenamiento=4,          # LoRA sobre 2000 ejemplos
    gpu_inferencia_usd_mes=600,     # A10G 24/7
)

volumenes = [1_000, 10_000, 100_000, 500_000, 2_000_000]
print(f"{'Requests/mes':<15} {'GPT-4o':<12} {'LoRA self-hosted':<20} {'Break-even?'}")
print("-" * 65)
for v in volumenes:
    c_api = costo_api_mensual(gpt4o, v)
    c_sh = costo_self_hosted_mensual(llama_lora)
    winner = "self-hosted" if c_sh < c_api else "API"
    print(f"{v:<15,} ${c_api:<11.0f} ${c_sh:<19.0f} {winner}")
```

**Lectura típica:** por debajo de ~50K-100K requests/mes la API gana; a partir de ahí self-hosted amortiza la GPU.

### 2. Ejemplo de cuándo NO fine-tunear (bastaba few-shot)

```python
# ============================================================
# Antipatrón: fine-tuning para clasificar sentimiento en 3 clases
# ============================================================
# Antes de gastar $500 en una corrida, prueba esto:

from openai import OpenAI
client = OpenAI()

FEW_SHOT_PROMPT = """Clasifica el sentimiento como POSITIVO, NEGATIVO o NEUTRAL.

Ejemplos:
"Me encanta este producto, lo recomiendo" -> POSITIVO
"Llegó roto y nadie me contesta" -> NEGATIVO
"El pedido llegó a tiempo" -> NEUTRAL
"Horrible atención, pido reembolso" -> NEGATIVO
"Mejor compra del año!" -> POSITIVO

Texto: "{texto}"
Sentimiento:"""

def clasificar(texto: str) -> str:
    resp = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[{"role": "user", "content": FEW_SHOT_PROMPT.format(texto=texto)}],
        max_tokens=5, temperature=0,
    )
    return resp.choices[0].message.content.strip()

# Si al medir sobre 200 ejemplos reales obtienes >92% accuracy,
# NO fine-tunees. Costo: $0.0001/clasificación vs $600/mes + 4h de entrenamiento.
```

**Regla:** si prompt + few-shot alcanza el SLA, fine-tunear es destruir valor.

### 3. LoRA mínimo con HuggingFace PEFT

```python
# ============================================================
# PEFT con LoRA: adaptar Llama-3-8B al estilo de soporte interno
# ============================================================
from peft import LoraConfig, get_peft_model, TaskType
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments
from trl import SFTTrainer

model_id = "meta-llama/Meta-Llama-3-8B-Instruct"
tokenizer = AutoTokenizer.from_pretrained(model_id)
model = AutoModelForCausalLM.from_pretrained(model_id, load_in_4bit=True)  # QLoRA

lora_config = LoraConfig(
    task_type=TaskType.CAUSAL_LM,
    r=16,                # rango bajo → ~0.1% de parámetros entrenables
    lora_alpha=32,       # escala del adapter
    lora_dropout=0.05,
    target_modules=["q_proj", "v_proj", "k_proj", "o_proj"],
)

model = get_peft_model(model, lora_config)
model.print_trainable_parameters()
# Ejemplo: trainable params: 8,388,608 || all params: 8,038,000,000
# -> 0.104% entrenables (reducción ~1000x vs full FT)

args = TrainingArguments(
    output_dir="./lora-soporte",
    num_train_epochs=3,
    per_device_train_batch_size=4,
    gradient_accumulation_steps=4,
    learning_rate=2e-4,
    bf16=True,
    logging_steps=10,
    save_strategy="epoch",
)

trainer = SFTTrainer(
    model=model, tokenizer=tokenizer,
    train_dataset=dataset_soporte,   # 500-2000 ejemplos (prompt, respuesta_estilo_interno)
    eval_dataset=dataset_eval,       # NUNCA olvidar el eval set
    args=args, max_seq_length=2048,
)
trainer.train()
```

## Errores comunes

- **Fine-tunear cuando bastaba RAG.** El modelo olvida información nueva cada vez que la base de conocimiento cambia; con RAG actualizas un índice en segundos.
- **Dataset demasiado pequeño.** Menos de ~500-1000 ejemplos rara vez justifica fine-tuning: el modelo memoriza y pierde generalización. Primero invierte en few-shot y evaluación.
- **Olvidar el eval set.** Si entrenas sin un conjunto *holdout* medido con la misma métrica que te importa en producción, no sabes si mejoraste o empeoraste.
- **Catastrophic forgetting.** Fine-tuning agresivo degrada capacidades generales del modelo (razonamiento, idiomas, código). Mitigaciones: LoRA en vez de full, mezclar datos genéricos (10-20%), learning rate bajo (`1e-5` a `2e-4`).
- **Overfitting al estilo de 3 autores.** Dataset sin diversidad (siempre el mismo redactor) produce un modelo que suena idéntico a esa persona y falla fuera de distribución.
- **Confundir fine-tuning con inyección de conocimiento.** El fine-tuning *puede* memorizar hechos, pero es carísimo y frágil comparado con RAG. Úsalo para **comportamiento**, no para **datos**.
- **Elegir el modelo más grande por defecto.** 7B con un buen LoRA le gana a 70B base en tareas acotadas y cuesta 10x menos.
- **Ignorar el costo total de ownership.** El fine-tuning no termina en el training: hay versionado, re-entrenamiento, monitoreo de drift, A/B testing.
- **Saltarse la escalera.** Ir directo a full fine-tuning sin medir prompt engineering es la causa #1 de proyectos de IA sobre-presupuestados.

### Contexto histórico y papers clave

| Año | Hito | Referencia |
|---|---|---|
| 2020 | GPT-3 muestra que *in-context learning* reemplaza mucho fine-tuning | Brown et al. 2020 |
| 2021 | LoRA: adaptación de bajo rango | Hu et al. 2021 |
| 2022 | InstructGPT / RLHF | Ouyang et al. 2022 |
| 2023 | Alpaca / Vicuna democratizan el instruction tuning | Stanford, LMSYS |
| 2023 | QLoRA: fine-tuning de 65B en una GPU de 48 GB | Dettmers et al. 2023 |
| 2023 | DPO: preferencias sin reward model | Rafailov et al. 2023 |
| 2024+ | Unsloth, Axolotl, TRL maduran el ecosistema | HuggingFace |

### Herramientas del ecosistema

- **APIs gestionadas:** OpenAI fine-tuning API, Anthropic fine-tuning vía AWS Bedrock, Google Vertex AI.
- **Open source:** HuggingFace `transformers` + `peft` + `trl`, Axolotl, Unsloth (2-5x más rápido).
- **Infra on-demand:** Together AI, Modal, Replicate, RunPod, Lambda Labs.
- **Experiment tracking:** Weights & Biases, MLflow, Comet.

## Resumen

- Existen **cuatro niveles** de personalización: prompt engineering, RAG, PEFT y full fine-tuning. Cada uno resuelve un problema distinto.
- **RAG arregla brechas de conocimiento; fine-tuning arregla brechas de capacidad.** Confundirlos es el error más caro.
- Sigue la **escalera de personalización**: empieza con prompts, sube solo con evidencia de que el nivel actual no basta.
- **LoRA** entrena `2·r·d` parámetros en vez de `d²` → reducción típica de ~1000x en memoria y tiempo, con pérdida de calidad mínima.
- **QLoRA** suma cuantización 4-bit y permite entrenar modelos de 65B en una sola GPU.
- **SFT** aprende de pares `(prompt, respuesta)`; **DPO** aprende de preferencias `(preferida, rechazada)` sin reward model; **continued pre-training** inyecta conocimiento de dominio.
- Con menos de **500-1000 ejemplos**, el fine-tuning rara vez supera a few-shot bien hecho.
- El break-even entre API gestionada y self-hosted suele estar entre **50K y 100K requests/mes**.
- Siempre **mide con un eval set** antes y después; sin eso, el fine-tuning es cargo culto.
- Nunca fine-tunees información que cambia cada mes: eso es un problema de **RAG**, no de pesos.
