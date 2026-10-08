# Mecanismos de Atención (Attention)

## ¿Qué es?

El **mecanismo de atención** es la operación matemática que permite a un modelo *decidir dinámicamente*, para cada palabra (token) de una secuencia, **cuáles otras palabras son relevantes** y en qué proporción. En lugar de procesar el texto como un flujo rígido de izquierda a derecha (como las RNN/LSTM), la atención permite que *cualquier* token mire a *cualquier* otro token y pondere su influencia.

La fórmula canónica, introducida en *"Attention Is All You Need"* (Vaswani et al., 2017), es la **scaled dot-product attention**:

```
Attention(Q, K, V) = softmax( Q · Kᵀ / √d_k ) · V
```

Donde:

- **Q (Query)** — "¿qué estoy buscando?". Vector que representa la pregunta del token actual.
- **K (Key)** — "¿qué ofrezco yo?". Vector que indexa el contenido de cada token candidato.
- **V (Value)** — "¿qué información entrego si me eligen?". Vector con el contenido semántico real.
- **d_k** — dimensión de las keys. El `√d_k` evita que los productos escalares crezcan demasiado y saturen el softmax (inestabilidad numérica).
- **softmax** — normaliza los scores a una distribución de probabilidad (suman 1).

### Analogía: Google para tu texto

Cuando buscas *"mejor pizza cerca"*:

- Tu **query** es la frase que escribes.
- Las **keys** son los títulos y descripciones indexados.
- Los **values** son los sitios web completos que recibes.

La atención hace exactamente lo mismo *dentro* del modelo: cada token emite una query, se compara contra las keys de los demás tokens, y recibe una mezcla ponderada de sus values.

> **Definición operativa:** la atención es una **lookup diferenciable y suave** sobre una memoria. En vez de "elige el token X" (hard), devuelve "mezcla el 73% del token X con el 15% del Y y el 12% del Z" (soft), lo cual es derivable y entrenable con backpropagation.

### Jerarquía: Atención → Self-Attention → Multi-Head → Transformer

```
Atención (concepto general: Q, K, V)
└── Self-Attention              ← Q, K, V vienen de la MISMA secuencia
    └── Multi-Head Attention    ← varias cabezas de self-attention en paralelo
        └── Bloque Transformer  ← MHA + FFN + residuales + LayerNorm
            └── Modelo completo ← apilar N bloques (12, 24, 96…)
```

## ¿Por qué importa?

Antes de la atención, las redes neuronales procesaban secuencias con **memoria a corto plazo severa**. RNN y LSTM comprimían toda la historia pasada en un vector de estado fijo que inevitablemente olvidaba lo lejano. Entrenarlas era lento (recurrencia impide paralelismo) y las dependencias a larga distancia se diluían con el *vanishing gradient*.

Considera este fragmento:

```python
class PaymentProcessor:
    """
    Procesa pagos para transacciones e-commerce.
    Todos los métodos requieren tokens de autenticación válidos.
    """

    def __init__(self, api_key, environment="sandbox"):
        # ... 50 líneas de inicialización ...

    def process_payment(self, transaction_data):
        if self.is_authenticated():   # ¿cómo se relaciona esto con el docstring?
            # ... lógica ...
```

Un modelo sin atención ya habría *olvidado* el docstring para cuando llega a `is_authenticated()`. La atención permite al modelo **saltar directamente** desde la línea 60 hasta la línea 3, sin importar la distancia.

### Beneficios concretos

- **Dependencias a larga distancia** — pronombres, referencias cruzadas, código con closures.
- **Paralelización masiva** — todas las posiciones se calculan a la vez en GPU, sin recurrencia.
- **Interpretabilidad parcial** — los pesos de atención se pueden visualizar como heatmaps.
- **Transferencia** — las representaciones pre-entrenadas con atención se transfieren muy bien (BERT, GPT).
- **Escala predecible** — doblar parámetros + datos + cómputo mejora el modelo de forma suave (scaling laws de Kaplan 2020, Chinchilla 2022).

### Contexto histórico

| Año | Hito |
|---|---|
| 2014 | Bahdanau et al.: atención aditiva para traducción (seq2seq con RNN) |
| 2015 | Luong et al.: atención multiplicativa (dot-product) |
| 2017 | **Vaswani et al.: "Attention Is All You Need"** → Transformer puro, sin RNN |
| 2018 | **BERT** (Google): encoder-only, pre-entrenamiento masked LM |
| 2019 | **GPT-2** (OpenAI): decoder-only, 1.5B parámetros |
| 2020 | **GPT-3**: 175B parámetros, few-shot learning emergente |
| 2022 | ChatGPT, Flash Attention, Chinchilla scaling laws |
| 2023 | GPT-4, LLaMA, Mistral, context windows de 100K+ tokens |
| 2024+ | Grouped-Query Attention, Mixture of Experts, atención subcuadrática (Mamba, RWKV) |

