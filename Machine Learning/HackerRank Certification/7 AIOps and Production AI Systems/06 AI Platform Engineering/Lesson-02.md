# Model Registry y Prompt Library Centralizados

## ¿Qué es?

Un **Model Registry** es el catálogo central y versionado de modelos entrenados, con su metadata (hiperparámetros, métricas, dataset, código, autor, lineage), sus **stages** del ciclo de vida (Dev → Staging → Prod → Archived) y los **artefactos** binarios (pesos, tokenizer, schema). Es a los modelos lo que un **container registry** es a las imágenes Docker: una fuente única de verdad.

Un **Prompt Library (Prompt Registry)** cumple la misma función pero para **prompts de LLM**: cada prompt tiene nombre, versión, variables, modelo asociado, evals, labels (`dev`/`staging`/`production`) y audit trail. Permite tratar prompts como código versionado sin desplegar la app cada vez que cambian.

| Herramienta | Qué registra | Notas |
|---|---|---|
| **MLflow** | Modelos ML/DL clásicos | Open-source, standard de facto |
| **Weights & Biases Models** | Modelos + experimentos + artifacts | SaaS, muy popular en DL |
| **Vertex AI Model Registry** | Modelos en GCP | Integración con Vertex Pipelines |
| **SageMaker Model Registry** | Modelos en AWS | Integración con SageMaker Pipelines |
| **Hugging Face Hub (privado)** | Modelos y datasets | Útil para LLMs/transformers |
| **Langfuse** | Prompts, trazas, evals | Open-source, LLM-first |
| **Humanloop** | Prompts, evals, feedback | SaaS, foco en product teams |
| **PromptLayer** | Prompts, logs, A/B | SaaS |
| **LangChain Hub** | Prompts versionados | Ligero, parte del ecosistema LangChain |

## ¿Por qué importa?

Sin registry pasa esto: alguien entrena `fraud_model_v3_FINAL_realfinal.pkl` en su laptop, lo sube a S3 "temporal", y seis meses después nadie puede responder qué dataset lo entrenó, qué métricas obtuvo ni quién aprobó su despliegue. Cuando llega la auditoría o un incidente de fraude en producción, no hay respuestas.

Los problemas que resuelve un registry central:

- **Reproducibilidad.** Dado un model_id, puedo reconstruir **datos + código + hiperparámetros** exactos.
- **Governance.** Quién promovió qué modelo a prod y cuándo, con qué approvers.
- **Comparación.** Decidir deploy mirando v1.4 vs v1.3 lado a lado (métricas, dataset, sesgo por grupo).
- **Rollback.** Volver a la versión anterior en segundos ante incidente.
- **Discovery.** "¿Ya existe un modelo de intent detection?" se responde en una búsqueda.
- **Compliance.** GDPR, HIPAA, SOC 2, EU AI Act y la mayoría de regulaciones exigen trazabilidad de modelos y datos.
- **Deploy automático.** El evento "modelo promovido a Production" dispara CI/CD; cero clicks manuales.

Para prompts aplica lo mismo multiplicado: un prompt cambia 20 veces más que un modelo, cualquiera puede editarlo, y una regresión silenciosa degrada calidad sin alertas.

## ¿Cómo funciona?

### Metadata obligatoria por versión

| Campo | Ejemplo |
|---|---|
| `model_id` | `fraud-txn-xgb` |
| `version` | `v12` o `1.4.0` |
| `stage` | `Dev` / `Staging` / `Production` / `Archived` |
| `metrics` | `{"auc": 0.962, "precision@top1%": 0.78}` |
| `params` | `{"max_depth": 8, "lr": 0.05, "seed": 42}` |
| `dataset_uri` | `s3://data/fraud/2026-02-15/train.parquet@v37` |
| `code_commit` | `git@corp:fraud/trainer#a1b2c3d` |
| `trained_by` | `ana@corp` |
| `trained_at` | `2026-02-16T14:22Z` |
| `framework` | `xgboost==2.1.0` |
| `signature` | input schema + output schema |
| `tags` | `team=risk, pii=true, cost_center=CC-4421` |

