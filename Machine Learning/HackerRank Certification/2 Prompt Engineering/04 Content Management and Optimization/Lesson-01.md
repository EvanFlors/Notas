# Entendiendo Límites de Tokens y Precios

## ¿Qué es?

Un **token** es la unidad mínima con la que un modelo de lenguaje mide, procesa y cobra el texto. No es una palabra ni un carácter: es un fragmento subpalabra producido por un **tokenizador** entrenado con **Byte Pair Encoding (BPE)** o un algoritmo similar (SentencePiece, WordPiece). La palabra `tokenización` puede partirse como `["token", "ización"]` en GPT-4 y como `["tok", "en", "iz", "ación"]` en Llama; cada modelo trae su propio vocabulario aprendido durante el pre-entrenamiento.

Dos conceptos operativos giran alrededor de los tokens:

- **Context window:** cantidad máxima de tokens que el modelo puede ver en una sola llamada (entrada + salida). Define lo que puedes "meter" en un prompt.
- **Precio por token:** las APIs cobran por millón de tokens, con tarifas separadas para `input`, `output` y, desde 2024, para `cache read` y `cache write`.

> Regla práctica en inglés: **1 token ≈ 4 caracteres ≈ 0.75 palabras**. En español la relación empeora (~1 token por 3 caracteres) porque las tildes y la morfología producen más subpalabras. En código y JSON la ratio es aún peor por los símbolos.

### Jerarquía de costos

```
Precio_llamada = (tokens_input × precio_input) + (tokens_output × precio_output)
Con cache:
Precio_llamada = (tokens_cache_write × precio_cache_write)         ← primera vez
              + (tokens_cache_read  × precio_cache_read)           ← siguientes
              + (tokens_output      × precio_output)
```

El precio de cache read suele ser **~10% del precio input normal** (90% de descuento en Anthropic, OpenAI y Google). Esto cambia radicalmente la economía de prompts largos.

## ¿Por qué importa?

Porque el costo y la latencia de un sistema de IA escalan **linealmente con el token count**, pero la calidad **no**. Un desarrollador que ignora la tokenización termina:

- **Pagando de más** por usar el modelo más caro cuando uno más barato bastaba.
- **Rompiendo producción** al exceder el context window sin estrategia de truncation.
- **Subestimando el presupuesto** porque contó palabras en vez de tokens (español y código pesan más de lo que parecen).
- **Perdiendo calidad** por meter demasiado contexto: el paper *Lost in the Middle* (Liu et al., 2023) demostró que los modelos ignoran información colocada en el centro de prompts largos.

### Impacto económico real

Un servicio que procesa 10,000 llamadas diarias con prompts de 1,000 tokens:

| Modelo | Precio input ($/MTok) | Costo diario input | Costo mensual |
|---|---|---|---|
| GPT-5 | $0.025 | $0.25 | $7.50 |
| Claude Sonnet 4 | $3.00 | $30 | $900 |
| GPT-4o | $2.50 | $25 | $750 |
| GPT-5 mini | $0.0008 | $0.008 | $0.24 |

Multiplicar por 100× el volumen (típico en producción) convierte "unos dólares" en "decenas de miles al mes". Un 20% de ahorro por mejor tokenización puede justificar un rediseño completo.

## ¿Cómo funciona?

### Tokenización bajo el capó

El algoritmo BPE funciona en dos fases:

1. **Entrenamiento:** parte de un vocabulario de caracteres y fusiona iterativamente los pares más frecuentes del corpus hasta alcanzar el tamaño objetivo (típicamente 50K–200K tokens).
2. **Inferencia:** aplica la secuencia de merges aprendidos a cualquier texto nuevo, produciendo la segmentación de mínima longitud posible dentro del vocabulario.

Resultado: palabras comunes como `the`, `and`, `function` son un solo token; términos raros, nombres propios, emojis y texto no inglés se parten en varios. GPT-4 usa `cl100k_base`, GPT-4o y GPT-5 usan `o200k_base` (más eficiente, especialmente en idiomas no ingleses).

### Context windows por modelo (2024-2026)

