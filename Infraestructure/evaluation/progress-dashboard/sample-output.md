# Dashboard de progreso — ci-cd-engineering-academy

_Generado: 2026-10-20 15:18 UTC_  
_Repo: `/Users/efloresp06/Desktop/Courses/Python/Notas/Infraestructure/ci-cd-engineering-academy`_

## Resumen global

- Actividades totales: **471**
- Completadas: **0** (0.0%)
- En curso: 0
- Bloqueadas: 0
- Pendientes: 471
- Minutos estimados totales: 32,810
- Minutos estimados completados: 0

### Por curso

| Curso | Total | Completadas | En curso | Bloqueadas | Pendientes | % |
|---|---:|---:|---:|---:|---:|---|
| git-and-github | 31 | 0 | 0 | 0 | 31 | `--------------------`   0.0% |
| github-actions | 31 | 0 | 0 | 0 | 31 | `--------------------`   0.0% |
| gitlab-cicd | 20 | 0 | 0 | 0 | 20 | `--------------------`   0.0% |
| jenkins | 16 | 0 | 0 | 0 | 16 | `--------------------`   0.0% |
| docker | 28 | 0 | 0 | 0 | 28 | `--------------------`   0.0% |
| kubernetes | 36 | 0 | 0 | 0 | 36 | `--------------------`   0.0% |
| helm | 20 | 0 | 0 | 0 | 20 | `--------------------`   0.0% |
| argocd-gitops | 26 | 0 | 0 | 0 | 26 | `--------------------`   0.0% |
| terraform | 28 | 0 | 0 | 0 | 28 | `--------------------`   0.0% |
| ansible | 20 | 0 | 0 | 0 | 20 | `--------------------`   0.0% |
| aws | 35 | 0 | 0 | 0 | 35 | `--------------------`   0.0% |
| gcp | 21 | 0 | 0 | 0 | 21 | `--------------------`   0.0% |
| azure | 20 | 0 | 0 | 0 | 20 | `--------------------`   0.0% |
| prometheus-grafana | 30 | 0 | 0 | 0 | 30 | `--------------------`   0.0% |
| opentelemetry | 28 | 0 | 0 | 0 | 28 | `--------------------`   0.0% |
| devsecops | 28 | 0 | 0 | 0 | 28 | `--------------------`   0.0% |
| platform-engineering | 24 | 0 | 0 | 0 | 24 | `--------------------`   0.0% |

### Por nivel

| Nivel | Total | Completadas | En curso | Bloqueadas | Pendientes | % |
|---|---:|---:|---:|---:|---:|---|
| advanced | 180 | 0 | 0 | 0 | 180 | `--------------------`   0.0% |
| beginner | 113 | 0 | 0 | 0 | 113 | `--------------------`   0.0% |
| intermediate | 178 | 0 | 0 | 0 | 178 | `--------------------`   0.0% |

### Por dimension

| Dimension | Total | Completadas | En curso | Bloqueadas | Pendientes | % |
|---|---:|---:|---:|---:|---:|---|
| arquitectonica | 58 | 0 | 0 | 0 | 58 | `--------------------`   0.0% |
| conceptual | 1 | 0 | 0 | 0 | 1 | `--------------------`   0.0% |
| operativa | 412 | 0 | 0 | 0 | 412 | `--------------------`   0.0% |

### Capstone — por etapa

| Etapa | Total | Completadas | En curso | Bloqueadas | Pendientes | % |
|---|---:|---:|---:|---:|---:|---|
| 01-app-tests-precommit | 3 | 0 | 0 | 0 | 3 | `--------------------`   0.0% |
| 02-versioning-releases | 1 | 0 | 0 | 0 | 1 | `--------------------`   0.0% |
| 03-ci-lint-test-sast-sca-secret-scan | 1 | 0 | 0 | 0 | 1 | `--------------------`   0.0% |
| 04-dockerization-compose-dev | 1 | 0 | 0 | 0 | 1 | `--------------------`   0.0% |
| 05-pipeline-build-scan-sbom-sign | 1 | 0 | 0 | 0 | 1 | `--------------------`   0.0% |
| 06-terraform-local-to-cloud-minimum | 2 | 0 | 0 | 0 | 2 | `--------------------`   0.0% |
| 07-cloud-deploy-ecs-cloudrun-aca | 1 | 0 | 0 | 0 | 1 | `--------------------`   0.0% |
| 08-kubernetes-kind-to-eks-gke-aks | 3 | 0 | 0 | 0 | 3 | `--------------------`   0.0% |
| 09-helm-chart-argocd | 2 | 0 | 0 | 0 | 2 | `--------------------`   0.0% |
| 10-gitops-multi-env-argo-rollouts | 1 | 0 | 0 | 0 | 1 | `--------------------`   0.0% |
| 11-observability-prom-grafana-otel-loki-slo | 1 | 0 | 0 | 0 | 1 | `--------------------`   0.0% |
| 12-devsecops-eso-kyverno-falco-pac | 3 | 0 | 0 | 0 | 3 | `--------------------`   0.0% |
| 13-platform-eng-backstage-scorecard-dora | 3 | 0 | 0 | 0 | 3 | `--------------------`   0.0% |
| 14-load-testing-chaos-dr-plan | 3 | 0 | 0 | 0 | 3 | `--------------------`   0.0% |
| 15-postmortem-simulated-runbook | 3 | 0 | 0 | 0 | 3 | `--------------------`   0.0% |

## DORA-style sobre el trabajo del estudiante

Aun no hay actividades con `status: completed`.

**Formulas que se calcularan cuando haya datos:**
- *Lead time*: diferencia entre el primer y el ultimo commit
  que toca cada `activity.yaml` completado.
- *Throughput*: numero de actividades completadas por semana ISO.
- *Bottlenecks*: cursos con mayor lead time promedio.

---

## Notas

- La *dimension* se infiere de `type` segun `TYPE_TO_DIMENSION`
  en `compute_dashboard.py`; ajustar ahi si cambia el criterio.
- Estados reconocidos: `not-started`, `in-progress`, `blocked`,
  `completed`. Cualquier otro valor se normaliza a `not-started`.
- El parser YAML es minimalista (solo escalares y listas raiz).
  Si se introducen nuevos campos anidados obligatorios, actualizar.
