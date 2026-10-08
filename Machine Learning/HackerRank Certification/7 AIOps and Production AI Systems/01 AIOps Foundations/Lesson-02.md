# Ciclo de vida y pipelines: de desarrollo a producción

## ¿Qué es?

El **ciclo de vida de un sistema de IA** es el conjunto de fases por las que atraviesa un modelo desde que es apenas una idea exploratoria hasta que sirve miles de predicciones por segundo en producción, y después se re-entrena continuamente para adaptarse. A diferencia del software tradicional, este ciclo **no es lineal sino cíclico**: nunca "terminas" un sistema de IA, siempre lo iteras.

El reto operativo central es que **cada fase tiene requisitos opuestos**. Exploración necesita flexibilidad y velocidad; producción necesita confiabilidad y rendimiento. Una ingeniera de datos puede entrenar un modelo brillante en una laptop con 16GB de RAM y un CSV local, pero ese mismo modelo debe responder en 200ms a miles de usuarios concurrentes con datos que llegan por API, caches, colas de mensajes y bases de datos distribuidas.

> **Idea clave:** el 90% del esfuerzo real en un sistema de IA ocurre *después* de que el notebook alcanza buena accuracy. El salto de notebook a producción es donde se decide si el proyecto genera valor o muere.

### Las cinco fases canónicas

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Exploración │ →  │ Desarrollo  │ →  │ Validación  │ →  │  Despliegue │ →  │ Monitoreo   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       ↑                                                                           │
       └───────────────────────────────────────────────────────────────────────────┘
                                  (re-iteración continua)
```

| Fase | Objetivo | Requisitos clave |
|---|---|---|
| **Exploración** | Validar si el problema es resoluble con ML | Rapidez, flexibilidad, notebooks |
| **Desarrollo** | Construir pipelines reproducibles | Versionado, tests, CI |
| **Validación** | Probar con datos y infra tipo producción | Paridad con producción, shadow traffic |
| **Despliegue** | Mover a producción con control de riesgo | Rollback, canary, blue-green |
| **Monitoreo** | Detectar degradación antes que el usuario | Observabilidad, alerting, dashboards |

### Entrenamiento vs. serving: dos mundos distintos

Entender la diferencia entre estos dos entornos es el prerrequisito para evitar sorpresas en producción:

| Dimensión | Entorno de entrenamiento | Entorno de serving |
|---|---|---|
| Optimiza para | Throughput, exactitud | Latencia, concurrencia |
| Patrón de datos | Batch grande (millones) | Request individual (1 ejemplo) |
| Hardware | GPUs grandes (A100 80GB, H100) | GPUs chicas (T4, A10) o CPUs/Inferentia |
| Duración | Horas o días | Milisegundos |
| Datos | Todo el histórico accesible | Solo el momento presente |
| Fuente de datos | Data lake, warehouse, parquet | API, Redis, PostgreSQL |
| Features futuros | Permitidos (eval retrospectiva) | Prohibidos (no existen aún) |
| Tolerancia a fallo | Alta: reintenta el job | Baja: usuario esperando |
| Costo | Pico corto, controlable | Continuo, debe optimizarse |

El **training-serving skew** aparece cuando las features se calculan con lógica distinta en entrenamiento y en serving: el modelo ve inputs ligeramente distintos a los que vio durante training y su performance se desploma. Es uno de los bugs más comunes y más caros.

## ¿Por qué importa?

Un ciclo de vida mal gestionado se manifiesta como:

- **Experimentos irreproducibles:** "funcionaba hace tres meses, ahora no sé por qué cambió". Sin lineage de artefactos, debuggear es imposible.
- **Despliegues riesgosos:** cambiar un modelo sin canary ni shadow deployment puede romper el producto para todos los usuarios simultáneamente.
- **Modelos obsoletos:** sin pipelines automatizadas, re-entrenar es un proyecto manual de dos semanas, y por eso casi nunca sucede.
- **Costos ocultos:** entrenamientos que corren innecesariamente o despliegues zombi que consumen GPUs sin servir tráfico.
- **Deuda técnica masiva:** sin disciplina, cada data scientist crea su propio pipeline y nadie puede operar los demás.

### El principio DRY aplicado a ML

Como en software tradicional, la clave es **no repetirse**: una sola librería de feature engineering, un solo registro de modelos, un solo stack de observabilidad. Herramientas como feature stores (Feast, Tecton), model registries (MLflow, W&B) y orquestadores (Prefect, Airflow, Dagster) existen precisamente para evitar que cada equipo reinvente la rueda.

## ¿Cómo funciona?

### Gestión de artefactos: más allá del código

En software tradicional versionas código. En ML debes versionar al menos **cinco cosas** y mantener la relación entre ellas:

```
Predicción  ←  Modelo (binario)
              ├── Código de training (git sha)
              ├── Dataset (hash del snapshot)
              ├── Hiperparámetros (yaml)
              ├── Dependencias (lock file)
              └── Infra (Docker image digest)
