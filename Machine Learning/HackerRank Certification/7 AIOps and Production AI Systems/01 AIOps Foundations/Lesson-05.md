# Reproducibilidad, versionado y caso real end-to-end

## ¿Qué es?

**Reproducibilidad** en IA significa que, dados los mismos inputs y el mismo entorno, obtienes exactamente las mismas predicciones y los mismos modelos. Es la propiedad fundamental que permite debuggear incidentes, cumplir regulaciones (GDPR, AI Act) y comparar experimentos de forma honesta.

A diferencia del software tradicional, donde reproducibilidad se logra con un commit de Git y un lock file de dependencias, en IA necesitas versionar **cinco artefactos** y mantener trazabilidad entre ellos:

```
Predicción  =  f(
    Modelo        (binario entrenado, v2.3.1),
    Código        (git commit abc123),
    Datos         (DVC hash xyz789),
    Config        (hiperparámetros, feature flags, seeds),
    Dependencias  (requirements.lock, imagen Docker sha256:...)
)
```

Si pierdes cualquiera de los cinco, no puedes reproducir el modelo original. Y si no puedes reproducirlo, no puedes debuggearlo cuando falle.

> **Idea clave:** la reproducibilidad no es un lujo académico; es la precondición de todo lo demás en AIOps. Sin ella, cada incidente es un misterio irresoluble.

### Las cinco dimensiones de versionado

| Artefacto | Herramienta típica | Estrategia |
|---|---|---|
| **Código** | Git | Commits firmados, branches protegidas |
| **Datos** | DVC, LakeFS, Delta Lake, Git-LFS | Hashes de contenido, snapshots inmutables |
| **Modelos** | MLflow Registry, W&B, SageMaker | Semver (v2.3.1), metadata de origen |
| **Config** | Hydra, OmegaConf, YAML en Git | Config as code, overrides por entorno |
| **Dependencias** | pip-tools, Poetry, Conda-lock, Docker | Lock files + digests de imagen |

### Niveles de reproducibilidad

| Nivel | Qué garantiza | Costo |
|---|---|---|
| **Bitwise exacto** | Mismos bits en el output | Alto: requiere seeds, hardware idéntico, determinismo total |
| **Numéricamente equivalente** | Resultados dentro de tolerancia ε | Medio: fijar seeds, controlar paralelismo |
| **Estadísticamente equivalente** | Mismas métricas agregadas | Bajo: solo fijar seed |
| **Conceptualmente reproducible** | Mismo workflow, resultados comparables | Mínimo: documentar pipeline |

Para producción, el objetivo típico es **numéricamente equivalente**. El determinismo bitwise en GPU es muy caro (requiere desactivar optimizaciones) y rara vez necesario.

## ¿Por qué importa?

Sin reproducibilidad, el equipo de IA opera a ciegas:

- **Incidentes irresolubles.** "El modelo bajó de 92% a 78%, no sé por qué". Sin lineage, no puedes saber si cambiaron los datos, el código, los hiperparámetros o la infra.
- **Experimentos no comparables.** Dos data scientists reportan resultados distintos para "el mismo" experimento porque usaron datasets ligeramente distintos.
- **Rollback imposible.** Volver al modelo de hace 3 meses requiere reconstruir el entorno exacto, lo cual es imposible si no se versionó.
- **Regulación incumplible.** GDPR Art. 22 y el AI Act exigen poder explicar y auditar decisiones automatizadas. Sin reproducibilidad, no hay auditoría posible.
- **Deuda técnica masiva.** Cada data scientist desarrolla su propio flujo porque no confía en los artefactos de los demás.

### Casos reales típicos

- Un banco debe explicar a un cliente por qué le negaron un crédito en 2024. El modelo cambió tres veces desde entonces. Sin versionado completo, no pueden reconstruir qué modelo evaluó esa aplicación.
- Un equipo descubre que el modelo degradó. El dataset de training original fue sobreescrito hace 6 meses. No pueden reproducir el modelo original para comparar.
- Un investigador publica un paper con resultados brillantes. Nadie puede reproducirlos porque el entorno Python exacto no está documentado.

## ¿Cómo funciona?

### Versionado de datos: DVC

**DVC (Data Version Control)** trata datasets como commits de Git usando hashes del contenido:

```bash
# Añadir dataset al tracking
dvc add data/training.parquet
git add data/training.parquet.dvc .gitignore
git commit -m "data: snapshot 2026-10-05"

# Push a S3/GCS/Azure
dvc push

# Checkout del dataset de un commit anterior
git checkout commit-sha
dvc checkout
```

El archivo `.dvc` contiene el hash del dataset. Git versiona el hash; S3 almacena los bytes. Reproducir el dataset exacto de hace 6 meses es cuestión de `git checkout` + `dvc checkout`.

