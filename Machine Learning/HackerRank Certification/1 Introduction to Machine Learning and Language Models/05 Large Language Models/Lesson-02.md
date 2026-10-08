# Interacción con LLMs: parámetros, tokens y optimización de costo

## ¿Qué es?

Cada llamada a una API de LLM es una pequeña configuración de **cómo generar texto**. No es sólo "mandar un prompt y recibir respuesta": es controlar — token por token — qué distribución de probabilidad usa el modelo para elegir el siguiente token, cuántos tokens produce, cuándo detenerse y cuánto cuesta.

Una interacción típica con un LLM se compone de:

| Componente | Qué es | Impacto |
|---|---|---|
| **Prompt** (system + user) | El texto de entrada | Define la tarea y el contexto |
| **Model selection** | Qué modelo del catálogo usar | Calidad, costo, latencia |
| **Sampling params** | `temperature`, `top_p`, `top_k`, `frequency_penalty`, `presence_penalty` | Creatividad vs. determinismo |
| **Length control** | `max_tokens`, `stop` sequences | Dónde cortar la generación |
| **Reproducibilidad** | `seed` | Mismo input → mismo output |
| **Token accounting** | Conteo input + output | Costo y uso de contexto |
| **Response format** | JSON mode, structured outputs, tool use | Garantías de formato |

La diferencia entre un prototipo que "funciona en el notebook" y un sistema de producción confiable es, en gran medida, **la elección deliberada de cada uno de estos componentes** en vez de aceptar los defaults.

### Analogía: la cámara fotográfica

Piensa en el LLM como una cámara profesional. Tu *prompt* es el sujeto que fotografías. Los *parámetros* son apertura, ISO, velocidad de obturación: el mismo sujeto cambia radicalmente según cómo los ajustes. Los *tokens* son tu presupuesto de rollo fotográfico: finito y pagado. Un fotógrafo profesional ajusta cada setting según el contexto; un desarrollador profesional de LLM apps hace lo mismo.

## ¿Por qué importa?

Porque **los defaults te traicionan en producción**:

- `temperature=1.0` (el default de OpenAI) hace que tu extractor de datos devuelva resultados distintos cada vez — rompiendo tests, caches y confianza del usuario.
- No fijar `max_tokens` deja que el modelo escriba 4000 tokens cuando necesitabas 50 — pagas 80× más de lo necesario.
- No contar tokens antes de enviar causa errores de *context overflow* en producción cuando el usuario pega un documento grande.
- No usar structured outputs hace que `json.loads()` lance excepciones aleatorias en el 2-5% de las requests.

El costo de una app LLM mal configurada se mide en miles de dólares/mes y clientes perdidos. El de una bien configurada, en centavos por request.

### Ejemplo cuantitativo

Un asistente de soporte procesa 100K requests/día. Prompt system de 2000 tokens, user ~200 tokens, respuesta ~300 tokens.

| Configuración | Costo/día (gpt-4o-mini) |
|---|---|
| Sin caching, max_tokens=4000 | ~$52 |
| Sin caching, max_tokens=400 | ~$18 |
| **Con prompt caching + max_tokens=400** | **~$4** |

Mismo producto, mismo modelo. 13× de diferencia.

## ¿Cómo funciona?

### 1. Tokenización — la unidad fundamental

Los LLMs no ven palabras, ven **tokens**: subunidades aprendidas con **Byte Pair Encoding (BPE)**. Reglas de pulgar:

| Contenido | Tokens / palabra | Chars / token |
|---|---|---|
| Inglés | 0.75 | 4.0 |
| Español | 1.0 – 1.3 | 3.5 |
| Código | 1.3 – 1.8 | 2.5 |
| JSON | 1.5 – 2.0 | 2.0 |
| Chino / Japonés / Árabe | 2 – 3 | 1.5 |

Encodings comunes:

| Encoding | Modelos |
|---|---|
| `cl100k_base` | GPT-3.5, GPT-4 clásico |
| `o200k_base` | GPT-4o, GPT-4.1, GPT-5, o1 |
| `p50k_base` | davinci legacy, Codex |

