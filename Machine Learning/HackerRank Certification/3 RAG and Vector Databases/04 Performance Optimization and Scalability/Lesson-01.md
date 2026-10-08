# Técnicas Avanzadas de Indexación (ANN)

## ¿Qué es?

Un **índice vectorial avanzado** es una estructura de datos especializada que acelera la búsqueda por similitud sacrificando una pequeña fracción de recall a cambio de reducir drásticamente la latencia. En lugar de comparar la consulta contra **todos** los vectores del dataset (búsqueda exacta `O(n)`), un índice **ANN (Approximate Nearest Neighbor)** organiza los vectores en grafos, árboles, listas invertidas o códigos cuantizados para encontrar los `k` vecinos más probables en `O(log n)` o `O(√n)`.

La familia ANN incluye cuatro grandes paradigmas:

| Familia | Idea central | Representantes |
|---|---|---|
| **Basados en grafos** | Grafo navegable: cada nodo apunta a sus vecinos más cercanos; se navega por "autopistas" y luego "calles locales". | HNSW, NSG, Vamana (DiskANN) |
| **Basados en particiones (IVF)** | K-means sobre el espacio: solo se buscan los clusters más cercanos a la query. | IVF-Flat, IVF-PQ, ScaNN |
| **Basados en cuantización** | Comprimir los vectores a códigos de pocos bytes para acelerar la distancia. | PQ (Product Quantization), SQ (Scalar), OPQ, RQ |
| **Basados en hashing** | Funciones hash que mapean vectores cercanos al mismo bucket con alta probabilidad. | LSH, Multi-probe LSH |

> **Definición formal:** dado un conjunto `X = {x₁, ..., x_n} ⊂ ℝᵈ` y una query `q ∈ ℝᵈ`, el problema **c-ANN** consiste en encontrar un punto `x*` tal que `d(q, x*) ≤ c · d(q, NN(q))` con probabilidad `1-δ`, donde `c > 1` es el factor de aproximación.

### Métrica fundamental: Recall@k

Recall mide qué tan completa es la respuesta aproximada frente a la exacta:

```
Recall@k = |ANN_k(q) ∩ Exact_k(q)| / k
```

Un recall@10 = 0.95 significa que, en promedio, 9.5 de los 10 vecinos devueltos por el índice ANN son también vecinos del algoritmo exacto. En producción se busca típicamente **recall ≥ 0.95** para RAG.

## ¿Por qué importa?

La búsqueda exacta por fuerza bruta tiene complejidad `O(n · d)`. Con `n = 10⁷` vectores de `d = 768` dimensiones (típico de un embedding `text-embedding-3-small` o `bge-large`), cada query realiza **~7.7 mil millones de operaciones** solo para calcular distancias. Incluso con BLAS optimizado y GPU, estamos hablando de cientos de milisegundos **por consulta**, lo cual destruye cualquier presupuesto de latencia (`latency budget`) razonable para un chatbot o API.

Un índice HNSW bien configurado responde la misma query en **1-5 ms** con **recall@10 ≥ 0.97**. La diferencia práctica es brutal:

| Escala | Flat (brute force) | HNSW | IVF-PQ | Nota |
|---|---|---|---|---|
| 10 K | 2 ms | 0.3 ms | 0.5 ms | Flat sigue siendo viable |
| 100 K | 25 ms | 1 ms | 1.5 ms | Flat empieza a doler |
| 1 M | 250 ms | 3 ms | 4 ms | Flat ya no cumple SLA |
| 10 M | 2.5 s | 8 ms | 10 ms | Flat imposible; memoria también explota |
| 100 M | 25 s | 30 ms | 15 ms | HNSW cabe apenas en RAM; IVF-PQ gana |

Además de latencia, el otro factor crítico es **memoria**:

- 10 M vectores × 768 dims × 4 bytes (float32) = **30 GB** solo para los vectores crudos.
- HNSW añade 30-50 % de overhead por el grafo → **~45 GB**.
- IVF-PQ con `m=96`, `nbits=8` comprime a 96 bytes/vector → **~1 GB**. Compresión **~30×**.

Para equipos con restricción de hardware o deploy serverless (Pinecone serverless, Qdrant Cloud, Milvus), la elección del índice define el **costo mensual**.

### Herramientas del ecosistema