```

| Artefacto | Herramienta típica | Retención sugerida |
|---|---|---|
| Código | Git | Indefinida |
| Datos de training | DVC, LakeFS, Delta Lake | Snapshots mensuales + versiones usadas en producción |
| Modelos | MLflow Registry, W&B, SageMaker | Todas las versiones en producción + staging 30 días |
| Experimentos | MLflow, W&B, Comet | Indefinida (son baratos y útiles) |
| Configuraciones | Git + Hydra/OmegaConf | Con el código |
| Imágenes Docker | ECR, GCR, Docker Hub | Las que corresponden a modelos activos |

### Orquestadores: Prefect vs Airflow vs Dagster

Los pipelines de ML necesitan un orquestador que ejecute pasos en orden, maneje reintentos, programe ejecuciones y permita observar qué está pasando:

| Herramienta | Fuerte en | Débil en |
|---|---|---|
| **Airflow** | Madurez, ecosistema enorme | DAGs estáticos, DX anticuada |
| **Prefect** | API moderna en Python, dynamic flows | Comunidad más pequeña |
| **Dagster** | Software-defined assets, lineage automático | Curva de aprendizaje |
| **Kubeflow Pipelines** | Nativo en Kubernetes, pensado para ML | Complejo de operar |
| **Metaflow** | DX amigable para data scientists | Opinionado, menos flexible |

### Model Registry: el corazón del ciclo de vida

Un **model registry** es un servicio que almacena modelos entrenados junto con su metadata y los expone con un ciclo de estados:

```
   [Entrenado]  →  [Candidato]  →  [Staging]  →  [Producción]  →  [Archivado]
                                          │              │
                                          └──────────────┘
                                           (rollback)
```

Cada versión del registry debe contener como mínimo:

- Métricas de evaluación offline (accuracy, F1, loss, etc.)
- Versión del código (git commit)
- Versión de los datos de training (DVC hash)
- Hiperparámetros usados
- Owner y fecha de creación
- Firma del modelo (shape de inputs/outputs)

## Ejemplo con código

### Pipeline completo con Prefect

```python
# pip install prefect mlflow dvc scikit-learn
from prefect import flow, task
from prefect.task_runners import ConcurrentTaskRunner
import mlflow
import pandas as pd
from pathlib import Path
from datetime import datetime

mlflow.set_tracking_uri("http://mlflow-server:5000")
mlflow.set_experiment("recommender-daily")


@task(retries=3, retry_delay_seconds=120)
def ingest(date: str) -> pd.DataFrame:
    """Descarga datos del warehouse para una fecha dada."""
    # En producción: query a Snowflake/BigQuery, no CSV local
    df = pd.read_parquet(f"s3://data/events/{date}.parquet")
    assert len(df) > 10_000, f"Dataset muy pequeño: {len(df)} filas"
    return df


@task
def validate(df: pd.DataFrame) -> pd.DataFrame:
    """Chequeos de calidad de datos (Great Expectations-style)."""
    assert df["user_id"].notna().all(), "user_id nulo detectado"
    assert df["timestamp"].is_monotonic_increasing, "timestamps no ordenados"
    assert df["price"].between(0, 10_000).all(), "precios fuera de rango"
    return df


