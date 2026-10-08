# Evolución de las Arquitecturas: de MLP a Transformers

## ¿Qué es?

Una **arquitectura de red neuronal** es el patrón estructural que define cómo se conectan las neuronas: cuántas capas tiene, de qué tipo (densa, convolucional, recurrente, atencional), cómo fluye la información y qué operaciones específicas realiza cada capa. La elección de arquitectura **codifica una hipótesis** (*inductive bias*) sobre la estructura de los datos:

- **MLP (feedforward)**: asume features independientes; buena para datos tabulares.
- **CNN**: asume **localidad e invarianza a traslación**; perfecta para imágenes.
- **RNN / LSTM**: asume **secuencialidad temporal**; buena para series y lenguaje corto.
- **Transformer**: asume que **cualquier par de posiciones** puede interactuar; domina lenguaje y, cada vez más, visión.

Cada arquitectura surgió para **superar un cuello de botella concreto** de la anterior. Entender esa cadena de limitaciones y soluciones es la mejor forma de intuir por qué hoy los Transformers dominan el panorama de los LLMs.

## ¿Por qué importa?

Elegir la arquitectura correcta puede ser la diferencia entre un modelo que entrena en minutos y uno que no converge en días. Además:

- Sesgos inductivos **mal elegidos** desperdician datos: usar un MLP para imágenes de 1024×1024 requiere ~1M parámetros solo en la primera capa, mientras que una CNN reutiliza filtros con <1K.
- La arquitectura determina qué **tipos de dependencias** el modelo puede capturar: una RNN olvida contexto a 100 tokens, un Transformer no.
- El **costo de inferencia en producción** depende directamente de la arquitectura (CNNs y Transformers son paralelizables; RNNs no).
- Las arquitecturas modernas (Transformer, Mixture-of-Experts) son el fundamento de ChatGPT, Claude, Gemini, Stable Diffusion y Whisper.

## ¿Cómo funciona?

### Cronología

| Año | Arquitectura | Problema que resolvió |
|---|---|---|
| 1958 | Perceptrón | Clasificación lineal |
| 1986 | MLP + backprop | No linealidad vía capas ocultas |
| 1989 | CNN (LeNet) | Imágenes con invarianza a traslación |
| 1997 | LSTM | Dependencias de largo plazo en secuencias |
| 2014 | Seq2Seq + attention | Traducción neuronal |
| 2015 | ResNet | Entrenar redes de >100 capas (skip connections) |
| 2017 | **Transformer** | Paralelización + dependencias globales |
| 2018 | BERT, GPT | Pre-entrenamiento masivo + fine-tuning |
| 2020 | GPT-3, ViT | Escalado 100B+ parámetros; Transformers en visión |
| 2022 | ChatGPT, Stable Diffusion | GenAI masiva |
| 2023+ | Mixture-of-Experts, Mamba (SSMs) | Escalar sin cuadratizar atención |

### 1. Feedforward / MLP

Es la red "clásica": cada capa es densa, totalmente conectada.

```
h⁽ˡ⁾ = φ(W⁽ˡ⁾·h⁽ˡ⁻¹⁾ + b⁽ˡ⁾)
```

**Problema con texto:** representa un correo como un **bag-of-words** (`"free money" = {free:1, money:1}`), perdiendo orden. `"Free the prisoners"` y `"get free money"` activan la misma neurona de "free". Logró ~85% en detección de spam pero **no entiende contexto**.

**Problema con imágenes:** una imagen 224×224×3 = 150,528 entradas. Una primera capa oculta de 1000 neuronas = **150M parámetros** sin siquiera empezar. Insostenible.

### 2. Convolutional Neural Networks (CNN)

**Idea clave:** en imágenes, los patrones son **locales** (un ojo ocupa ~20×20 pixels) y **invariantes a traslación** (un gato sigue siendo un gato esté arriba o abajo). Esto se codifica con **filtros convolucionales** compartidos:

```
(I * K)(i, j) = Σ_m Σ_n I(i+m, j+n) · K(m, n)
```

Un filtro 3×3 tiene 9 parámetros y se desliza por toda la imagen. Jerarquía de representaciones aprendida automáticamente:

| Capa | Qué detecta |
|---|---|
| 1 | Bordes orientados, cambios de color |
| 2 | Texturas, esquinas, patrones repetidos |
| 3 | Partes de objetos (ruedas, ojos) |
| 4+ | Objetos completos |

**Operaciones típicas de una CNN:**

```
Conv2D → BatchNorm → ReLU → MaxPool  ← bloque básico
...repetir varias veces, reduciendo spatial, aumentando canales
Flatten → Dense → Softmax             ← cabeza clasificadora
```

**Hitos:** LeNet-5 (1998, dígitos), **AlexNet (2012)** que ganó ImageNet y detonó la revolución moderna, VGG (2014), GoogLeNet/Inception (2014), **ResNet (2015)** con skip connections que permiten entrenar >100 capas, EfficientNet (2019).

**Limitación con texto:** las CNNs capturan n-gramas locales (`"not good"`, `"very bad"`) pero no relacionan palabras distantes. "El **banco** cerca del río... pidió un préstamo al **banco** central" las trata como dos ocurrencias independientes.

### 3. Recurrent Neural Networks (RNN)

**Idea clave:** procesar la secuencia **paso a paso**, manteniendo un **estado oculto** `h_t` que resume lo visto hasta el instante `t`:

```
h_t = tanh(W_hh·h_{t−1} + W_xh·x_t + b)
y_t = W_hy·h_t + b_y
```

Por primera vez, la red entendía que `"bank"` significa cosa distinta en `"river bank"` vs `"bank loan"` gracias al **contexto previo**. Revolucionó traducción automática, chatbots y predicción de series.

**Problema fundamental:** gradientes que se **desvanecen o explotan** al retropropagar por secuencias largas. En la práctica, una RNN "olvida" información más allá de ~10-20 tokens.

### 4. Long Short-Term Memory (LSTM)

**Idea clave:** añadir **compuertas** (gates) que deciden qué recordar, qué olvidar y qué sacar, con una celda de memoria `c_t` que fluye casi sin modificar entre pasos:

```
f_t = σ(W_f·[h_{t−1}, x_t] + b_f)   ← forget gate
i_t = σ(W_i·[h_{t−1}, x_t] + b_i)   ← input gate
o_t = σ(W_o·[h_{t−1}, x_t] + b_o)   ← output gate
c̃_t = tanh(W_c·[h_{t−1}, x_t] + b_c)
c_t = f_t ⊙ c_{t−1} + i_t ⊙ c̃_t    ← celda de memoria
h_t = o_t ⊙ tanh(c_t)
```

LSTMs mantienen contexto por cientos de tokens. Potenciaron Google Translate (2016), autocompletado de email, Siri/Alexa primera generación. **GRU** (2014) es una variante más simple con sólo 2 compuertas.

**Problema persistente:** siguen siendo **secuenciales por diseño**. Para procesar el token `t` necesitas el `t−1`. Esto imposibilita paralelizar en GPU y limita el tamaño de los modelos que es económicamente viable entrenar.

### 5. Transformers (2017)

**Paper fundacional:** *Attention Is All You Need* (Vaswani et al., 2017). **Idea radical:** eliminar completamente la recurrencia. En lugar de procesar palabra por palabra, cada palabra "mira" **todas las demás simultáneamente** vía un mecanismo llamado **self-attention**.

#### Self-attention en una fórmula

```
Attention(Q, K, V) = softmax(Q·Kᵀ / √d_k) · V
```

Donde para cada token se calculan tres vectores:

- `Q` (query): "qué estoy buscando"
- `K` (key):   "qué ofrezco"
- `V` (value): "mi contenido real"

