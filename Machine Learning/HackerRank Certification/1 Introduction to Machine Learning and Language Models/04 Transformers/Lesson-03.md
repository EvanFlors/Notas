# Arquitecturas de Transformer: Encoder-only, Decoder-only y Encoder-Decoder

## ¿Qué es?

Los **mismos bloques Transformer** (atención + FFN + residuales + LayerNorm, como vimos en Lesson-02) pueden organizarse en **tres patrones arquitecturales fundamentalmente distintos** según cómo fluye la atención y qué tarea se busca resolver:

1. **Encoder-only** — atención **bidireccional**. Todos los tokens se ven entre sí. Óptimo para *entender* texto.
2. **Decoder-only** — atención **causal (masked)**. Cada token solo ve a los anteriores. Óptimo para *generar* texto.
3. **Encoder-Decoder** — combina ambos. El encoder entiende la entrada bidireccionalmente, el decoder genera la salida de forma causal con **cross-attention** sobre las representaciones del encoder. Óptimo para *transformar* entrada en salida.

> **Analogía:** piensa en tres layouts distintos de fábrica usando la misma maquinaria. Una línea para **inspeccionar** productos terminados (encoder), una para **fabricar** productos desde cero (decoder), y una fábrica que **inspecciona materias primas y luego las transforma** en productos nuevos (encoder-decoder).

### Mapa rápido de ejemplos

| Arquitectura | Ejemplos de modelos | Tareas naturales |
|---|---|---|
| Encoder-only | BERT, RoBERTa, DeBERTa, DistilBERT, ELECTRA, ModernBERT | Clasificación, NER, QA extractivo, embeddings, búsqueda semántica |
| Decoder-only | GPT-2/3/4, Claude, LLaMA, Mistral, Qwen, Gemma, DeepSeek | Chat, generación, código, razonamiento, instruction-following |
| Encoder-Decoder | T5, BART, mT5, Flan-T5, Pegasus, Whisper, NLLB | Traducción, resumen, parafraseo, data-to-text, ASR |

## ¿Por qué importa?

Elegir mal la arquitectura es un error caro:

- Usar **GPT** para clasificar sentimientos cuando tienes dataset etiquetado → desperdicias cómputo y tiempo. BERT fine-tuned será más rápido, barato y preciso.
- Usar **BERT** para generar texto → no puede, su objetivo no es modelar `P(x_t | x_{<t})`.
- Usar **decoder-only** para traducción cuando puedes usar **T5/NLLB** → T5 fue diseñado exactamente para eso y suele ser mejor en benchmarks con menos parámetros.

Pero también hay convergencia práctica: con *instruction tuning*, los **decoder-only** modernos (GPT-4, Claude, LLaMA 3) resuelven razonablemente bien *casi todo*, incluyendo clasificación y traducción. Esto ha llevado a que la industria entre 2022-2024 se consolide hacia **decoder-only** como arquitectura dominante para modelos generales, mientras **encoder-only** sigue imbatible en tareas de embeddings/retrieval y cuando el presupuesto de inferencia es ajustado.

### Contexto histórico

| Año | Modelo | Arquitectura | Contribución |
|---|---|---|---|
| 2017 | Transformer original | Encoder-Decoder | Traducción EN→DE, nace la arquitectura |
| 2018 | **BERT** | Encoder-only | Masked LM + bidireccionalidad → revolución en NLU |
| 2018 | **GPT-1** | Decoder-only | Pre-entrenamiento generativo + fine-tuning |
| 2019 | **GPT-2** | Decoder-only | Zero-shot sorprendente, escalado a 1.5B |
| 2019 | **T5** | Encoder-Decoder | "Text-to-Text": todo como seq2seq |
| 2019 | **BART** | Encoder-Decoder | Denoising autoencoder, excelente en resumen |
| 2020 | **GPT-3** | Decoder-only | In-context learning emergente, 175B |
| 2021 | **CLIP** | Dual-encoder | Vision-language por contraste |
| 2023 | **LLaMA, Mistral** | Decoder-only | Open weights competitivos |
| 2024 | **ModernBERT** | Encoder-only | Resurgimiento de BERT optimizado para 2024 |