@task
def feature_engineering(df: pd.DataFrame) -> pd.DataFrame:
    """Calcula features derivadas usando la MISMA librería que serving."""
    from shared_features import compute_user_features  # ← clave: compartida
    return compute_user_features(df)


@task
def train(features: pd.DataFrame) -> dict:
    """Entrena y registra el modelo con MLflow."""
    from sklearn.ensemble import GradientBoostingClassifier
    from sklearn.metrics import f1_score

    X = features.drop(columns=["label"])
    y = features["label"]

    with mlflow.start_run() as run:
        model = GradientBoostingClassifier(n_estimators=200, max_depth=5)
        model.fit(X, y)

        preds = model.predict(X)
        f1 = f1_score(y, preds, average="macro")

        mlflow.log_params({"n_estimators": 200, "max_depth": 5})
        mlflow.log_metric("f1_macro", f1)
        mlflow.log_metric("train_rows", len(X))
        mlflow.sklearn.log_model(model, "model",
                                  registered_model_name="recommender")

        return {"run_id": run.info.run_id, "f1": f1, "version": None}


@task
def promote_if_better(result: dict, min_f1: float = 0.85) -> bool:
    """Promueve a staging solo si supera un umbral mínimo."""
    client = mlflow.MlflowClient()
    if result["f1"] < min_f1:
        print(f"F1={result['f1']:.3f} < {min_f1}, no se promueve")
        return False

    # Buscar la última versión registrada
    versions = client.search_model_versions("name='recommender'")
    latest = max(versions, key=lambda v: int(v.version))
    client.transition_model_version_stage(
        name="recommender",
        version=latest.version,
        stage="Staging",
    )
    print(f"Modelo v{latest.version} promovido a Staging")
    return True


@flow(task_runner=ConcurrentTaskRunner(), name="daily-training")
def daily_training_pipeline(date: str = None):
    date = date or datetime.utcnow().strftime("%Y-%m-%d")
    raw = ingest(date)
    clean = validate(raw)
    features = feature_engineering(clean)
    result = train(features)
    promoted = promote_if_better(result)
    return {"date": date, "promoted": promoted, **result}


if __name__ == "__main__":
    daily_training_pipeline()
```

### Equivalente en Airflow (estilo DAG clásico)

```python
from airflow import DAG
from airflow.decorators import task
from datetime import datetime, timedelta

default_args = {
    "owner": "ml-platform",
    "retries": 3,
    "retry_delay": timedelta(minutes=5),
    "email_on_failure": True,
}

with DAG(
    dag_id="recommender_daily",
    default_args=default_args,
    schedule="0 2 * * *",   # 2am UTC
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=["ml", "recommender"],
) as dag:

    @task
    def ingest(ds=None): ...

    @task
    def validate(df): ...

    @task
    def train(df): ...

    @task
    def promote(result): ...

    promote(train(validate(ingest())))
```

### Equivalente en Dagster (software-defined assets)

```python
from dagster import asset, AssetIn

@asset
def raw_events() -> "pd.DataFrame":
    return pd.read_parquet("s3://data/events/latest.parquet")

@asset(ins={"raw": AssetIn("raw_events")})
def clean_events(raw):
    return raw.dropna()

@asset(ins={"clean": AssetIn("clean_events")})
def trained_model(clean):
    # ... training ...
    return model
```

Dagster trata cada tabla y cada modelo como un **asset** con lineage automático, lo cual es muy útil para debugging.

### Model Registry con MLflow

```python
import mlflow
from mlflow import MlflowClient

client = MlflowClient("http://mlflow-server:5000")

# Promoción manual con validación
def promote_to_production(model_name: str, version: int,
                          min_f1: float, min_latency_ms: float):
    v = client.get_model_version(model_name, version)
    metrics = client.get_run(v.run_id).data.metrics

    if metrics["f1_macro"] < min_f1:
        raise ValueError(f"F1 insuficiente: {metrics['f1_macro']}")
    if metrics["inference_latency_ms"] > min_latency_ms:
        raise ValueError(f"Latencia excesiva: {metrics['inference_latency_ms']}ms")

    # Archivar la versión actual en producción
    for mv in client.search_model_versions(f"name='{model_name}'"):
        if mv.current_stage == "Production":
            client.transition_model_version_stage(
                model_name, mv.version, "Archived"
            )

    client.transition_model_version_stage(
        model_name, version, "Production"
    )
