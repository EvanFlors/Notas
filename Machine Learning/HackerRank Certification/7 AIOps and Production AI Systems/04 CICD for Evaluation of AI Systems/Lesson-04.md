# Deployment pipelines, model registry y auto-rollback

## ¿Qué es?

Una vez que un modelo o prompt pasó los gates de evaluación, hay que **llevarlo a producción** de forma segura, reproducible y reversible. Esto se compone de tres piezas:

- **Automated deployment pipeline** — una secuencia de stages (build → test → package → deploy-staging → validate → deploy-prod → validate) orquestada por GitHub Actions, GitLab CI, Argo CD, Kubeflow Pipelines, etc.
- **Model registry + promotion workflow** — un catálogo central donde cada modelo tiene estado (`dev → staging → production`), lineage (código + data + hyperparams), métricas y aprobaciones humanas.
- **Deployment verification + automated rollback** — tras cada rollout, el sistema valida con smoke tests, golden requests y canary analysis; si algo degrada, revierte sin intervención humana.

> **Idea clave:** el deploy no termina cuando el tráfico llega al nuevo modelo. Termina cuando las métricas del nuevo modelo durante un periodo de validación son equivalentes o mejores que las del anterior.

## ¿Por qué importa?

- **Deploy manual = incidentes.** Pasos olvidados, orden incorrecto, config hardcodeada: el error humano domina las causas raíz de incidentes.
- **Sin rollback automático, perdés tiempo cuando más duele.** En un incidente, cada minuto cuenta. Depender de "alguien tiene que correr este script" es la receta para outages largos.
- **Governance y auditoría.** En industrias reguladas (finanzas, salud) necesitas saber quién aprobó qué modelo, con qué datos, con qué métricas y cuándo.
- **Velocidad con seguridad.** Equipos con buen deploy pipeline deployan N veces al día; sin él, el "release day" es un evento aterrador que ocurre cada 2 semanas.

## ¿Cómo funciona?

### 1. Stages del pipeline

| Stage | Qué hace | Herramientas |
|---|---|---|
| **Build** | Crea container con modelo + serving code | Docker, Buildkit, Ko |
| **Test** | Unit + smoke tests sobre el container | pytest |
| **Package** | Tag + push al registry; genera manifests | ECR, GCR, Helm |
| **Deploy-staging** | Aplica manifest a cluster staging | kubectl, Argo CD, Flux |
| **Validate-staging** | Integration tests + eval + load corto | Promptfoo, k6 |
| **Deploy-prod** | Progresivo (canary, blue-green) | Argo Rollouts, Flagger |
| **Validate-prod** | Golden requests + métricas en vivo | Datadog, Prometheus |
| **Promote / rollback** | Decide según métricas | Flagger, custom |

### 2. Triggers del pipeline

- **Nuevo modelo registrado:** evento del model registry (MLflow webhook) dispara deploy a staging.
- **Merge a main:** cambios de código de serving.
- **Promoción manual:** humano aprueba `staging → production` desde una UI.
- **Git tag semántico:** `v1.4.0` dispara release.
- **Schedule:** retraining nightly con auto-deploy si pasa gates.

### 3. Model registry y promotion workflow

El **model registry** (MLflow, Weights & Biases, SageMaker Model Registry, Vertex AI Model Registry, Humanloop) centraliza:

| Metadato | Ejemplo |
|---|---|
| ID + versión | `support-agent@v4.2` |
| Stage | `dev`, `staging`, `production`, `archived` |
| Métricas | `accuracy=0.84`, `p95=1200ms`, `cost=0.004 USD/req` |
| Lineage | `code=sha abc123`, `data=golden-v1.4`, `params={temp:0.2}` |
| Approvals | `aprobado por @ana_ml el 2026-10-05` |
| Artifact URI | `s3://models/support/4.2/model.tar.gz` |
| Prompt version | hash del prompt en Git |

Estados y transiciones típicas:

