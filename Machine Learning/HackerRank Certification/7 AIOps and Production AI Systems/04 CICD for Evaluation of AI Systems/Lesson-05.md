# Diseño integral del pipeline, mejores prácticas y herramientas

## ¿Qué es?

Diseñar un pipeline CI/CD completo para AI significa **integrar** las piezas que vimos en las lecciones anteriores (eval, data validation, model registry, deployment, rollback) en un sistema coherente que funcione desde el commit del dev hasta el usuario final.

En equipos maduros, no hay **un** pipeline sino **varios pipelines interconectados** por eventos:

- **Code pipeline:** disparado por commits/PRs; corre tests rápidos, construye containers, deploya a dev.
- **Training pipeline:** disparado por nueva data o schedule; valida data, entrena, evalúa, registra en el model registry.
- **Deployment pipeline:** disparado por promoción de modelo o tag; deploya a staging → shadow → canary → producción.
- **Monitoring pipeline:** continuo; mide calidad, drift, costo; dispara retraining o rollback automáticos.

> **Idea clave:** cada pipeline tiene su propia cadencia (commits = minutos, training = horas-días, monitoring = continuo). Separarlos permite optimizar cada uno sin interferir.

## ¿Por qué importa?

- **Un pipeline monolítico se vuelve inoperable.** Si cada commit dispara 6 horas de retraining, los devs dejan de commitear. Si cada deploy requiere revalidar todo el dataset, pierdes velocidad.
- **Cada pipeline falla distinto.** Que el training pipeline falle por mala data no debe tirar el code pipeline. Separación de concerns = resiliencia.
- **Governance clara.** Approvers distintos para distintos pipelines; audit trail específico; permisos granulares (quién puede promover modelos ≠ quién puede mergear código).
- **Costos controlados.** El código es barato de probar; el entrenamiento es caro. Separar permite correr lo barato siempre y lo caro cuando corresponde.

## ¿Cómo funciona?

### 1. Arquitectura de referencia

```
┌──────────────┐           ┌──────────────┐          ┌──────────────┐
│ Code         │           │ Training     │          │ Deployment   │
│ pipeline     │           │ pipeline     │          │ pipeline     │
│              │           │              │          │              │
│ trigger:     │           │ trigger:     │          │ trigger:     │
│  commit/PR   │           │  data/sched  │          │  promote tag │
│              │           │              │          │              │
│ steps:       │           │ steps:       │          │ steps:       │
│  lint        │           │  data valid. │          │  deploy stg  │
│  unit tests  │           │  preprocess  │          │  int tests   │
│  eval gate   │           │  train       │          │  shadow      │
│  build img   │           │  eval        │          │  canary      │
│  deploy dev  │           │  register    │          │  rollout     │
└──────┬───────┘           └──────┬───────┘          └──────▲───────┘
       │                          │                         │
       │                          │   promote               │
       │                          └─────────────────────────┘
       │
       ▼
   container registry  ←───  model registry  ───→  artifact store
       │                          │                         │
       └──────────────────────────┴─────────────────────────┘
                                  │
                           ┌──────▼─────────┐
                           │ Monitoring     │
                           │ pipeline       │
                           │ (continuo)     │
                           └────────────────┘
```

Puntos de integración:

- **Model registry** conecta training ↔ deployment.
- **Container registry** conecta code ↔ deployment.
- **Config repo** conecta todos los pipelines.
- **Monitoring** cierra el loop hacia training (triggers de retraining) y hacia deployment (auto-rollback).

### 2. Orchestration tools

| Herramienta | Fortaleza | Mejor para |
|---|---|---|
| **GitHub Actions / GitLab CI** | Nativo del repo, YAML simple | Code pipelines, orquestación ligera |
| **Argo Workflows / Argo CD** | Kubernetes-native, GitOps | Deployment pipelines en K8s |
| **Apache Airflow** | DAGs programables en Python, maduro | Training pipelines batch |
| **Kubeflow Pipelines** | ML-first, componentes reutilizables | Training pipelines en K8s |
| **Metaflow** | API Python elegante, Netflix | Data science workflows |
| **Prefect** | Dynamic DAGs, moderno | Workflows híbridos |
| **AWS Step Functions / Vertex Pipelines** | Serverless, integrado al cloud | Equipos single-cloud |
| **Dagster** | Software-defined assets, lineage | Data + ML combinados |

### 3. Mejores prácticas (y sus antipatrones)