| Modelo | Context window | Max output | Precio input ($/MTok) | Precio output |
|---|---|---|---|---|
| Claude Sonnet 4 | 1,000,000 | 64,000 | $3.00 | $15.00 |
| Claude Opus 4 | 200,000 | 32,000 | $15.00 | $75.00 |
| Claude Haiku 3.5 | 200,000 | 8,192 | $0.80 | $4.00 |
| GPT-5 | 400,000 | 128,000 | $0.025 | $0.05 |
| GPT-5 mini | 400,000 | 128,000 | $0.0008 | $0.0012 |
| GPT-4o | 128,000 | 16,384 | $2.50 | $10.00 |
| Gemini 2.0 Pro | 2,000,000 | 8,192 | $1.25 | $5.00 |
| Gemini 2.0 Flash | 1,000,000 | 8,192 | $0.075 | $0.30 |
| Llama 3.1 405B | 128,000 | 8,192 | $3.00 (hosted) | $3.00 |

> El context window no es gratis: cada token sumado a la entrada cuesta y aumenta la latencia (atención es O(n²) en vanilla transformers, O(n log n) con FlashAttention).

### Prompt caching (lanzado por Anthropic en agosto 2024)

Permite marcar porciones estables de un prompt (system message, documentos, few-shots) para que el servidor las guarde y cobre barato en las siguientes llamadas.

| Proveedor | Descuento en cache hit | TTL | Mínimo cacheable |
|---|---|---|---|
| Anthropic (`cache_control`) | 90% (ephemeral 5m) / 50% ahorro con 1h | 5 min o 1 hora | 1,024 tokens (Sonnet), 2,048 (Haiku) |
| OpenAI (implicit cache) | 50% | ~5-10 min | 1,024 tokens, automático |
| Google Gemini (context cache) | ~75% | configurable | 32,768 tokens |

La diferencia clave: **Anthropic es explícito** (tú marcas qué cachear con `cache_control`), **OpenAI es implícito** (detecta prefijos repetidos automáticamente).

### Estrategias de truncation y agregación

Cuando el contenido no cabe:

| Estrategia | Cómo funciona | Pros | Contras |
|---|---|---|---|
| **Stuffing** | Mete todo lo que quepa | Simple, un solo call | Falla si excede límite |
| **Map-reduce** | Procesa chunks en paralelo, luego resume los resúmenes | Escalable, paraleliza | Pierde contexto cross-chunk |
| **Refine** | Procesa chunk 1, pasa output al chunk 2, etc. | Mantiene contexto | Secuencial, lento |
| **Rerank + top-K** | Recupera N chunks, re-rankea, usa los K mejores | Precisión alta | Requiere embeddings + reranker |
| **Hierarchical summarization** | Resume por secciones, luego resume los resúmenes | Preserva estructura | Pierde detalle fino |

## Ejemplo con código

### Contar tokens con `tiktoken`

```python
import tiktoken

def contar_tokens(texto: str, modelo: str = "gpt-4o") -> int:
    """Cuenta tokens exactos para un modelo OpenAI."""
    enc = tiktoken.encoding_for_model(modelo)
    return len(enc.encode(texto))

def estimar_costo(texto_input: str, texto_output: str, modelo: str) -> dict:
    precios = {
        "gpt-5":      {"in": 0.025,  "out": 0.05},
        "gpt-5-mini": {"in": 0.0008, "out": 0.0012},
        "gpt-4o":     {"in": 2.50,   "out": 10.00},
    }
    enc = tiktoken.encoding_for_model(modelo if modelo != "gpt-5" else "gpt-4o")
    n_in  = len(enc.encode(texto_input))
    n_out = len(enc.encode(texto_output))
    p = precios[modelo]
    costo_in  = n_in  * p["in"]  / 1_000_000
    costo_out = n_out * p["out"] / 1_000_000
    return {
        "tokens_in": n_in,
        "tokens_out": n_out,
        "costo_usd": round(costo_in + costo_out, 6),
    }

prompt = "Explica el teorema de Pitágoras en una frase."
respuesta = "En un triángulo rectángulo, el cuadrado de la hipotenusa es la suma de los cuadrados de los catetos."
print(estimar_costo(prompt, respuesta, "gpt-5-mini"))
# {'tokens_in': 10, 'tokens_out': 25, 'costo_usd': 3.8e-05}
```

### Comparar tokenización entre familias