### Versionado de datos a escala: LakeFS y Delta Lake

Para datasets de terabytes, DVC no escala. **LakeFS** y **Delta Lake** aplican el modelo de Git directamente sobre data lakes (S3):

- **Branches** de datos (puedes crear un branch "experimental" sin copiar los datos).
- **Commits** inmutables con mensaje.
- **Time travel**: querear "el estado del dataset ayer".
- **Rollback** instantáneo.

### Versionado de modelos: MLflow Registry

```python
import mlflow

mlflow.set_tracking_uri("http://mlflow:5000")

# Registrar modelo con lineage completo
with mlflow.start_run() as run:
    mlflow.log_params(hyperparameters)
    mlflow.log_metrics(metrics)
    mlflow.log_param("data_dvc_hash", get_dvc_hash("data/training.parquet"))
    mlflow.log_param("git_commit", get_git_commit())
    mlflow.log_artifact("config.yaml")

    model_info = mlflow.sklearn.log_model(
        sk_model=model,
        artifact_path="model",
        registered_model_name="recommender",
        signature=infer_signature(X_train, y_pred),
        input_example=X_train.head(3),
    )
```

Cada versión del registry queda ligada a su `run_id`, que a su vez contiene todos los parámetros, métricas y referencias a código y datos.

### Determinismo: fijando seeds

```python
import os
import random
import numpy as np
import torch

def set_seed(seed: int = 42):
    """Fija todas las fuentes de aleatoriedad para reproducibilidad."""
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)

    # Para determinismo completo en PyTorch (más lento)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False
    os.environ["PYTHONHASHSEED"] = str(seed)
    os.environ["CUBLAS_WORKSPACE_CONFIG"] = ":4096:8"
    torch.use_deterministic_algorithms(True, warn_only=True)
```

### Versionado de dependencias

```bash
# Con pip-tools: separar requirements.in de requirements.txt
pip-compile requirements.in --generate-hashes -o requirements.txt
pip-sync requirements.txt

# Con Poetry
poetry lock
poetry install --sync
```

Más robusto: fija también la imagen base de Docker por digest:

```dockerfile
FROM python:3.11-slim@sha256:abc123...
```

### Lineage end-to-end

Un sistema maduro traza cada predicción hasta su origen:

```
Predicción (en producción, timestamp 2026-10-05T12:34:56)
    ↓
Model recommender v2.3.1 (MLflow)
    ↓
Run abc123 (MLflow)
    ├── Código: git sha def456
    ├── Datos: DVC hash xyz789
    ├── Config: hyperparameters.yaml v4
    ├── Dependencias: requirements.lock + docker:sha256:...
    └── Métricas offline: F1=0.89, AUC=0.92
```

Herramientas que automatizan esto: **Dagster** (software-defined assets con lineage automático), **MLflow + DVC**, **Metaflow**.

## Ejemplo con código

### Caso completo: sistema de recomendación end-to-end

Vamos a aterrizar todo el módulo en un caso realista. **Requisitos:**

- Recomendaciones personalizadas en homepage y detalle de producto.
- 5,000 requests por segundo en pico.
- Latencia p99 < 200ms.
- 50 millones de usuarios activos.
- Modelo de 200M parámetros (~800MB en FP16).

### Arquitectura propuesta

```
┌─────────┐    ┌──────────────┐    ┌─────────────────┐
│ Frontend│───▶│ API Gateway  │───▶│  FastAPI (ECS)  │
└─────────┘    │ (auth, rate) │    │  recommender    │
               └──────────────┘    └────────┬────────┘
                                            │
                           ┌────────────────┼────────────────┐
                           ▼                ▼                ▼
                   ┌──────────────┐  ┌─────────┐    ┌──────────────┐
                   │ Redis cache  │  │Postgres │    │ Triton on GPU│
                   │ (user feats, │  │(product │    │ (model v2.3) │
                   │  recos hot)  │  │catalog) │    │ batch=32,    │
                   └──────────────┘  └─────────┘    │ 20ms window  │
                                                    └──────────────┘
                           │
                           ▼
                   ┌──────────────┐
                   │ Prometheus + │
                   │   Grafana    │
                   │ (SLOs, drift)│
                   └──────────────┘
```

### Decisiones y trade-offs

| Decisión | Alternativas | Elección | Razón |
|---|---|---|---|
| Real-time vs batch | 100% real-time / 100% batch / híbrido | **Híbrido** | Homepage: batch nocturno (más fresco < coste); PDP: real-time |
| Compute | CPU (~833 cores) vs GPU (~2 T4) | **GPU T4** | $4,320/mes vs $18,720/mes, latencia 5ms vs 150ms |
| Caching | Sin cache / Redis / CDN | **Multi-nivel: CDN + Redis** | Homepage ~100% hit en CDN, features en Redis TTL 60s |
| Data pipeline | Batch nightly / streaming / híbrido | **Streaming (Kafka) + batch** | Kafka → Redis en segundos; warehouse nightly para training |
| Deploy | Big bang / canary / blue-green | **Blue-green + shadow 24h** | 2x infra temporal, pero rollback instantáneo |