El producto `Q·Kᵀ` da una matriz `N×N` con la "afinidad" entre cada par de tokens. El softmax la convierte en pesos, y multiplicando por `V` se obtiene, para cada token, una suma ponderada de los demás.

#### Multi-Head Attention

En lugar de un solo set `(Q, K, V)`, se usan **h cabezas en paralelo** (típicamente 8-96), cada una aprendiendo un tipo distinto de relación (sintáctica, semántica, coreferencia…):

```
MHA(x) = Concat(head_1, ..., head_h) · W_O
head_i = Attention(x·W_Q^i, x·W_K^i, x·W_V^i)
```

#### Bloque Transformer completo

```
x → MultiHeadAttention → Add & Norm → FeedForward → Add & Norm → x'
          │                   │             │               │
          └── skip ───────────┘             └── skip ───────┘
```

Las conexiones residuales (`Add`) y `LayerNorm` son esenciales para que el entrenamiento sea estable con decenas de capas.

#### Positional encoding

Como la atención es permutación-invariante, hay que inyectar la **posición** explícitamente. Esquemas populares:

- **Sinusoidal** (paper original): `PE(pos, 2i) = sin(pos / 10000^(2i/d))`
- **Learned**: posiciones como parámetros entrenables.
- **RoPE** (Rotary): rotaciones aplicadas a Q/K; estándar en LLaMA, GPT-NeoX.
- **ALiBi**: sesgo lineal según distancia; mejora extrapolación a secuencias largas.

### Comparativa de arquitecturas

| Arquitectura | Datos ideales | Paralelizable | Memoria contextual | Costo por token | Modelos famosos |
|---|---|---|---|---|---|
| **MLP** | Tabulares | Sí | Ninguna (no secuencial) | O(1) | XGBoost+MLP híbridos |
| **CNN** | Imágenes, audio | Sí | Local (receptive field) | O(1) por posición | ResNet, EfficientNet, YOLO |
| **RNN / LSTM / GRU** | Secuencias cortas | **No** | ~100-500 tokens | O(1) secuencial | ELMo, DeepSpeech |
| **Transformer** | Lenguaje, imágenes, código | Sí | Hasta 1M+ tokens (modelos modernos) | **O(N²)** en secuencia | GPT, BERT, Claude, LLaMA, ViT |
| **SSM (Mamba, S4)** | Secuencias muy largas | Sí | Prácticamente ilimitada | **O(N)** | Mamba, Jamba |
| **MoE** | Escala masiva | Sí (sparse) | Depende del backbone | O(k·d), k expertos activos | GPT-4 (rumoreado), Mixtral, DeepSeek |

### Variantes del Transformer

- **Encoder-only (BERT, 2018):** bidireccional, pre-entrenado con *masked language modeling*. Rey en clasificación, NER, embeddings.
- **Decoder-only (GPT, 2018+):** autoregresivo, predice el siguiente token. Rey en generación de texto. GPT-2 → GPT-3 → GPT-4 → GPT-4.1, Claude 1-4.x.
- **Encoder-decoder (T5, BART):** entrada se codifica, salida se genera. Bueno para traducción, resumen.
- **Vision Transformer (ViT, 2020):** parte la imagen en parches 16×16 y los trata como "tokens". Supera a las CNNs con suficiente data.
- **Multimodales (CLIP, Flamingo, GPT-4V, Claude 3+):** combinan tokens de texto e imagen (y audio, video).

## Ejemplo con código

### Self-attention desde cero (NumPy)