### Stages y lifecycle

```
┌──────────┐  register   ┌──────────┐  validate   ┌──────────┐
│   Dev    │────────────►│ Staging  │────────────►│Production│
└──────────┘             └──────────┘             └──────────┘
     ▲                        │                        │
     │                        │ reject                 │ rollback
     └────────────────────────┴────────────────────────┘
                                                        │
                                                        ▼
                                                   ┌──────────┐
                                                   │ Archived │
                                                   └──────────┘
```

Cada transición es un **evento auditable**. Dev→Staging suele requerir aprobación del data scientist; Staging→Production requiere **doble aprobación** (DS + eng lead), checks automáticos pasados y evals en benchmark congelado por encima de umbral.

### Approval workflow (patrón estándar)

1. Trainer sube `v13` → stage `Dev`.
2. CI corre tests: schema, performance mínima, drift vs `v12`, bias por grupo, security scan.
3. Si todo pasa → request `Dev → Staging` (auto-approve o 1 reviewer).
4. En staging, canary al 5% de tráfico con shadow eval.
5. Request `Staging → Production` con contexto en el PR: métricas, delta vs v12, test results, plan de rollout.
6. Aprobaciones requeridas (configurables por riesgo del modelo).
7. Promoción dispara CI/CD → despliegue a prod + locking de versión + notificación Slack.
8. Si hay regresión → `rollback` instantáneo al tag anterior.

### Lineage

Lineage conecta `modelo → código → datos → features`. Útil para preguntas como: *"si retiramos el dataset D porque un usuario pidió deletion, ¿qué modelos están afectados?"*. Herramientas: OpenLineage, DataHub, Marquez.

### Prompt library: lifecycle paralelo

Los prompts siguen un flujo similar: `draft` → `staging` → `production`. Cambios se hacen por PR, con evals automáticas antes de promover.

```
prompt: support/triage      versions: v1, v2, v3, v4
labels: production → v3     staging → v4    draft → v5
```

La app pide siempre por **label** (`production`), no por versión fija. Rollback = mover la label.

### Audit trail y compliance

Todo cambio queda logueado con `(who, what, when, why, approver)`. En industrias reguladas (banca, salud) estos logs se exportan periódicamente a un sistema inmutable (S3 Object Lock, append-only DB). El EU AI Act y la FDA exigen **≥ 10 años** de retención para sistemas de alto riesgo.

### Access control y version locking

- **RBAC** por rol: `ds_junior` puede registrar; `ds_senior` promueve a staging; `ml_lead` promueve a prod; `admin` archiva.
- **Version locking**: una vez `Production`, el artefacto y la metadata son **inmutables**. Nadie puede sobreescribir, solo registrar nueva versión.

## Ejemplo con código

### 1. MLflow: registro, promoción con approval y rollback