> **Overhead del chat API:** cada mensaje añade ~3-4 tokens de estructura (role, delimitadores). Una conversación de 10 turnos puede acumular 60-80 tokens sólo en estructura. En multi-turn largas, resumen las N-5 anteriores.

### 2. Temperature — creatividad vs. determinismo

Temperature `T` escala los *logits* antes del softmax:

```
P(token_i) = softmax(logits_i / T)
```

- `T → 0` : la distribución colapsa en el token más probable → **determinista**.
- `T = 1` : distribución nativa del modelo.
- `T → ∞` : distribución uniforme → caos.

Guía práctica por caso de uso:

| Tarea | Temperature | Por qué |
|---|---|---|
| Extracción de datos / clasificación | 0.0 | Mismo input, misma salida |
| Generación de código | 0.1 – 0.2 | Precisión, sintaxis correcta |
| Soporte al cliente / RAG | 0.2 – 0.4 | Útil pero consistente |
| Resúmenes, traducción | 0.3 – 0.5 | Fidelidad con algo de variedad |
| Escritura técnica | 0.5 – 0.7 | Balance |
| Brainstorming | 0.8 – 1.0 | Variedad de ideas |
| Escritura creativa | 1.0 – 1.3 | Máxima creatividad |

### 3. Top-p (nucleus sampling) y top-k

**Top-k**: considera solo los `k` tokens más probables. Simple pero rígido.

**Top-p (nucleus)**: considera el conjunto más chico de tokens cuya probabilidad acumulada supere `p`. Dinámico — en pasos "obvios" solo mira pocos tokens, en pasos ambiguos considera muchos.

```
top_p = 0.1  → muy focalizado (10% de masa de probabilidad)
top_p = 0.9  → estándar en producción
top_p = 1.0  → sin filtrado
```

Recomendación de OpenAI/Anthropic: **ajusta temperature O top_p, no ambos**. Default sensato: `temperature=0.3, top_p=1.0` o `temperature=1.0, top_p=0.9`.

### 4. max_tokens, stop sequences y seed

- **`max_tokens`:** techo duro de tokens generados. Protege contra respuestas infinitas y costos descontrolados. Siempre dimensiona según la tarea (50 para clasificar, 500 para analizar, 2000 para generar artículo).
- **`stop` sequences:** strings donde el modelo debe cortar. Útiles para formatos estructurados ("`\n\n###`", "`</answer>`") o generación de código ("`\ndef`" para no empezar otra función).
- **`seed`:** fija la aleatoriedad del sampling. Mismo seed + mismo prompt + mismo modelo = misma salida (determinismo *best-effort*, no 100% garantizado por los proveedores). Esencial para tests.
- **`frequency_penalty` / `presence_penalty`:** desincentivan repetición. Útiles si notas que el modelo repite frases. Valores típicos 0.0 – 1.0.

### 5. System prompts

El `system` message define identidad, estilo y restricciones del asistente. Se procesa igual que cualquier texto pero convencionalmente el modelo le da más peso. Un buen system prompt:

```
Eres <ROL> especializado en <DOMINIO>.
Tu objetivo: <TAREA>.
Formato de respuesta: <ESTRUCTURA>.
Restricciones: <LO QUE NO HACER>.
Si no sabes algo, di "No lo sé" en vez de inventar.
```

### 6. Structured outputs (JSON mode, tool use)

En vez de pedir "devuelve JSON" en prose y rezar, usa las APIs nativas:

- **OpenAI:** `response_format={"type": "json_schema", "json_schema": {...}}` — garantiza JSON válido conforme al schema.
- **Anthropic:** `tools=[...]` con `tool_choice` forzado — el modelo responde llamando a tu "función".
- **Librerías:** **Instructor**, **Outlines**, **LMFormatEnforcer**, **Pydantic AI**.

### 7. Pricing — modelo de dos tramos

Todas las APIs cobran distinto input vs. output (output es 2-5× más caro porque es más lento de generar):

