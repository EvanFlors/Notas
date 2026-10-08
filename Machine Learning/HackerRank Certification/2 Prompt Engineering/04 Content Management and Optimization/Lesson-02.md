# Estrategias de Chunking y Gestión de Contexto

## ¿Qué es?

**Chunking** es el proceso de partir un contenido largo (manual, código, transcripción, conversación) en fragmentos manejables llamados *chunks*, de modo que cada uno quepa en el **context window** del modelo y preserve la semántica necesaria para que la respuesta siga siendo correcta. La **gestión de contexto** va un paso más allá: decide **qué chunks entran al prompt**, en **qué orden** y **con qué nivel de compresión**, bajo restricciones de tokens y presupuesto.

No es "cortar texto cada N caracteres". Un buen sistema de chunking responde tres preguntas:

1. **¿Dónde cortar?** (en fronteras naturales: párrafo, sección, función, turno de diálogo).
2. **¿Qué incluir en la ventana?** (relevancia por query, recencia, importancia estructural).
3. **¿Cómo comprimir lo que no cabe?** (resumen, descarte, re-ranking).

> El fenómeno **Lost in the Middle** (Liu et al., 2023, Stanford) mostró que los LLMs responden mucho mejor cuando la información relevante está al **inicio o al final** del contexto; en el medio se degrada hasta un 20% de accuracy. Chunking inteligente no es solo meter cosas: es ponerlas donde el modelo las verá.

### Vocabulario mínimo

- **Chunk size:** tokens por fragmento (típico 500–2,000).
- **Overlap:** tokens repetidos entre chunks consecutivos (típico 10–20%) para no cortar ideas.
- **Retrieval:** recuperar los top-K chunks relevantes a una query (típicamente vía embeddings + similitud coseno).
- **Rerank:** re-ordenar los chunks recuperados con un modelo cross-encoder más preciso.
- **Context pressure:** proporción `tokens_usados / context_window`.

## ¿Por qué importa?

Porque sin chunking inteligente, un sistema de IA se rompe de dos maneras:

- **Error duro:** `maximum context length exceeded` → la API devuelve 400 y la aplicación cae.
- **Error silencioso:** el modelo responde, pero omite la sección relevante porque fue truncada o colocada en una zona que ignora.

Un caso real: un chatbot de soporte referencia un manual de 60 páginas. El usuario pregunta sobre errores de autenticación, cuya sección está en la página 45. Con truncation naive el prompt corta en la página 30 y el modelo contesta con información genérica. El usuario abandona.

### Los cuatro problemas de la truncation naive

| Problema | Qué ocurre | Consecuencia |
|---|---|---|
| **Context loss** | Se elimina información arbitraria | Respuestas que no contestan la pregunta |
| **Coherence break** | Se corta a mitad de frase | Modelo alucina para completar |
| **Semantic fragmentation** | Ideas relacionadas quedan en chunks distintos | No se detectan relaciones |
| **Priority inversion** | Lo irrelevante del inicio desplaza lo crítico del final | Peor calidad con **más** contexto |

### Lost in the Middle (Liu 2023)

```
Posición de la info clave:   inicio    medio    final
Accuracy en Q&A (GPT-3.5):    76%      55%      71%
Accuracy en Q&A (Claude 1.3): 80%      62%      75%
```

Conclusión: **colocar lo importante al principio o al final** del prompt mejora la calidad sin cambiar el modelo.

## ¿Cómo funciona?

### 1. Chunking por tipo de contenido

Cada tipo de documento tiene fronteras naturales que preservan semántica:

| Tipo de contenido | Frontera natural | Qué preservar |
|---|---|---|
| Artículo científico | Sección (Intro, Methods, Results) | Citas, tablas, figuras referenciadas |
| Transcripción de conversación | Turno de hablante | Resolución de pronombres, timestamps |
| Código fuente | Función/clase | Imports, docstrings, dependencias |
| Documentación técnica | Encabezado `##` o `###` | Code blocks, enlaces internos |
| Legal / contrato | Cláusula numerada | Definiciones referenciadas |
| Chat de usuario | Mensaje completo | Rol, timestamp |

### 2. Estrategias de compresión bajo presión

Monitoreo del `pressure_ratio = tokens_usados / context_window`:

| Rango | Estrategia | Qué conserva |
|---|---|---|
| 0 – 60% | Sin acción | Todo intacto |
| 60 – 80% | Compresión selectiva de mensajes antiguos | Últimos 10 turnos íntegros |
| 80 – 95% | Pruning agresivo | Últimos 5 turnos + resumen |
| 95 – 100% | Emergency summarization | Últimos 3 turnos + resumen de alto nivel |

### 3. Progressive summarization (jerárquica por capas)

```
Capa 1 (full detail):    últimos 5 mensajes      → sin modificar
Capa 2 (resumen medio):  mensajes 6-20            → resumen estructurado
Capa 3 (resumen alto):   mensajes 21-∞            → bullets de alto nivel
```

### 4. Priority-based selection

Cuatro criterios combinables para decidir qué chunk entra:

- **Keyword density:** cuántas veces aparecen términos relevantes a la query.
- **Position weighting:** introducción y conclusión suelen pesar más.
- **Recency weighting:** info reciente pesa más (crítico en soporte técnico).
- **Reference frequency:** secciones referenciadas por otras son foundational.

### 5. Comparativa de estrategias

| Estrategia | Uso | Ventaja | Desventaja |
|---|---|---|---|
| **Fixed-size chunking** | Prototipo rápido | Simple | Rompe estructura |
| **Recursive character splitting** | Markdown, HTML | Respeta jerarquía | Config fina |
| **Sentence-aware** | Prosa narrativa | Mantiene oraciones | Chunks desiguales |
| **Semantic chunking** | Documentos heterogéneos | Agrupa por similitud de embeddings | Costoso computacionalmente |
| **Hierarchical (parent-child)** | RAG avanzado | Recupera parent al hit de child | Más almacenamiento |
| **Agentic chunking** | Dominio especializado | LLM decide fronteras | Costoso en tokens |

## Ejemplo con código

### Chunking consciente del tipo de documento

```python
import tiktoken

ENC = tiktoken.encoding_for_model("gpt-4o")

def contar(texto: str) -> int:
    return len(ENC.encode(texto))

def chunk_recursivo(texto: str, max_tokens: int = 2000, overlap: int = 200,
                    separadores: list[str] | None = None) -> list[str]:
    """Divide por los separadores en orden; si un bloque sigue grande, baja al siguiente."""
    separadores = separadores or ["\n\n## ", "\n\n", "\n", ". ", " "]
    if contar(texto) <= max_tokens:
        return [texto]
    sep = separadores[0]
    partes = texto.split(sep)
    chunks, buffer = [], ""
    for p in partes:
        candidato = (buffer + sep + p) if buffer else p
        if contar(candidato) <= max_tokens:
            buffer = candidato
        else:
            if buffer:
                chunks.append(buffer)
            if contar(p) > max_tokens and len(separadores) > 1:
                chunks.extend(chunk_recursivo(p, max_tokens, overlap, separadores[1:]))
                buffer = ""
            else:
                buffer = p
    if buffer:
        chunks.append(buffer)
    return _aplicar_overlap(chunks, overlap)

def _aplicar_overlap(chunks: list[str], overlap_tokens: int) -> list[str]:
    out = [chunks[0]]
    for i in range(1, len(chunks)):
        prev_tokens = ENC.encode(chunks[i - 1])[-overlap_tokens:]
        out.append(ENC.decode(prev_tokens) + "\n" + chunks[i])
    return out
```

### Chunking por secciones (research papers / docs)

```python
import re

def chunk_por_secciones(markdown: str) -> list[dict]:
    """Divide un markdown en chunks por encabezado H2, preservando el título como metadata."""
    patron = re.compile(r"^(## .+)$", re.MULTILINE)
    cortes = [m.start() for m in patron.finditer(markdown)]
    cortes.append(len(markdown))
    secciones = []
    for i in range(len(cortes) - 1):
        bloque = markdown[cortes[i]:cortes[i + 1]].strip()
        titulo = bloque.split("\n", 1)[0].lstrip("# ").strip()
        secciones.append({"titulo": titulo, "contenido": bloque, "tokens": contar(bloque)})
    return secciones
```

### Chunking de código por funciones

```python
import ast

def chunk_python_por_funcion(codigo: str) -> list[dict]:
    """Un chunk por función/clase, incluyendo imports del archivo."""
    tree = ast.parse(codigo)
    lineas = codigo.splitlines()
    imports = [l for l in lineas if l.startswith(("import ", "from "))]
    header = "\n".join(imports) + "\n\n"
    chunks = []
    for nodo in tree.body:
        if isinstance(nodo, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            cuerpo = "\n".join(lineas[nodo.lineno - 1 : nodo.end_lineno])
            chunks.append({"nombre": nodo.name, "contenido": header + cuerpo})
    return chunks
```

### Priority-based selection con keyword density

```python
from collections import Counter
import re

def score_relevancia(chunk: str, query: str) -> float:
    palabras_q = [w.lower() for w in re.findall(r"\w+", query) if len(w) > 3]
    tokens_chunk = re.findall(r"\w+", chunk.lower())
    cnt = Counter(tokens_chunk)
    hits = sum(cnt[w] for w in palabras_q)
    return hits / max(len(tokens_chunk), 1)

def seleccionar_top_k(chunks: list[str], query: str, k: int = 5) -> list[str]:
    ranked = sorted(chunks, key=lambda c: score_relevancia(c, query), reverse=True)
    return ranked[:k]
```

(En producción esto se hace con embeddings + similitud coseno, no con keyword density; la versión keyword es una baseline útil y gratis.)

### Gestión dinámica bajo presión