```
registered (dev)
    │  gates automáticos: eval + unit + data validation
    ▼
staging
    │  integration tests + load + shadow en prod
    ▼
production-candidate
    │  canary 1% → 10% → 50%, auto-rollback por métricas
    ▼
production (stable)
    │  reemplaza stable anterior → stable anterior pasa a archived
    ▼
archived
```

### 4. Approval workflows

Para deploys críticos, los gates automáticos **no bastan**: se exige firma humana. Patrón:

- Aprobador 1: Data Scientist (confirma métricas).
- Aprobador 2: Product Manager (confirma impacto de negocio).
- Timeout: si no hay aprobación en 48h, el PR expira.

Herramientas que lo soportan nativamente: GitHub Environments (required reviewers), GitLab manual jobs, Argo CD manual sync, MLflow stage transition requests.

### 5. Deployment strategies

| Estrategia | Cómo funciona | Pro | Contra |
|---|---|---|---|
| **Recreate** | Mata vieja, levanta nueva | Simple | Downtime |
| **Rolling update** | Reemplaza instancias de a una | Sin downtime | Mezcla versiones durante rollout |
| **Blue-green** | Dos entornos; switch de tráfico atómico | Rollback instantáneo | 2× infraestructura durante switch |
| **Canary** | % creciente de tráfico al nuevo | Blast radius controlado | Más complejo de operar |
| **Shadow** | Nuevo recibe mismo tráfico pero no sirve respuesta | Riesgo cero para usuario | 2× costo de inferencia |
| **Feature flag** | Decisión por request/usuario desde runtime | Rollback instantáneo sin redeploy | Lógica dispersa en código |

Para LLMs/modelos pesados, el patrón recomendado es **shadow → canary → progressive rollout**, con rollback instantáneo via feature flag o alias del model registry.

### 6. Verification tras deploy

| Check | Qué valida |
|---|---|
| **Health check** | `/healthz` responde 200 en < 1s |
| **Smoke test** | Un request end-to-end básico funciona |
| **Golden requests** | 50-200 requests conocidos → outputs esperados |
| **Canary analysis** | Error rate / latencia / business metric del canary vs stable, con significancia estadística |
| **Shadow comparison** | Delta de calidad entre shadow y stable sobre tráfico real |

### 7. Auto-rollback

Reglas que disparan rollback automático durante el rollout:

```yaml
rollback_rules:
  - metric: http_5xx_rate
    threshold: 0.02           # > 2% errores
    window: 2m
  - metric: p95_latency_ms
    threshold: 3000           # > 3s
    window: 5m
  - metric: llm_judge_score
    threshold_delta: -0.05    # cae 5pp vs stable
    window: 10m
  - metric: cost_per_req_usd
    threshold_delta: 0.5      # +50% en costo
    window: 5m
```

Herramientas: **Flagger** (Kubernetes-native con Istio/Linkerd), **Argo Rollouts** (análisis con métricas de Prometheus), **AWS CodeDeploy** (CloudWatch alarms), **Spinnaker**.

### 8. Aliases para rollback instantáneo

En vez de "deploy la versión X", despliega **aliases**: `production-stable`, `production-candidate`. El router mira el alias:

- 95% del tráfico → `production-stable`
- 5% → `production-candidate`

Promoción = cambiar el apuntador. Rollback = revertir el apuntador. Un comando, segundos.

### 9. Audit trail

Toda transición (`register`, `promote`, `approve`, `rollback`) queda loggeada con:

- `who` (user o service account)
- `when` (timestamp)
- `why` (link a PR / ticket)
- `what` (versión origen → destino)
- `metrics_at_time_of_decision`

Obligatorio en finanzas (SOX), salud (HIPAA), seguros, y recomendable en todo lo demás.

## Ejemplo con código

Pipeline completo en GitHub Actions con model registry (MLflow), promoción a staging, validación con Promptfoo y rollout canario con Flagger.