| Práctica | Antipatrón |
|---|---|
| Separar training de deployment | Retrainear en cada commit → USD y horas quemados |
| Feature flags para rollout gradual | Cambios *big bang* sin canal de revertir |
| Staging con infra production-like | Saltar staging "porque es idéntico a prod" |
| Monitoreo del pipeline mismo | Solo monitorear producción |
| Data validation como primer paso | Validar después de entrenar |
| Versionar **todo** (código, modelos, data, config, prompts) | "Esto es solo config, no hace falta" |
| Practicar rollback regularmente | Rollback que nunca se probó |
| Automated quality gates + aprobación humana | 100% automático sin oversight en deploys críticos |
| Progressive deployment por default | Deploy al 100% esperando lo mejor |
| **Mismo** serving code en todos los entornos | Dev usa `transformers`, prod usa `vLLM` → skew |
| Eval en PR + full suite nightly | Suite única de 30 min bloqueando a los devs |
| Cache de embeddings y respuestas LLM | Pagar cada corrida de CI |
| Shadow eval antes de canary | Pasar directo de staging a 100% |
| Alias en el registry para rollback instantáneo | Redeploy manual durante incidente |

### 4. Separación training vs deployment

Para un modelo que tarda 6 horas y cuesta USD 50 entrenar:

- **Code commit** → corre tests sobre modelo **actual** (sin reentrenar).
- **Nueva data (triggered por sensor)** → corre training pipeline.
- **Schedule nocturno** → corre training si pasó N horas desde el último.
- **Degradación de métricas en producción** → dispara training (closed loop).

### 5. Feature flags para desacoplar deploy y release

- **Deploy:** el nuevo código/modelo está instalado en producción.
- **Release:** el usuario ve el nuevo comportamiento.

Con un feature flag (LaunchDarkly, Unleash, GrowthBook, Statsig) deploys cuando quieras y liberas por cohortes:

```python
if flags.enabled("support_agent_v4", user_id):
    answer = await ask_v4(msg)
else:
    answer = await ask_v3(msg)
```

Rollback = flip del flag en segundos, sin redeploy.

### 6. Progressive rollout por default

```
1%  →  5min análisis  →  10%  →  15min  →  50%  →  30min  →  100%
       │                       │                   │
       └── auto-rollback si: error_rate > 2%, p95 > 3s,
           llm_judge < baseline - 5pp, cost > baseline + 50%
```

### 7. Pipeline monitoring

El pipeline mismo es un sistema que puede degradarse. Métricas a trackear:

- **Lead time:** desde commit hasta producción.
- **Deployment frequency:** cuántos deploys por día/semana.
- **Change failure rate:** % de deploys que requieren rollback o hotfix.
- **MTTR:** tiempo medio para restaurar servicio tras un fallo.
- **Pipeline success rate:** % de corridas verdes.
- **Pipeline duration p50/p95:** tiempos por stage; detectar lentificación.

Estas son las métricas **DORA**; equipos elite deploy varias veces al día con MTTR < 1h y change failure rate < 15%.

### 8. Catálogo de herramientas (ecosistema actual)

| Capa | Herramientas |
|---|---|
| **Version control** | Git + GitHub, GitLab, Bitbucket |
| **Data versioning** | DVC, LakeFS, Delta Lake, lakeFS, Nessie |
| **CI/CD** | GitHub Actions, GitLab CI, CircleCI, Jenkins |
| **ML orchestration** | Airflow, Kubeflow Pipelines, Metaflow, Prefect, Dagster |
| **Container registry** | GHCR, ECR, GCR, Harbor, Quay |
| **Model registry** | MLflow, Weights & Biases, Neptune, SageMaker, Vertex, Humanloop |
| **Artifact store** | S3, GCS, Azure Blob, MinIO |
| **Secret / config mgmt** | Vault, AWS Parameter Store, K8s Secrets, SOPS |
| **Deployment** | Argo CD, Flux, Spinnaker; Flagger / Argo Rollouts para canary |
| **Serving** | vLLM, TGI, Triton, TorchServe, BentoML, Ray Serve |
| **Observability** | Prometheus, Grafana, Datadog, OpenTelemetry |
| **ML observability** | Arize, Fiddler, Evidently, WhyLabs |
| **LLM eval** | Promptfoo, DeepEval, Braintrust, Humanloop, LangSmith, Ragas |
| **LLM tracing** | LangSmith, Langfuse, Arize Phoenix, Honeycomb |
| **Feature flags** | LaunchDarkly, Unleash, GrowthBook, Statsig |
| **Infra as code** | Terraform, Pulumi, CDK, Crossplane |

