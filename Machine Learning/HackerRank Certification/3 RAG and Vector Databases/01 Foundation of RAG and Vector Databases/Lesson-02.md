# Embeddings y similitud semántica

## ¿Qué es?

Un **embedding** es la representación de un objeto (palabra, frase, documento, imagen, audio) como un **vector denso** de números reales en un espacio de alta dimensión `ℝᵈ`. La propiedad clave es que **la geometría del espacio refleja la semántica**: objetos con significado parecido quedan **cerca**, y objetos no relacionados quedan **lejos**.

Formalmente, un modelo de embeddings es una función:

```
E : Texto → ℝᵈ
```

Donde `d` (la **dimensionalidad**) es típicamente 384, 768, 1024, 1536 o 3072 según el modelo. El vector resultante **no es interpretable componente por componente** (no hay una dimensión que signifique "animal" o "comida"); el significado emerge de la **geometría global** del espacio.

### Analogía: GPS del significado

Si las coordenadas GPS `(lat, lon)` ubican lugares en el espacio físico, los embeddings ubican conceptos en un "espacio del significado". Dos ciudades cercanas en lat/lon están físicamente cerca; dos frases cercanas en el espacio de embeddings tienen **significado cercano**. "Cancelar suscripción" y "dar de baja la cuenta" apuntan casi al mismo lugar, aunque no comparten ni una palabra.

### Breve historia

| Año | Hito |
|---|---|
| 2003 | Bengio: Neural Language Model (primera idea de embeddings densos) |
| 2013 | Mikolov: **Word2Vec** (CBOW, Skip-gram) — hito popular |
| 2014 | Pennington: **GloVe** |
| 2018 | Devlin: **BERT** — embeddings contextuales |
| 2019 | Reimers: **Sentence-BERT** — frases enteras eficientes |
| 2022 | OpenAI: `text-embedding-ada-002` democratiza embeddings vía API |
| 2023-24 | **BGE**, **E5**, **Cohere embed-v3**, `text-embedding-3-*` |
| 2024-25 | MTEB leaderboard, Matryoshka embeddings, embeddings multimodales |

## ¿Por qué importa?

Sin embeddings no habría RAG. Las bases de datos tradicionales buscan por **coincidencia exacta** (`WHERE title LIKE '%refund%'`), lo cual falla cuando el usuario escribe "money back" y el documento dice "reembolso". Los embeddings transforman la búsqueda en **comparación de vectores**, capturando sinónimos, paráfrasis, errores ortográficos y hasta traducciones (con modelos multilingües) sin reglas explícitas.

Casos donde los embeddings dominan:

- **Semantic search:** búsqueda por significado.
- **RAG:** recuperar contexto para LLMs.
- **Clustering:** agrupar tickets de soporte por tema.
- **Clasificación zero-shot:** comparar un texto contra "etiquetas candidato".
- **Deduplicación semántica:** encontrar documentos casi iguales.
- **Recomendación:** "artículos similares a este".
- **Detección de anomalías:** texto fuera de la distribución habitual.
- **Multimodalidad:** CLIP mapea imágenes y texto al mismo espacio.

### Dimensionalidad y la "maldición"

A mayor `d`, mayor **capacidad expresiva** pero también más costo (memoria, compute, bandwidth) y aparece la **curse of dimensionality**: en espacios muy altos, las distancias entre puntos tienden a concentrarse (todo se vuelve "equidistante") y la noción de "vecino más cercano" pierde discriminación. Por eso embeddings densos (384-3072 dims) funcionan mejor que vectores sparse de millones de dims (TF-IDF, bag-of-words).

Tendencia reciente: **Matryoshka Representation Learning (MRL)** entrena un embedding de 3072 dims cuyos prefijos (512, 1024, 2048) **también son embeddings válidos**. Permite ajustar calidad vs. costo en runtime truncando el vector.

## ¿Cómo funciona?

### Entrenamiento (vista rápida)

Los modelos modernos se entrenan con **contrastive learning**: dado un par positivo `(a, b)` (dos frases con el mismo significado) y pares negativos `(a, c)`, el modelo aprende a **acercar** `a` y `b` y **alejar** `a` y `c` en el espacio. La función de pérdida típica es **InfoNCE / contrastive loss**:

```
L = -log(  exp(sim(a, b⁺) / τ)  /  Σ_c exp(sim(a, c) / τ)  )
```

Donde `τ` es la temperatura. Datasets usados: MS MARCO, Natural Questions, StackExchange, Reddit, S2ORC. Modelos como **E5** y **BGE** usan además **fine-tuning asymétrico**: distintos prefijos para query y documento (`"query: ..."` vs `"passage: ..."`).

### Métricas de similitud

Dadas dos vectores `A, B ∈ ℝᵈ`:

#### Cosine similarity

```
cosine_sim(A, B) = (A · B) / (||A|| · ||B||)
                 = Σᵢ Aᵢ·Bᵢ  /  (√Σᵢ Aᵢ²  ·  √Σᵢ Bᵢ²)
```

- **Rango:** `[-1, 1]` (texto suele dar `[0, 1]`).
- **Interpretación:** `1` = misma dirección (idéntico significado), `0` = perpendicular (no relacionados), `-1` = opuestos.
- **Ignora magnitud:** solo importa la dirección. Es el estándar de facto para texto.

#### Dot product (producto punto)

```
dot(A, B) = A · B = Σᵢ Aᵢ · Bᵢ
```

- **Equivalente a cosine si los vectores están normalizados** (`||A|| = ||B|| = 1`).
- Más rápido de computar (una suma menos).
- Si no están normalizados, favorece vectores de mayor magnitud (usado en algunos modelos como DPR).

#### Euclidean distance (L2)

```
euclidean(A, B) = ||A - B|| = √Σᵢ (Aᵢ - Bᵢ)²
```

- **Rango:** `[0, ∞)`. Más pequeño = más similar.
- Para vectores normalizados: `||A - B||² = 2 - 2·cosine(A, B)` → equivalente al cosine.
- Útil cuando la magnitud sí es informativa (ej. embeddings de imágenes de ciertas redes).

#### Relación clave

```
Si ||A|| = ||B|| = 1 (normalizados):
   cosine_sim(A, B) = dot(A, B) = 1 - ||A - B||² / 2
```

Por eso **normalizar siempre que puedas**: cosine, dot y euclidean dan rankings idénticos pero dot es el más rápido.

### Comparación de modelos de embeddings

| Modelo | Dims | Max tokens | Precio (per 1M tok) | MTEB score | Notas |
|---|---|---|---|---|---|
| `text-embedding-3-small` (OpenAI) | 1536 (reducible, MRL) | 8191 | $0.02 | ~62.3 | Default económico |
| `text-embedding-3-large` (OpenAI) | 3072 (reducible) | 8191 | $0.13 | ~64.6 | Mejor OpenAI |
| `embed-english-v3.0` (Cohere) | 1024 | 512 | $0.10 | ~64.5 | Asymmetric (`search_query` / `search_document`) |
| `embed-multilingual-v3.0` (Cohere) | 1024 | 512 | $0.10 | ~64.0 | 100+ idiomas |
| `BAAI/bge-large-en-v1.5` | 1024 | 512 | gratis (local) | ~64.2 | Open-source, excelente |
| `BAAI/bge-m3` | 1024 | 8192 | gratis | ~65 | Multilingüe + long context |
| `intfloat/e5-large-v2` | 1024 | 512 | gratis | ~62.3 | Prefijos `query:` / `passage:` |
| `intfloat/multilingual-e5-large` | 1024 | 512 | gratis | ~63 | 100 idiomas |
| `sentence-transformers/all-MiniLM-L6-v2` | 384 | 256 | gratis | ~56.3 | Rapidísimo, el "hello world" |
| `sentence-transformers/all-mpnet-base-v2` | 768 | 384 | gratis | ~57.8 | Baseline sólido |
| `voyage-3` (Voyage AI) | 1024 | 32k | $0.06 | ~65+ | Fuerte en dominios técnicos |
| `jina-embeddings-v3` | 1024 | 8192 | $0.02 | ~65 | Task-specific LoRAs |

El **MTEB leaderboard** (Massive Text Embedding Benchmark, HuggingFace) es la referencia: 56+ tareas en 112 idiomas.

### Elegir modelo: framework de decisión