## ¿Cómo funciona?

### Encoder-only (BERT y familia)

![Encoder-Only Architecture](https://hrcdn.net/ai-engineering/module-1/dark/transformers-lesson03-architecture-comparison.svg)

**Patrón de atención:** completamente bidireccional. Cada token atiende a *todos* los demás, incluyendo los posteriores.

```
Input: "The software engineer debugged the authentication bug"

"software"       atiende a: [The, software, engineer, debugged, the, authentication, bug]
"debugged"       atiende a: [The, software, engineer, debugged, the, authentication, bug]
"authentication" atiende a: [The, software, engineer, debugged, the, authentication, bug]
```

**Objetivo de pre-entrenamiento: Masked Language Modeling (MLM)**

Se enmascara el 15% de los tokens con `[MASK]` y el modelo debe predecirlos usando contexto bidireccional:

```
Input:  "The [MASK] engineer debugged the [MASK] bug"
Target:                software                      authentication
```

Como el modelo ve el contexto a ambos lados de cada máscara, aprende representaciones muy ricas. **BERT** añade además *Next Sentence Prediction* (si dos frases van consecutivas); **RoBERTa** demostró que NSP es innecesario y basta con MLM más largo.

**Uso típico:**

```python
from transformers import pipeline

# Clasificación
clf = pipeline("sentiment-analysis",
               model="distilbert-base-uncased-finetuned-sst-2-english")
clf("The debugging experience was surprisingly pleasant.")

# QA extractivo (devuelve el span de la respuesta en el contexto)
qa = pipeline("question-answering", model="deepset/roberta-base-squad2")
qa(question="What was debugged?", context="The engineer debugged the auth bug.")

# Embeddings para búsqueda semántica
from sentence_transformers import SentenceTransformer
enc = SentenceTransformer("sentence-transformers/all-MiniLM-L6-v2")
vecs = enc.encode(["authentication bug", "login error", "pizza recipe"])
```

**Fortalezas:**

- Representaciones ricas para *entender* texto.
- Rápido en inferencia: una sola pasada forward produce la representación completa.
- Ideal para **embeddings** (RAG, búsqueda semántica, clustering).
- Puede fine-tunearse con muy poco data (cientos de ejemplos) para clasificación.

**Limitación clave:** **no puede generar texto fluido**. Puede rellenar máscaras, pero no es autoregresivo.

### Decoder-only (GPT y familia)

**Patrón de atención:** causal (masked). Cada token solo puede atender a sí mismo y a los anteriores. Se implementa aplicando una **máscara triangular** sobre los scores de atención antes del softmax:

```
Input: "The software engineer debugged"

"The"      atiende a: [The]
"software" atiende a: [The, software]
"engineer" atiende a: [The, software, engineer]
"debugged" atiende a: [The, software, engineer, debugged]
```

Matricialmente:

```
         The  software  engineer  debugged
The       ✓     ✗         ✗         ✗
software  ✓     ✓         ✗         ✗
engineer  ✓     ✓         ✓         ✗
debugged  ✓     ✓         ✓         ✓
```

**Objetivo de pre-entrenamiento: Next-Token Prediction (NTP)**

```
P(x_1, x_2, …, x_n) = ∏ P(x_t | x_1, …, x_{t-1})
```

Loss = cross-entropy entre la distribución predicha sobre el vocab y el siguiente token real. Simplísimo y escalable.

**Generación autoregresiva:**

```
Step 1: Input "Write a function to"           → predict "validate"
Step 2: Input "Write a function to validate"  → predict "user"
Step 3: Input "Write a function to validate user" → predict "credentials"
...
```

Cada paso ejecuta un forward completo del modelo. Esto es caro, por eso en inferencia se usa el **KV cache**: se guardan las keys y values ya calculadas y solo se procesa el nuevo token, bajando de O(n²) por paso a O(n).

```python
from transformers import AutoTokenizer, AutoModelForCausalLM

tok = AutoTokenizer.from_pretrained("gpt2")
model = AutoModelForCausalLM.from_pretrained("gpt2")

inputs = tok("def authenticate(", return_tensors="pt")
out = model.generate(
    **inputs,
    max_new_tokens=40,
    do_sample=True,
    temperature=0.7,
    top_p=0.9,
    use_cache=True,          # KV cache activado por defecto
)
print(tok.decode(out[0], skip_special_tokens=True))
```

**Fortalezas:**

- Generación de alta calidad, coherente a largo plazo.
- Un solo modelo multi-tarea vía **prompting** (zero-shot y few-shot).
- Escala extremadamente bien (GPT-3, GPT-4, Claude, LLaMA).
- Instruction-tuning + RLHF lo convierten en chatbot utilizable (ChatGPT, Claude).

**Características operativas:**

- **Latencia de generación** — N forward passes para N tokens. El time-to-first-token es rápido, pero los tokens siguientes son secuenciales.
- **Context window crece durante generación** — eventualmente topa con el límite.
- **"Lost in the middle"** — los modelos tienden a prestar menos atención al centro del contexto (Liu et al., 2023).

### Encoder-Decoder (T5, BART, Whisper)

Combina ambas arquitecturas:

```
         ┌──────────────────┐
Input ──▶│    ENCODER       │─┐
         │ (bidirectional)  │ │  representaciones
         └──────────────────┘ │  del encoder
                              ▼
                     ┌──────────────────┐
         Target ────▶│    DECODER       │────▶ Output
         (shifted)   │  self-attn causal│
                     │  + cross-attn    │◀── K, V del encoder
                     └──────────────────┘
```

**Flujo en dos fases:**

**Fase 1 — Encoding** (una sola vez, en paralelo sobre toda la entrada):

```
Input: "def authenticate_user(token):"
Encoder produce: representaciones ricas de cada token, bidireccionales.
```

**Fase 2 — Decoding** (token por token, autoregresivo):

Cada bloque del decoder tiene **tres** subcapas en vez de dos:

1. **Masked self-attention** sobre lo generado hasta ahora.
2. **Cross-attention**: Q viene del decoder, K y V vienen de la salida del encoder.
3. **Feed-forward**.

```
Generating documentation:
"This"    atiende a (self): [This] + (cross): [TODAS las representaciones del encoder]
"function" atiende a (self): [This, function] + (cross): [TODAS las del encoder]
"validates" atiende a (self): [This, function, validates] + (cross): [...]
```

**Objetivos de pre-entrenamiento:**

- **T5** — *span corruption*: enmascarar spans contiguos de tokens y predecirlos. Todo se formula como seq2seq: `"translate English to German: Hello" → "Hallo"`.
- **BART** — *denoising autoencoder*: corromper el input (shuffle, mask, delete, infill) y reconstruirlo.
- **Whisper** — audio en el encoder, texto autoregresivo en el decoder (ASR).

**Uso con HuggingFace:**

```python
from transformers import pipeline

# Resumen con BART
summ = pipeline("summarization", model="facebook/bart-large-cnn")
summ("Long article text ...", max_length=100, min_length=30)

# Traducción con NLLB (encoder-decoder masivo multilingüe)
tr = pipeline("translation", model="facebook/nllb-200-distilled-600M",
              src_lang="eng_Latn", tgt_lang="spa_Latn")
tr("The transformer architecture changed everything.")

# T5 formato text-to-text
from transformers import T5Tokenizer, T5ForConditionalGeneration
tok = T5Tokenizer.from_pretrained("t5-base")
model = T5ForConditionalGeneration.from_pretrained("t5-base")
inp = tok("translate English to German: The house is wonderful.", return_tensors="pt")
out = model.generate(**inp, max_new_tokens=50)
print(tok.decode(out[0], skip_special_tokens=True))
```

**Cuándo elegirlo:**

- Input y output tienen **estructuras muy diferentes** (traducción EN→ZH, audio→texto).
- La entrada es larga y hay que **comprimirla** fuertemente (resumen).
- Hay **mucha información que no debe aparecer en la salida** pero sí condicionar la generación.
- Dataset relativamente pequeño donde la bidireccionalidad del encoder ayuda.

### Comparación lado a lado

![Attention Patterns](https://hrcdn.net/ai-engineering/module-1/light/transformers-lesson03-attention-patterns-comparison.svg)

| Dimensión | Encoder-only (BERT) | Decoder-only (GPT) | Encoder-Decoder (T5) |
|---|---|---|---|
| Atención en el input | Bidireccional | Causal (unidireccional) | Bidireccional en encoder, causal en decoder |
| Cross-attention | ❌ | ❌ | ✅ (decoder → encoder) |
| Objetivo pre-training | Masked LM | Next-token prediction | Span corruption / denoising |
| Genera texto | ❌ (solo rellena máscaras) | ✅ (autoregresivo) | ✅ (autoregresivo condicionado) |
| Produce embeddings | ✅✅ (ideal) | ✓ (hidden del último token) | ✓ |
| Inferencia | 1 forward | N forwards (con KV cache) | 1 forward encoder + N forwards decoder |
| Fine-tuning | Fácil con pocos datos | Más costoso, prefiere LoRA | Intermedio |
| Multi-tarea vía prompt | ❌ | ✅ | ✅ (texto-a-texto desde origen) |
| Tamaño típico 2024 | 100M-400M | 1B-400B+ | 220M-11B |
| Dominantes en | Embeddings, clasificación, NER | Chat, código, agentes | Traducción, resumen, ASR |

### Resumen de patrones de atención (código didáctico)

```python
def demonstrate_attention_patterns():
    sentence = ["The", "software", "engineer", "debugged", "the", "bug"]
    n = len(sentence)

    print("ENCODER-ONLY (BERT): bidireccional")
    for i, w in enumerate(sentence):
        print(f"  {w:>10} atiende a: {'✓ ' * n}")

    print("\nDECODER-ONLY (GPT): causal")
    for i, w in enumerate(sentence):
        print(f"  {w:>10} atiende a: {'✓ ' * (i + 1) + '✗ ' * (n - i - 1)}")

    print("\nENCODER-DECODER (T5)")
    print("  Encoder (bidireccional):")
    for i, w in enumerate(sentence[:3]):
        print(f"    {w:>10} atiende a: {'✓ ' * 3}")
    print("  Decoder (causal self + full cross):")
    for i, w in enumerate(["This", "function", "fixes"]):
        print(f"    {w:>10}  self:{'✓ ' * (i + 1)}{'✗ ' * (2 - i)}  cross:{'✓ ' * 3}")

demonstrate_attention_patterns()
```

## Ejemplo con código

### 1. Elegir arquitectura según la tarea

```python
from transformers import pipeline

# Tarea: clasificar sentimiento → ENCODER-ONLY
sent = pipeline("sentiment-analysis", model="distilbert-base-uncased-finetuned-sst-2-english")
print(sent("I love this new attention mechanism."))

# Tarea: generar código → DECODER-ONLY
code = pipeline("text-generation", model="bigcode/starcoder2-3b")
print(code("def fibonacci(n):\n", max_new_tokens=60))

# Tarea: resumir un artículo largo → ENCODER-DECODER
summ = pipeline("summarization", model="facebook/bart-large-cnn")
print(summ("The transformer architecture, introduced in 2017, ...", max_length=50))

# Tarea: traducir → ENCODER-DECODER
tr = pipeline("translation_en_to_fr", model="t5-base")
print(tr("The transformer changed everything."))

# Tarea: embeddings para RAG → ENCODER-ONLY
from sentence_transformers import SentenceTransformer
emb = SentenceTransformer("BAAI/bge-small-en-v1.5")
print(emb.encode(["attention mechanism", "self-attention"]).shape)
```

### 2. Fine-tuning BERT para clasificación (encoder-only)

```python
from transformers import (AutoTokenizer, AutoModelForSequenceClassification,
                          Trainer, TrainingArguments)
from datasets import load_dataset

ds = load_dataset("imdb")
tok = AutoTokenizer.from_pretrained("distilbert-base-uncased")

def preprocess(ex):
    return tok(ex["text"], truncation=True, max_length=256, padding="max_length")

ds = ds.map(preprocess, batched=True)
model = AutoModelForSequenceClassification.from_pretrained(
    "distilbert-base-uncased", num_labels=2)

args = TrainingArguments(
    output_dir="bert-imdb", num_train_epochs=1,
    per_device_train_batch_size=16, learning_rate=2e-5,
    evaluation_strategy="epoch", bf16=True,
)
Trainer(model=model, args=args,
        train_dataset=ds["train"].shuffle(seed=0).select(range(2000)),
        eval_dataset=ds["test"].select(range(500))).train()
```

### 3. Fine-tuning GPT para instrucciones (decoder-only)

```python
from datasets import load_dataset
from transformers import AutoTokenizer, AutoModelForCausalLM, TrainingArguments
from trl import SFTTrainer

ds = load_dataset("tatsu-lab/alpaca", split="train[:2000]")
tok = AutoTokenizer.from_pretrained("gpt2")
tok.pad_token = tok.eos_token
model = AutoModelForCausalLM.from_pretrained("gpt2")

trainer = SFTTrainer(
    model=model, tokenizer=tok, train_dataset=ds,
    dataset_text_field="text", max_seq_length=512,
    args=TrainingArguments(output_dir="gpt2-alpaca", num_train_epochs=1,
                           per_device_train_batch_size=4, learning_rate=5e-5, bf16=True),
)
trainer.train()
```

### 4. Fine-tuning T5 para resumen (encoder-decoder)

```python
from transformers import (T5Tokenizer, T5ForConditionalGeneration,
                          Seq2SeqTrainingArguments, Seq2SeqTrainer, DataCollatorForSeq2Seq)
from datasets import load_dataset

ds = load_dataset("samsum")
tok = T5Tokenizer.from_pretrained("t5-small")
model = T5ForConditionalGeneration.from_pretrained("t5-small")

def preprocess(ex):
    inputs = ["summarize: " + d for d in ex["dialogue"]]
    model_inputs = tok(inputs, max_length=512, truncation=True)
    labels = tok(text_target=ex["summary"], max_length=128, truncation=True)
    model_inputs["labels"] = labels["input_ids"]
    return model_inputs

ds = ds.map(preprocess, batched=True, remove_columns=ds["train"].column_names)
collator = DataCollatorForSeq2Seq(tok, model=model)

args = Seq2SeqTrainingArguments(
    output_dir="t5-samsum", num_train_epochs=1,
    per_device_train_batch_size=8, learning_rate=3e-4,
    predict_with_generate=True, bf16=True,
)
Seq2SeqTrainer(model=model, args=args,
               train_dataset=ds["train"].select(range(1000)),
               eval_dataset=ds["validation"].select(range(100)),
               data_collator=collator, tokenizer=tok).train()
```

### 5. Implementación mínima del patrón de máscara causal

```python
import torch
import torch.nn.functional as F

def causal_attention(Q, K, V):
    N = Q.shape[-2]
    scores = Q @ K.transpose(-2, -1) / (Q.shape[-1] ** 0.5)
    mask = torch.triu(torch.ones(N, N), diagonal=1).bool()
    scores = scores.masked_fill(mask, float("-inf"))
    return F.softmax(scores, dim=-1) @ V

def bidirectional_attention(Q, K, V):
    scores = Q @ K.transpose(-2, -1) / (Q.shape[-1] ** 0.5)
    return F.softmax(scores, dim=-1) @ V       # sin máscara

def cross_attention(Q_dec, K_enc, V_enc):
    scores = Q_dec @ K_enc.transpose(-2, -1) / (Q_dec.shape[-1] ** 0.5)
    return F.softmax(scores, dim=-1) @ V_enc   # sin máscara, Q del decoder, K/V del encoder
```

## Errores comunes

- **Usar GPT para clasificar cuando tienes dataset etiquetado.** Un BERT fine-tuned de 100M suele ganar a un prompt zero-shot con GPT-3.5, es 100× más barato y 10× más rápido.
- **Usar BERT para generar texto.** No es su objetivo. Puedes rellenar máscaras una a una, pero el resultado es incoherente comparado con un decoder.
- **Olvidar la máscara causal en un decoder entrenándolo desde cero.** El loss cae artificialmente porque el modelo "ve el futuro". En inferencia colapsa.
- **Olvidar la cross-attention en un encoder-decoder.** El decoder genera sin condicionarse al encoder → produce texto ignorando la entrada.
- **Usar embeddings del último token en un decoder-only sin considerar su sesgo.** Los embeddings del último token están contaminados por la causalidad. Para búsqueda semántica usa modelos específicos (sentence-transformers, BGE, E5) o técnicas como *mean pooling* sobre todas las posiciones.
- **Confundir "modelo generativo" con "arquitectura decoder".** T5 (encoder-decoder) también genera. Lo que define generación es la **salida autoregresiva**, no el nombre.
- **Fine-tune ingenuo de un LLM gigante.** Hacer full fine-tuning de LLaMA 70B requiere cientos de GB de VRAM. Usa **LoRA / QLoRA**.
- **Tokenizer incorrecto.** Mezclar `gpt2` tokenizer con un modelo T5 produce basura silenciosa.
- **No usar KV cache en inferencia decoder.** La generación es 10-100× más lenta. HuggingFace lo activa por defecto con `use_cache=True`.
- **Contexto gigante como solución universal.** Un modelo con 200K tokens de contexto no "lee" todo con la misma atención. Mejor **RAG** con un buen retriever + encoder embedding.
- **No considerar instruction tuning / RLHF.** Un decoder-only pre-entrenado "raw" (GPT-3 base) no es un chatbot. Hace falta SFT + RLHF/DPO para que siga instrucciones (ChatGPT, Claude, LLaMA-Instruct).
- **Elegir arquitectura por moda.** En 2024 todo el mundo quiere decoder-only, pero para clasificación de documentos legales con dataset etiquetado, un DeBERTa-v3 fine-tuned sigue siendo el estado del arte y 1000× más barato de servir.

## Herramientas

- **HuggingFace Transformers** — biblioteca unificada para las tres familias.
- **sentence-transformers** — wrapper encima de encoder-only para embeddings.
- **PEFT** — LoRA, QLoRA, adapters para fine-tuning eficiente.
- **TRL** — SFTTrainer, DPOTrainer, PPOTrainer para instruction tuning y RLHF.
- **vLLM** — motor de inferencia optimizado (PagedAttention) para decoder-only.
- **Text Generation Inference (TGI)** — servidor de HuggingFace para producción.
- **MTEB** — benchmark estándar para evaluar modelos de embeddings (encoder-only).

## Resumen

- Tres patrones arquitecturales nacen de **la misma caja de LEGO** (bloques Transformer) pero cambian el flujo de atención.
- **Encoder-only (BERT, RoBERTa, DeBERTa, ModernBERT):** atención bidireccional, pre-entrenado con Masked LM, ideal para *entender* → clasificación, NER, QA extractivo, embeddings, búsqueda semántica.
- **Decoder-only (GPT, Claude, LLaMA, Mistral):** atención causal, pre-entrenado con next-token prediction, ideal para *generar* → chat, código, razonamiento, in-context learning.
- **Encoder-Decoder (T5, BART, Whisper, NLLB):** encoder bidireccional + decoder causal + **cross-attention**, ideal para *transformar* una entrada en una salida muy distinta → traducción, resumen, ASR.
- La diferencia operativa clave es la **máscara de atención** y la presencia o no de **cross-attention**.
- **Decoder-only domina 2022-2024** porque un solo modelo multi-tarea vía prompting es extremadamente flexible, pero no siempre es la mejor elección: para clasificación con datos etiquetados y presupuesto ajustado, un BERT fine-tuned sigue siendo imbatible.
- **Encoder-only sigue vivo y relevante** para embeddings (RAG, retrieval, semantic search) y tareas de clasificación de alta precisión a bajo costo.
- **Encoder-decoder** sigue siendo el estándar en traducción, resumen y multimodal condicionado (Whisper audio→texto).
- Elegir la arquitectura correcta antes de entrenar/servir ahorra orden(es) de magnitud en costo y latencia.
- Dominar estas tres familias es el prerequisito para los módulos siguientes: **prompting**, **fine-tuning**, **RAG**, **agentes** y evaluación de LLMs.