## ¿Cómo funciona?

### Ejemplo intuitivo: resolver "it"

Considera: *"The laptop was expensive, but **it** was worth the investment."*

Para procesar *"it"*, el modelo:

1. Genera un **query** desde "it" que esencialmente pregunta: *"¿a qué sustantivo me refiero?"*
2. Cada otra palabra expone una **key** que describe su "índice semántico":
   - `laptop` → "soy un sustantivo concreto, objeto físico"
   - `expensive` → "soy un adjetivo de costo"
   - `investment` → "soy un sustantivo abstracto, dinero"
3. Se calcula el producto escalar entre el query y cada key → **score de similitud**.
4. Softmax normaliza los scores → **pesos de atención** (suman 1).
5. La nueva representación de "it" = suma ponderada de los **values** de todas las palabras.

Como `laptop` tiene la key más alineada con el query ("busco un sustantivo físico"), recibe el mayor peso y "it" termina representado principalmente como "laptop".

![Query/Key/Value Diagram](https://hrcdn.net/ai-engineering/module-1/light/transformers-lesson01-query-key-value-framework.svg)

### Las tres matrices aprendibles: W_Q, W_K, W_V

Los vectores Q, K, V **no** son los embeddings crudos de los tokens. Se obtienen proyectando los embeddings `X` (de dimensión `d_model`) por tres matrices aprendibles:

```
Q = X · W_Q        shape: (n, d_k)
K = X · W_K        shape: (n, d_k)
V = X · W_V        shape: (n, d_v)
```

Donde `n` = longitud de secuencia, y `W_Q, W_K, W_V` son los parámetros que el modelo *aprende* para producir buenas queries, keys y values. Esta es la razón por la que la atención es **entrenable**: ajustamos `W_Q, W_K, W_V` por gradiente para que las queries y keys relevantes se alineen.

### Por qué `√d_k`: estabilidad numérica

Si `Q · Kᵀ` crece con `d_k`, el softmax entra en una región de gradientes casi nulos (saturación). Dividir por `√d_k` mantiene la varianza en torno a 1:

```
Var(Q·Kᵀ) ≈ d_k         →         Var(Q·Kᵀ / √d_k) ≈ 1
```

Omitir este factor es un **error clásico** al implementar atención desde cero: el modelo no entrena.

### Self-Attention

Cuando Q, K y V se derivan todos de **la misma secuencia** (`X`), hablamos de *self-attention*: cada token atiende a los demás tokens del mismo input. Es la operación central del Transformer.

- **Encoder self-attention** (BERT): bidireccional, todos los tokens se ven entre sí.
- **Masked / causal self-attention** (GPT): un token solo puede mirar a los anteriores (se aplica una máscara triangular que pone `-∞` en las posiciones futuras antes del softmax).
- **Cross-attention** (encoder-decoder, T5): Q viene del decoder, K y V vienen del encoder.

### Multi-Head Attention

Una sola cabeza de atención aprende *un* tipo de relación. Para capturar varias (sintaxis, correferencia, semántica, posición) en paralelo, el Transformer usa **h cabezas** independientes, cada una con sus propias `W_Q^i, W_K^i, W_V^i`:

```
head_i = Attention(X·W_Q^i, X·W_K^i, X·W_V^i)
MHA(X) = Concat(head_1, …, head_h) · W_O
```

En BERT-base: `h=12`, `d_model=768`, cada cabeza opera en `d_k=64`. En GPT-3: `h=96`, `d_model=12288`.

Analogía: en lugar de un solo experto leyendo el texto, tienes 12 especialistas (uno enfocado en sintaxis, otro en entidades, otro en tiempo verbal…) y luego combinas sus notas.

### Positional Encoding

La atención es **permutation-invariant**: si barajas los tokens, el output es el mismo (solo reordenado). Pero el orden importa en el lenguaje. Hay que **inyectar posición** explícitamente.

**1. Positional encoding sinusoidal** (Vaswani 2017, usado en el Transformer original):

```
PE(pos, 2i)   = sin(pos / 10000^(2i/d_model))
PE(pos, 2i+1) = cos(pos / 10000^(2i/d_model))
```

Se **suma** al embedding del token. Ventajas: no requiere parámetros, generaliza a longitudes no vistas, codifica distancias relativas via identidades trigonométricas.

**2. Positional embeddings aprendidos** (BERT, GPT-2): una matriz `(max_len, d_model)` entrenable. Simple pero no extrapola más allá de `max_len`.

**3. RoPE — Rotary Position Embedding** (Su et al., 2021, usado en LLaMA, GPT-NeoX, Qwen): **rota** los pares de dimensiones de Q y K según la posición. Preserva la norma del vector y codifica *posición relativa* dentro del producto escalar `Q·Kᵀ`. Permite extrapolar a contextos más largos de los vistos en entrenamiento.

**4. ALiBi** (Press et al., 2022): añade un **sesgo lineal negativo** proporcional a la distancia directamente en los scores de atención. Simple y robusto a longitudes largas.

### Complejidad O(n²): por qué el contexto es caro

Cada token debe comparar su query contra las keys de los `n` tokens → `n²` productos escalares. En memoria, la matriz de atención es `n × n`:

```
Longitud (n)   Operaciones   Costo relativo
    1,000        1 M            1x
    2,000        4 M            4x
    4,000       16 M           16x
    8,000       64 M           64x
   32,000     1,024 M        1024x
  100,000    10,000 M       10000x
```

Esto explica:

- **Precios de API** — un contexto de 128K no cuesta 32× más que 4K, cuesta ~1000× más en cómputo.
- **Latencia** — doblar la longitud cuadruplica el tiempo.
- **Límites de contexto** — la memoria GPU se agota (`O(n²)` para almacenar los scores).

### Variantes modernas para romper el O(n²)

| Variante | Idea central | Dónde se usa |
|---|---|---|
| **Flash Attention** (Dao 2022) | Reorganiza el cálculo en bloques que caben en SRAM, evita materializar la matriz n×n en HBM | GPT-4, LLaMA, estándar en 2024+ |
| **Multi-Query Attention (MQA)** | Una sola K y V compartidas entre todas las cabezas (solo las Q son múltiples) | PaLM, Falcon |
| **Grouped-Query Attention (GQA)** | Compromiso: grupos de cabezas comparten K/V | LLaMA 2, LLaMA 3, Mistral |
| **Sliding Window Attention** | Cada token solo atiende a una ventana local de tamaño `w` | Longformer, Mistral 7B |
| **Sparse Attention** | Patrones de atención dispersos (strided, dilated) | GPT-3 (parcial), BigBird |
| **Linear Attention** | Reescribe softmax para obtener O(n) | Performer, Linformer |
| **State-Space / RNN moderna** | Abandona atención, usa recurrencia selectiva O(n) | Mamba, RWKV, Hyena |

### Encoder vs Decoder vs Encoder-Decoder (resumen rápido, se desarrolla en Lesson-03)

| Arquitectura | Atención | Tarea natural | Ejemplos |
|---|---|---|---|
| Encoder-only | Bidireccional | Comprensión, clasificación, embeddings | BERT, RoBERTa, DeBERTa |
| Decoder-only | Causal (masked) | Generación autoregresiva | GPT-2/3/4, LLaMA, Claude, Mistral |
| Encoder-decoder | Encoder bidireccional + decoder causal + cross-attention | Transformación (traducción, resumen) | T5, BART, mT5, Flan-T5 |

## Ejemplo con código

### 1. Self-attention mínima con NumPy

```python
import numpy as np

def softmax(x, axis=-1):
    x = x - x.max(axis=axis, keepdims=True)       # estabilidad numérica
    e = np.exp(x)
    return e / e.sum(axis=axis, keepdims=True)

def scaled_dot_product_attention(Q, K, V, mask=None):
    """
    Q: (n, d_k)   queries
    K: (m, d_k)   keys
    V: (m, d_v)   values
    mask: (n, m) booleana. True = posicion permitida.
    """
    d_k = Q.shape[-1]
    scores = Q @ K.T / np.sqrt(d_k)               # (n, m)
    if mask is not None:
        scores = np.where(mask, scores, -1e9)     # -inf en posiciones prohibidas
    weights = softmax(scores, axis=-1)            # (n, m)
    output = weights @ V                          # (n, d_v)
    return output, weights

# Ejemplo: 4 tokens, dimensión 8
rng = np.random.default_rng(0)
n, d = 4, 8
X = rng.normal(size=(n, d))

# Proyecciones aprendidas (aquí aleatorias para demostración)
W_Q = rng.normal(size=(d, d))
W_K = rng.normal(size=(d, d))
W_V = rng.normal(size=(d, d))

Q, K, V = X @ W_Q, X @ W_K, X @ W_V
out, attn = scaled_dot_product_attention(Q, K, V)

print("Pesos de atención (filas suman 1):")
print(attn.round(2))
```

### 2. Máscara causal (decoder-only, estilo GPT)

```python
def causal_mask(n):
    """Matriz triangular inferior: posicion i solo ve 0..i."""
    return np.tril(np.ones((n, n), dtype=bool))

mask = causal_mask(n)
out_causal, attn_causal = scaled_dot_product_attention(Q, K, V, mask=mask)

print("Atención causal (triangular inferior):")
print(attn_causal.round(2))
# Observa: la primera fila concentra todo en la posición 0,
# la segunda se reparte entre 0 y 1, etc.
```

### 3. Multi-Head Attention en PyTorch

```python
import torch
import torch.nn as nn
import torch.nn.functional as F

class MultiHeadSelfAttention(nn.Module):
    def __init__(self, d_model: int, n_heads: int, causal: bool = False):
        super().__init__()
        assert d_model % n_heads == 0
        self.d_model = d_model
        self.n_heads = n_heads
        self.d_k = d_model // n_heads
        self.causal = causal

        # Una sola proyección combinada para Q, K, V (3*d_model)
        self.qkv = nn.Linear(d_model, 3 * d_model, bias=False)
        self.out = nn.Linear(d_model, d_model, bias=False)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        B, N, D = x.shape
        qkv = self.qkv(x)                                   # (B, N, 3D)
        qkv = qkv.reshape(B, N, 3, self.n_heads, self.d_k)
        qkv = qkv.permute(2, 0, 3, 1, 4)                    # (3, B, h, N, d_k)
        Q, K, V = qkv[0], qkv[1], qkv[2]

        scores = (Q @ K.transpose(-2, -1)) / (self.d_k ** 0.5)   # (B, h, N, N)
        if self.causal:
            m = torch.triu(torch.ones(N, N, device=x.device), diagonal=1).bool()
            scores = scores.masked_fill(m, float("-inf"))
        attn = F.softmax(scores, dim=-1)

        y = attn @ V                                        # (B, h, N, d_k)
        y = y.transpose(1, 2).reshape(B, N, D)              # (B, N, D)
        return self.out(y)

# Prueba
mha = MultiHeadSelfAttention(d_model=64, n_heads=8, causal=True)
x = torch.randn(2, 10, 64)       # batch=2, seq=10, d=64
y = mha(x)
print(y.shape)                   # torch.Size([2, 10, 64])
```

### 4. Uso práctico con HuggingFace Transformers

```python
from transformers import pipeline

# Clasificación de sentimiento (BERT fine-tuned)
clf = pipeline("sentiment-analysis", model="distilbert-base-uncased-finetuned-sst-2-english")
print(clf("The attention mechanism is surprisingly elegant."))
# [{'label': 'POSITIVE', 'score': 0.9998}]

# Generación de texto (GPT-2)
gen = pipeline("text-generation", model="gpt2")
print(gen("Attention is", max_new_tokens=20)[0]["generated_text"])

# Inspección de los pesos de atención
from transformers import AutoTokenizer, AutoModel
tok = AutoTokenizer.from_pretrained("bert-base-uncased")
mdl = AutoModel.from_pretrained("bert-base-uncased", output_attentions=True)

inputs = tok("The laptop was expensive but it was worth it", return_tensors="pt")
out = mdl(**inputs)
attn = out.attentions          # tupla de 12 tensores (una por capa)
print(attn[0].shape)           # (1, 12_heads, seq_len, seq_len)
```

### 5. Fine-tuning snippet (clasificación binaria)

```python
from transformers import AutoTokenizer, AutoModelForSequenceClassification, Trainer, TrainingArguments
from datasets import load_dataset

ds = load_dataset("imdb")
tok = AutoTokenizer.from_pretrained("distilbert-base-uncased")

def tokenize(batch):
    return tok(batch["text"], truncation=True, padding="max_length", max_length=256)

ds = ds.map(tokenize, batched=True)
model = AutoModelForSequenceClassification.from_pretrained("distilbert-base-uncased", num_labels=2)

args = TrainingArguments(
    output_dir="out",
    num_train_epochs=1,
    per_device_train_batch_size=16,
    learning_rate=2e-5,
    evaluation_strategy="epoch",
    bf16=True,                      # entrenamiento en bfloat16
)

trainer = Trainer(
    model=model,
    args=args,
    train_dataset=ds["train"].select(range(2000)),
    eval_dataset=ds["test"].select(range(500)),
)
trainer.train()
```

### 6. Flash Attention (producción)

```python
# Requiere: pip install flash-attn (CUDA)
from flash_attn import flash_attn_func

# Q, K, V: (B, N, h, d_k) en fp16/bf16, en GPU
out = flash_attn_func(Q, K, V, causal=True)
# ~2-4x más rápido y usa O(n) memoria en vez de O(n²)
```

## Errores comunes

- **Olvidar `/ √d_k`.** El softmax satura, los gradientes se desvanecen, el modelo no aprende. Es el error #1 al implementar atención desde cero.
- **Olvidar la máscara causal en decoders.** Sin la máscara triangular, el modelo "espía" los tokens futuros durante el entrenamiento → *data leakage* catastrófico. En inferencia se desploma.
- **Positional encoding mal escalado.** Sumar PE con amplitud mucho mayor que el embedding → el modelo solo ve posición y pierde semántica. O al revés: PE insignificante → pierde orden.
- **Padding mal manejado.** Los tokens `[PAD]` reciben atención si no se enmascaran, metiendo ruido. Siempre pasa una `attention_mask` al tokenizer de HuggingFace.
- **Softmax sin estabilización.** `exp(x)` desborda si `x` es grande. Restar el máximo antes de exponenciar (truco estándar).
- **Confundir cabezas con capas.** Las cabezas (`n_heads`) actúan en paralelo *dentro* de una capa. Las capas (`n_layers`) se apilan en serie. BERT-base: 12 capas × 12 cabezas.
- **Materializar la matriz n×n en secuencias largas.** Con `n=32K`, la matriz pesa `32K² × 4 bytes = 4 GB` por cabeza en fp32. Usa Flash Attention o atención dispersa.
- **Tokenización incorrecta.** Pasar texto sin el tokenizer correcto (BPE, WordPiece, SentencePiece) rompe los embeddings. El modelo y el tokenizer deben ser del mismo checkpoint.
- **Interpretar los pesos de atención como "explicación causal".** Los weights muestran *dónde mira* el modelo, no necesariamente *por qué decide*. Son una señal débil, no una prueba (ver Jain & Wallace 2019 "Attention is not Explanation").
- **No usar `torch.no_grad()` o `model.eval()` en inferencia.** Dropout se queda activo, resultados no reproducibles, y gastas memoria en gradientes.
- **Dimensión incompatible entre cabezas.** `d_model` debe ser divisible por `n_heads`. 768/12 = 64 ✓, 768/10 = 76.8 ✗.
- **Confiar en context windows gigantes sin medir "lost in the middle".** Los modelos tienden a prestar menos atención al centro del contexto (Liu et al., 2023). Poner la información clave al principio o al final.

## Herramientas y librerías

- **HuggingFace Transformers** — hub + API uniforme para 100K+ modelos pre-entrenados.
- **PyTorch** / `torch.nn.functional.scaled_dot_product_attention` — implementación nativa optimizada (usa Flash Attention internamente desde PyTorch 2.0).
- **flash-attn** — librería oficial de Flash Attention 2 (Dao Lab).
- **xformers** — colección de kernels de atención eficiente (Meta).
- **vLLM / TGI** — motores de inferencia para LLMs con atención paginada (PagedAttention).
- **bertviz** — visualización interactiva de pesos de atención en Jupyter.

## Resumen

- La **atención** es una lookup suave y diferenciable sobre una memoria: para cada **query**, pesa un conjunto de **keys** y devuelve una mezcla de **values**.
- La fórmula canónica es `softmax(Q·Kᵀ / √d_k) · V`. El `√d_k` es esencial para la estabilidad del softmax.
- **Self-attention** usa Q, K, V derivados de la misma secuencia; es la operación central del Transformer.
- **Multi-head attention** corre `h` cabezas en paralelo para capturar relaciones distintas (sintaxis, correferencia, semántica…).
- La atención es **permutation-invariant** → hace falta inyectar orden con **positional encodings** (sinusoidal, aprendido, RoPE o ALiBi).
- Las variantes **encoder-only** (BERT), **decoder-only** (GPT), **encoder-decoder** (T5) solo cambian el patrón de máscara y la dirección de la atención.
- La **complejidad O(n²)** explica los precios de API, los límites de contexto y la latencia creciente con secuencias largas.
- Variantes modernas (**Flash Attention, MQA, GQA, sliding window, Mamba**) atacan ese cuello de botella.
- **Errores clásicos**: olvidar `√d_k`, olvidar la máscara causal, mal manejo de padding, mala tokenización y confiar en context windows sin medir pérdida de atención en el medio.
- La atención no es solo matemática elegante: es el salto cualitativo que separa los modelos pre-2017 (RNN/LSTM que olvidaban) de los Transformers modernos capaces de razonar sobre miles de tokens en paralelo.