1. **¿Dominio general o especializado?**
   - General → `text-embedding-3-small`, BGE, E5.
   - Legal/médico/código → modelos especializados (SPECTER, CodeBERT, Voyage-code).
2. **¿Un idioma o varios?**
   - Monolingüe → modelos EN-only (mejor calidad).
   - Multilingüe → `multilingual-e5`, `bge-m3`, Cohere multilingual.
3. **¿Latencia crítica?**
   - Sí → MiniLM (384d, ~2 ms).
   - No → bge-large / mpnet (768-1024d, ~10-20 ms).
4. **¿On-premise o cloud?**
   - On-premise → sentence-transformers (BGE, E5, MiniLM).
   - Cloud → OpenAI / Cohere / Voyage.
5. **¿Documentos largos (>512 tokens)?**
   - Sí → `bge-m3` (8K), `text-embedding-3` (8K), `jina-v3` (8K), o chunk-ear.

### Asymmetric embeddings

Modelos como **E5** y **Cohere embed-v3** son **asimétricos**: usan prefijos distintos para query y documento.

```python
# E5
query_input    = "query: ¿cómo cancelo mi suscripción?"
document_input = "passage: Para cancelar tu suscripción ve a Configuración > Cuenta..."

# Cohere embed-v3
co.embed(texts=[...], input_type="search_query")
co.embed(texts=[...], input_type="search_document")
```

Esto refleja la **asimetría real** del task: una query corta busca un passage largo, y el modelo aprende dos "proyecciones" ligeramente distintas al mismo espacio. **No mezclar los tipos** o la similitud se degrada.

## Ejemplo con código

### 1. Embeddings local con sentence-transformers + comparación de métricas

```python
# pip install sentence-transformers numpy
import numpy as np
from sentence_transformers import SentenceTransformer

model = SentenceTransformer("all-MiniLM-L6-v2")

frases = [
    "Quiero cancelar mi suscripción",
    "¿Cómo doy de baja mi cuenta?",
    "Terminate my account please",
    "¿Qué hora es?",
    "Receta de chocolate con nueces",
]

# normalize_embeddings=True → vectores unitarios (||v|| = 1)
V = model.encode(frases, normalize_embeddings=True)
print("Shape:", V.shape)   # (5, 384)

def cosine(a, b):
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))

def dot(a, b):
    return float(np.dot(a, b))

def euclid(a, b):
    return float(np.linalg.norm(a - b))

anchor = V[0]  # "Quiero cancelar mi suscripción"
print(f"\n{'Frase':<45} {'cos':>6} {'dot':>6} {'L2':>6}")
for frase, v in zip(frases[1:], V[1:]):
    print(f"{frase:<45} {cosine(anchor, v):>6.3f} {dot(anchor, v):>6.3f} {euclid(anchor, v):>6.3f}")

# Observa:
# - "doy de baja mi cuenta" y "terminate my account" dan cosine alto (~0.6-0.8)
# - "qué hora es" y "receta de chocolate" dan cosine bajo (~0.0-0.2)
# - Con vectores normalizados: cos == dot y L2² = 2 - 2·cos
```

### 2. Embeddings con OpenAI y búsqueda top-k

```python
# pip install openai numpy
from openai import OpenAI
import numpy as np

client = OpenAI()

def embed(texts: list[str], model: str = "text-embedding-3-small") -> np.ndarray:
    resp = client.embeddings.create(model=model, input=texts)
    vecs = np.array([d.embedding for d in resp.data], dtype=np.float32)
    # normalizar para usar dot product como cosine
    vecs /= np.linalg.norm(vecs, axis=1, keepdims=True)
    return vecs

docs = [
    "Los reembolsos tardan de 5 a 7 días hábiles.",
    "Para cambios de talla usa el portal de devoluciones.",
    "El soporte atiende de lunes a viernes 9-18 CST.",
    "Los productos digitales no se reembolsan.",
    "Las entregas internacionales toman 10-15 días.",
]
D = embed(docs)

query = "¿Cuánto tarda mi devolución de dinero?"
q = embed([query])[0]

# top-k por producto punto (equivale a cosine por estar normalizados)
scores = D @ q
top_k = np.argsort(-scores)[:3]
for i in top_k:
    print(f"[{scores[i]:.3f}] {docs[i]}")
```

