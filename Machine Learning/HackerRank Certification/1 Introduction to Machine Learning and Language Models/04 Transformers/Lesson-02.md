# Arquitectura Completa del Transformer

## ¿Qué es?

El **Transformer** es una arquitectura de red neuronal basada enteramente en atención, introducida por Vaswani et al. en *"Attention Is All You Need"* (NeurIPS 2017). Elimina la recurrencia (RNN/LSTM) y la convolución, y las reemplaza por **bloques apilados** que combinan **multi-head self-attention**, **feed-forward networks**, **conexiones residuales** y **layer normalization**.

Un **bloque Transformer** es la unidad de repetición. Un modelo completo apila `N` bloques (BERT-base: 12, GPT-3: 96, LLaMA 3 70B: 80). Dentro de cada bloque, el flujo canónico es:

```
          ┌─────────────────────────────────────┐
Input ───▶│  LayerNorm → MHA → + (residual)     │
          │  LayerNorm → FFN → + (residual)     │─▶ Output al siguiente bloque
          └─────────────────────────────────────┘
```

> **Analogía:** piensa en una línea de ensamble inteligente. Cada estación tiene un trabajo específico: tokenizar (romper el input en piezas), embedir (traducir a vectores), atender (buscar contexto relevante), procesar (razonar en el FFN) y estabilizar (normalizar). Todo esto se repite N veces, cada vez con un entendimiento más abstracto.

### Las piezas del bloque

| Componente | Qué hace | Dónde está la mayoría del cómputo |
|---|---|---|
| **Token embedding** | Convierte cada token (entero) en un vector denso `d_model` | — |
| **Positional encoding** | Inyecta posición (sinusoidal, aprendida, RoPE, ALiBi) | — |
| **Multi-Head Attention** | Cada token mira a los demás y recoge contexto | O(n²·d) por capa |
| **Residual connection** | `x + Sublayer(x)` para preservar información y gradientes | — |
| **Layer Normalization** | Estabiliza la escala de las activaciones | — |
| **Feed-Forward Network** | "Pensamiento" por posición: expande → activa → comprime | ~2/3 de los parámetros |
| **Output head** | Capa final: softmax sobre vocab (LLM), clasificador (BERT), etc. | — |

## ¿Por qué importa?

Antes del Transformer, el estado del arte en NLP eran las RNN con atención (Bahdanau 2014). Problemas serios:

- **No paralelizables** — el estado `h_t` depende de `h_{t-1}`, imposible procesar la secuencia en paralelo en GPU.
- **Gradientes inestables** — el backpropagation through time (BPTT) sufre vanishing/exploding en secuencias largas.
- **Memoria comprimida** — toda la historia pasada se mete en un vector de estado fijo.

El Transformer soluciona los tres problemas de un plumazo:

1. **Paralelismo total** — todas las posiciones se procesan a la vez; el entrenamiento aprovecha completamente la GPU/TPU.
2. **Gradientes directos** — gracias a las residuales, los gradientes fluyen sin diluirse, permitiendo apilar 96+ capas.
3. **Memoria explícita** — la atención accede *directamente* a cualquier token, sin cuellos de botella.

Esto desbloqueó las *scaling laws* (Kaplan 2020, Hoffmann 2022 "Chinchilla"): más parámetros + más datos + más cómputo → mejor rendimiento, de forma predecible. Es la base de **BERT, GPT, T5, LLaMA, Claude, Mistral, Gemini** y prácticamente todo LLM post-2018.

### Hitos arquitecturales

| Año | Modelo | Novedad arquitectural |
|---|---|---|
| 2017 | Transformer original | Encoder-decoder, 6+6 capas, 65M parámetros, traducción EN→DE |
| 2018 | BERT | Encoder-only, pre-entrenamiento Masked LM + NSP |
| 2019 | GPT-2 | Decoder-only, zero-shot sorprendente, 1.5B parámetros |
| 2019 | T5 | "Text-to-Text Transfer Transformer", todo como seq2seq |
| 2020 | GPT-3 | 175B parámetros, few-shot in-context learning |
| 2022 | PaLM, Chinchilla | Scaling laws corregidos, Multi-Query Attention |
| 2023 | LLaMA, Mistral | RoPE, GQA, SwiGLU, pre-norm, open weights |
| 2024+ | Mixture of Experts (Mixtral, DeepSeek), long context (1M+ tokens) |