```python
import mlflow
from mlflow.tracking import MlflowClient
from mlflow.entities.model_registry import ModelVersion

mlflow.set_tracking_uri("https://mlflow.internal")
MODEL = "risk/fraud-txn-xgb"

# ---------- 1. Entrenar y registrar ----------
with mlflow.start_run(run_name="xgb-v13") as run:
    mlflow.log_params({"max_depth": 8, "lr": 0.05, "seed": 42})
    mlflow.log_metrics({"auc": 0.962, "precision_at_1pct": 0.78})
    mlflow.set_tags({
        "team": "risk",
        "pii": "true",
        "dataset_uri": "s3://data/fraud/2026-02-15/train.parquet@v37",
        "code_commit": "a1b2c3d",
    })
    mlflow.xgboost.log_model(booster, artifact_path="model",
                             signature=signature,
                             registered_model_name=MODEL)

client = MlflowClient()
latest = client.get_latest_versions(MODEL, stages=["None"])[0]

# ---------- 2. Checks automáticos pre-promoción ----------
def passes_quality_gates(mv: ModelVersion) -> bool:
    run = client.get_run(mv.run_id)
    metrics = run.data.metrics
    if metrics["auc"] < 0.95:
        return False
    # comparar con prod actual
    prod = client.get_latest_versions(MODEL, stages=["Production"])
    if prod:
        prod_auc = client.get_run(prod[0].run_id).data.metrics["auc"]
        if metrics["auc"] < prod_auc - 0.005:   # no regresión > 0.5pp
            return False
    return True

assert passes_quality_gates(latest), "quality gate failed"

# ---------- 3. Promoción con audit ----------
client.transition_model_version_stage(
    name=MODEL,
    version=latest.version,
    stage="Staging",
    archive_existing_versions=False,
)
client.set_model_version_tag(MODEL, latest.version, "approved_by", "ana@corp")

# ---------- 4. Después de canary OK → prod ----------
client.transition_model_version_stage(
    name=MODEL, version=latest.version, stage="Production",
    archive_existing_versions=True,     # archiva el prod anterior
)

# ---------- 5. Rollback en incidente ----------
def rollback(model_name: str):
    archived = client.search_model_versions(
        f"name='{model_name}' and tags.last_prod='true'"
    )
    prev = sorted(archived, key=lambda m: int(m.version))[-1]
    client.transition_model_version_stage(
        model_name, prev.version, "Production", archive_existing_versions=True
    )
```

### 2. Approval workflow con webhook + Slack

```python
# webhook disparado por MLflow al cambiar stage
from fastapi import FastAPI, Request
import httpx, os

app = FastAPI()
SLACK = os.environ["SLACK_WEBHOOK_APPROVALS"]

@app.post("/mlflow/webhook")
async def on_transition(req: Request):
    event = await req.json()
    if event["to_stage"] == "Production":
        msg = (
            f":rotating_light: Promoción a *Production* solicitada\n"
            f"• modelo: `{event['model_name']}` v{event['version']}\n"
            f"• por: {event['user']}\n"
            f"• AUC: {event['metrics']['auc']:.3f}\n"
            f"<https://mlflow.internal/#/models/{event['model_name']}/versions/{event['version']}|Revisar>"
        )
        await httpx.AsyncClient().post(SLACK, json={"text": msg})
    return {"ok": True}
```

### 3. Prompt library con Langfuse (versioning + labels)

```python
from langfuse import Langfuse

lf = Langfuse(host="https://langfuse.internal")

# ----- publicar nueva versión -----
lf.create_prompt(
    name="support/triage",
    prompt=(
        "Eres un asistente de soporte. Categoriza el ticket en "
        "{{categories}}. Responde SOLO el nombre de la categoría.\n\n"
        "Ticket: {{ticket}}"
    ),
    config={"model": "smart-chat", "temperature": 0.0, "max_tokens": 20},
    labels=["staging"],         # entra como staging, no como production
    tags=["support", "classification"],
)

# ----- promoción a production (tras evals OK) -----
latest = lf.get_prompt("support/triage", label="staging")
lf.update_prompt(name="support/triage", version=latest.version,
                 new_labels=["production", "staging"])

# ----- consumo desde la app (SIEMPRE por label) -----
p = lf.get_prompt("support/triage", label="production")
rendered = p.compile(categories="billing,bug,other", ticket=ticket_text)

# el SDK adjunta prompt_name y prompt_version a la traza:
with lf.start_as_current_span(name="triage", input=ticket_text) as span:
    span.update(prompt=p)   # audit: qué versión atendió esta request
    answer = llm.chat(rendered)
    span.update(output=answer)
```

### 4. Audit trail estructurado (ejemplo esquema)

```sql
CREATE TABLE model_audit (
    id            BIGSERIAL PRIMARY KEY,
    ts            TIMESTAMPTZ NOT NULL DEFAULT now(),
    actor         TEXT NOT NULL,         -- user/service account
    action        TEXT NOT NULL,         -- register|promote|archive|rollback
    model_name    TEXT NOT NULL,
    version       TEXT NOT NULL,
    from_stage    TEXT,
    to_stage      TEXT,
    reason        TEXT,
    approvers     JSONB,                 -- [{"user":"ana","ts":...}, ...]
    metrics       JSONB,
    dataset_uri   TEXT,
    code_commit   TEXT
);
-- append-only: revocar DELETE/UPDATE a todos salvo auditor
REVOKE UPDATE, DELETE ON model_audit FROM PUBLIC;
```