```

## Errores comunes

- **Tratar las fases como lineales en vez de cíclicas.** El ciclo nunca termina: cada iteración mejora el modelo con nuevos datos y hallazgos de producción. Diseña tus pipelines pensando en re-ejecutarlos cientos de veces.
- **Entrenar en un entorno y servir en otro sin paridad.** Si training usa pandas con Python 3.11 y serving usa Rust con conversiones numéricas distintas, las predicciones divergen. Mantén paridad con contenedores compartidos.
- **No usar un model registry desde el inicio.** Carpetas con `model_v1.pkl`, `model_v1_final.pkl`, `model_v1_FINAL_use_this.pkl` son el síntoma. Adopta MLflow o W&B desde el primer modelo.
- **No versionar los datos de training.** Dos entrenamientos con "el mismo" dataset producen modelos distintos si alguien editó el CSV. Usa DVC, LakeFS o Delta Lake.
- **Features futuros en training.** Usar el precio final de venta como feature para predecir ventas: funciona perfecto en training, falla catastróficamente en producción. Sé estricto con qué features existen en el momento de la predicción real.
- **Training-serving skew.** Calcular features con lógica distinta en training (pandas) vs serving (SQL). Solución: feature store o librería compartida.
- **Promover modelos solo con métricas offline.** Un modelo con mejor F1 offline puede tener peor CTR online. Agrega validación con shadow traffic y A/B testing antes de promoverlo.
- **Olvidar cleanup de artefactos.** Modelos y datasets viejos acumulan terabytes. Define políticas de retención claras.
- **No automatizar el pipeline.** Si re-entrenar requiere que una persona corra 5 notebooks a mano, nunca se hará con la frecuencia necesaria. Orquesta todo con Prefect/Airflow/Dagster.
- **Despliegues sin control de versiones del modelo.** Si no sabes qué versión está sirviendo tráfico en cada momento, debuggear incidentes es imposible.

## Contexto y referencias

- **"Hidden Technical Debt in Machine Learning Systems"** (Sculley et al., NeurIPS 2015): paper fundacional sobre la complejidad real del ciclo de vida ML.
- **MLflow docs** (mlflow.org): referencia para model registry y experiment tracking.
- **Prefect, Airflow, Dagster:** compara arquitecturas en los docs oficiales antes de elegir.
- **Feast (feast.dev):** feature store open source para resolver training-serving skew.
- **DVC (dvc.org) y LakeFS (lakefs.io):** versionado de datos a escala.

## Resumen

- El ciclo de vida de un sistema de IA es **cíclico** (exploración → desarrollo → validación → despliegue → monitoreo → retrain) y nunca termina.
- Los entornos de **entrenamiento y serving son opuestos**: throughput vs. latencia, batch grande vs. request individual, horas vs. milisegundos.
- La **gestión de artefactos** en IA incluye código, datos, modelos, hiperparámetros, dependencias e infra, con lineage trazable entre ellos.
- Un **model registry** (MLflow, W&B, SageMaker) centraliza modelos, metadata y estados (Staging/Production/Archived).
- Los **orquestadores** (Prefect, Airflow, Dagster) ejecutan pipelines reproducibles, con reintentos, scheduling y observabilidad.
- El **training-serving skew** es uno de los bugs más comunes y caros: evítalo usando feature stores o librerías compartidas de feature engineering.
- **Automatizar el pipeline** no es un lujo: es lo que permite re-entrenar con la frecuencia necesaria para adaptarse al drift.
- Promueve modelos a producción solo tras pasar **umbrales de calidad + validación online** (shadow, canary, A/B), nunca solo por métricas offline.
- Define **políticas de retención** desde el inicio para no acumular artefactos obsoletos caros de almacenar.