```python
import numpy as np

def softmax(x, axis=-1):
    x = x - x.max(axis=axis, keepdims=True)
    e = np.exp(x)
    return e / e.sum(axis=axis, keepdims=True)

def self_attention(X, W_Q, W_K, W_V):
    """
    X   : (N, d_model) — N tokens embebidos
    W_* : (d_model, d_k) — proyecciones aprendibles
    """
    Q = X @ W_Q            # (N, d_k)
    K = X @ W_K            # (N, d_k)
    V = X @ W_V            # (N, d_k)
    d_k = Q.shape[-1]
    scores  = Q @ K.T / np.sqrt(d_k)         # (N, N)
    weights = softmax(scores, axis=-1)       # pesos de atención
    return weights @ V, weights

# Toy: 4 tokens, d_model = 8, d_k = 4
rng = np.random.default_rng(0)
X   = rng.normal(size=(4, 8))
W_Q = rng.normal(size=(8, 4))
W_K = rng.normal(size=(8, 4))
W_V = rng.normal(size=(8, 4))

out, attn = self_attention(X, W_Q, W_K, W_V)
print("Salida:", out.shape)                  # (4, 4)
print("Matriz de atención (filas = queries):")
print(attn.round(2))
```

### Mini-transformer con PyTorch

```python
import torch
import torch.nn as nn

class TransformerBlock(nn.Module):
    def __init__(self, d_model=128, n_heads=4, d_ff=512, p=0.1):
        super().__init__()
        self.attn = nn.MultiheadAttention(d_model, n_heads,
                                          dropout=p, batch_first=True)
        self.ln1  = nn.LayerNorm(d_model)
        self.ff   = nn.Sequential(
            nn.Linear(d_model, d_ff),
            nn.GELU(),
            nn.Linear(d_ff, d_model),
        )
        self.ln2  = nn.LayerNorm(d_model)
        self.drop = nn.Dropout(p)

    def forward(self, x, mask=None):
        # Pre-norm (más estable que post-norm original)
        h = self.ln1(x)
        a, _ = self.attn(h, h, h, attn_mask=mask, need_weights=False)
        x = x + self.drop(a)
        h = self.ln2(x)
        x = x + self.drop(self.ff(h))
        return x

class MiniGPT(nn.Module):
    def __init__(self, vocab=50257, d_model=128, n_heads=4,
                 n_layers=4, max_len=1024):
        super().__init__()
        self.tok_emb = nn.Embedding(vocab, d_model)
        self.pos_emb = nn.Embedding(max_len, d_model)
        self.blocks  = nn.ModuleList(
            [TransformerBlock(d_model, n_heads) for _ in range(n_layers)]
        )
        self.ln_f    = nn.LayerNorm(d_model)
        self.head    = nn.Linear(d_model, vocab, bias=False)

    def forward(self, idx):
        B, T = idx.shape
        pos  = torch.arange(T, device=idx.device)
        x    = self.tok_emb(idx) + self.pos_emb(pos)
        # Máscara causal: cada posición solo ve el pasado
        mask = torch.triu(torch.ones(T, T, device=idx.device), diagonal=1).bool()
        for blk in self.blocks:
            x = blk(x, mask=mask)
        return self.head(self.ln_f(x))

model = MiniGPT()
idx   = torch.randint(0, 50257, (2, 32))     # batch 2, 32 tokens
logits = model(idx)
print("logits:", logits.shape)               # (2, 32, 50257)
print("params:", sum(p.numel() for p in model.parameters()))
```

### LSTM comparativo (PyTorch)

```python
import torch.nn as nn

lstm = nn.LSTM(input_size=64, hidden_size=128,
               num_layers=2, batch_first=True, dropout=0.1)
x = torch.randn(16, 50, 64)                  # batch, seq, feat
out, (h, c) = lstm(x)
# out:(16,50,128)  h:(2,16,128)  c:(2,16,128)
```

## Errores comunes