| Modelo (2025, referencial) | Input $/1M | Output $/1M | Cached input |
|---|---|---|---|
| gpt-4o | 2.50 | 10.00 | 1.25 |
| gpt-4o-mini | 0.15 | 0.60 | 0.075 |
| gpt-5-mini | 0.25 | 2.00 | 0.025 |
| gpt-5-nano | 0.05 | 0.40 | 0.005 |
| Claude 3.5 Sonnet | 3.00 | 15.00 | 0.30 (90% off) |
| Claude Haiku 3.5 | 0.80 | 4.00 | 0.08 |
| Claude Opus 4 | 15.00 | 75.00 | 1.50 |
| Gemini 1.5 Pro | 1.25 | 5.00 | 0.3125 |
| Gemini 1.5 Flash | 0.075 | 0.30 | 0.01875 |
| DeepSeek V3 | 0.27 | 1.10 | 0.07 |

> **Prompt caching** (OpenAI, Anthropic, Google): si tu system prompt o contexto RAG es grande y se repite, actívalo. Reduce costo input hasta 90% y latencia hasta 85%. Es *una línea* de código.

## Ejemplo con código

### Conteo preciso de tokens antes de llamar

```python
# pip install tiktoken
import tiktoken

class ContadorTokens:
    _ENCODINGS = {
        "gpt-4o":        "o200k_base",
        "gpt-4o-mini":   "o200k_base",
        "gpt-5":         "o200k_base",
        "gpt-5-mini":    "o200k_base",
        "gpt-4":         "cl100k_base",
        "gpt-3.5-turbo": "cl100k_base",
    }

    def __init__(self, modelo="gpt-4o"):
        self.enc = tiktoken.get_encoding(self._ENCODINGS.get(modelo, "o200k_base"))

    def contar(self, texto: str) -> int:
        return len(self.enc.encode(texto))

    def contar_mensajes(self, mensajes: list[dict]) -> int:
        """Incluye el overhead de estructura del chat API."""
        total = 3  # priming del assistant
        for m in mensajes:
            total += 3
            for k, v in m.items():
                total += len(self.enc.encode(str(v)))
                if k == "name":
                    total += 1
        return total

c = ContadorTokens("gpt-4o")
mensajes = [
    {"role": "system", "content": "Eres un asistente conciso."},
    {"role": "user",   "content": "¿Qué es el nucleus sampling?"},
]
print("Input tokens:", c.contar_mensajes(mensajes))
```

### Presets de parámetros por tarea

```python
PRESETS = {
    "extraccion_json":  {"temperature": 0.0, "top_p": 1.0, "max_tokens": 300, "seed": 42},
    "clasificacion":    {"temperature": 0.0, "top_p": 1.0, "max_tokens": 10},
    "codigo":           {"temperature": 0.1, "top_p": 0.95, "max_tokens": 800},
    "soporte":          {"temperature": 0.3, "top_p": 0.9,  "max_tokens": 400},
    "resumen":          {"temperature": 0.4, "top_p": 0.9,  "max_tokens": 500},
    "brainstorm":       {"temperature": 0.9, "top_p": 0.95, "max_tokens": 600},
    "creativo":         {"temperature": 1.2, "top_p": 0.95, "max_tokens": 1200},
}

def llamar(oai, modelo, tarea, mensajes):
    return oai.chat.completions.create(
        model=modelo, messages=mensajes, **PRESETS[tarea]
    )
```

### Calculadora de costos y presupuesto

```python
PRECIOS = {  # $/1M tokens
    "gpt-4o":       {"in": 2.50,  "out": 10.00, "cached_in": 1.25},
    "gpt-4o-mini":  {"in": 0.15,  "out": 0.60,  "cached_in": 0.075},
    "gpt-5-nano":   {"in": 0.05,  "out": 0.40,  "cached_in": 0.005},
    "claude-sonnet": {"in": 3.00, "out": 15.00, "cached_in": 0.30},
    "claude-haiku":  {"in": 0.80, "out": 4.00,  "cached_in": 0.08},
}

def costo(in_tok, out_tok, modelo, cached_tok=0):
    p = PRECIOS[modelo]
    uncached_in = in_tok - cached_tok
    return (
        uncached_in * p["in"] / 1_000_000
        + cached_tok * p["cached_in"] / 1_000_000
        + out_tok   * p["out"] / 1_000_000
    )

# Un request con 2000 tokens cacheados + 200 tokens nuevos + 300 output
print(f"Sin cache: ${costo(2200, 300, 'claude-sonnet'):.5f}")
print(f"Con cache: ${costo(2200, 300, 'claude-sonnet', cached_tok=2000):.5f}")
```