```yaml
# .github/workflows/deploy-llm.yml
name: Deploy LLM service

on:
  workflow_dispatch:
    inputs:
      model_version:
        required: true
      target_env:
        type: choice
        options: [staging, production]
  push:
    tags: ["v*.*.*"]

env:
  REGISTRY: ghcr.io/myorg/support-agent

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    outputs:
      image: ${{ steps.meta.outputs.tags }}
    steps:
      - uses: actions/checkout@v4

      - id: meta
        run: echo "tags=${REGISTRY}:${GITHUB_SHA}" >> $GITHUB_OUTPUT

      - uses: docker/setup-buildx-action@v3
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          build-args: |
            MODEL_VERSION=${{ inputs.model_version }}

  deploy-staging:
    needs: build-and-push
    environment: staging
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy a staging
        run: |
          helm upgrade --install support-agent ./charts/agent \
            --namespace staging \
            --set image=${{ needs.build-and-push.outputs.image }} \
            --set modelVersion=${{ inputs.model_version }} \
            --wait --timeout 5m

      - name: Smoke tests
        run: |
          curl -fsS https://staging.api.ex/healthz
          pytest tests/smoke --base-url https://staging.api.ex

      - name: Eval en staging
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: promptfoo eval -c evals/promptfoo.staging.yaml --fail-on-threshold

      - name: Marcar en MLflow
        run: |
          mlflow models transition-stage \
            --name support-agent \
            --version ${{ inputs.model_version }} \
            --stage Staging

  approve-prod:
    needs: deploy-staging
    environment: production   # required reviewers
    runs-on: ubuntu-latest
    steps:
      - run: echo "Aprobacion recibida"

  deploy-prod-canary:
    needs: approve-prod
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Aplicar Canary (Flagger analiza)
        run: |
          kubectl apply -f k8s/canary.yaml -n production
          kubectl annotate deployment support-agent \
            flagger.app/promote-image=${{ needs.build-and-push.outputs.image }} \
            -n production
          # Flagger ejecuta pasos: 10% -> 25% -> 50% -> 100%
          # con análisis de metricas; si falla, auto-rollback.

      - name: Esperar resultado de Flagger
        run: |
          kubectl wait --for=condition=Promoted canary/support-agent \
            -n production --timeout=30m

      - name: Promover en MLflow
        run: |
          mlflow models transition-stage \
            --name support-agent \
            --version ${{ inputs.model_version }} \
            --stage Production \
            --archive-existing-versions

      - name: Notificar Slack
        if: always()
        uses: slackapi/slack-github-action@v1.26.0
        with:
          payload: |
            {"text": "Deploy support-agent v${{ inputs.model_version }}: ${{ job.status }}"}
```

Canary de Flagger:

```yaml
# k8s/canary.yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: support-agent
  namespace: production
spec:
  targetRef: { apiVersion: apps/v1, kind: Deployment, name: support-agent }
  service:
    port: 8080
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
        interval: 1m
      - name: llm-judge-score
        templateRef: { name: llm-judge }   # custom metric via Prometheus
        thresholdRange: { min: 0.80 }
        interval: 5m
    webhooks:
      - name: smoke-test
        url: http://flagger-loadtester.test/
        timeout: 30s
        metadata:
          cmd: "hey -z 1m -q 10 -c 2 https://support-canary/healthz"
```

Script de promoción con audit trail:

```python
# scripts/promote.py
"""Promote via MLflow con audit trail en Postgres."""
import mlflow, os, json, datetime, psycopg
from mlflow.tracking import MlflowClient

client = MlflowClient()

def promote(name: str, version: str, stage: str, approver: str, ticket: str):
    mv = client.get_model_version(name, version)
    metrics = client.get_run(mv.run_id).data.metrics

    # Gate: accuracy minima
    if stage == "Production" and metrics.get("accuracy", 0) < 0.80:
        raise SystemExit(f"Accuracy {metrics.get('accuracy')} < 0.80, no promueve")

    client.transition_model_version_stage(
        name=name, version=version, stage=stage,
        archive_existing_versions=(stage == "Production"),
    )

    with psycopg.connect(os.environ["AUDIT_DSN"]) as con:
        con.execute(
            "INSERT INTO model_audit(model, version, from_stage, to_stage, "
            "approver, ticket, metrics, ts) VALUES (%s,%s,%s,%s,%s,%s,%s,%s)",
            (name, version, mv.current_stage, stage, approver, ticket,
             json.dumps(metrics), datetime.datetime.utcnow()),
        )
    print(f"OK: {name} v{version} -> {stage}")

if __name__ == "__main__":
    import sys
    promote(*sys.argv[1:])
```

