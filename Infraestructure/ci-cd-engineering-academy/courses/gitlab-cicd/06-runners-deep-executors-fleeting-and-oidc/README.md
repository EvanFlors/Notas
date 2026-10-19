# gl-06 — Runners en profundidad: ejecutores, Fleeting y OIDC

## Identificación

- **ID:** `gl-06-runners-deep-executors-fleeting-and-oidc`
- **Curso:** `gitlab-cicd`
- **Nivel:** intermediate
- **Duración estimada:** 4 h
- **Prerrequisitos:** `gl-02` (anatomía de `.gitlab-ci.yml` y runners), `gl-03` (variables, secretos, ID Tokens).

## Objetivo

Operar runners propios con criterio y conectar los pipelines a la nube sin claves de larga duración. Al terminar deberías poder: elegir el ejecutor correcto (`shell`, `docker`, `kubernetes`, Fleeting), justificar DinD vs Kaniko/BuildKit, montar un runner Kubernetes con el chart oficial, y federar GitLab con AWS vía ID Tokens (OIDC) para desplegar sin `AWS_ACCESS_KEY_ID`.

## Alcance

Este módulo cubre:

- **Ejecutores de GitLab Runner**: `shell`, `docker`, `docker-machine` (deprecado → Fleeting), `kubernetes`, `virtualbox`, `ssh`, `custom`. Trade-offs por carga.
- **Docker-in-Docker (DinD)**: patrón `services: docker:dind` + `DOCKER_TLS_CERTDIR`, y alternativas sin daemon (**Kaniko**, **BuildKit**).
- **Runner en Kubernetes** mediante el chart oficial de GitLab (`gitlab/gitlab-runner`): registro con *authentication token*, pods efímeros por job, configuración `[runners.kubernetes]`.
- **Fleeting autoscaler**: sucesor de `docker-machine`, plugins para AWS/GCP/Azure, pool de VMs on-demand.
- **ID Tokens / OIDC** desde GitLab a AWS (`id_tokens:`, `aud:`, `sub:`), *trust policy* con `StringLike` sobre `project_path:group/repo:ref_type:branch:ref:main`.
- Patrón de **pinning por `project_path`, `ref`, `environment`** en el `sub` claim para evitar que cualquier proyecto del grupo asuma el rol.
- Migración desde *registration tokens* (deprecados) a *authentication tokens* y comandos modernos (`gitlab-runner register --token`).

Lo que **no** cubre (se verá después):

- Scanners nativos y Container Registry → `gl-08`.
- Environments, Review Apps y approvals de prod → `gl-07`.
- Migración GHA↔GitLab y gobernanza del catálogo → `gl-10`.

Este módulo es **mayoritariamente conceptual + validación estructural**. **No** se levanta un cluster real ni se crea un IAM role real: los artefactos (TOML/YAML del runner, `trust-policy.json`, `.gitlab-ci.yml`) se validan **estructuralmente** con `bash`, `jq` y `python3` (`yaml`, `tomllib`).

## Materiales

- **`theory/lesson.md`** — lección profunda (12 secciones) sobre ejecutores, DinD, Fleeting y federación OIDC.
- **`examples/`** — tres ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-k8s-executor-chart/` — `values.yaml` anotado del chart `gitlab/gitlab-runner` + `[runners.kubernetes]` relevante en `config.toml`.
  - `02-fleeting-aws-asg/` — esqueleto de `config.toml` con `[runners.autoscaler]` + plugin `fleeting-plugin-aws`, política mínima IAM del host runner.
  - `03-oidc-id-token-to-aws/` — walkthrough end-to-end: provider OIDC, trust policy, `id_tokens:` en el job, `aws sts assume-role-with-web-identity`.
- **`activities/`** — dos actividades **independientes** entre sí:
  - `01-runner-k8s-and-first-job/` — guided-lab: escribir `values.yaml` del chart, `config.toml` del runner K8s y un `.gitlab-ci.yml` que use `tags: [k8s]`; validar estructura.
  - `02-federate-with-aws-oidc/` — walkthrough: *trust policy* para GitLab como IdP OIDC, `.gitlab-ci.yml` con `id_tokens:` + `aws sts assume-role-with-web-identity`, `README-INTENT.md` justificando pinning por `project_path` y `ref`.
- **`resources/links.md`** — docs oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué DinD con `privileged: true` es un riesgo y cómo lo mitigan Kaniko/BuildKit; distinguir *registration token* (legacy) de *authentication token*. |
| Operativa (sin infra) | Escribir el `values.yaml` de `gitlab/gitlab-runner` y la sección `[runners.kubernetes]` de `config.toml`; redactar una *trust policy* con `StringLike` sobre `sub`. |
| Arquitectónica | Elegir ejecutor por workload (CPU bursty, build de imágenes, tests legacy en VM); diseñar la federación OIDC pinada a `project_path` + `ref` + `environment`. |

## Criterios de evaluación

- Dado un workload (ej.: "build Docker image rootless", "pytest matrix 3x3", "test de GUI con Chrome"), elegir ejecutor y justificar.
- Leer una *trust policy* y detectar si el `sub` está lo bastante pinado (o si permite a cualquier proyecto del grupo asumir el rol).
- Enumerar al menos 3 acciones destructivas que DinD con `privileged: true` habilita en el host y por qué.
- Entregar las dos actividades con sus validadores estructurales en verde.

## Entregables

- **Runner K8s** descrito en `values.yaml` + `config.toml` + `.gitlab-ci.yml` consumidor (actividad 01).
- **Federación OIDC a AWS**: `trust-policy.json` + `.gitlab-ci.yml` con `id_tokens:` + `README-INTENT.md` (actividad 02).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto, YAML, TOML y JSON. No se requiere cluster ni cuenta AWS activa. Si en una fase posterior decides provisionar lo diseñado:

- **GitLab Runner (chart)**: gratis; paga la infra del cluster (nodos EKS/GKE/AKS).
- **Fleeting + AWS**: paga las VMs del ASG según uso (típicamente EC2 Spot para abaratar).
- **OIDC provider** en AWS: gratis.

## Siguiente módulo

→ `gl-07-environments-deployments-and-review-apps` — environments, Review Apps por MR y approvals de prod sobre esta base de runners.