### 9. Elegir herramientas: criterios

- **Integración > features individuales.** Un stack simple bien integrado le gana a uno con 15 herramientas desconectadas.
- **Infra que ya tienes.** Si vives en AWS, Vertex Pipelines y GCS tienen fricción. Si vives en K8s, Argo + Flagger es natural.
- **Tamaño del equipo.** 3 personas → GitHub Actions + MLflow + S3 es suficiente. 50 personas → Kubeflow + custom orchestration tiene sentido.
- **Madurez ML.** Primer modelo en prod → start simple. 50 modelos en prod → necesitas registry centralizado + governance.
- **Open-source vs SaaS.** Open-source baja costo variable, sube costo de operación. SaaS al revés.

### 10. Patrón recomendado para equipos empezando

```
GitHub (code + eval configs)
   │
   ├── GitHub Actions ─ code pipeline + eval gate con Promptfoo
   │
   ├── Airflow ─ training pipeline nightly
   │       └── MLflow registry
   │
   └── Argo CD + Flagger ─ deployment pipeline con canary
          └── Prometheus + Grafana + Langfuse
```

Simple, battle-tested, mayoría open-source, escala hasta decenas de modelos.

## Ejemplo con código

Pipeline integral con separación de responsabilidades. Mostramos los tres triggers principales y cómo se conectan.

### Code pipeline (cada PR)

```yaml
# .github/workflows/code.yml
name: Code pipeline
on: [pull_request]

jobs:
  fast-checks:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }
      - run: pip install -r requirements-dev.txt
      - run: ruff check . && mypy src/
      - run: pytest tests/unit -n auto --timeout 30

  eval-gate:
    runs-on: ubuntu-latest
    needs: fast-checks
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
        with: { lfs: true }
      - name: Cache de resultados
        uses: actions/cache@v4
        with:
          path: ~/.promptfoo
          key: eval-${{ hashFiles('evals/*.yaml', 'prompts/**') }}
      - run: npm install -g promptfoo@latest
      - env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: promptfoo eval -c evals/pr-fast.yaml --fail-on-threshold
      - run: python scripts/compare_vs_baseline.py
```

### Training pipeline (Airflow, schedule + data trigger)

```python
# dags/training_pipeline.py
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.sensors.external_task import ExternalTaskSensor
from datetime import datetime, timedelta
import mlflow

default_args = {"retries": 1, "retry_delay": timedelta(minutes=5)}

with DAG(
    "train_support_agent",
    schedule="0 2 * * *",
    start_date=datetime(2026, 1, 1),
    catchup=False,
    default_args=default_args,
) as dag:

    validate = PythonOperator(
        task_id="validate_data",
        python_callable=lambda: __import__("src.pipelines.data_validation").run(),
    )

    train = PythonOperator(
        task_id="train",
        python_callable=lambda: __import__("src.pipelines.train").run(),
    )

    evaluate = PythonOperator(
        task_id="eval",
        python_callable=lambda: __import__("src.pipelines.evaluate").run(),
    )

    def register_if_better(**ctx):
        new = ctx["ti"].xcom_pull(task_ids="eval")
        client = mlflow.tracking.MlflowClient()
        prod = client.get_latest_versions("support-agent", stages=["Production"])[0]
        prod_acc = float(client.get_run(prod.run_id).data.metrics["accuracy"])
        if new["accuracy"] < prod_acc - 0.01:
            raise ValueError(f"Nuevo {new['accuracy']:.3f} < prod {prod_acc:.3f}")
        mlflow.register_model(new["artifact_uri"], "support-agent")

    register = PythonOperator(task_id="register", python_callable=register_if_better)

    validate >> train >> evaluate >> register
```

### Deployment pipeline (Argo CD + Flagger, triggered por nuevo tag en registry)

```yaml
# argo-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: support-agent
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/infra-manifests
    path: apps/support-agent
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated: { prune: true, selfHeal: true }
```

```yaml
# apps/support-agent/canary.yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata: { name: support-agent, namespace: production }
spec:
  targetRef: { apiVersion: apps/v1, kind: Deployment, name: support-agent }
  service: { port: 8080 }
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 100
    stepWeight: 10
    metrics:
      - name: request-success-rate
        thresholdRange: { min: 99 }
        interval: 1m
      - name: request-duration-p95
        thresholdRange: { max: 3000 }
      - name: llm-judge-score
        templateRef: { name: llm-judge }
        thresholdRange: { min: 0.80 }
    webhooks:
      - name: golden-requests
        url: http://verifier/golden
        timeout: 60s
```

