# <!-- NOMBRE --> — CI/CD Engineering Portfolio

> Portafolio técnico tras completar la ci-cd-engineering-academy (17 cursos + capstone).  
> Última actualización: `<YYYY-MM-DD>`.

## TL;DR

Soy ingeniero/a CI/CD con foco en `<área>` (p. ej. GitOps + observabilidad + supply-chain security). Este repo contiene **artefactos reales** — pipelines, manifests, dashboards, ADRs, postmortems — de un programa de 17 cursos y un capstone de 15 etapas.

Para hiring managers, 10 min:

1. Lee la sección **"Capstone en una página"** abajo.
2. Mira `capstone/architecture/overview.png`.
3. Elige 1 ADR de `ADRs/` que te interese.
4. Elige 1 pipeline de `capstone/pipelines/`.
5. (Opcional) lee un postmortem de `capstone/incident-writeups/`.

Para una entrevista técnica, 60 min: te recomiendo preparar preguntas sobre uno de los ADRs y uno de los incidentes.

---

## Capstone en una página

- **Problema**: `<descripción corta y neutra, 2 líneas>`.
- **Stack**:
  - Lenguaje app: `<Python / FastAPI + PostgreSQL>`.
  - CI: `<GitHub Actions | GitLab CI | Jenkins>` (justificación en `ADRs/0004-ci-choice.md`).
  - Container: Docker (multi-stage, non-root, distroless donde aplica).
  - Orquestador: `<EKS | GKE | AKS | kind local>` (`ADRs/0005-orchestrator.md`).
  - GitOps: `<Argo CD | Flux>` (`ADRs/0002-gitops-tool.md`).
  - Progressive delivery: Argo Rollouts canary + análisis Prometheus.
  - Observabilidad: Prometheus + Grafana + OpenTelemetry Collector + `<Loki | otro>`.
  - Supply chain: Trivy (SAST/SCA) + Syft (SBOM) + cosign (firma) + Kyverno (admisión).
  - Secretos: External Secrets Operator contra `<AWS SM | GCP SM | Azure KV>`.
  - IaC: Terraform + remote backend con locking.
- **DORA actuales** (ver `metrics/dora.md` para método):
  - Deployment frequency: `<x/día>`
  - Lead time for changes: `<x min/h>`
  - Change failure rate: `<x %>`
  - MTTR: `<x min>`
- **Lo que me enorgullece**: `<2-3 bullets concretos, p. ej. "política Kyverno que bloqueó una imagen no firmada en demo y pude probar el rechazo">`.
- **Lo que **no** terminé y por qué**: `<1-2 bullets honestos>`.

---

## Cobertura por curso

| Curso | Estado | Artefactos clave |
|-------|:------:|------------------|
| git-and-github | ✅ | `courses/git-and-github/` — ADR branching + firma commits |
| github-actions | ✅ | workflow reutilizable + OIDC a cloud |
| gitlab-cicd | ⚠️ parcial | pipeline parent/child; sin review app en vivo |
| jenkins | ✅ | Jenkinsfile + shared lib |
| docker | ✅ | multi-stage + SBOM + cosign verificada |
| kubernetes | ✅ | manifests + NetworkPolicy + debug walkthrough |
| helm | ✅ | chart con values schema |
| argocd-gitops | ✅ | Application + Project RBAC + Rollout canary |
| terraform | ✅ | módulo + backend con locking + runbook state lock |
| ansible | ⚠️ parcial | role sin Molecule aún |
| aws | ✅ | diagrama + OIDC + runbook rotación |
| gcp | — | — |
| azure | — | — |
| prometheus-grafana | ✅ | SLO + burn-rate multi-window + dashboard |
| opentelemetry | ✅ | app instrumentada + collector + traza cross-service |
| devsecops | ✅ | SAST+SCA+secret scan + política de admisión + SBOM |
| platform-engineering | ✅ | Backstage catalog + scorecard + DORA |

Estados: ✅ cumple mínimos, ⚠️ parcial (ver `STATUS.md`), — no cursado todavía.

---

## ADRs destacados

- [`ADRs/0002-gitops-tool.md`](ADRs/0002-gitops-tool.md) — Argo CD vs Flux
- [`ADRs/0003-progressive-delivery-strategy.md`](ADRs/0003-progressive-delivery-strategy.md) — canary vs blue-green
- [`ADRs/0006-secrets-strategy.md`](ADRs/0006-secrets-strategy.md) — ESO vs SOPS vs Sealed Secrets
- [`ADRs/0008-observability-stack.md`](ADRs/0008-observability-stack.md) — por qué Prom + OTel y no SaaS

Lista completa: [`ADRs/README.md`](ADRs/README.md).

---

## Incidentes y runbooks

- [`capstone/incident-writeups/2026-xx-canary-abort.md`](capstone/incident-writeups/2026-xx-canary-abort.md) — real, análisis de 5 whys.
- [`capstone/incident-writeups/sim-leaked-cosign-key.md`](capstone/incident-writeups/sim-leaked-cosign-key.md) — simulado.
- [`capstone/runbooks/`](capstone/runbooks/) — on-call runbooks ejecutables.

---

## Cómo reproducir (local)

Requisitos: `docker`, `kind`, `kubectl`, `helm`, `argocd` CLI, `terraform`, `cosign`.

```bash
make bootstrap        # levanta kind + argocd + prometheus + grafana
make deploy-app       # despliega la app vía Argo CD
make demo-canary      # ejecuta canary + induce falla + rollback
make verify-signature # cosign verify de la imagen publicada
make teardown
```

Ver [`capstone/README.md`](capstone/README.md) para detalle.

---

## Dashboard de progreso de la academia

Snapshot en [`metrics/dashboard.md`](metrics/dashboard.md), generado con el script [`compute_dashboard.py`](https://github.com/<org>/ci-cd-engineering-academy/tree/main/evaluation/progress-dashboard) de la academia.

---

## Defensa de capstone

- Slides: [`defense/slides.pdf`](defense/slides.pdf)
- Script de demo: [`defense/demo-script.md`](defense/demo-script.md)
- Rúbrica firmada por el panel: [`defense/rubric-signed.md`](defense/rubric-signed.md)

---

## Contacto

- GitHub: `<@username>`
- LinkedIn: `<url>`
- Email: `<email>`

Para una entrevista técnica, propongo:
- 30 min deep-dive sobre un ADR a elección.
- 30 min live-coding / debugging sobre un manifest a elección (prefiero no filtrar categorías de antemano).
