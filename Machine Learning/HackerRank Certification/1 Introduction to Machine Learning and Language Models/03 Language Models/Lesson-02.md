# BERT: Modelado de Lenguaje Enmascarado para Tareas de Entendimiento

## ¿Qué es?

**BERT** (*Bidirectional Encoder Representations from Transformers*) es un modelo de lenguaje publicado por Google AI en octubre de 2018 (Devlin et al., *"BERT: Pre-training of Deep Bidirectional Transformers for Language Understanding"*). Fue el primer modelo que logró un **entendimiento verdaderamente bidireccional** del texto gracias a dos ideas clave:

1. **Arquitectura encoder-only** basada únicamente en la mitad "encoder" del Transformer original (Vaswani et al., 2017).
2. **Masked Language Modeling (MLM)**: un objetivo de entrenamiento donde el modelo debe adivinar palabras ocultas usando contexto de ambos lados.

Formalmente, BERT aprende una función `f_θ: tokens → vectores contextuales` tal que cada token `wᵢ` se representa como un vector `hᵢ ∈ ℝ^d` que depende de **toda** la secuencia:

```
hᵢ = f_θ(w₁, w₂, …, wᵢ, …, wₙ)
```

A diferencia de los modelos autorregresivos (GPT), donde `hᵢ` depende sólo de `w₁..wᵢ₋₁`, en BERT `hᵢ` ve también `wᵢ₊₁..wₙ`. Esto se logra permitiendo que la atención *vea en ambas direcciones* durante el entrenamiento.