### 3. Matryoshka: reducir dimensiones gratis

```python
# text-embedding-3-* permite truncar
vec_3072 = embed(["hola"])[0]       # (3072,) con 3-large
vec_1024 = vec_3072[:1024]
vec_1024 /= np.linalg.norm(vec_1024)  # re-normalizar tras truncar
# Trade-off: ~2% peor en MTEB, 3x menos almacenamiento y compute
```

### 4. Visualizar embeddings con UMAP

```python
# pip install umap-learn matplotlib
import umap
import matplotlib.pyplot as plt

reducer = umap.UMAP(n_components=2, metric="cosine", random_state=42)
V2 = reducer.fit_transform(V)

plt.figure(figsize=(8, 6))
plt.scatter(V2[:, 0], V2[:, 1])
for i, txt in enumerate(frases):
    plt.annotate(txt, (V2[i, 0], V2[i, 1]), fontsize=8)
plt.title("Embeddings proyectados a 2D (UMAP)")
plt.show()
```

## Errores comunes

- **Mezclar modelos de embeddings.** Vectores de `MiniLM` y `text-embedding-3-small` viven en **espacios distintos**; compararlos no tiene sentido. Si cambias de modelo, **re-indexa todo**.
- **No normalizar.** Si usas cosine la normalización es irrelevante, pero si usas dot product sin normalizar, favoreces vectores de mayor magnitud y rompes el ranking. Regla segura: **normaliza siempre** (`normalize_embeddings=True`).
- **Ignorar los prefijos asimétricos.** E5 sin `query:`/`passage:` pierde ~5-10 puntos de MTEB. Cohere embed-v3 sin `input_type` idem.
- **Texto demasiado largo.** La mayoría de modelos truncan silenciosamente a 512 tokens. Un chunk de 2000 tokens pierde el 75% del contenido. Verifica `max_seq_length` y chunk-ea.
- **Elegir solo por MTEB score.** El benchmark no incluye tu dominio. Siempre **evalúa en tu corpus** con queries reales.
- **Sobre-dimensionar.** 3072 dims pueden ser overkill. Con MRL o modelos pequeños (384-768) se consume 4-8x menos storage y compute, con pérdida mínima.
- **Confundir similitud alta con relevancia.** Un cosine de 0.9 entre "cómo cancelo" y "política de cancelación" no significa que ese chunk responda la pregunta; mide **relevancia** con una métrica aparte (nDCG, LLM-judge).
- **Olvidar re-ranking.** Los embeddings densos capturan tema pero no siempre precisión fina. Añade un **cross-encoder re-ranker** (bge-reranker-v2, Cohere Rerank) sobre los top-50 para elegir top-5.
- **No cachear.** Embeber el mismo texto dos veces es tirar dinero. Cachea por hash del input.
- **Mezclar idiomas con modelo monolingüe.** Un modelo EN-only coloca el español en un rincón del espacio y la similitud se degrada. Usa multilingual.

## Resumen

- Un **embedding** mapea texto a un vector `ℝᵈ` donde cercanía geométrica = cercanía semántica.
- Dimensionalidades típicas: 384, 768, 1024, 1536, 3072. **MRL (Matryoshka)** permite truncar sin reentrenar.
- Métricas: **cosine** `(A·B)/(||A||·||B||)` es el estándar para texto; **dot** es equivalente si están normalizados; **L2** también para vectores unitarios.
- Modelos clave: `text-embedding-3-*` (OpenAI), `embed-v3` (Cohere), **BGE**, **E5**, `all-MiniLM-L6-v2`, `all-mpnet-base-v2`. Compara en **MTEB**.
- **Asymmetric embeddings** (E5, Cohere): distintos prefijos para query y documento; respétalos.
- Decisiones: dominio, idioma, latencia, hosting, longitud → eligen el modelo.
- **Siempre normaliza**, **nunca mezcles modelos**, **re-indexa al cambiar**, **evalúa en tu corpus**.
- Para alta precisión final: embeddings densos para recall + **re-ranker** cross-encoder para precision.
- Sin embeddings no hay semantic search; sin semantic search no hay RAG. Es la pieza más fundacional del stack.