| Herramienta | Autor | Fuerte en |
|---|---|---|
| **FAISS** | Facebook AI Research (2017) | Librería C++/Python de referencia; IVF, PQ, HNSW, GPU |
| **HNSWlib** | Yury Malkov (autor del paper) | Implementación mínima y rapidísima de HNSW puro |
| **ScaNN** | Google Research (2020) | Anisotropic quantization; estado del arte en recall/QPS |
| **Milvus** | Zilliz | DB vectorial distribuida; sharding, replicación, GPU |
| **Qdrant** | Qdrant (Rust) | HNSW + payload rich filtering; API gRPC |
| **Pinecone** | Pinecone (serverless) | Managed; separa storage de compute (pod-free) |
| **Weaviate** | SeMI | HNSW + GraphQL + modules de embedding |
| **pgvector** | Supabase/Timescale | Extensión de PostgreSQL; IVFFlat y HNSW |

## ¿Cómo funciona?

### HNSW (Hierarchical Navigable Small World)

Publicado por **Yury Malkov y Dmitry Yashunin (2016)**, HNSW combina dos ideas: los grafos *small-world* de Kleinberg y una estructura jerárquica tipo skip-list.

**Estructura:**

```
Layer 2:    A ────────────── D
            │                │
Layer 1:    A ──── B ──────── D ──── F
            │      │          │      │
Layer 0:    A ─ B ─ C ─ D ─ E ─ F ─ G ─ H   ← todos los nodos
```

- Cada vector se inserta en la capa `l` elegida con probabilidad geométrica `P(l) = (1-p) · pˡ` (típicamente `p = 1/ln(M)`).
- Capas superiores: pocos nodos, conexiones largas → navegación rápida (autopistas).
- Capa 0: todos los nodos, conexiones cortas → precisión local (calles).
- Búsqueda: *greedy* desde el entry point en la capa top, bajando capa a capa, manteniendo una lista de candidatos de tamaño `ef`.

**Complejidad:**

```
Inserción:  O(log N · M · efConstruction)
Búsqueda:   O(log N · ef)   ← logarítmica en el tamaño del dataset
Memoria:    O(N · M · 2)    ← ~M conexiones por nodo en promedio
```

**Hiperparámetros clave:**

| Parámetro | Qué controla | Rango típico | Impacto |
|---|---|---|---|
| `M` | Conexiones máximas por nodo en capas > 0 | 8–64 | ↑ M → ↑ recall, ↑ memoria, ↑ build time |
| `efConstruction` | Tamaño del candidate set durante inserción | 100–500 | ↑ → mejor grafo, build más lento |
| `efSearch` | Tamaño del candidate set en búsqueda | 32–512 | ↑ → ↑ recall, ↑ latencia (ajustable por query) |

### IVF (Inverted File)

K-means parte el espacio en `nlist` clusters. En búsqueda, solo se exploran los `nprobe` clusters más cercanos a la query.

```
Build:   kmeans(X, k=nlist)  →  lista invertida por centroide
Search:  nearest_centroids(q, nprobe)  →  comparar solo esos buckets
```

- Reduce el espacio de búsqueda de `n` a aproximadamente `n · nprobe / nlist`.
- `nlist ≈ √N` es la heurística clásica (ej. 10 M vectores → 3-4 K clusters).
- `nprobe` controla el trade-off: más clusters = más recall = más latencia.

### PQ (Product Quantization)

Idea de **Jégou, Douze y Schmid (2011)**: dividir cada vector `d`-dimensional en `m` sub-vectores de dimensión `d/m`, y cuantizar cada sub-vector contra un codebook de `k = 2^nbits` centroides.

**Compresión:**

```
Tamaño original:    d · 4 bytes          (float32)
Tamaño comprimido:  m · nbits / 8 bytes
Ratio:              (d · 32) / (m · nbits)
```

Ejemplo: `d=768`, `m=96`, `nbits=8` → `(768·32)/(96·8) = 32×` compresión.

### Distancia asimétrica (ADC)

En búsqueda IVF-PQ, la query **no se cuantiza**: se calcula una tabla `d/m × k` de distancias precomputadas query-vs-centroides, y la distancia aproximada a cualquier vector almacenado se obtiene sumando `m` lookups.

```
distancia_approx(q, x) = Σᵢ₌₁ᵐ ||q_i - codebook_i[code_i(x)]||²
```

Esto es **~10× más rápido** que descomprimir y comparar, y el error de cuantización es manejable.

### Tabla comparativa de ANN

| Algoritmo | Recall@10 | QPS (1 M vec) | Memoria | Build time | Soporta updates |
|---|---|---|---|---|---|
| **Flat** | 1.00 | ~50 | 100 % | 0 | Sí |
| **HNSW (M=16, ef=100)** | 0.98 | ~5 000 | 130-150 % | Medio | Sí (slow deletes) |
| **IVF-Flat (nlist=√N, nprobe=16)** | 0.95 | ~3 000 | 105 % | Rápido | Sí |
| **IVF-PQ (m=96, nbits=8)** | 0.88-0.93 | ~8 000 | 3-5 % | Medio | Sí |
| **ScaNN (anisotropic)** | 0.96 | ~15 000 | 15-25 % | Lento | No fácil |
| **LSH (multi-probe)** | 0.70-0.85 | ~2 000 | 50 % | Rápido | Sí |