```python
import tiktoken
from transformers import AutoTokenizer

def comparar_tokenizadores(texto: str) -> dict:
    openai = tiktoken.encoding_for_model("gpt-4o")        # o200k_base
    claude = tiktoken.get_encoding("cl100k_base")         # aproximación
    llama  = AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B")
    return {
        "gpt-4o/5": len(openai.encode(texto)),
        "claude (aprox)": len(claude.encode(texto)),
        "llama-3.1": len(llama.encode(texto)),
        "longitud_chars": len(texto),
    }

texto_es = "El token es la unidad mínima de facturación en los modelos de lenguaje modernos."
print(comparar_tokenizadores(texto_es))
# {'gpt-4o/5': 18, 'claude (aprox)': 23, 'llama-3.1': 24, 'longitud_chars': 83}
```

Para el mismo texto en español, Llama consume **33% más tokens** que GPT-4o. En volumen alto, esa diferencia es la factura mensual completa.

### Prompt caching con Anthropic (`cache_control`)

```python
import anthropic

client = anthropic.Anthropic()

with open("manual_producto.txt") as f:
    manual = f.read()   # ~50,000 tokens, estable entre llamadas

respuesta = client.messages.create(
    model="claude-sonnet-4-20250514",
    max_tokens=1024,
    system=[
        {
            "type": "text",
            "text": "Eres un asistente de soporte técnico.",
        },
        {
            "type": "text",
            "text": manual,
            "cache_control": {"type": "ephemeral"},   # <-- marca para cachear
        },
    ],
    messages=[{"role": "user", "content": "¿Cómo reseteo la contraseña?"}],
)

print(respuesta.usage)
# cache_creation_input_tokens: 50000  (primera vez: cobra +25% sobre input)
# cache_read_input_tokens:     0
# input_tokens:                15
# Siguiente llamada:
# cache_creation_input_tokens: 0
# cache_read_input_tokens:     50000  (cobra solo 10% del precio normal)
```

**Economía:** sin cache, 100 llamadas × 50,000 tokens × $3/MTok = **$15**. Con cache (1 write + 99 reads): $3.75 (write con +25%) + 99×$0.015 = **$5.24**. Ahorro del **65%**.

### Chunking de documentos largos con overlap

```python
import tiktoken

def chunk_con_overlap(texto: str, max_tokens: int = 2000, overlap: int = 200,
                      modelo: str = "gpt-4o") -> list[str]:
    """Parte un texto en chunks con solapamiento, respetando frases cuando puede."""
    enc = tiktoken.encoding_for_model(modelo)
    tokens = enc.encode(texto)
    chunks = []
    i = 0
    while i < len(tokens):
        ventana = tokens[i : i + max_tokens]
        chunks.append(enc.decode(ventana))
        i += max_tokens - overlap            # retrocede `overlap` para evitar cortes
    return chunks

with open("documento_largo.md") as f:
    partes = chunk_con_overlap(f.read(), max_tokens=1500, overlap=150)
print(f"{len(partes)} chunks generados")
```

### Resumen recursivo (hierarchical summarization)

```python
from openai import OpenAI
client = OpenAI()

def resumir(texto: str, max_tokens_resumen: int = 500) -> str:
    r = client.chat.completions.create(
        model="gpt-5-mini",
        messages=[
            {"role": "system", "content": "Resume preservando datos, nombres y cifras."},
            {"role": "user",   "content": texto},
        ],
        max_tokens=max_tokens_resumen,
    )
    return r.choices[0].message.content

def resumen_recursivo(chunks: list[str], umbral_tokens: int = 8000) -> str:
    """Reduce N chunks hasta que caben en un solo call final."""
    resumenes = [resumir(c) for c in chunks]
    combinado = "\n\n".join(resumenes)
    if contar_tokens(combinado) <= umbral_tokens:
        return resumir(combinado, max_tokens_resumen=1000)
    # Si todavía es muy grande, re-chunkea y repite
    return resumen_recursivo(chunk_con_overlap(combinado, 2000), umbral_tokens)
```

### Selección dinámica de modelo con presupuesto