### Código de implementación: endpoint principal

```python
# serving/app.py
from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
from prometheus_client import Counter, Histogram, Gauge, make_asgi_app
import httpx
import time
import redis.asyncio as redis
import asyncpg

app = FastAPI()
app.mount("/metrics", make_asgi_app())

# Métricas
REQUESTS = Counter("inference_requests_total", "", ["version", "page"])
LATENCY = Histogram("inference_duration_seconds", "", ["version", "page"],
                   buckets=[0.01, 0.05, 0.1, 0.2, 0.5, 1.0])
FALLBACKS = Counter("fallback_used_total", "", ["reason"])

MODEL_VERSION = "v2.3.1"

# Clientes compartidos
redis_client: redis.Redis = None
db_pool: asyncpg.Pool = None
triton_client = httpx.AsyncClient(base_url="http://triton:8000",
                                   timeout=httpx.Timeout(0.1))


@app.on_event("startup")
async def startup():
    global redis_client, db_pool
    redis_client = redis.from_url("redis://redis:6379")
    db_pool = await asyncpg.create_pool(dsn="postgres://...", max_size=20)


class RecoRequest(BaseModel):
    user_id: str
    page: str
    context: dict


@app.post("/recommend")
async def recommend(req: RecoRequest):
    start = time.perf_counter()
    REQUESTS.labels(MODEL_VERSION, req.page).inc()

    try:
        # 1. Chequeo de cache (homepage: 100% hit; PDP: ~20%)
        cache_key = f"reco:{req.user_id}:{req.page}"
        if cached := await redis_client.get(cache_key):
            return {"items": cached, "cached": True,
                    "model_version": MODEL_VERSION}

        # 2. Fetch features (paralelo)
        user_feat_task = redis_client.get(f"user_feat:{req.user_id}")
        product_task = db_pool.fetch(
            "SELECT id, embedding FROM products WHERE active LIMIT 500"
        )
        user_features, products = await asyncio.gather(
            user_feat_task, product_task
        )

        if not user_features:
            FALLBACKS.labels("missing_features").inc()
            return fallback_recommendations(req.page)

        # 3. Inferencia en Triton (dynamic batching de 20ms)
        payload = build_triton_payload(user_features, products, req.context)
        resp = await triton_client.post(
            f"/v2/models/recommender/versions/{MODEL_VERSION}/infer",
            json=payload,
        )
        scores = resp.json()["outputs"][0]["data"]

        # 4. Post-proceso: filtrar out-of-stock, aplicar reglas
        items = post_process(products, scores, req.context)

        # 5. Cachear resultado
        await redis_client.setex(cache_key, 60, items)
        return {"items": items, "cached": False,
                "model_version": MODEL_VERSION}

    except httpx.TimeoutException:
        FALLBACKS.labels("model_timeout").inc()
        return fallback_recommendations(req.page)
    except Exception as e:
        FALLBACKS.labels("unknown").inc()
        raise HTTPException(500, "Error interno")
    finally:
        LATENCY.labels(MODEL_VERSION, req.page).observe(
            time.perf_counter() - start
        )


def fallback_recommendations(page: str):
    """Degradación graciosa: top-N global cuando el modelo falla."""
    return {"items": TOP_GLOBAL[page], "cached": True,
            "model_version": "fallback"}
```

### Pipeline de retraining con lineage completo

```python
# pipelines/retrain.py
from prefect import flow, task
import mlflow
import dvc.api
import subprocess

@task
def snapshot_data() -> str:
    """Crea snapshot inmutable del dataset con DVC."""
    subprocess.run(["dvc", "add", "data/training.parquet"], check=True)
    subprocess.run(["dvc", "push"], check=True)
    hash_result = subprocess.run(
        ["dvc", "status", "data/training.parquet.dvc"],
        capture_output=True, text=True, check=True,
    )
    git_sha = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    return git_sha


@task
def train_with_lineage(git_sha: str):
    with mlflow.start_run() as run:
        # Log de todos los artefactos para lineage
        mlflow.log_param("git_commit", git_sha)
        mlflow.log_param("data_dvc_url",
                         dvc.api.get_url("data/training.parquet"))
        mlflow.log_artifact("config.yaml")
        mlflow.log_artifact("requirements.lock")

        model = build_and_train()

        mlflow.sklearn.log_model(
            model, "model",
            registered_model_name="recommender",
            signature=infer_signature(X_train, model.predict(X_train)),
        )
        return run.info.run_id


@flow(name="recommender-retrain")
def retrain():
    sha = snapshot_data()
    run_id = train_with_lineage(sha)
    print(f"Run {run_id} completo. Lineage trazable desde predicción.")
```