### Cuantización escalar vs. producto

| Tipo | Cómo | Compresión | Pérdida |
|---|---|---|---|
| **Scalar (SQ8)** | Cada dim → 1 byte (0-255) | 4× | Mínima (~1 % recall) |
| **Product (PQ)** | Sub-vectores → códigos | 8–64× | Moderada (depende de `m`, `nbits`) |
| **Residual (RQ)** | Múltiples capas de PQ sobre residuales | 10-30× | Menor que PQ puro |
| **Binary (ITQ)** | Hash a bits + XOR | 32× | Alta (recall ~0.75) |

## Ejemplo con código

### 1. FAISS: construir y comparar Flat, HNSW y IVF-PQ

```python
import numpy as np
import faiss
import time

# ------------------------------------------------------------
# Dataset sintético: 1 M vectores de 128 dims (reducido para demo)
# ------------------------------------------------------------
d = 128
nb = 1_000_000          # base
nq = 1_000              # queries
np.random.seed(42)
xb = np.random.random((nb, d)).astype("float32")
xq = np.random.random((nq, d)).astype("float32")

# ------------------------------------------------------------
# Ground truth con Flat (exacto)
# ------------------------------------------------------------
flat = faiss.IndexFlatL2(d)
flat.add(xb)
t0 = time.time(); D_gt, I_gt = flat.search(xq, 10); t_flat = time.time() - t0

# ------------------------------------------------------------
# HNSW
# ------------------------------------------------------------
M = 32
hnsw = faiss.IndexHNSWFlat(d, M)
hnsw.hnsw.efConstruction = 200    # build quality
t0 = time.time(); hnsw.add(xb); t_build_hnsw = time.time() - t0

hnsw.hnsw.efSearch = 64           # search quality (ajustable en runtime)
t0 = time.time(); D_h, I_h = hnsw.search(xq, 10); t_hnsw = time.time() - t0

# ------------------------------------------------------------
# IVF-PQ
# ------------------------------------------------------------
nlist = int(np.sqrt(nb))          # ~1 000 clusters
m = 16                            # sub-vectores (d debe ser múltiplo)
nbits = 8                         # 256 centroides por sub-codebook
quantizer = faiss.IndexFlatL2(d)
ivfpq = faiss.IndexIVFPQ(quantizer, d, nlist, m, nbits)
ivfpq.train(xb)                   # k-means + codebook training
ivfpq.add(xb)
ivfpq.nprobe = 16                 # clusters a visitar en búsqueda
t0 = time.time(); D_i, I_i = ivfpq.search(xq, 10); t_ivfpq = time.time() - t0

# ------------------------------------------------------------
# Métricas: recall@10, QPS, latencia media
# ------------------------------------------------------------
def recall_at_k(I_pred, I_gt, k=10):
    return np.mean([
        len(set(I_pred[i]) & set(I_gt[i])) / k
        for i in range(len(I_gt))
    ])

print(f"{'Índice':<10} {'QPS':>8} {'ms/query':>10} {'recall@10':>12}")
for nombre, I_pred, t in [("Flat", I_gt, t_flat), ("HNSW", I_h, t_hnsw), ("IVFPQ", I_i, t_ivfpq)]:
    qps = nq / t
    ms = 1000 * t / nq
    r = recall_at_k(I_pred, I_gt, 10)
    print(f"{nombre:<10} {qps:>8.0f} {ms:>10.2f} {r:>12.3f}")
```

Salida típica (CPU single-thread):

```
Índice         QPS   ms/query    recall@10
Flat            45     22.00        1.000
HNSW          6200      0.16        0.978
IVFPQ         9800      0.10        0.912
```

### 2. HNSWlib puro: control fino de parámetros

```python
import hnswlib
import numpy as np

d, N = 768, 500_000
data = np.random.random((N, d)).astype("float32")

# Inicialización
index = hnswlib.Index(space="cosine", dim=d)
index.init_index(
    max_elements=N,
    M=32,                 # 32 conexiones (bueno para d alto)
    ef_construction=200,  # calidad del grafo
)

# Añadir datos (soporta batching y multithreading)
index.add_items(data, ids=np.arange(N), num_threads=8)

# Parámetro de búsqueda (ajustable por request)
index.set_ef(100)         # ef_search

# Query
q = np.random.random((1, d)).astype("float32")
labels, distances = index.knn_query(q, k=10)
print(labels, distances)

# Persistencia
index.save_index("hnsw.bin")
# ... más tarde:
loaded = hnswlib.Index(space="cosine", dim=d)
loaded.load_index("hnsw.bin", max_elements=N)
```