- **Usar una RNN cuando necesitas contexto largo**. Para >500 tokens, un Transformer casi siempre gana. LSTMs sobreviven en edge devices por su bajo footprint.
- **Olvidar la máscara causal en un decoder**. Sin ella, GPT "ve el futuro" durante el entrenamiento y luego falla miserablemente en inferencia.
- **Olvidar positional encoding**. Sin él, un Transformer trata la secuencia como un conjunto desordenado: `"perro muerde hombre"` = `"hombre muerde perro"`.
- **Confundir encoder-only con decoder-only**. BERT no genera texto fluido; GPT no es la mejor opción para embeddings de clasificación. Elige según la tarea.
- **Asumir que atención O(N²) escala gratis**. Doblar el contexto cuadruplica memoria y cómputo. Para contextos muy largos: **FlashAttention**, **sliding window**, **Mamba**, **sparse attention**.
- **Pre-norm vs. post-norm**. El paper original usa post-norm (`LN(x + sublayer(x))`), pero post-norm es inestable a gran escala. Los LLMs modernos usan **pre-norm** (`x + sublayer(LN(x))`).
- **Fine-tunear capas convolucionales con learning rate alto**. Las primeras capas de una CNN pre-entrenada ya aprendieron bordes universales; destruirlas con un LR fuerte empeora el resultado. Usa **LR diferenciados** por capa.
- **Vanishing gradients en redes profundas sin skip connections**. Resnet lo resolvió para CNNs; los Transformers lo heredan vía las conexiones residuales de cada bloque. Nunca las elimines.
- **No tokenizar correctamente**. Un Transformer no procesa texto crudo: necesita un tokenizer (BPE, WordPiece, SentencePiece). El tokenizer **debe ser el mismo** en entrenamiento e inferencia.
- **Elegir arquitectura por moda, no por datos**. Para 10,000 filas tabulares, un XGBoost suele ganarle a cualquier red neuronal. Mide, no asumas.

## Modelos emblemáticos que verás en producción

| Modelo | Año | Arquitectura | Parámetros | Nota |
|---|---|---|---|---|
| LeNet-5 | 1998 | CNN | 60K | Lectura de cheques |
| AlexNet | 2012 | CNN | 60M | Ganó ImageNet |
| ResNet-50 | 2015 | CNN + skip | 25M | Backbone estándar |
| BERT-base | 2018 | Transformer encoder | 110M | NLP de propósito general |
| GPT-2 | 2019 | Transformer decoder | 1.5B | Generación coherente |
| GPT-3 | 2020 | Transformer decoder | 175B | Few-shot learning |
| ViT-L | 2020 | Transformer en imágenes | 300M | Compite con CNN |
| Stable Diffusion | 2022 | U-Net + Transformer (latent) | ~1B | Generación de imágenes |
| LLaMA 3 / Claude / GPT-4+ | 2023-26 | Decoder + MoE | 70B–1T+ | Estado del arte en texto |
| Mamba | 2023 | SSM | 1-7B | Alternativa O(N) a atención |

## Resumen

- La historia del DL es una **cadena de arquitecturas** que superan el cuello de botella de la anterior: MLP → CNN → RNN → LSTM → **Transformer** → SSMs/MoE.
- **MLP**: universal pero sin sesgo útil para datos estructurados.
- **CNN**: localidad + invarianza a traslación → rey en visión.
- **RNN/LSTM**: secuencialidad + memoria → rey histórico en lenguaje, pero no paraleliza.
- **Transformer**: atención global + paralelización masiva → base de todos los LLMs modernos (GPT, Claude, LLaMA, Gemini).
- **Self-attention** `softmax(QKᵀ/√d_k)·V` es la operación central; **multi-head** permite múltiples tipos de relaciones; **positional encoding** reintroduce el orden.
- **Variantes**: encoder-only (BERT, embeddings), decoder-only (GPT, generación), encoder-decoder (T5, traducción), ViT (visión), multimodales (CLIP, GPT-4V).
- La elección de arquitectura **codifica un sesgo inductivo**: elige la que mejor case con la estructura de tus datos, no la de moda.
- El futuro cercano: contextos de millones de tokens (FlashAttention, Ring Attention), eficiencia O(N) (**Mamba**, SSMs) y **Mixture-of-Experts** para escalar sin cuadratizar costos.