## ¿Cómo funciona?

### Paso 0: Tokenización

El texto crudo se parte en **subword tokens** usando un algoritmo como:

- **BPE (Byte Pair Encoding)** — GPT-2/3/4, LLaMA.
- **WordPiece** — BERT.
- **SentencePiece / Unigram** — T5, mT5, LLaMA.
- **tiktoken** (BPE optimizado) — modelos de OpenAI.

Ejemplo con GPT-2:

```python
from transformers import AutoTokenizer
tok = AutoTokenizer.from_pretrained("gpt2")
print(tok.tokenize("def authenticate_user(token):"))
# ['def', 'Ġauthent', 'icate', '_', 'user', '(', 'token', '):']
```

El símbolo `Ġ` representa un espacio. **Palabras raras** se descomponen en piezas conocidas → el modelo puede manejar palabras que nunca vio en entrenamiento combinando subwords.

### Paso 1: Token embedding + positional encoding

Cada token (entero) se busca en una matriz de embeddings aprendida `E ∈ ℝ^(V × d_model)`:

```python
x = E[token_id]          # vector de dimensión d_model
x = x + PE[position]     # suma la codificación posicional
```

Las dos variantes principales:

- **Sinusoidal** (Transformer original, se suma):
  ```
  PE(pos, 2i)   = sin(pos / 10000^(2i/d))
  PE(pos, 2i+1) = cos(pos / 10000^(2i/d))
  ```
- **RoPE** (LLaMA, Mistral, Qwen): se aplica *rotando* Q y K dentro de la atención, no se suma al embedding.