```python
class RouterModelo:
    PRECIOS = {
        "gpt-5-mini":      {"in": 0.0008, "out": 0.0012},
        "claude-sonnet-4": {"in": 3.00,   "out": 15.00},
        "gpt-5":           {"in": 0.025,  "out": 0.05},
    }

    def elegir(self, complejidad: int, max_costo_usd: float, tokens_estimados: int) -> str:
        """complejidad: 1-10. Devuelve el modelo más potente que cabe en el presupuesto."""
        candidatos = []
        for modelo, p in self.PRECIOS.items():
            costo = tokens_estimados * (p["in"] + p["out"]) / 1_000_000
            if costo <= max_costo_usd:
                candidatos.append((modelo, costo))
        if complejidad <= 3:
            return "gpt-5-mini"
        if complejidad <= 7 and "claude-sonnet-4" in dict(candidatos):
            return "claude-sonnet-4"
        return "gpt-5"
```

## Errores comunes

- **Contar palabras en vez de tokens.** Un documento de 1,000 palabras en español puede ser 1,800 tokens. Usa siempre `tiktoken` (o el tokenizador del proveedor) para presupuestar.
- **No cachear el system prompt largo.** Un prompt de sistema de 10K tokens repetido en cada llamada sin `cache_control` desperdicia 90% del gasto que ya tenías ganado.
- **Context stuffing que degrada calidad.** Meter 500K tokens porque "cabe" dispara el fenómeno *Lost in the Middle*: el modelo responde mejor con 20K tokens bien curados que con 500K ruidosos.
- **Hard-codear un solo modelo.** Los precios bajan ~70% al año; una app atada a GPT-4 en 2023 paga 10× lo que debería hoy. Diseña con un `ModelRouter` desde el día uno.
- **Olvidar los tokens de output.** El output suele costar 2-5× más que el input. Un `max_tokens=4096` abierto es una factura abierta.
- **Re-generar embeddings innecesariamente.** Si tu documento no cambió, no re-embebas: guarda vectores en Pinecone/Qdrant/pgvector con el hash del texto como key.
- **No medir cost por request.** Instrumenta cada llamada con `usage.input_tokens`, `usage.output_tokens`, `cache_read`, `cache_write`. Sin métricas no hay optimización.
- **Ignorar tokens de la conversación histórica.** En chats largos, el historial crece y crece. Implementa sliding window o resumen incremental.
- **Usar tokenizadores aproximados en producción.** `len(texto) / 4` es útil para prototipos; en producción puede desviarse 30% y causar errores por exceso de límite.

## Herramientas del ecosistema

| Herramienta | Para qué sirve |
|---|---|
| **tiktoken** | Tokenización exacta de modelos OpenAI |
| **Anthropic SDK** | `cache_control` para prompt caching explícito |
| **LangChain / LlamaIndex** | Chunking, map-reduce, refine, retrievers |
| **Promptfoo** | Benchmark de costo/calidad entre modelos |
| **Helicone** | Observabilidad de costos por llamada |
| **LangSmith / Langfuse** | Tracing + token/cost por traza |
| **OpenAI tokenizer web** | <https://platform.openai.com/tokenizer> |

## Resumen

- Un **token** es la unidad de facturación y de capacidad; `1 token ≈ 4 caracteres en inglés`, menos en español.
- Cada familia de modelos tokeniza distinto: el mismo texto en Llama puede costar 30% más que en GPT-5.
- La fórmula de costo es `tokens × precio`, pero el **prompt caching** (90% off en Anthropic) rompe esa relación para prefijos estables.
- Context windows crecieron de 2K (GPT-3) a 2M (Gemini 2 Pro); eligir **el tamaño correcto** importa más que elegir el más grande.
- Más contexto **no** es mejor contexto: *Lost in the Middle* demostró que la información en el centro se ignora.
- Estrategias de truncation: **stuffing, map-reduce, refine, rerank+top-K, hierarchical summarization**. Elige según coherencia requerida vs. paralelismo.
- **Dynamic model routing** (mini para tareas simples, grande para razonamiento) ahorra 50-80% sin pérdida de calidad.
- Instrumenta `tokens_in/out`, `cache_read/write` y `costo_usd` por request desde el día uno.
- Herramientas obligatorias: `tiktoken`, prompt caching de tu proveedor, un observability layer (Helicone/Langfuse) y un gateway de modelos.
