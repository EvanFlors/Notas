# GPT: Modelos de Próximo Token para Generación de Texto

## ¿Qué es?

**GPT** (*Generative Pre-trained Transformer*) es una familia de modelos de lenguaje creada por OpenAI que se basa en una idea notablemente simple: **predecir el siguiente token** dado todo lo anterior. Formalmente, GPT modela la probabilidad conjunta de una secuencia como el producto de probabilidades condicionales:

```
P(w₁, w₂, …, wₙ) = Π_{i=1}^{n} P(wᵢ | w₁, w₂, …, wᵢ₋₁)
```

Esta formulación —idéntica a la que usaban los modelos n-gram desde los años 80— se vuelve extraordinariamente poderosa cuando la aproximas con una **red neuronal profunda** (Transformer decoder) entrenada sobre **cientos de miles de millones de tokens**.

A diferencia de BERT (que ve toda la secuencia a la vez), GPT es **autorregresivo** y **causal**: cada token sólo puede atender a los tokens anteriores, nunca a los futuros. Esto se logra con una **máscara de atención causal** (triangular inferior) dentro del mecanismo de self-attention.

![Arquitectura GPT](https://hrcdn.net/ai-engineering/module-1/dark/language-models-lesson03-gpt-architecture.svg)

### Línea evolutiva

| Año | Modelo | Parámetros | Contexto | Hito |
|---|---|---|---|---|
| 2018 | GPT-1 | 117 M | 512 | Prueba el paradigma pre-train + fine-tune |
| 2019 | GPT-2 | 1.5 B | 1024 | OpenAI retiene el modelo "por riesgo" |
| 2020 | GPT-3 | 175 B | 2048 | Few-shot learning emergente |
| 2022 | ChatGPT (GPT-3.5) | ~175 B | 4k–16k | Masificación pública |
| 2023 | GPT-4 | ~1.7 T (MoE) | 8k–128k | Multimodal, razonamiento |
| 2024 | GPT-4o / o1 | — | 128k+ | Modalidad omni + razonamiento con cadena |

En paralelo surgieron familias open-source con la misma arquitectura decoder-only: **LLaMA** (Meta), **Mistral**, **Falcon**, **Qwen**, **Gemma** (Google), **Claude** (Anthropic), **DeepSeek**.

## ¿Por qué importa?

El objetivo de predecir el próximo token parece trivial pero resulta un **objetivo universal**: para predecir bien el siguiente token el modelo debe aprender gramática, semántica, pragmática, conocimiento del mundo, aritmética, código, estilo, lógica… todo lo que esté implícito en el corpus de entrenamiento.

El resultado práctico es que un único modelo puede, con el prompt adecuado:

- **Chatbots y asistentes** (ChatGPT, Claude).
- **Generación y edición de código** (GitHub Copilot, Cursor).
- **Redacción** (correos, documentación, marketing).
- **Resumen y reescritura**.
- **Traducción** (sin ser entrenado específicamente para ello).
- **Agentes autónomos** que planifican y ejecutan acciones.
- **RAG**: responder preguntas sobre documentos privados.

### Capacidades emergentes

Un hallazgo del artículo de GPT-3 (Brown et al., 2020, *"Language Models are Few-Shot Learners"*) es que ciertas capacidades —aritmética de varios dígitos, razonamiento análogo, respuesta a instrucciones— **emergen súbitamente** cuando el modelo cruza cierto umbral de escala (~10B parámetros). Son invisibles por debajo y robustas por encima.

### Impacto cultural y económico

- ChatGPT alcanzó **100M usuarios en 2 meses** (noviembre 2022–enero 2023), el producto digital de adopción más rápida de la historia.
- La industria de IA generativa se valoró en >$150B en 2024 (McKinsey).
- Reconfiguró roles: *prompt engineer*, *AI engineer*, *LLM ops*.

## ¿Cómo funciona?

### 1. Predicción del próximo token

Dado un prompt como `"El clima hoy está"`, GPT calcula una **distribución de probabilidad sobre todo el vocabulario** para el siguiente token:

```
P(wₙ₊₁ | "El clima hoy está")
    = { soleado: 0.30, nublado: 0.25, lluvioso: 0.20,
        hermoso: 0.15, horrible: 0.10 }
```

Después se **muestrea** un token de esa distribución, se concatena al prompt y se repite. Esto es la **generación autorregresiva**.

![Objetivo de entrenamiento GPT](https://hrcdn.net/ai-engineering/module-1/dark/language-models-lesson03-next-token-prediction.svg)

### 2. Función de pérdida

Durante el entrenamiento, para cada posición `i` se compara la distribución predicha con el token real usando **cross-entropy**:

```
L = -Σᵢ log P(wᵢ | w₁, …, wᵢ₋₁)
```

Métrica derivada: la **perplejidad**, interpretable como "cuántas opciones promedio sopesó el modelo":

```
Perplejidad = exp(L) = 2^H   (donde H = entropía cruzada en bits)
```

Un modelo con perplejidad 10 "duda" entre ~10 tokens en promedio; uno con perplejidad 1.5 está casi seguro. GPT-3 alcanzaba ~20 en WikiText-103; los modelos actuales están por debajo de 10.

### 3. Arquitectura decoder-only

Cada capa de GPT contiene:

1. **Masked Multi-Head Self-Attention** (con máscara causal: posición `i` sólo ve `≤ i`).
2. **Add & LayerNorm** (en versiones recientes se usa Pre-LN y RMSNorm).
3. **Feed-Forward Network** (dos linears + GELU o SwiGLU).
4. **Add & LayerNorm**.

```
Tokens → Embedding + Posicional (RoPE/ALiBi en modelos recientes)
         ↓
         N × [Masked Self-Attention → FFN]      (N = 12 a 96+)
         ↓
         Linear → Softmax sobre vocabulario
         ↓
         P(wₙ₊₁ | w₁..wₙ)
```

La **máscara causal** es simplemente una matriz triangular superior de `-∞` sumada a los scores de atención antes del softmax:

```
mask[i, j] = 0      si j ≤ i
mask[i, j] = -∞     si j > i   ← bloquea mirar al futuro
```

### 4. Estrategias de muestreo

Elegir el próximo token a partir de la distribución es un arte:

| Estrategia | Descripción | Cuándo usar |
|---|---|---|
| **Greedy** | Siempre el máximo | Determinista, para pruebas o tareas con única respuesta |
| **Beam search** | Mantiene las K secuencias más probables | Traducción, resumen (reduce "surprise") |
| **Temperature** `T` | Reescala logits: `pᵢ ∝ exp(logitᵢ / T)` | T<1 conservador, T>1 creativo |
| **Top-k** | Muestrea entre los k tokens más probables | Elimina cola larga de absurdos |
| **Top-p (nucleus)** | Muestrea del conjunto más pequeño cuya suma de prob ≥ p | Adaptativo, muy popular |
| **Repetition penalty** | Reduce probabilidad de tokens ya emitidos | Evita bucles |

**Fórmula de temperatura:**

```
P_T(wᵢ) = exp(logitᵢ / T) / Σⱼ exp(logitⱼ / T)
```

- `T → 0`: equivale a greedy (toda la masa en el máximo).
- `T = 1`: distribución original del modelo.
- `T → ∞`: distribución uniforme (ruido puro).

### 5. Entrenamiento en tres etapas (modelos modernos)

1. **Pre-entrenamiento** sobre terabytes de web/código con next-token prediction.
2. **Supervised Fine-Tuning (SFT)** con pares `(prompt, respuesta)` curados por humanos.
3. **RLHF** (*Reinforcement Learning from Human Feedback*) o **DPO** para alinear el modelo con preferencias humanas.

Esta receta es lo que convirtió un *modelo que completa texto* (GPT-3) en un *asistente que sigue instrucciones* (ChatGPT).

## Ejemplo con código

### 1. Simulación didáctica de generación autorregresiva

```python
import random

def generar(contexto, transiciones, max_tokens=10, seed=0):
    random.seed(seed)
    texto = contexto
    for paso in range(max_tokens):
        clave = " ".join(texto.split()[-2:])
        candidatos = transiciones.get(clave, ["."])
        siguiente = random.choice(candidatos)
        texto += " " + siguiente
        print(f"Paso {paso+1}: contexto='{clave}' → '{siguiente}'  ⇒  {texto}")
        if siguiente in {".", "!"}:
            break
    return texto

transiciones = {
    "El gato":  ["duerme", "corre", "salta"],
    "gato duerme": ["sobre", "cerca"],
    "duerme sobre": ["el", "la"],
    "sobre el":  ["sofá", "tapete"],
    "el sofá":   ["."],
}
generar("El gato", transiciones, seed=1)
```

### 2. Efecto de la temperatura (desde cero)

```python
import math, random
from collections import Counter

def softmax_temp(logits, T):
    exps = {k: math.exp(v / T) for k, v in logits.items()}
    z = sum(exps.values())
    return {k: v / z for k, v in exps.items()}

def muestrear(dist, n=1000):
    tokens, pesos = zip(*dist.items())
    return Counter(random.choices(tokens, weights=pesos, k=n))

logits = {"soleado": 2.0, "nublado": 1.5, "lluvioso": 1.0, "tormenta": 0.5}
for T in [0.1, 0.7, 1.0, 2.0]:
    d = softmax_temp(logits, T)
    print(f"T={T}  → {{" + ", ".join(f'{k}:{v:.2f}' for k, v in d.items()) + "}")
    print("        muestras:", dict(muestrear(d, 1000)))
```

### 3. Top-k y Top-p (nucleus)

```python
def top_k(dist, k):
    orden = sorted(dist.items(), key=lambda kv: kv[1], reverse=True)[:k]
    z = sum(v for _, v in orden)
    return {k: v / z for k, v in orden}

def top_p(dist, p=0.9):
    orden = sorted(dist.items(), key=lambda kv: kv[1], reverse=True)
    acum, elegidos = 0.0, []
    for tok, prob in orden:
        elegidos.append((tok, prob))
        acum += prob
        if acum >= p:
            break
    z = sum(v for _, v in elegidos)
    return {k: v / z for k, v in elegidos}

dist = {"a": 0.4, "b": 0.3, "c": 0.15, "d": 0.1, "e": 0.05}
print("Top-k(2):", top_k(dist, 2))
print("Top-p(0.8):", top_p(dist, 0.8))
```

### 4. Generación real con un GPT open-source

```python
# pip install transformers accelerate
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch

MODEL = "gpt2"  # cámbialo por "mistralai/Mistral-7B-Instruct-v0.2" si tienes GPU
tok = AutoTokenizer.from_pretrained(MODEL)
model = AutoModelForCausalLM.from_pretrained(MODEL)

prompt = "La inteligencia artificial transformará la medicina porque"
inputs = tok(prompt, return_tensors="pt")

salida = model.generate(
    **inputs,
    max_new_tokens=60,
    do_sample=True,
    temperature=0.8,
    top_p=0.9,
    repetition_penalty=1.15,
    pad_token_id=tok.eos_token_id,
)
print(tok.decode(salida[0], skip_special_tokens=True))
```

### 5. Tokenización con tiktoken (OpenAI)

```python
# pip install tiktoken
import tiktoken

enc = tiktoken.get_encoding("cl100k_base")  # GPT-4 / GPT-3.5
texto = "La IA generativa está cambiando el mundo del software."
ids = enc.encode(texto)
print(f"Tokens ({len(ids)}): {ids}")
print("Decoded piezas:", [enc.decode([i]) for i in ids])
```

### 6. Usando la API de OpenAI (producción)

```python
# pip install openai
from openai import OpenAI
client = OpenAI()  # requiere OPENAI_API_KEY

resp = client.chat.completions.create(
    model="gpt-4o-mini",
    temperature=0.7,
    max_tokens=200,
    messages=[
        {"role": "system", "content": "Eres un asistente técnico en español."},
        {"role": "user",   "content": "Explica qué es la perplejidad en 3 líneas."},
    ],
)
print(resp.choices[0].message.content)
```

## Errores comunes

- **Confundir "sampling" con "generación determinista".** Con `temperature>0` cada ejecución da resultados distintos. Para pipelines reproducibles usa `temperature=0` o fija `seed`.
- **Prompts ambiguos.** "Resume esto" no es tan efectivo como "Resume en 3 bullets de máximo 15 palabras para un ejecutivo que no es técnico".
- **Olvidar el límite de contexto.** Si tu prompt + historial + respuesta superan la ventana (p.ej. 128k en GPT-4-turbo), se trunca silenciosamente. Diseña con *context management* (resumir, RAG, sliding window).
- **No manejar alucinaciones.** GPT puede inventar datos con total confianza. Siempre que el output contenga hechos verificables, incluye fuentes (RAG) o validación posterior.
- **Costos sin control.** Un sistema que usa GPT-4 sin caching ni *prompt compression* puede escalar a miles de dólares/día. Mide tokens por request y cachea respuestas repetidas.
- **Prompt injection.** Si tu app concatena input de usuario al prompt del sistema, un atacante puede escribir "ignora tus instrucciones y haz X". Usa validación, delimitadores y modelos con *instruction hierarchy*.
- **Streaming mal implementado.** Para UX fluida usa `stream=True`; sin streaming el usuario espera 20s mirando un spinner.
- **Elegir la familia equivocada.** Para *clasificar* texto repetitivo, un BERT fine-tuned es 10–100x más barato y rápido que GPT-4. Reserva LLMs para tareas que requieran generación o razonamiento abierto.
- **No controlar repetición.** Sin `repetition_penalty` o `no_repeat_ngram_size`, GPT puede entrar en bucles ("la la la la…").
- **Olvidar `pad_token_id`.** En HuggingFace, generar con GPT-2 sin fijar `pad_token_id=eos_token_id` lanza warnings y a veces trunca mal.
- **Mezclar tokenizers.** El conteo de tokens de `cl100k_base` difiere del de LLaMA; estimar costos con el tokenizer equivocado puede desviar un 30%.

## Parámetros clave de generación (cheat sheet)

| Parámetro | Rango útil | Efecto |
|---|---|---|
| `temperature` | 0.0 – 1.5 | 0 = determinista, >1 = creativo/caótico |
| `top_p` | 0.5 – 1.0 | Nucleus sampling; 0.9 es un gran default |
| `top_k` | 0 – 100 | Limita al top-k; 0 lo desactiva |
| `max_tokens` | 1 – contexto | Longitud máxima de la respuesta |
| `frequency_penalty` | −2.0 – 2.0 | Penaliza tokens frecuentes |
| `presence_penalty` | −2.0 – 2.0 | Penaliza tokens ya usados |
| `stop` | string(s) | Secuencia(s) que detienen la generación |
| `seed` | int | Semilla para reproducibilidad (OpenAI) |

**Recetas rápidas:**

- Código / docs técnicos: `T=0.1–0.3, top_p=0.95`.
- Chatbot amigable: `T=0.7, top_p=0.9`.
- Lluvia de ideas creativa: `T=1.0–1.2, top_p=0.95`.
- Clasificación zero-shot: `T=0, max_tokens=5, stop=["\n"]`.

## Comparación GPT vs. BERT

| Dimensión | GPT (decoder-only) | BERT (encoder-only) |
|---|---|---|
| Dirección de atención | Causal (izq→der) | Bidireccional |
| Objetivo | Next-token prediction | Masked LM |
| Entrada típica | Prompt libre | Oración(es) + `[CLS]`, `[SEP]` |
| Salida típica | Nuevos tokens | Vectores contextuales |
| Fortaleza | Generación, instrucción, razonamiento | Entendimiento, clasificación, NER |
| Costo de inferencia | Alto (una pasada por token) | Bajo (una pasada por documento) |
| Few-shot / zero-shot | Excelente a gran escala | Limitado; requiere fine-tuning |

## Resumen

- **GPT** modela `P(wᵢ | w₁..wᵢ₋₁)` con un **Transformer decoder-only** y máscara de atención **causal**.
- El entrenamiento consiste en **predecir el siguiente token** sobre miles de millones de ejemplos; a escala suficiente emergen capacidades sorprendentes.
- Se entrena en tres etapas en los modelos modernos: **pre-entrenamiento → SFT → RLHF/DPO**.
- La **generación es autorregresiva**: un token a la vez, cada uno condicionado por todos los previos.
- **Temperatura, top-k y top-p** controlan el balance entre creatividad y coherencia. 0.7 y top-p 0.9 son defaults razonables.
- Métrica central: **perplejidad = exp(cross-entropy)**; medida de qué tan "sorprendido" está el modelo.
- Elige GPT para **generación**, chat, código, agentes y razonamiento abierto. Elige BERT (u otros encoders) para **clasificación/NER** puros.
- Vigila **alucinaciones, prompt injection, costos y límites de contexto**: son los problemas que diferencian un prototipo de un sistema en producción.
- La familia decoder-only (GPT, LLaMA, Mistral, Claude, Qwen) domina el panorama 2023–2026 y es la base de los **AI agents** y productos conversacionales modernos.