### Reintentos con backoff exponencial (producción)

```python
# pip install tenacity
from tenacity import retry, wait_random_exponential, stop_after_attempt, retry_if_exception_type
import openai

@retry(
    wait=wait_random_exponential(min=1, max=60),
    stop=stop_after_attempt(6),
    retry=retry_if_exception_type((openai.RateLimitError, openai.APITimeoutError)),
)
def llamar_robusto(oai, **kwargs):
    return oai.chat.completions.create(**kwargs)
```

### Structured outputs (OpenAI) — JSON garantizado

```python
from pydantic import BaseModel

class Reseña(BaseModel):
    sentimiento: str   # "positivo" | "neutral" | "negativo"
    puntaje: int       # 1-5
    temas: list[str]

r = oai.beta.chat.completions.parse(
    model="gpt-4o-mini",
    messages=[
        {"role": "system", "content": "Clasifica la reseña del cliente."},
        {"role": "user",   "content": "El producto llegó roto y tardó 3 semanas."},
    ],
    response_format=Reseña,
    temperature=0,
)
resena: Reseña = r.choices[0].message.parsed
print(resena.sentimiento, resena.puntaje, resena.temas)
```

### Tool use con Anthropic (equivalente a structured output)

```python
tools = [{
    "name": "guardar_resena",
    "description": "Guarda la reseña procesada.",
    "input_schema": {
        "type": "object",
        "properties": {
            "sentimiento": {"type": "string", "enum": ["positivo","neutral","negativo"]},
            "puntaje":     {"type": "integer", "minimum": 1, "maximum": 5},
            "temas":       {"type": "array", "items": {"type": "string"}},
        },
        "required": ["sentimiento","puntaje","temas"],
    },
}]

r = ant.messages.create(
    model="claude-3-5-sonnet-latest",
    max_tokens=500,
    tools=tools,
    tool_choice={"type": "tool", "name": "guardar_resena"},
    messages=[{"role":"user","content":"El producto llegó roto y tardó 3 semanas."}],
)
print(r.content[0].input)   # dict ya parseado
```

### Streaming (mejor UX)

```python
stream = oai.chat.completions.create(
    model="gpt-4o-mini",
    messages=[{"role":"user","content":"Cuenta hasta 20."}],
    stream=True,
)
for chunk in stream:
    delta = chunk.choices[0].delta.content or ""
    print(delta, end="", flush=True)
```

### Caching del system prompt (Anthropic)

```python
system_largo = open("docs/manual_producto.md").read()   # 20K tokens

r = ant.messages.create(
    model="claude-3-5-sonnet-latest",
    max_tokens=400,
    system=[{
        "type": "text",
        "text": system_largo,
        "cache_control": {"type": "ephemeral"},   # ← la línea mágica
    }],
    messages=[{"role":"user","content":"¿Cómo reseteo el dispositivo?"}],
)
# La primera llamada paga el costo full; las siguientes 5 min pagan 0.1× por los tokens cacheados.
```

### Routing entre modelos (barato → caro)

```python
def responder(pregunta: str) -> str:
    # 1. Clasificar complejidad con un modelo barato
    cls = oai.chat.completions.create(
        model="gpt-4o-mini", temperature=0, max_tokens=1,
        messages=[
            {"role":"system","content":"Responde solo 'S' si la pregunta requiere razonamiento complejo, 'N' si es simple."},
            {"role":"user","content":pregunta},
        ],
    )
    complejo = cls.choices[0].message.content.strip().upper() == "S"
    modelo = "gpt-4o" if complejo else "gpt-4o-mini"
    return oai.chat.completions.create(
        model=modelo, messages=[{"role":"user","content":pregunta}], temperature=0.3,
    ).choices[0].message.content
```