![Token to Vector Conversion Process](https://hrcdn.net/ai-engineering/module-1/light/transformers-lesson02-tokenization-embedding-pipeline.svg)

### Paso 2: Self-Attention multi-cabeza

Ya cubierto en Lesson-01. Resumen operativo dentro del bloque:

```python
attn_out = MultiHeadAttention(x)         # (B, N, d_model)
```

### Paso 3: Residual connection

```python
x = x + attn_out
```

**¿Por qué?** Sin residuales, apilar 24+ capas vuelve el entrenamiento inviable: los gradientes se diluyen (vanishing gradient) y las representaciones se degradan. Con `x + f(x)`, el gradiente siempre tiene un camino directo (`∂/∂x`) sin pasar por `f`.

> **He et al. 2016 (ResNet)** demostró que las conexiones residuales permitían entrenar redes de 150+ capas en visión. El Transformer adoptó la misma idea.

### Paso 4: Layer Normalization

```
LN(x) = γ · (x - μ) / √(σ² + ε) + β
```

Donde `μ, σ²` se calculan **por token** (sobre las `d_model` dimensiones). `γ, β` son parámetros aprendibles.

**Por qué importa:**

- Mantiene las activaciones en un rango estable → gradientes bien escalados.
- Permite usar learning rates más altos.
- A diferencia de BatchNorm, no depende del tamaño del batch (crítico para seq2seq con tamaños variables).

**Pre-norm vs post-norm:**

- **Post-norm** (Transformer original): `x = LN(x + Sublayer(x))`. Fácil de divergir en modelos grandes.
- **Pre-norm** (GPT-2, LLaMA, estándar moderno): `x = x + Sublayer(LN(x))`. Mucho más estable para 50+ capas.

**Variantes modernas:**

- **RMSNorm** (LLaMA): omite la media, solo normaliza por la raíz del promedio cuadrático. ~10-30% más rápido, igual de efectivo.

### Paso 5: Feed-Forward Network (FFN)

Red fully-connected de 2 capas aplicada **por posición** (independiente para cada token):

```
FFN(x) = W_2 · activation(W_1 · x + b_1) + b_2
```

- `W_1 ∈ ℝ^(d_model × d_ff)` — expande (típicamente `d_ff = 4 · d_model`).
- Activación: **ReLU** (original) → **GELU** (BERT, GPT-2) → **SwiGLU** (LLaMA, PaLM, estándar moderno).
- `W_2 ∈ ℝ^(d_ff × d_model)` — comprime de vuelta.

En GPT-3 (`d_model=12288`, `d_ff=49152`): el FFN tiene `12288 · 49152 · 2 ≈ 1.2B parámetros por capa`. Con 96 capas → **~110B parámetros**, aproximadamente **2/3 del total** (175B). Esta es la razón por la que los FFN son el principal objetivo de **cuantización** y **Mixture of Experts**.

**SwiGLU** (variante moderna):

```
SwiGLU(x) = (W_1 x ⊙ σ(W_g x)) · W_2
```

Donde `⊙` es producto Hadamard y `σ` es la sigmoide SiLU. Ligeramente mejor que GELU/ReLU empíricamente.

### Paso 6: Segunda residual + norm

```python
x = x + FFN(LN(x))
```

Fin del bloque. Output del tamaño exacto del input → se apila directamente al siguiente bloque.

### Pseudocódigo del bloque completo (pre-norm, estilo moderno)

```python
def transformer_block(x):
    x = x + multi_head_attention(layer_norm(x))
    x = x + feed_forward(layer_norm(x))
    return x
```

### Context window: por qué hay límites

Como vimos en Lesson-01, la atención tiene complejidad O(n²) en tiempo y memoria. Con `n = 100,000` tokens, la matriz de atención por cabeza pesa `100K² × 4 bytes = 40 GB` en fp32 → ni siquiera cabe en un H100 (80 GB) para una sola cabeza.

Estrategias para contextos largos:

| Técnica | Mecanismo |
|---|---|
| **Flash Attention** | Reorganiza en bloques, nunca materializa la matriz n×n completa |
| **Sliding Window** | Cada token solo atiende a una ventana local (Mistral 7B: w=4096) |
| **Sparse / BigBird** | Patrones de atención dispersos (global + local + random) |
| **Sliding + Attention Sinks** (StreamingLLM) | Mantiene los primeros K tokens siempre visibles |
| **Chunking jerárquico** | Resumir chunks, luego atender a resúmenes |
| **RAG** | No ampliar contexto: recuperar pasajes relevantes externamente |
| **State-space models** (Mamba) | O(n) complejidad reemplazando atención por recurrencia selectiva |

### Variantes de modelo: BERT vs GPT vs T5 vs LLaMA

| | **BERT** (2018) | **GPT-3** (2020) | **T5** (2019) | **LLaMA 3** (2024) |
|---|---|---|---|---|
| Tipo | Encoder-only | Decoder-only | Encoder-Decoder | Decoder-only |
| Atención | Bidireccional | Causal (masked) | Bi (enc) + causal (dec) + cross | Causal + GQA |
| Pre-training | Masked LM + Next Sentence | Next-token prediction | Span corruption (text-to-text) | Next-token |
| Positional enc. | Aprendida absoluta | Aprendida absoluta | Relativa (bucketized) | **RoPE** |
| Normalización | Post-norm LayerNorm | Pre-norm LayerNorm | Pre-norm RMSNorm (T5v1.1) | **Pre-norm RMSNorm** |
| Activación FFN | GELU | GELU | ReLU (v1) / GEGLU (v1.1) | **SwiGLU** |
| Parámetros | 110M (base) / 340M (large) | 175B | 11B (XXL) | 8B / 70B / 405B |
| Context | 512 | 2048 | 512 | 8K → 128K |
| Tarea natural | Clasificación, NER, QA | Generación, few-shot | Traducción, resumen, QA | Chat, código, razonamiento |
| Open weights | ✅ | ❌ | ✅ | ✅ |

### Diagrama de encoder-only vs decoder-only vs encoder-decoder

```
ENCODER-ONLY (BERT)             DECODER-ONLY (GPT)             ENCODER-DECODER (T5)
                                                               
Input tokens                    Input tokens                   Input tokens → ENCODER
     ↓                               ↓                                           ↓
[Embed + PE]                    [Embed + PE]                   [cross-attend from DEC]
     ↓                               ↓                                           ↓
┌─────────────┐                 ┌──────────────┐              Target tokens → DECODER
│  N bloques  │                 │  N bloques   │                                 ↓
│  self-attn  │                 │  causal attn │                              Output
│  bidirec    │                 └──────────────┘
└─────────────┘                        ↓
     ↓                            [LM head]
[CLS/mask head]                        ↓
     ↓                             Next token
Classification
```

## Ejemplo con código

### 1. Bloque Transformer completo en PyTorch (pre-norm)

```python
import torch
import torch.nn as nn
import torch.nn.functional as F


class MultiHeadSelfAttention(nn.Module):
    def __init__(self, d_model, n_heads, causal=False, dropout=0.1):
        super().__init__()
        assert d_model % n_heads == 0
        self.n_heads = n_heads
        self.d_k = d_model // n_heads
        self.causal = causal
        self.qkv = nn.Linear(d_model, 3 * d_model, bias=False)
        self.out = nn.Linear(d_model, d_model, bias=False)
        self.drop = nn.Dropout(dropout)

    def forward(self, x, attn_mask=None):
        B, N, D = x.shape
        qkv = self.qkv(x).reshape(B, N, 3, self.n_heads, self.d_k).permute(2, 0, 3, 1, 4)
        Q, K, V = qkv[0], qkv[1], qkv[2]                     # (B, h, N, d_k)

        scores = (Q @ K.transpose(-2, -1)) / (self.d_k ** 0.5)
        if self.causal:
            m = torch.triu(torch.ones(N, N, device=x.device), diagonal=1).bool()
            scores = scores.masked_fill(m, float("-inf"))
        if attn_mask is not None:
            scores = scores.masked_fill(~attn_mask[:, None, None, :], float("-inf"))
        attn = F.softmax(scores, dim=-1)
        attn = self.drop(attn)

        y = (attn @ V).transpose(1, 2).reshape(B, N, D)
        return self.out(y)


class FeedForward(nn.Module):
    """FFN con SwiGLU, estilo LLaMA."""
    def __init__(self, d_model, d_ff, dropout=0.1):
        super().__init__()
        self.w1 = nn.Linear(d_model, d_ff, bias=False)
        self.w_g = nn.Linear(d_model, d_ff, bias=False)
        self.w2 = nn.Linear(d_ff, d_model, bias=False)
        self.drop = nn.Dropout(dropout)

    def forward(self, x):
        return self.drop(self.w2(F.silu(self.w_g(x)) * self.w1(x)))


class TransformerBlock(nn.Module):
    def __init__(self, d_model, n_heads, d_ff, causal=False, dropout=0.1):
        super().__init__()
        self.norm1 = nn.LayerNorm(d_model)
        self.attn = MultiHeadSelfAttention(d_model, n_heads, causal, dropout)
        self.norm2 = nn.LayerNorm(d_model)
        self.ffn = FeedForward(d_model, d_ff, dropout)

    def forward(self, x, attn_mask=None):
        x = x + self.attn(self.norm1(x), attn_mask)       # residual 1
        x = x + self.ffn(self.norm2(x))                   # residual 2
        return x
```

### 2. Un GPT mínimo (decoder-only)

```python
class MiniGPT(nn.Module):
    def __init__(self, vocab_size, d_model=256, n_heads=8, d_ff=1024,
                 n_layers=6, max_len=512):
        super().__init__()
        self.tok_emb = nn.Embedding(vocab_size, d_model)
        self.pos_emb = nn.Embedding(max_len, d_model)
        self.blocks = nn.ModuleList([
            TransformerBlock(d_model, n_heads, d_ff, causal=True)
            for _ in range(n_layers)
        ])
        self.norm = nn.LayerNorm(d_model)
        self.head = nn.Linear(d_model, vocab_size, bias=False)
        # Weight tying: comparte pesos entre embedding de entrada y proyección de salida
        self.head.weight = self.tok_emb.weight

    def forward(self, idx):                               # idx: (B, N)
        B, N = idx.shape
        pos = torch.arange(N, device=idx.device)
        x = self.tok_emb(idx) + self.pos_emb(pos)         # (B, N, d_model)
        for blk in self.blocks:
            x = blk(x)
        x = self.norm(x)
        logits = self.head(x)                             # (B, N, vocab)
        return logits

    @torch.no_grad()
    def generate(self, idx, max_new_tokens=50, temperature=1.0, top_k=None):
        self.eval()
        for _ in range(max_new_tokens):
            idx_cond = idx[:, -self.pos_emb.num_embeddings:]
            logits = self(idx_cond)[:, -1, :] / temperature
            if top_k is not None:
                v, _ = torch.topk(logits, top_k)
                logits[logits < v[:, [-1]]] = -float("inf")
            probs = F.softmax(logits, dim=-1)
            next_id = torch.multinomial(probs, num_samples=1)
            idx = torch.cat([idx, next_id], dim=1)
        return idx


model = MiniGPT(vocab_size=10000)
inp = torch.randint(0, 10000, (2, 32))
print(model(inp).shape)        # (2, 32, 10000)
```

### 3. Positional encoding sinusoidal

```python
def sinusoidal_pe(max_len, d_model):
    pe = torch.zeros(max_len, d_model)
    pos = torch.arange(max_len).unsqueeze(1).float()
    div = torch.exp(torch.arange(0, d_model, 2).float() * -(torch.log(torch.tensor(10000.0)) / d_model))
    pe[:, 0::2] = torch.sin(pos * div)
    pe[:, 1::2] = torch.cos(pos * div)
    return pe

PE = sinusoidal_pe(max_len=512, d_model=128)
print(PE.shape)        # (512, 128)
```

### 4. RoPE (rotary position embedding) simplificado

```python
def apply_rope(x, pos):
    # x: (..., N, d), d par
    d = x.shape[-1]
    freqs = 1.0 / (10000 ** (torch.arange(0, d, 2).float() / d))
    angles = pos[:, None] * freqs[None, :]            # (N, d/2)
    cos, sin = angles.cos(), angles.sin()
    x1, x2 = x[..., 0::2], x[..., 1::2]
    x_rot = torch.stack([x1 * cos - x2 * sin,
                         x1 * sin + x2 * cos], dim=-1).flatten(-2)
    return x_rot
```

### 5. Uso práctico con HuggingFace

```python
from transformers import AutoTokenizer, AutoModelForCausalLM

tok = AutoTokenizer.from_pretrained("gpt2")
model = AutoModelForCausalLM.from_pretrained("gpt2")

inputs = tok("The transformer architecture", return_tensors="pt")
out = model.generate(**inputs, max_new_tokens=30, do_sample=True, top_p=0.9)
print(tok.decode(out[0], skip_special_tokens=True))

# Inspección: ver todos los módulos del modelo
print(model)
# GPT2LMHeadModel(
#   (transformer): GPT2Model(
#     (wte): Embedding(50257, 768)             ← token embedding
#     (wpe): Embedding(1024, 768)              ← positional embedding
#     (h): ModuleList(                         ← 12 bloques
#       (0-11): GPT2Block(
#         (ln_1): LayerNorm
#         (attn): GPT2Attention                ← MHA causal
#         (ln_2): LayerNorm
#         (mlp): GPT2MLP                       ← FFN
#       )
#     )
#     (ln_f): LayerNorm                        ← LN final
#   )
#   (lm_head): Linear(768, 50257, bias=False)  ← cabeza de salida
# )
```

### 6. Fine-tuning con LoRA (eficiente en parámetros)

```python
# pip install peft bitsandbytes accelerate
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments
from peft import LoraConfig, get_peft_model
from trl import SFTTrainer
from datasets import load_dataset

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-3.2-1B",
    load_in_4bit=True,          # cuantización 4-bit para caber en GPU pequeña
)
tok = AutoTokenizer.from_pretrained("meta-llama/Llama-3.2-1B")

lora = LoraConfig(
    r=16, lora_alpha=32, lora_dropout=0.05,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],   # solo las proyecciones de atención
    task_type="CAUSAL_LM",
)
model = get_peft_model(model, lora)
model.print_trainable_parameters()
# trainable params: 4.2M || all params: 1.24B || trainable%: 0.34

ds = load_dataset("tatsu-lab/alpaca", split="train[:1000]")
trainer = SFTTrainer(
    model=model, tokenizer=tok, train_dataset=ds,
    args=TrainingArguments(output_dir="out", per_device_train_batch_size=4,
                           num_train_epochs=1, bf16=True, learning_rate=2e-4),
    dataset_text_field="text", max_seq_length=512,
)
trainer.train()
```

## Errores comunes

- **Olvidar el positional encoding.** Sin PE, el modelo trata la secuencia como un *bag of words*: "el perro mordió al hombre" ≡ "el hombre mordió al perro". El output degenera.
- **Positional encoding mal escalado respecto al embedding.** Si `||PE|| >> ||token_emb||`, el modelo solo ve posición y pierde contenido. Si al revés, pierde orden. Los embeddings suelen inicializarse con `std ≈ 0.02` por una razón.
- **Post-norm en modelos profundos.** Diverge en entrenamientos de 24+ capas sin warmup extremo. Usa **pre-norm** por defecto en nuevos modelos.
- **Olvidar la máscara causal en decoders.** El modelo "espía" el futuro durante el entrenamiento → loss cae rapidísimo pero inferencia es basura.
- **No manejar `attention_mask` con padding.** Los tokens `[PAD]` reciben atención real si no se enmascaran. Siempre pasar `attention_mask` al tokenizer.
- **`d_model` no divisible entre `n_heads`.** Falla silenciosamente o lanza un error críptico. Verifica: `d_model % n_heads == 0`.
- **Materializar la matriz n² en secuencias largas.** Para `n > 4K`, usa `torch.nn.functional.scaled_dot_product_attention` (que invoca Flash Attention internamente desde PyTorch 2.0) o `flash-attn` explícitamente.
- **Tokenizer y modelo descoincidentes.** Cargar el modelo `gpt2` con el tokenizer `bert-base-uncased` → embeddings garbage. Siempre usa el mismo checkpoint para ambos.
- **No activar `model.eval()` en inferencia.** Dropout queda activo, resultados estocásticos y mal rendimiento.
- **Olvidar el weight tying.** En LLMs pequeños, compartir pesos entre embedding de entrada y cabeza de salida ahorra `V · d_model` parámetros y mejora la generalización.
- **No usar gradient checkpointing en modelos grandes.** El forward guarda todas las activaciones intermedias → OOM. `model.gradient_checkpointing_enable()` cambia memoria por recomputo.
- **Ignorar que el FFN domina los parámetros.** Al optimizar velocidad/memoria, atacar los FFN (cuantización, pruning, MoE) rinde más que atacar la atención.
- **Chunking brutal de documentos largos.** Cortar texto a mitad de frase pierde contexto. Fragmenta en límites naturales (párrafos, secciones) y mantén overlap.

## Herramientas

- **PyTorch / `torch.nn.TransformerEncoderLayer`, `TransformerDecoderLayer`** — implementaciones de referencia.
- **HuggingFace Transformers** — todos los modelos pre-entrenados con API uniforme.
- **PEFT** — LoRA, QLoRA, prefix tuning, adapters.
- **Accelerate / DeepSpeed / FSDP** — entrenamiento distribuido en múltiples GPUs.
- **bitsandbytes** — cuantización 8-bit y 4-bit.
- **vLLM, TGI, llama.cpp** — motores de inferencia optimizados.
- **flash-attn** — kernels CUDA de Flash Attention 2.
- **tiktoken** — tokenizer BPE de OpenAI.
- **nanoGPT** (Karpathy) — implementación educativa de ~300 líneas de un GPT entrenable.

## Resumen

- El **Transformer** = atención + feed-forward + residuales + layer norm, apilados en N bloques, sin recurrencia ni convolución.
- Flujo canónico de un bloque: `Embed+PE → MHA → +residual → LN → FFN → +residual → LN`. Los modelos modernos usan **pre-norm** por estabilidad.
- Los **tokens** son enteros tras pasar por un tokenizer subword (BPE, WordPiece, SentencePiece). Se convierten en vectores vía una matriz de embedding aprendida.
- El **positional encoding** compensa la invariancia a permutaciones de la atención. Variantes: sinusoidal, aprendida, **RoPE** (LLaMA), ALiBi.
- Las **conexiones residuales** permiten entrenar 50+ capas sin vanishing gradient; la **LayerNorm (o RMSNorm)** estabiliza las activaciones.
- El **FFN** (expand-activate-compress) contiene ~2/3 de los parámetros del modelo. Activación moderna: **SwiGLU**.
- La atención es O(n²): el **context window** está limitado por memoria. Soluciones: **Flash Attention**, sliding window, atención dispersa, Mamba.
- Las **variantes arquitecturales** (BERT, GPT, T5, LLaMA) reutilizan los mismos bloques en configuraciones distintas: encoder-only, decoder-only, encoder-decoder.
- **BERT vs GPT vs T5 vs LLaMA**: cambia el patrón de máscara, la posicional, la normalización, la activación y el objetivo de pre-entrenamiento.
- **Errores clásicos**: olvidar máscara causal, PE mal escalado, post-norm en modelos profundos, tokenizer incorrecto, no enmascarar padding.
- Dominar esta arquitectura es la base para entender fine-tuning, LoRA, cuantización, RAG, agentes y todo lo que viene en los módulos siguientes.
