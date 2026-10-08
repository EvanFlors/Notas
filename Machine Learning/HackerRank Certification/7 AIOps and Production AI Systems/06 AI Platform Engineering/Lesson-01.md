# Platform Thinking para Equipos de IA

## ¿Qué es?

Una **plataforma interna de IA** es un conjunto de servicios compartidos (training, serving, feature store, model registry, gateway, observabilidad, governance) que los equipos de producto consumen **self-service** para construir y operar modelos sin reinventar infraestructura. En otras palabras, es un **producto interno** cuyos clientes son data scientists, ML engineers y backend engineers de la propia empresa.

El concepto proviene de la disciplina más amplia de **Platform Engineering** (popularizada por Team Topologies y por reportes de Thoughtworks), aplicada a cargas de trabajo de IA/ML/LLM. Ejemplos públicos:

| Empresa | Plataforma | Descripción |
|---|---|---|
| Netflix | **Metaflow** | Framework open-source para pipelines ML con ejecución local/cloud transparente. |
| Uber | **Michelangelo** | End-to-end ML platform (feature store, training, serving, monitoring). |
| LinkedIn | **Pro-ML** | Plataforma para feed ranking, people-you-may-know y search. |
| Spotify | **ML Platform + Backstage** | Portal unificado para experimentos, modelos y features. |
| Airbnb | **Bighead** | Pipeline estandarizado train→deploy→monitor. |
| Anthropic / OpenAI | Herramientas internas de evals, fine-tuning y gateway | Governance de costos y acceso a modelos propios. |

### Principios fundacionales

1. **Self-service primero.** Deploy en minutos sin ticket.
2. **Golden paths.** El camino "fácil y correcto" coincide: hacer lo bien pensado es lo más rápido.
3. **Opinionated pero no rígido.** Defaults sanos, escape hatches cuando se necesitan.
4. **Platform-as-a-Product.** Hay roadmap, usuarios, NPS, versioning y backward compatibility.
5. **Governance invisible.** Seguridad, compliance y cost caps se obtienen por default, no se piden.

## ¿Por qué importa?

Sin plataforma, cada equipo reinventa serving, monitoring, auth, feature pipelines y gateways a LLMs. El costo oculto es brutal:

- **Duplicación:** 10 equipos × 3 ingenieros × 2 meses construyendo "serving" = 60 persona-meses tirados.
- **Inconsistencia:** cada equipo con su propio formato de logs, SLOs y métricas → imposible comparar o auditar.
- **Riesgo de seguridad:** cada app implementa auth a su manera, con bugs distintos. Un atacante solo necesita el eslabón más débil.
- **Costos fuera de control:** sin chargeback, nadie limita a GPT-4 en producción con prompts de 20k tokens.
- **Compliance imposible:** sin trazabilidad central (quién entrenó qué, con qué datos, cuándo se desplegó), auditorías GDPR/HIPAA/SOC 2 se vuelven pesadillas.

Una buena plataforma convierte **semanas de yak-shaving** en **minutos de "git push"**. El impacto típico tras un año de plataforma madura:

| Métrica | Antes | Después |
|---|---|---|
| Tiempo deploy modelo nuevo | 2 semanas | < 1 hora |
| % tiempo ingenieros en infra | 40% | 10% |
| Incidentes por configuración | 3-5 / mes | < 1 / mes |
| Costo LLM por request | sin control | capped por team |
| Modelos reproducibles | ~30% | > 95% |

### Cuándo NO construir una plataforma

- Equipo < 10 personas y < 5 modelos → **compra** (SageMaker, Vertex, Databricks) o adopta Metaflow/MLflow directamente.
- "Vamos a hacerla por si acaso" sin stakeholders definidos → se vuelve un museo.
- Un solo caso de uso que nunca se replicará → sobre-ingeniería garantizada.

## ¿Cómo funciona?

Una plataforma de IA madura expone capas que los equipos componen según necesidad.

### Componentes típicos