![Arquitectura BERT](https://hrcdn.net/ai-engineering/module-1/light/language-models-lesson02-bert-architecture-full.svg)

### Versiones oficiales

| Modelo | Capas | Dimensión | Cabezas de atención | Parámetros |
|---|---|---|---|---|
| BERT-base | 12 | 768 | 12 | 110 M |
| BERT-large | 24 | 1024 | 16 | 340 M |
| DistilBERT | 6 | 768 | 12 | 66 M (40% más pequeño) |
| RoBERTa-base | 12 | 768 | 12 | 125 M (más datos, sin NSP) |
| ALBERT-base | 12 | 768 | 12 | 12 M (parámetros compartidos) |

## ¿Por qué importa?

Antes de BERT, los modelos de NLP se construían **desde cero** para cada tarea. BERT inauguró la era del **pre-entrenamiento + fine-tuning**: un único modelo masivo entrenado una sola vez sobre todo Wikipedia + BooksCorpus, y luego adaptado a decenas de tareas con pocos ejemplos.

Impacto medible: en el momento de su publicación, BERT **rompió el estado del arte en 11 benchmarks de NLP simultáneamente** (GLUE, SQuAD 1.1 y 2.0, SWAG). Google integró BERT a su buscador en 2019 para mejorar la comprensión de queries (afecta ~10% de todas las búsquedas).

### Casos de uso donde BERT brilla

| Tarea | Ejemplo real | Métrica |
|---|---|---|
| Clasificación de intención | Routing de tickets en Zendesk | F1 macro |
| Análisis de sentimiento | Reviews de Amazon/Yelp | Accuracy |
| NER (biomédico, legal, financiero) | BioBERT, LegalBERT, FinBERT | F1 por entidad |
| Question Answering extractivo | SQuAD, buscador de Google | Exact Match / F1 |
| Similitud semántica | Sentence-BERT para búsqueda vectorial | Cosine similarity |
| Detección de parafraseo | MRPC, PAWS | Accuracy |
| Natural Language Inference | SNLI, MNLI | Accuracy |

### Por qué la bidireccionalidad importa

Considera dos oraciones con la palabra "banco":

> "El **banco** puede garantizar que los depósitos cubrirán la colegiatura."
> "El **banco** del río estaba cubierto de hojas."

Un modelo left-to-right (como GPT-1) ve sólo "El" antes de procesar "banco". BERT ve también "depósitos" o "río" **al mismo tiempo**, lo que resuelve la ambigüedad en una sola pasada.

![Atención bidireccional](https://hrcdn.net/ai-engineering/module-1/light/language-models-lesson02-bidirectional-attention.svg)

## ¿Cómo funciona?

BERT se entrena en dos fases: **pre-entrenamiento** (una sola vez, costoso) y **fine-tuning** (por tarea, barato).

### Pre-entrenamiento: dos objetivos

#### 1. Masked Language Modeling (MLM)

Se enmascara aproximadamente el **15%** de los tokens de cada secuencia y el modelo debe predecirlos. Para evitar que el modelo se vuelva dependiente del token `[MASK]` (que no existe en producción), Devlin et al. aplicaron una estrategia **80/10/10**:

| Probabilidad | Acción | Ejemplo (`cat`) |
|---|---|---|
| 80% | Reemplazar por `[MASK]` | `cat → [MASK]` |
| 10% | Reemplazar por token aleatorio | `cat → dog` |
| 10% | Dejar sin cambio | `cat → cat` |

La pérdida se calcula **sólo sobre las posiciones enmascaradas** usando cross-entropy:

```
L_MLM = -Σ_{i ∈ M} log P(wᵢ | w₍\M₎)
```

donde `M` es el conjunto de posiciones enmascaradas y `w₍\M₎` el resto de la secuencia.

#### 2. Next Sentence Prediction (NSP)

Dado un par de oraciones (A, B), el modelo predice si B sigue realmente a A (positivo) o es aleatoria (negativo). Esto le enseña a entender relaciones entre oraciones (útil para QA y NLI).

> **Nota crítica:** Estudios posteriores (RoBERTa, 2019) mostraron que NSP **no aporta**; eliminarlo y entrenar sólo con MLM mejora resultados. La mayoría de modelos modernos tipo BERT omiten NSP.

### Fine-tuning: una tarea, una cabeza

Tras el pre-entrenamiento, se añade una pequeña capa `cabeza` sobre BERT (lineal + softmax para clasificación, lineal por token para NER, etc.) y se entrena todo el conjunto con tus datos específicos durante 2–4 épocas con un learning rate bajo (típicamente 2e-5 a 5e-5).

```
Pre-entrenamiento (una vez, caro, Google-tier)
    ↓
Checkpoint `bert-base-uncased` publicado
    ↓
Fine-tuning sobre TU dataset (horas, no días)
    ↓
Modelo listo para producción
```

### Arquitectura interna

Cada capa de BERT es un bloque Transformer **encoder** compuesto por:

1. **Multi-Head Self-Attention** (bidireccional, sin máscara causal).
2. **Add & Norm** (residual + LayerNorm).
3. **Feed-Forward Network** (dos linears + GELU).
4. **Add & Norm** otra vez.

```
Entrada:  [CLS] el gato se sentó [SEP] perseguía al ratón [SEP]
           ↓   ↓   ↓   ↓   ↓     ↓
         [Embedding + Positional + Segment]
           ↓
         12× [MHA bidireccional → FFN]
           ↓
         Vectores contextuales (768-d por token)
```

Tokens especiales:

- `[CLS]`: añadido al inicio; su vector final se usa como representación del documento para clasificación.
- `[SEP]`: separa segmentos (preguntas/contextos, oración A/B).
- `[MASK]`: usado en pre-entrenamiento.
- `[PAD]`: relleno hasta longitud fija.

### Encoder vs. Decoder

![Encoder](https://hrcdn.net/ai-engineering/module-1/light/language-models-lesson02-encoder-concept.svg)

| Aspecto | Encoder (BERT) | Decoder (GPT) |
|---|---|---|
| Atención | Bidireccional | Causal (left-to-right) |
| Objetivo | Reconstruir tokens enmascarados | Predecir siguiente token |
| Fortaleza | Entender texto existente | Generar texto nuevo |
| Salida típica | Vector por token | Distribución sobre vocabulario |
| Buena para | Clasificación, NER, QA extractiva, similitud | Chatbots, redacción, código |
| Mala para | Generación libre | Clasificación pura con poca data |

![Decoder](https://hrcdn.net/ai-engineering/module-1/light/language-models-lesson02-decoder-concept.svg)

### Tokenización WordPiece

BERT no trabaja con palabras completas sino con **subpalabras** mediante el algoritmo **WordPiece**. Ejemplo:

```
"unhappiness" → ["un", "##happiness"] → ["un", "##happy", "##ness"]
```

Esto permite manejar palabras raras sin inflar el vocabulario (BERT usa ~30,522 tokens). El prefijo `##` indica continuación de la palabra anterior.

Comparación con otros esquemas:

| Algoritmo | Modelo que lo usa | Idea central |
|---|---|---|
| **BPE** (Byte-Pair Encoding) | GPT-2, RoBERTa | Fusiona pares frecuentes de bytes |
| **WordPiece** | BERT, DistilBERT | Fusiona pares que maximizan likelihood |
| **SentencePiece / Unigram** | T5, XLNet, LLaMA | Modelo probabilístico, maneja idiomas sin espacios |
| **tiktoken** | GPT-3.5/4, GPT-4o | BPE optimizado por OpenAI |

## Ejemplo con código

### 1. Explorar bidireccionalidad vs. causal

```python
def analizar_contexto(oracion, pos):
    tokens = oracion.split()
    objetivo = tokens[pos]
    izq = tokens[:pos]
    der = tokens[pos + 1:]
    print(f"Palabra objetivo: '{objetivo}'  (posición {pos})")
    print(f"  Left-to-right (GPT ve):   {' '.join(izq) or '∅'}")
    print(f"  Bidireccional (BERT ve):  {' '.join(izq)} ___ {' '.join(der)}")

analizar_contexto("El banco puede garantizar depósitos para colegiatura", 1)
analizar_contexto("El banco del río estaba cubierto de hojas",            1)
```

### 2. Usar BERT pre-entrenado para fill-mask

```python
# pip install transformers torch
from transformers import pipeline

mlm = pipeline("fill-mask", model="dccuchile/bert-base-spanish-wwm-cased")

for oracion in [
    "El doctor recetó un [MASK] para el dolor de cabeza.",
    "París es la capital de [MASK].",
    "La inteligencia artificial transformará la [MASK] en los próximos años.",
]:
    print(f"\nEntrada: {oracion}")
    for cand in mlm(oracion)[:3]:
        print(f"  {cand['token_str']:<15} (score={cand['score']:.3f})")
```

### 3. Fine-tuning de BERT para clasificación de sentimiento

```python
# pip install transformers datasets evaluate accelerate
from datasets import load_dataset
from transformers import (
    AutoTokenizer, AutoModelForSequenceClassification,
    TrainingArguments, Trainer, DataCollatorWithPadding,
)
import evaluate, numpy as np

MODEL = "distilbert-base-multilingual-cased"
tokenizer = AutoTokenizer.from_pretrained(MODEL)

ds = load_dataset("amazon_reviews_multi", "es")  # reviews en español 1-5 estrellas
ds = ds.map(lambda ex: {"label": 0 if ex["stars"] <= 2 else (1 if ex["stars"] == 3 else 2)})

def tok(batch):
    return tokenizer(batch["review_body"], truncation=True, max_length=256)

ds_tok = ds.map(tok, batched=True)
collator = DataCollatorWithPadding(tokenizer=tokenizer)

model = AutoModelForSequenceClassification.from_pretrained(MODEL, num_labels=3)
metric = evaluate.load("f1")

def compute_metrics(eval_pred):
    logits, labels = eval_pred
    preds = np.argmax(logits, axis=-1)
    return metric.compute(predictions=preds, references=labels, average="macro")

args = TrainingArguments(
    output_dir="./out",
    learning_rate=3e-5,
    per_device_train_batch_size=16,
    per_device_eval_batch_size=32,
    num_train_epochs=3,
    weight_decay=0.01,
    evaluation_strategy="epoch",
    save_strategy="epoch",
    load_best_model_at_end=True,
    metric_for_best_model="f1",
)

trainer = Trainer(
    model=model, args=args,
    train_dataset=ds_tok["train"].select(range(5000)),
    eval_dataset=ds_tok["validation"].select(range(1000)),
    tokenizer=tokenizer, data_collator=collator,
    compute_metrics=compute_metrics,
)

trainer.train()
```

### 4. NER con BERT fine-tuned

```python
from transformers import pipeline

ner = pipeline(
    "token-classification",
    model="mrm8488/bert-spanish-cased-finetuned-ner",
    aggregation_strategy="simple",
)

texto = ("Lionel Messi fichó por el Inter Miami en julio de 2023 "
         "tras dejar el Paris Saint-Germain.")
for ent in ner(texto):
    print(f"{ent['word']:<25} {ent['entity_group']:<6} score={ent['score']:.2f}")
```

### 5. Simulación didáctica de MLM (estrategia 80/10/10)

```python
import random

def mlm_demo(oracion, prob=0.15, seed=0):
    random.seed(seed)
    tokens = oracion.split()
    etiquetas, entrada = [], []
    for t in tokens:
        if random.random() < prob:
            r = random.random()
            if r < 0.8:
                entrada.append("[MASK]")
            elif r < 0.9:
                entrada.append(random.choice(["azul", "corre", "manzana"]))
            else:
                entrada.append(t)
            etiquetas.append(t)
        else:
            entrada.append(t); etiquetas.append("_")
    print("Entrada :", " ".join(entrada))
    print("Objetivo:", " ".join(etiquetas))

mlm_demo("El modelo aprende patrones semánticos del lenguaje natural", seed=7)
```

## Errores comunes

- **Usar BERT para generar texto.** Es encoder-only; no está entrenado para generación autorregresiva. Para generar usa GPT, LLaMA, T5 o similares.
- **Fine-tuning con learning rate alto.** Valores >1e-4 catastróficamente destruyen los pesos pre-entrenados (*catastrophic forgetting*). Usa 2e-5 a 5e-5.
- **No usar `[CLS]` para clasificación.** La convención es tomar el vector `[CLS]` (o un mean-pooling) para alimentar la cabeza clasificadora.
- **Truncar sin pensar.** BERT acepta máximo 512 tokens. Documentos largos requieren estrategias: sliding window, Longformer, BigBird o jerarquías (BERT por párrafo + agregador).
- **Olvidar la máscara de atención.** Si no pasas `attention_mask` el modelo atiende a los `[PAD]`, degradando resultados.
- **Mezclar tokenizer y modelo distintos.** `bert-base-cased` requiere `AutoTokenizer.from_pretrained("bert-base-cased")`; usar otro tokenizador rompe silenciosamente la segmentación.
- **Fine-tuning con pocos datos sin regularización.** BERT tiene 110M parámetros; con <1k ejemplos sobreajusta. Usa early stopping, dropout, data augmentation o considera adapters/LoRA.
- **Sesgos heredados.** BERT fue entrenado en Wikipedia/libros; aprende sesgos de género, raza y región. Auditar con benchmarks como StereoSet, CrowS-Pairs.
- **Ignorar la variante en español.** Para texto en español usar modelos en inglés degrada 10–30 puntos de F1. Alternativas: BETO, MarIA, mBERT, XLM-R.
- **Confundir BERT con un chatbot.** BERT **no** genera respuestas conversacionales; para chat usa modelos tipo GPT/Claude o un pipeline T5/BART.

## Comparación: BERT vs. GPT vs. T5

| Dimensión | BERT | GPT | T5 |
|---|---|---|---|
| Arquitectura | Encoder-only | Decoder-only | Encoder-Decoder |
| Objetivo | MLM (+ NSP) | Next-token | Span-corruption |
| Atención | Bidireccional | Causal | Mixto |
| Tarea natural | Entender | Generar | Seq2Seq |
| Clasificación | Excelente | Bueno con prompt | Excelente con "text-to-text" |
| Generación | No puede | Excelente | Bueno |
| Año | 2018 | 2018–presente | 2019 |

## Cuándo elegir BERT

**Sí, elige BERT cuando:**

- Necesitas **clasificar** o **extraer entidades** sobre texto corto/medio (<512 tokens).
- Tienes al menos **1,000–10,000 ejemplos etiquetados** para fine-tuning.
- Latencia moderada es aceptable (10–50 ms por request en GPU, 100–300 ms en CPU).
- Necesitas **embeddings densos** para búsqueda semántica (Sentence-BERT).

**No elijas BERT si:**

- Necesitas generar texto libre (usa GPT, Claude, LLaMA).
- Tienes <100 ejemplos (usa few-shot con un LLM grande).
- Debes correr en edge/móvil con <50 MB (usa DistilBERT, TinyBERT, MobileBERT).
- Trabajas con documentos muy largos (usa Longformer, BigBird, o chunking).

## Resumen

- **BERT** (Devlin et al., 2018) es un modelo **encoder-only** con atención **bidireccional**, entrenado con **Masked Language Modeling** y, originalmente, Next Sentence Prediction.
- Su gran aporte fue inaugurar el paradigma **pre-entrenamiento + fine-tuning**: un modelo masivo general que se adapta a muchas tareas con pocos ejemplos.
- Excelente para **entendimiento**: clasificación, NER, QA extractivo, similitud semántica. **No sirve** para generar texto.
- Usa **WordPiece** para tokenización en subpalabras (vocabulario de ~30k).
- La estrategia **80/10/10** en MLM evita que el modelo dependa del token `[MASK]` en producción.
- Variantes modernas: **RoBERTa** (sin NSP, más datos), **DistilBERT** (60% más rápido), **ALBERT** (parámetros compartidos), y versiones de dominio: **BioBERT**, **LegalBERT**, **FinBERT**, **BETO** (español).
- Fine-tuning: learning rate bajo (**2e-5 a 5e-5**), 2–4 épocas, batch 16–32, early stopping sobre validación.
- Limitaciones: máximo **512 tokens**, 110M+ parámetros (costo de inferencia), heredará sesgos del corpus de pre-entrenamiento.
- BERT inaugura la familia de **encoders-only**; la siguiente lección cubre la familia complementaria —**decoders-only** tipo GPT— especializada en generación.