### 5. Comparación de registries

| Capacidad | MLflow | W&B | Vertex AI | SageMaker | Langfuse (prompts) |
|---|---|---|---|---|---|
| Open-source | ✅ | ❌ | ❌ | ❌ | ✅ |
| Stages lifecycle | ✅ (aliases) | ✅ | ✅ | ✅ | ✅ (labels) |
| Webhooks | ✅ | ✅ | ✅ (Eventarc) | ✅ (EventBridge) | ✅ |
| RBAC fino | parcial | ✅ | ✅ | ✅ | ✅ |
| Lineage integrado | parcial | ✅ | ✅ | ✅ | n/a |
| Self-hosted | ✅ | ✅ (enterprise) | ❌ | ❌ | ✅ |
| Evals de LLM | ❌ | ✅ | parcial | parcial | ✅ |

## Errores comunes

- **Guardar modelos en S3 sin registry.** `s3://bucket/models/final_v2_definitivo.pkl` sin metadata ni lineage. En 6 meses nadie sabe qué es, quién lo entrenó, ni si está en prod.
- **No lockear versiones en Production.** Alguien sobreescribe `v12` y rompe reproducibilidad y auditoría. La versión promovida debe ser **inmutable**.
- **Prompts hardcodeados en el código.** Cambiar un prompt obliga a redeploy; A/B es imposible y no hay audit. Mueve todo a prompt library con labels.
- **Promover a prod sin checks automáticos.** Solo aprobación humana → errores pasan. Combina **gate automático** (métricas, drift, bias, PII, security) con **aprobación humana** (contexto, estrategia).
- **Approval workflow sin contexto.** Pedir "aprobar v13" sin mostrar métricas vs v12, test results y plan de rollout → el aprobador firma a ciegas o rechaza por default.
- **Audit trail mutable.** Logs en una tabla donde cualquiera puede hacer `UPDATE` → sin valor para auditoría. Usa append-only con permisos revocados.
- **No alertar al promover a prod.** El equipo de SRE se entera del cambio por el incidente. Integra con Slack/Teams.
- **Un solo entorno (no hay staging).** Todo va directo de dev a prod. Primer error en producción cuesta el 10x que en staging.
- **Lineage incompleto.** Se registra el código pero no el **dataset_uri + version**. Reproducir el modelo es imposible y el "right to be forgotten" se vuelve un ticket imposible de cerrar.
- **Un registry por equipo.** Cada equipo con su MLflow → se pierde discovery, se duplican modelos y la governance se vuelve imposible. **Uno central, multi-tenant con RBAC**.
- **Rollback no probado.** El procedimiento existe en docs pero nunca se ejecutó; cuando toca usarlo (incidente a las 3am), descubres que el artefacto viejo fue garbage-collected.

## Resumen

- Un **Model Registry** es la fuente única de verdad de modelos: artefactos + metadata + lineage + stages + audit, versionado e inmutable en Production.
- El **lifecycle** estándar es `Dev → Staging → Production → Archived`, con transiciones **auditadas** y aprobaciones proporcionales al riesgo.
- Los **approval workflows** combinan checks automáticos (performance, drift, bias, security) con juicio humano sobre contexto.
- Un **Prompt Library** (Langfuse, Humanloop, LangChain Hub) hace lo mismo para prompts: versiones, labels, evals y rollback por label.
- **Audit trails inmutables** y **version locking** son requisitos duros para GDPR, HIPAA, SOC 2 y EU AI Act.
- **RBAC granular** por rol (DS junior / senior / lead / admin) impide promociones no autorizadas.
- Los errores más graves: artefactos sueltos en S3, prompts hardcodeados, promociones sin contexto y audit trails mutables.
- **Un solo registry central multi-tenant** vence a N registries por equipo: permite discovery, governance y chargeback consistentes.