| Componente | Función | Herramientas |
|---|---|---|
| **Model Gateway / Router** | Punto único a LLMs (propios y externos) con auth, rate-limit, fallbacks, budgets. | LiteLLM, Portkey, OpenRouter, Kong AI Gateway |
| **Model Registry** | Catálogo versionado de modelos + metadata + stages. | MLflow, Weights & Biases, Vertex Model Registry |
| **Prompt Library / Registry** | Prompts versionados con A/B, evals y audit trail. | Langfuse, Humanloop, PromptLayer, LangChain Hub |
| **Feature Store** | Features consistentes entre training y serving. | Feast, Tecton, Hopsworks |
| **Training Orchestration** | Pipelines reproducibles, retries, caching. | Metaflow, Kubeflow, Airflow, Dagster |
| **Serving** | Autoscaling, batching, canary. | KServe, BentoML, vLLM, Ray Serve, Seldon |
| **Eval Infrastructure** | Evals de regresión, offline y online. | Langfuse, Promptfoo, Braintrust, Patronus |
| **Observabilidad** | Trazas, métricas, drift. | Arize, Evidently, WhyLabs, Datadog LLM Obs |
| **Developer Portal** | UI única para onboarding, docs, catálogo. | Backstage, Port, Cortex |
| **Governance** | SSO, RBAC, approvals, cost caps, PII guardrails. | OPA, Keycloak, in-house |

### Golden paths

Un **golden path** es la secuencia bendecida para un escenario común. Ejemplo: "lanzar un chatbot RAG a producción".

```
┌───────────────────────────────────────────────────────────┐
│  cookiecutter chatbot-rag  →  genera repo con:            │
│    - Dockerfile estandarizado                             │
│    - CI que corre evals y PII scan                        │
│    - Hook a Langfuse (prompts + trazas)                   │
│    - Config LiteLLM (routing GPT-4 → Claude fallback)     │
│    - SLO template (p95 < 2s, error rate < 1%)             │
│    - Terraform para KServe + Pinecone namespace           │
│  →  git push  →  CI aprueba  →  deploy a sandbox          │
│  →  approval del tech lead  →  deploy prod                │
└───────────────────────────────────────────────────────────┘
```

Si el equipo quiere algo distinto (otro vector DB, otro proveedor), puede, pero sale del golden path y asume responsabilidad de operarlo.

### Self-service onboarding

Flujo típico:

```
Team registra en portal (Backstage)
      ↓
SSO (Okta/Azure AD) asigna RBAC por grupo
      ↓
Sandbox provisioned (namespace k8s, API keys, budget $500/mes)
      ↓
Equipo construye prototipo, mide con evals
      ↓
Request promoción a prod → aprobación platform + security
      ↓
Prod namespace + cost chargeback automático a cost center
```

### Multi-tenancy

Un cluster/una infra, muchos equipos. Aislamiento por:

- **Namespaces k8s** con quotas (CPU, GPU, memoria).
- **API keys** por equipo con rate-limits y budgets en el gateway.
- **Row-level security** en feature store (team A no ve features de team B).
- **Logs/trazas** etiquetados por `team_id` para chargeback.
- **Secrets** en Vault/Secrets Manager con policies por equipo.

### SSO y RBAC

Un solo login (Okta, Azure AD, Google Workspace) para portal, MLflow, Langfuse, Grafana. Los permisos derivan de **grupos LDAP/IdP**:

```
grupo:ml-platform-admins   → full
grupo:team-search-ml       → namespace "search", budget $5k/mes, deploy a staging
grupo:team-search-leads    → + approve prod promotions
grupo:data-scientists-all  → read-only al registry
```

### Governance como código

- **Approvals obligatorios** antes de prod (2 reviewers si el modelo toca PII).
- **Cost caps** por equipo/proyecto: el gateway corta llamadas al llegar al umbral.
- **PII policies** aplicadas en el pipeline (OPA / Rego) antes de aceptar un dataset.
- **API versioning**: `/v1/generate` nunca cambia su contrato; cambios breaking van a `/v2`.

## Ejemplo con código

### 1. LiteLLM proxy: gateway unificado con routing, fallbacks y budgets

`litellm_config.yaml`:

```yaml
model_list:
  - model_name: smart-chat
    litellm_params:
      model: openai/gpt-4o
      api_key: os.environ/OPENAI_API_KEY
      rpm: 500
  - model_name: smart-chat
    litellm_params:
      model: anthropic/claude-sonnet-4-5
      api_key: os.environ/ANTHROPIC_API_KEY
      rpm: 500
  - model_name: cheap-chat
    litellm_params:
      model: openai/gpt-4o-mini

router_settings:
  routing_strategy: simple-shuffle
  fallbacks:
    - smart-chat: [cheap-chat]       # si falla smart-chat, baja a cheap
  num_retries: 2
  timeout: 30
  allowed_fails: 3
  cooldown_time: 60

general_settings:
  master_key: os.environ/LITELLM_MASTER_KEY
  database_url: os.environ/DATABASE_URL
  alerting: ["slack"]

litellm_settings:
  success_callback: ["langfuse"]
  failure_callback: ["langfuse"]
  cache: true
```

Crear un **virtual key** por equipo con presupuesto:

```bash
curl -X POST https://litellm.internal/key/generate \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "team_id": "team-search",
    "max_budget": 2000,
    "budget_duration": "30d",
    "models": ["smart-chat", "cheap-chat"],
    "metadata": {"cost_center": "CC-4421"}
  }'
```

El equipo lo consume con el SDK estándar de OpenAI, sin saber qué proveedor atiende:

```python
from openai import OpenAI

client = OpenAI(
    base_url="https://litellm.internal/v1",
    api_key="sk-team-search-xxxx",   # virtual key emitida por la plataforma
)

resp = client.chat.completions.create(
    model="smart-chat",
    messages=[{"role": "user", "content": "Resume este ticket..."}],
    extra_headers={"x-request-id": "req-abc123", "x-user-id": "u-9981"},
)
print(resp.choices[0].message.content)
```

### 2. Model Registry con MLflow

```python
import mlflow
from mlflow.tracking import MlflowClient

mlflow.set_tracking_uri("https://mlflow.internal")
mlflow.set_experiment("search/query-intent")

with mlflow.start_run(run_name="xgb-v12") as run:
    mlflow.log_params({"max_depth": 8, "lr": 0.05})
    mlflow.log_metrics({"f1": 0.912, "auc": 0.954})
    mlflow.xgboost.log_model(model, artifact_path="model")

    # Registrar en el registry central
    mv = mlflow.register_model(
        model_uri=f"runs:/{run.info.run_id}/model",
        name="search-query-intent",
        tags={"team": "search", "owner": "ana@corp"},
    )

# Promover entre stages (con approval real detrás)
client = MlflowClient()
client.transition_model_version_stage(
    name="search-query-intent",
    version=mv.version,
    stage="Staging",
)
```

### 3. Prompt Library con versioning (Langfuse)

```python
from langfuse import Langfuse

lf = Langfuse(host="https://langfuse.internal")

# Publicar un prompt versionado
lf.create_prompt(
    name="support/triage-v3",
    prompt="Eres un asistente de soporte. Clasifica el ticket en: {{categories}}.\nTicket: {{ticket}}",
    config={"model": "smart-chat", "temperature": 0.0},
    labels=["production"],   # etiqueta activa; la app pide siempre "production"
)

# El código de la app NUNCA hardcodea el prompt:
prompt_obj = lf.get_prompt("support/triage-v3", label="production")
compiled = prompt_obj.compile(categories="billing,bug,other", ticket=ticket_text)
```

Promoción entre entornos vía CI/CD (dev → staging → production) con PR review.

### 4. SSO con OAuth2 (ejemplo FastAPI + Okta)

```python
from fastapi import FastAPI, Depends, HTTPException
from fastapi.security import OAuth2AuthorizationCodeBearer
from jose import jwt
import httpx

ISSUER = "https://corp.okta.com/oauth2/default"
AUDIENCE = "ai-platform"

oauth2 = OAuth2AuthorizationCodeBearer(
    authorizationUrl=f"{ISSUER}/v1/authorize",
    tokenUrl=f"{ISSUER}/v1/token",
)

async def current_user(token: str = Depends(oauth2)):
    jwks = httpx.get(f"{ISSUER}/v1/keys").json()
    try:
        claims = jwt.decode(token, jwks, audience=AUDIENCE, issuer=ISSUER)
    except Exception:
        raise HTTPException(401, "invalid token")
    return {"sub": claims["sub"], "groups": claims.get("groups", [])}

def require_group(group: str):
    def _check(user=Depends(current_user)):
        if group not in user["groups"]:
            raise HTTPException(403, f"requires {group}")
        return user
    return _check

app = FastAPI()

@app.post("/registry/promote")
def promote(model: str, user=Depends(require_group("ml-prod-approvers"))):
    # solo miembros del grupo pueden promover a prod
    return {"ok": True, "approved_by": user["sub"]}
```