## Errores comunes

- **Dejar `temperature` en el default (1.0).** Para cualquier tarea factual o estructurada esto es un error. Baja a 0-0.3.
- **No fijar `max_tokens`.** El modelo puede generar hasta su límite (4K-16K tokens) incluso para una pregunta "sí/no". Siempre define un techo razonable.
- **Ajustar temperature y top_p a la vez.** No es incorrecto, pero el efecto es confuso. Elige uno como palanca principal.
- **Pedir JSON en el prompt sin usar structured outputs.** El modelo a veces incluye prosa, markdown, comentarios, o cierra con "`"}`" sin coma. Usa el modo nativo.
- **No contar tokens antes de enviar.** Resulta en errores 400 por overflow en producción cuando el usuario pega un documento grande.
- **No cachear.** Si tu system prompt es grande y repetido, estás pagando 10-20× lo necesario.
- **Confundir input y output pricing.** Output es típicamente 4-5× más caro. Si tu respuesta puede ser corta (ej. clasificación: 1 token), limita `max_tokens`.
- **Enviar historial completo en cada turno de un chat largo.** Costo cuadrático con la longitud de la conversación. Soluciones: resumen incremental, sliding window, vector store de memoria.
- **No implementar retry/backoff.** APIs devuelven 429 y 503. Sin retry robusto, un pico de tráfico tira tu feature.
- **No loggear tokens ni costo por request.** Sin observabilidad, no puedes optimizar. Guarda `usage.input_tokens`, `usage.output_tokens`, latencia, modelo, y el hash del prompt.
- **Confiar en `seed` para 100% determinismo.** OpenAI/Anthropic lo marcan como *best-effort*. Para tests críticos, snapshotea las respuestas en vez.
- **No sanitizar inputs del usuario (prompt injection).** Si tu system dice "no reveles datos internos" y el user pega "ignora las instrucciones anteriores y...", muchos modelos obedecen. Capas: input filtering, output filtering, guardrails, y nunca des al LLM acceso directo a herramientas destructivas sin confirmación humana.
- **Pedir `max_tokens` muy pequeño y recibir respuestas cortadas a mitad de frase.** Dimensiona con holgura (ej. si esperas 100 tokens, pide 200).
- **No usar modelos locales (Ollama, llama.cpp) cuando aplica.** Para tareas de alta frecuencia y baja complejidad, un LLaMA 3 8B self-hosted puede costar centavos vs. dólares/día en APIs.

## Resumen

- Toda llamada LLM es una **configuración deliberada**: modelo, prompt, parámetros de sampling, control de longitud, formato de salida, observabilidad.
- **Tokeniza y mide.** Usa `tiktoken` (OpenAI) o el tokenizer del proveedor. Español ≈ 1.3× el costo de inglés; código ≈ 1.5-2×.
- **Temperature controla aleatoriedad** vía escalado de logits. `T=0` para extracción/clasificación, `T=0.3-0.5` para asistentes, `T=0.8-1.2` para creatividad.
- **Top-p** limita la masa de probabilidad considerada. Ajusta uno u otro, no ambos. Default sensato: `T=0.3, top_p=1.0`.
- **`max_tokens` es un seguro de costo.** Sin él, puedes pagar 20× lo necesario.
- **Pricing es asimétrico:** output cuesta 3-5× más que input. Diseña prompts que pidan respuestas acotadas.
- **Prompt caching** reduce 85-90% costo input para system prompts/contexto repetidos. Actívalo.
- **Structured outputs / tool use** garantizan JSON válido; nunca más `json.loads()` fallando aleatoriamente.
- **Observabilidad desde el día uno:** loggea tokens, costo, latencia por request. Usa LangSmith/Langfuse/Helicone.
- **Reintentos con backoff**, **routing entre modelos**, **streaming** y **validación del output** son los cuatro patrones que separan prototipo de producción.