### Monitoring pipeline (dispara retraining si hay drift)

```python
# monitoring/drift_watchdog.py
"""Chequea drift cada hora, dispara el DAG de training si supera umbral."""
import pandas as pd, requests
from evidently.report import Report
from evidently.metrics import DatasetDriftMetric

ref = pd.read_parquet("s3://data/reference-2026-09.parquet")
cur = pd.read_parquet("s3://data/last-24h.parquet")

report = Report(metrics=[DatasetDriftMetric()])
report.run(reference_data=ref, current_data=cur)
drift = report.as_dict()["metrics"][0]["result"]["dataset_drift"]

if drift:
    requests.post(
        "https://airflow.ex/api/v1/dags/train_support_agent/dagRuns",
        auth=("svc", TOKEN),
        json={"conf": {"reason": "drift_detected"}},
    )
```

Metricas DORA en un dashboard de Prometheus:

```promql
# Lead time (commit → prod)
avg_over_time(deploy_lead_time_seconds[7d])

# Deployment frequency
count_over_time(deploy_success_total[7d])

# Change failure rate
sum(rate(deploy_rollback_total[7d])) / sum(rate(deploy_total[7d]))

# MTTR
avg(incident_duration_seconds)
```

## Errores comunes

- **Un solo pipeline monolítico.** Code, training y deploy en el mismo YAML → lento, acoplado, imposible de mantener. Separa.
- **Retraining en cada commit.** Confunde "mi código cambió" con "mi modelo necesita cambiar". Separa triggers.
- **Omitir staging "porque es idéntico a prod".** No lo es: datos reales, tráfico real, dependencias reales. Staging catch > 50% de bugs de integración.
- **No versionar data o config.** Un bug reproducible sin la data exacta y la config exacta no es reproducible. Versiona todo.
- **Elegir 10 herramientas antes de tener 1 modelo en prod.** YAGNI aplica a MLOps también. Empieza con un stack simple.
- **Pipeline sin monitoreo.** El propio pipeline degrada: builds más lentos, fallos intermitentes. Trackea métricas DORA.
- **Automatizar 100% sin oversight.** Alta velocidad + alto blast radius = incidentes graves. Deploys críticos merecen aprobación humana.
- **Deploys *big bang*.** 100% al primer intento, sin canary. Progressive rollout por default.
- **Mismo container de training y serving.** 20 GB de dependencias de PyTorch en el pod de serving. Usa containers distintos y optimiza el de serving (vLLM, Triton).
- **Config hardcoded.** `API_URL = "https://prod..."` en el código. Externaliza en env vars o config maps.
- **No cerrar el loop con monitoring.** El pipeline deploya pero nadie revisa que efectivamente mejoró. Dashboards + alertas obligatorios.
- **Integraciones frágiles entre herramientas.** Scripts bash pegando MLflow con Argo con Slack: funcionan hasta que uno cambia API. Usa webhooks nativos o eventos.
- **No invertir en developer experience.** Si un dev tarda 2 horas en entender cómo correr el pipeline localmente, abandona. Documenta, provee CLIs, scripts `make dev`.

## Resumen

- Un **pipeline AI completo** = **code pipeline + training pipeline + deployment pipeline + monitoring pipeline**, interconectados por **model registry**, **container registry** y **config repo**.
- **Separar** training de deployment permite cadencias apropiadas (minutos vs horas) y evita costos innecesarios.
- **Mejores prácticas:** staging obligatorio, versionado total, progressive deployment, feature flags, quality gates automáticos + aprobación humana en deploys críticos, mismo serving code en todos los entornos.
- **Antipatrones:** retrainear en cada commit, saltar staging, no probar rollback, pipeline monolítico, over-tooling prematuro.
- **Orchestration:** GitHub Actions / GitLab CI para code; Airflow / Kubeflow para training; Argo CD + Flagger para deployment.
- **Stack recomendado para empezar:** GitHub Actions + Promptfoo + MLflow + Argo CD + Flagger + Prometheus + Langfuse.
- Trackea **métricas DORA** (lead time, deploy frequency, change failure rate, MTTR) para medir salud del pipeline.
- El pipeline **nunca** está terminado: se itera con la organización, el producto y la madurez del equipo.