### 5. Tabla de decisión build vs buy

| Factor | Favorece **BUY** (SageMaker/Vertex/Databricks) | Favorece **BUILD** (open-source + glue) |
|---|---|---|
| Equipo < 20 ingenieros | ✅ | ❌ |
| Casos de uso estándar | ✅ | ❌ |
| Lock-in aceptable | ✅ | ❌ |
| Compliance específico (gob, defensa) | ❌ | ✅ |
| Volumen > $500k/año en managed | ❌ | ✅ |
| Diferenciador competitivo | ❌ | ✅ |
| Multi-cloud obligatorio | ❌ | ✅ |
| Time-to-market prioritario | ✅ | ❌ |

Enfoque práctico: **híbrido**. Compra lo commodity (compute, serving básico), construye el "pegamento" diferenciador (gateway con tus políticas, portal con tu catálogo).

## Errores comunes

- **Plataforma construida sin stakeholders reales.** El equipo platform decide qué hace falta sin hablar con data scientists; resultado: hermosa arquitectura que nadie usa. Antídoto: 10 entrevistas antes de la primera línea de código, y métricas de adopción desde el día 1.
- **Demasiada abstracción, un solo patrón forzado.** "Todos los modelos deben usar nuestro framework X." Rompe casos legítimos (streaming, batch, LLMs, visión) y empuja al shadow IT. Deja escape hatches.
- **No hay cost chargeback.** Como el gasto cae en "la cuenta de la plataforma", los equipos consumen GPT-4 sin medida. Sin **virtual keys con budget** y reporte mensual al cost center, los costos explotan en 3 meses.
- **Auth reimplementado en cada app.** Cada team hace su OAuth con bugs distintos. Centraliza SSO + RBAC desde el inicio, aunque sea feo al principio.
- **Sin API versioning.** Un cambio breaking en `/generate` rompe 40 microservicios el martes a las 10am. Siempre versiona (`/v1`, `/v2`), mantén la vieja por 6-12 meses y deprecate con avisos.
- **Platform team sin product manager.** Sin PM, el backlog es "lo que al staff engineer le pareció interesante esta semana". NPS cae, adopción se estanca.
- **Confundir "platform" con "infrastructure".** Infra es Terraform y Kubernetes; platform añade UX, docs, templates, soporte, roadmap público. Sin eso es solo plumbing.
- **Querer Stage 4 de maturity en año 1.** Feature store, AutoML y continuous training antes de tener serving confiable → colapso.
- **Un solo gateway sin fallbacks.** Si LiteLLM/Portkey cae, toda la empresa queda sin LLMs. Diseña HA real (multi-región, circuit breakers, cache de emergencia).
- **Documentación como afterthought.** Si el "getting started" tarda más de 30 minutos, los equipos no vuelven. Mide **Time to First Deployment** y optímalo como KPI.

## Resumen

- Una **plataforma interna de IA** es un **producto** cuyos clientes son los equipos de la empresa; servicios compartidos de training, serving, registry, prompts, features, gateway, observabilidad y governance.
- Los principios clave son **self-service**, **golden paths**, **governance invisible** y **platform-as-a-product**.
- Componentes centrales: **Model Gateway** (LiteLLM, Portkey), **Model Registry** (MLflow), **Prompt Library** (Langfuse, Humanloop), **Feature Store** (Feast), **Developer Portal** (Backstage).
- La adopción se gana con **excelente DX**: docs claras, errores accionables, templates listos y deploys en minutos.
- **Multi-tenancy, SSO y RBAC** no son opcionales: todo pasa por un login único, con quotas, budgets y audit trail por equipo.
- **Build vs buy** depende de tamaño, criticidad y presupuesto; la mayoría acaba con un **híbrido** (comprar commodity, construir el diferenciador).
- Los errores más caros son construir sin stakeholders, no implementar **cost chargeback** y re-hacer auth en cada app.
- Referencias de madurez: Netflix Metaflow, Uber Michelangelo, LinkedIn Pro-ML, Spotify ML Platform, Airbnb Bighead.