```python
def gestionar_presion(mensajes: list[dict], ctx_max: int, uso_actual: int,
                      resumidor) -> list[dict]:
    ratio = uso_actual / ctx_max
    if ratio < 0.60:
        return mensajes
    if ratio < 0.80:
        recientes, viejos = mensajes[-10:], mensajes[:-10]
        resumen = resumidor(viejos)
        return [{"role": "system", "content": f"[Resumen previo]\n{resumen}"}] + recientes
    if ratio < 0.95:
        recientes, viejos = mensajes[-5:], mensajes[:-5]
        resumen = resumidor(viejos, nivel="agresivo")
        return [{"role": "system", "content": f"[Resumen]\n{resumen}"}] + recientes
    # Emergencia: solo últimos 3 + resumen muy comprimido
    recientes, viejos = mensajes[-3:], mensajes[:-3]
    return [{"role": "system", "content": resumidor(viejos, nivel="emergencia")}] + recientes
```

### Hierarchical (parent-child) retrieval

```python
# Idea: embebes chunks pequeños (hijos) para precisión en el matching,
# pero inyectas el chunk grande (padre) en el prompt para contexto.
padres   = chunk_por_secciones(documento)              # grandes, p.ej. 2000 tokens
hijos    = []
for i, p in enumerate(padres):
    for sub in chunk_recursivo(p["contenido"], max_tokens=300):
        hijos.append({"texto": sub, "parent_id": i})

# retrieval: busca entre `hijos`, pero devuelve `padres[hijos[hit].parent_id]`
```

### Validación de tokens antes de enviar

```python
BUFFER_SEGURIDAD = 0.15   # reserva 15% para la respuesta

def cabe_en_contexto(prompt: str, ctx_max: int, max_output: int) -> bool:
    disponible = int(ctx_max * (1 - BUFFER_SEGURIDAD)) - max_output
    return contar(prompt) <= disponible
```

## Errores comunes

- **Truncation naive por caracteres.** Corta en medio de palabras y mide mal. Usa siempre tokens reales con `tiktoken` o el tokenizador del proveedor.
- **Chunking sin overlap.** Pierdes información en las fronteras. Usa 10-20% de overlap o un *smart boundary detector* en párrafos.
- **Ignorar Lost in the Middle.** Colocar la info clave en el medio de un prompt largo baja accuracy hasta 20 puntos. Pon lo crítico al inicio o al final.
- **No contar tokens antes de enviar.** Reserva un buffer de 10-15% del context window para la respuesta; nunca llenes al 100%.
- **Mismo tokenizador para todos los modelos.** `cl100k_base` para GPT-4 ≠ `o200k_base` para GPT-5 ≠ Claude ≠ Llama. Usa el tokenizador real del modelo destino.
- **Context collapse.** Comprimir demasiado agresivamente borra información necesaria. Haz compresión graduada y valida que la respuesta siga siendo correcta.
- **Re-embeber en cada deploy.** Guarda los embeddings con un hash del texto y del modelo (`sha256(texto+modelo)`); solo re-embeber lo que cambió.
- **Chunking de código por caracteres.** Rompe funciones. Usa AST (`ast` en Python, tree-sitter en general) para respetar fronteras sintácticas.
- **No persistir metadata.** Un chunk sin `source_id`, `section`, `position` es imposible de citar en la respuesta final.
- **Reinventar RAG.** Para 90% de casos, LangChain / LlamaIndex / Haystack tienen chunkers probados; empieza por ahí antes de escribir el tuyo.

## Herramientas del ecosistema

| Herramienta | Para qué |
|---|---|
| **LangChain `RecursiveCharacterTextSplitter`** | Chunking jerárquico por separadores |
| **LlamaIndex `SentenceWindowNodeParser`** | Chunking con ventana contextual |
| **unstructured.io** | Parsing de PDF/HTML/DOCX con estructura |
| **tree-sitter** | Chunking semántico de código en cualquier lenguaje |
| **Semantic Chunker (LangChain)** | Agrupa por similitud de embeddings |
| **Cohere Rerank / Jina Reranker** | Re-ordenar top-K recuperados |
| **Pinecone / Qdrant / pgvector** | Almacén vectorial con metadata |

## Resumen

- **Chunking inteligente** respeta las fronteras naturales del contenido (sección, función, turno) en vez de cortar cada N caracteres.
- La **truncation naive** produce *context loss, coherence break, semantic fragmentation* y *priority inversion*.
- Usa **overlap de 10-20%** entre chunks para no cortar ideas en los bordes.
- **Lost in the Middle** (Liu 2023): los LLMs ignoran el centro de prompts largos; coloca lo crítico al inicio o final.
- La **gestión dinámica** monitorea `pressure_ratio` y comprime en capas: full detail reciente, resumen medio, bullets antiguos.
- **Priority-based selection** combina keyword density, position, recency y reference frequency.
- **Hierarchical retrieval** (parent-child) consigue precisión en el matching con contexto rico en el prompt.
- Reserva un **buffer de 10-15%** del context window para la salida; nunca llenes al 100%.
- Mide siempre con el **tokenizador real** del modelo destino.
- Para empezar: `RecursiveCharacterTextSplitter` + overlap 15% + top-K con rerank. Añade complejidad solo cuando las métricas lo justifiquen.
