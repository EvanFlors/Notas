# gl-07 — Environments, Deployments y Review Apps

## Identificacion

- **ID:** `gl-07-environments-deployments-and-review-apps`
- **Curso:** `gitlab-cicd`
- **Nivel:** advanced
- **Duracion estimada:** 4 h
- **Prerrequisitos:** `gl-04-rules-workflow-needs-dag-parallel-matrix`, curso `github-actions` (modelo mental de environments/deployments).

## Objetivo

Modelar deployments en GitLab usando `environment:` como objeto de primera clase, aplicar **protected environments con approval rules** para producciones serias, y entender **Review Apps** como preview-per-MR nativo. Al terminar, podras diseñar politicas de environments (dev/stg/prod + review) sin confundir un `environment:` con una variable, ni un approval rule con un `rules:` del pipeline.

## Alcance

Este modulo cubre:

- **`environment:` por job** — keywords `name`, `url`, `action` (`start|stop|prepare|verify|access`), `auto_stop_in`, `on_stop`.
- **Deployments** como objeto de dominio: historial, rollback via UI, API `deployments` para automatizacion.
- **Protected environments** y **deployment approvals** (approval rules multi-aprobador, incluyendo requerir aprobadores por grupo/role).
- **Review Apps**: environment efimero por Merge Request, nombrado por `$CI_MERGE_REQUEST_IID`, destruido por `on_stop:` cuando se cierra el MR.
- **Patrones blue/green y canary** en GitLab (manual con conditional jobs + estrategia progressive).
- **GitLab Agent for Kubernetes** (`kas`): sucesor del "Kubernetes integration" clasico; expone CI/CD → cluster sin publicar el `kube-apiserver`. Modo **GitOps** (manifest tracking desde el repo) y comparacion con Argo CD / Flux.
- Mapping conceptual con **GitHub Actions Environments + Deployments + PR previews**.

Lo que **no** cubre (se vera despues):

- Compliance pipelines y governance de approvals a escala organizacional → `gl-09`.
- Scanners de seguridad en Review Apps (DAST sobre el environment efimero) → `gl-08`.
- OIDC desde runners del Agent for Kubernetes a cloud → `gl-06`.

Este modulo es **mayoritariamente conceptual + diseño + validacion de YAML**. **No** se despliega nada en un cluster real. Las dos actividades son archivos YAML + ADR validados estructuralmente; el unico tooling es `bash`, `python3` (con `pyyaml`) y un editor Markdown.

## Materiales

- **`theory/lesson.md`** — leccion con 10 secciones (modelo, keywords, Review Apps, protected environments, Agent for K8s, blue/green/canary, GitOps mode, operacion).
- **`examples/`** — demostrativos (lectura y analisis, no ejecucion):
  - `01-environment-with-url/` — job con `environment: { name: staging, url: ... }` y como aparece en la UI "Deployments".
  - `02-review-apps-on-mr/` — pipeline con job `review` + `review_stop` y plantilla de URL `$CI_MERGE_REQUEST_IID`.
  - `03-protected-env-approval/` — configuracion de protected environment con approval rule y comportamiento esperado al desplegar.
- **`activities/`** — dos actividades **independientes**:
  - `01-review-apps-end-to-end/` — diseñar un `.gitlab-ci.yml` con Review Apps por MR + ADR `ADR-REVIEW-APPS.md`.
  - `02-approval-rule-prod/` — escribir la configuracion YAML de un protected environment `production` con approval rules + ADR `ADR-APPROVAL-PROD.md`.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimension | Al terminar deberias |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre `environment:` y una variable; por que un deployment es un objeto (no un side effect del script); por que Review Apps es nativo en GitLab y en GHA es un patron. |
| Operativa (sin infra) | Escribir un `.gitlab-ci.yml` con Review Apps + `on_stop`; configurar un protected environment con approval rules; diseñar `auto_stop_in` razonable. |
| Arquitectonica | Decidir cuando usar GitLab Agent for Kubernetes vs Argo CD/Flux; definir politica de environments (dev/stg/prod + review + hotfix); mapear GHA Environments ↔ GitLab Environments. |

## Criterios de evaluacion

- Dado un `.gitlab-ci.yml`, identificar que jobs crean deployments y a que environment.
- Leer un protected environment YAML y explicar cuantos approvers requiere y de que grupo.
- Justificar por que un Review App necesita `on_stop:` y como se dispara.
- Nombrar las 5 `action:` validas (`start|stop|prepare|verify|access`) y cuando usar cada una.
- Entregar las dos actividades con sus validadores estructurales en verde.

## Entregables

- **`.gitlab-ci.yml`** con Review Apps por MR + ADR `ADR-REVIEW-APPS.md` (actividad `01`).
- **`protected-environment.yaml`** + **`approval-rules.yaml`** + ADR `ADR-APPROVAL-PROD.md` (actividad `02`).

## Costos

**Ninguno.** Todo el modulo se desarrolla localmente contra archivos de texto, YAML y Markdown. No se requiere proyecto GitLab activo ni cluster Kubernetes. Si en una fase posterior decides materializarlo:

- **GitLab SaaS Free**: Review Apps y environments basicos estan disponibles; approval rules multi-aprobador requieren Premium/Ultimate.
- **GitLab Agent for Kubernetes**: el agente es open-source; corre en tu cluster y tu pagas por el cluster.
- **Minutos de runners**: cada Review App consume minutos de runner para crearse y destruirse.

## Siguiente modulo

→ `gl-08-security-scanners-registry-and-supply-chain` — scanners nativos (SAST/DAST/SCA/Container/IaC/Fuzz), Container Registry y supply chain (SBOM + cosign con ID Token).