### Resultado medido

Con esta arquitectura:

- **5,000 RPS en pico, p99 < 180ms** (dentro de SLO).
- **Costo mensual:** ~$6,000 (2x T4 GPUs + Redis + Postgres + egress).
- **Escala a 10K RPS** añadiendo 2 GPUs más (lineal).
- **Degradación graciosa:** fallback a top global si Triton falla.
- **Rollback instantáneo** con blue-green y traffic shifting en 30 minutos.
- **Lineage completo:** cada predicción traza a modelo, código, datos y config exactos.

## Errores comunes

- **No versionar los tres pilares a la vez.** Versionar solo código, o solo modelos, deja huecos irresolubles. Versiona código + datos + modelos + config + deps como una unidad coherente.
- **Datasets mutables.** Sobreescribir `training.csv` en S3 rompe cualquier intento de reproducibilidad. Usa DVC/LakeFS/Delta Lake con snapshots inmutables.
- **Seeds no fijados.** Entrenamientos "equivalentes" producen modelos distintos por aleatoriedad. Fija seeds en Python, NumPy, PyTorch y CUDA.
- **Dependencias flotantes.** `requirements.txt` con `transformers>=4.0` instala versiones distintas en cada build. Usa lock files con hashes.
- **Imágenes Docker sin digest.** `FROM python:3.11` cambia con el tiempo. Fija el digest `@sha256:...`.
- **MLflow sin lineage de datos y código.** Loggear solo métricas no basta: incluye git sha, DVC hash y config file como `log_param`/`log_artifact`.
- **Diseños monolíticos sin fallbacks.** Un sistema que colapsa al 100% si el modelo falla es inoperable. Siempre ten un fallback (reglas, top global, cache).
- **Sobre-ingenierizar la arquitectura.** Docenas de microservicios y colas crean sistemas frágiles. Empieza simple; añade complejidad solo cuando lo simple ya no basta.
- **Ignorar el training-serving skew.** Features calculadas con lógica distinta en training vs serving es la fuente #1 de bugs en producción.
- **No ensayar el rollback.** Un botón de rollback que nunca se probó es equivalente a no tenerlo. Haz drills regulares.

## Contexto y referencias

- **DVC (dvc.org):** versionado de datos basado en Git.
- **LakeFS (lakefs.io) y Delta Lake (delta.io):** versionado a escala de data lake.
- **MLflow (mlflow.org):** experiment tracking + model registry.
- **Weights & Biases (wandb.ai):** alternativa comercial con mejor UI.
- **"Reproducibility in Machine Learning: A Lightning Talk"** (Joel Grus): clásico sobre el problema.
- **ML Reproducibility Checklist** (Joelle Pineau, NeurIPS): lista de verificación estándar.
- **Google Research Reproducibility practices:** documentación sobre determinismo en TPUs/GPUs.

## Resumen

- La **reproducibilidad** es la propiedad fundamental que habilita debugging, auditoría y comparabilidad honesta en IA.
- Hay que versionar **cinco artefactos**: código, datos, modelos, config, dependencias, con **lineage trazable** entre ellos.
- **DVC/LakeFS/Delta Lake** para datos; **MLflow/W&B** para modelos; **Git** para código y config; **Poetry/pip-tools + Docker digest** para dependencias.
- **Determinismo** requiere fijar seeds en todos los frameworks y a veces desactivar optimizaciones GPU; para producción basta con equivalencia numérica.
- Sin reproducibilidad: incidentes irresolubles, experimentos incomparables, rollback imposible y regulación incumplible.
- El caso real de un recomendador a 5K RPS combina: **API gateway**, **FastAPI**, **cache multi-nivel (CDN+Redis)**, **Triton con dynamic batching en GPU**, **Postgres**, **blue-green deployment** y **observabilidad Prometheus/Grafana**.
- La arquitectura ganadora **no es la más sofisticada**: es la que balancea latencia, costo y complejidad para el contexto concreto.
- **Degradación graciosa** (fallback a reglas o cache) es obligatoria: ningún componente puede ser single point of failure.
- La disciplina de **versionado + lineage + SLOs + observabilidad + rollback probado** convierte a un prototipo frágil en un sistema de producción confiable.
- AIOps no es un conjunto de herramientas: es una **cultura operativa** que atraviesa todo el ciclo de vida del modelo.

Este cierre del submódulo de fundamentos te prepara para el siguiente: estrategias concretas de **despliegue de modelos** (canary, shadow, blue-green, A/B) y patrones de serving a escala.