Rollback instantáneo via alias:

```python
# scripts/rollback.py
from mlflow.tracking import MlflowClient
client = MlflowClient()
latest_stable = [v for v in client.search_model_versions("name='support-agent'")
                 if v.tags.get("last_stable") == "true"][0]
client.set_registered_model_alias("support-agent", "production", latest_stable.version)
print(f"Alias production -> v{latest_stable.version}")
```

## Errores comunes

- **No practicar el rollback.** La primera vez que lo necesitas, descubres que `kubectl rollout undo` no funciona porque el deployment fue reemplazado por un script bash. Haz drills mensuales.
- **Un solo environment (dev → prod).** Sin staging, los integration tests corren contra producción. Añade staging con infra production-like.
- **No versionar prompts junto al modelo.** El modelo rollbackea pero el prompt sigue siendo el nuevo → bug mitad roto, mitad arreglado. El registry debe incluir hash de prompt.
- **Canary demasiado corto.** 5 minutos no permiten detectar regresiones intermitentes. Mínimo 15-30 min para tráfico medio.
- **Métricas del canary sin significancia.** Con tráfico bajo, un pico aislado de 500 ms dispara rollback espurio. Usa ventanas y p95/p99, no instantáneos.
- **Aprobaciones humanas sin SLA.** PR espera 2 semanas por aprobación y el contexto se pierde. Define SLA de aprobación y expiración.
- **Deploy mezcla training + serving code.** Un cambio pequeño en el formateador obliga a reentrenar el modelo. Separa pipelines y containers.
- **Guardar modelos en Git.** Repos de 50 GB imposibles de clonar. Modelos en object storage versionado (S3, GCS); solo URI/metadata en Git.
- **No tener alias en producción.** Rollback = redeployar container → minutos de downtime. Usa alias en el model registry o routing layer.
- **Monitoreo que no mide calidad del output.** Error rate y latencia OK, pero el modelo responde en inglés a usuarios en español. Agrega métricas de calidad (LLM-as-judge, feedback) al canary analysis.
- **No notificar al equipo.** Deploy silencioso durante un incidente desperdicia tiempo de diagnóstico. Integra Slack/Teams.
- **No desafiar la auditoría.** Audit trail "best effort" en logs rotados. Guarda en storage inmutable (append-only DB) por N años según regulación.

## Resumen

- Un **deployment pipeline** moderno es una cadena de stages: build → test → package → deploy-staging → validate → deploy-prod → validate, con auto-abort en cualquier stage.
- El **model registry** (MLflow, W&B, SageMaker, Vertex) centraliza metadatos, lineage, aprobaciones y estados (`dev → staging → production → archived`).
- **Promotion workflows** combinan **gates automáticos** (eval, data validation) con **aprobación humana** para transiciones críticas.
- Estrategias de despliegue: **shadow → canary → progressive rollout** es el patrón recomendado para LLMs; **aliases** permiten rollback instantáneo.
- **Verificación post-deploy** combina health checks, smoke tests, golden requests y canary analysis con significancia estadística.
- **Auto-rollback** por reglas de métricas (error rate, latencia, calidad, costo) con herramientas como **Flagger**, **Argo Rollouts**, **Spinnaker**.
- **Audit trail** inmutable es requisito en industrias reguladas; incluye quién, cuándo, por qué y qué métricas había al momento.
- Practica el rollback regularmente: untested rollback = rollback que fallará cuando más lo necesites.