### 3. Barrido de `efSearch` para encontrar el punto operativo

```python
# Objetivo: encontrar el ef más chico que logre recall >= 0.95
import numpy as np

targets = [16, 32, 64, 100, 150, 250, 400]
for ef in targets:
    hnsw.hnsw.efSearch = ef
    t0 = time.time(); _, I_h = hnsw.search(xq, 10); dt = time.time() - t0
    r = recall_at_k(I_h, I_gt, 10)
    p95 = np.percentile([dt/nq]*nq, 95) * 1000  # aprox
    print(f"ef={ef:>4}  recall={r:.3f}  p95≈{p95:.2f} ms  QPS={nq/dt:.0f}")
```

Este tipo de barrido es la práctica estándar: se grafica `recall vs QPS` (curva de Pareto) y se elige el `ef` que cumple el presupuesto de latencia con el recall objetivo.

## Errores comunes

- **`efSearch` demasiado bajo** → recall se desploma silenciosamente. El sistema "funciona" (devuelve resultados) pero el RAG empieza a dar respuestas incompletas o alucinadas porque pierde documentos clave. **Siempre monitorear recall@k contra un ground truth muestreado.**
- **No entrenar IVF-PQ con datos representativos.** El `train()` ajusta codebooks: si entrenas con 10 K puntos de un cluster y en producción llegan queries de otro cluster, el recall colapsa. Usa muestra aleatoria estratificada ≥ 100 K.
- **Olvidar que `d` debe ser divisible por `m` en PQ.** FAISS falla silenciosamente o con error críptico si `d % m != 0`.
- **Usar HNSW cuando el dataset ya no cabe en RAM.** HNSW requiere acceso aleatorio al grafo; swapping a disco mata el performance. Para datasets >100 M vectores considerar DiskANN/Vamana o IVF-PQ en memoria.
- **Fuerza bruta `O(n)` cuando el dataset creció.** Equipos que empezaron con 10 K vectores (donde Flat era óptimo) no migran al pasar a 1 M y empiezan a tener p95 de segundos. Automatizar la migración por umbral (`if n > 100_000: use HNSW`).
- **No recalcular recall tras updates masivos.** HNSW degrada su recall tras muchos `delete` + `insert` porque el grafo acumula "nodos tumba". Reindexar periódicamente (semanal/mensual) según rotación.
- **No cachear embeddings regenerados.** Cada vez que llamas a OpenAI/Cohere para embedir la misma query pagas latencia (~100 ms) y dinero. El cache de embeddings da hit rates de 40-60 % en producción.
- **No shardear al crecer.** Un solo nodo con 50 M vectores HNSW es un SPOF y se queda sin RAM. Shardear horizontalmente por hash del `doc_id` o por tenant.
- **Confundir distancias.** Si entrenaste embeddings normalizados para coseno pero construyes el índice con `IndexFlatL2`, los rankings son correctos pero las distancias no son interpretables. Usa `IndexFlatIP` para producto interno o normaliza + L2.
- **Ignorar el *build budget*.** `efConstruction=500` con 100 M vectores puede tomar días. Medir y planear reindexaciones en ventanas de mantenimiento.

## Resumen

- La **búsqueda ANN** cambia una fracción pequeña de recall por una mejora de órdenes de magnitud en latencia: `O(n)` → `O(log n)`.
- **HNSW** es el default moderno para datasets de 100 K a 10 M vectores con alto recall; sus parámetros clave son `M`, `efConstruction` (build time) y `efSearch` (runtime).
- **IVF-PQ** es la opción cuando la memoria es la restricción dura: compresión 8-32× con recall 0.88-0.93 aceptable para RAG grandes.
- **ScaNN** (Google) y **DiskANN** son estado del arte en recall/QPS y en escala multi-millonaria respectivamente.
- Las métricas obligatorias son **recall@k**, **QPS**, **p95 latency** y **memory footprint**; sin ellas no sabes si el índice "funciona".
- La **cuantización** (SQ, PQ, OPQ, RQ) y la **distancia asimétrica (ADC)** son las palancas de compresión; PQ domina en producción.
- Herramientas: FAISS (librería), HNSWlib (minimalista), ScaNN (Google), y las DBs vectoriales Milvus, Qdrant, Pinecone, Weaviate, pgvector.
- Elegir el índice con una **matriz de decisión** (tamaño, memoria, recall objetivo, SLA) y **medir siempre** con un ground truth real, no sintético.
- Monitorear el **recall tras updates** y planear reindexaciones: HNSW no sobrevive bien a borrados masivos sin rebuild.
