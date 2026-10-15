# Curso: GitHub Actions

Roadmap especializado #2. CI/CD nativo de GitHub, principal plataforma de automatización del programa.

## 1. Introducción

### Qué es

**GitHub Actions** (GHA) es una plataforma de automatización basada en **eventos** integrada en GitHub. Dado un repositorio, cualquier evento (push, pull_request, release, schedule, dispatch manual, llamada desde otro workflow, webhook externo…) puede disparar uno o más **workflows**: archivos YAML en `.github/workflows/` que describen uno o más **jobs**, cada uno compuesto por **steps** que ejecutan comandos de shell o invocan **actions** (unidades reutilizables empaquetadas).

Los jobs corren sobre **runners**: máquinas virtuales efímeras provistas por GitHub (`ubuntu-latest`, `windows-latest`, `macos-latest`, variantes ARM y "larger runners") o **self-hosted** administradas por el usuario (incluyendo autoescaladas en Kubernetes vía **Actions Runner Controller** / ARC).

### Historia (síntesis)

- **2018** — GitHub anuncia Actions en forma de beta orientada a contenedores.
- **2019** — Lanzamiento general como motor de CI/CD con sintaxis YAML y marketplace.
- **2020–2022** — OIDC a cloud providers, reusable workflows, environments, concurrency, composite actions, required reviewers, CODEOWNERS para workflows.
- **2023+** — Larger runners, ARM runners, build provenance / attestations basadas en Sigstore, deployment protection rules, merge queues integradas.

### Problemas que resuelve

- **Pipeline as Code** versionado junto al código fuente.
- **CI** (lint/test/build por commit y PR) y **CD** (deploy, release) desde la misma plataforma donde vive el código.
- **Automatización reactiva** a eventos del repo (etiquetar PRs, actualizar deps, publicar artefactos, operar infraestructura con GitOps).
- **Reutilización** de lógica común vía actions del marketplace, composite actions y reusable workflows.

### Casos de uso

- CI de aplicaciones (lint, test, build, análisis estático, scanning).
- Publicación de artefactos (contenedores en GHCR, paquetes PyPI/npm, releases).
- Despliegues (a cloud vía OIDC; a Kubernetes vía Argo CD/Flux o directo).
- Automatización de repo (triage de issues, PRs, releases, docs).
- Infraestructura (Terraform plan/apply, policy checks).

### Arquitectura general

```
┌─────────────────────────────────────────────────┐
│ GitHub (plano de control)                       │
│  - API, Events, Runs, Logs                      │
│  - Secrets / Variables / Environments           │
│  - Workflow scheduler                           │
└─────────────────────────────────────────────────┘
                 │ encola runs
                 ▼
┌─────────────────────────────────────────────────┐
│ Runners (plano de ejecución)                    │
│   - GitHub-hosted (VMs efímeras)                │
│   - Self-hosted / ARC en Kubernetes             │
│   - Larger runners (más CPU/RAM, ARM, GPU)      │
└─────────────────────────────────────────────────┘
                 │ ejecuta
                 ▼
┌─────────────────────────────────────────────────┐
│ Workflow run                                    │
│   jobs → steps → actions / shell commands       │
│   context: github, env, inputs, secrets, needs  │
└─────────────────────────────────────────────────┘
```

Un **workflow** es un archivo YAML con `on:` (eventos), `jobs:` (uno o más), `permissions:` (del `GITHUB_TOKEN`) y `concurrency:`. Un **job** corre en un único runner, con sus steps secuenciales, y puede declarar `needs:` para dependencia a otros jobs, `strategy:` para matrices y `environment:` para gates de deployment. Un **action** puede ser *JavaScript*, *Docker container* o *composite* (compone otros steps).

### Alternativas

- **GitLab CI/CD**: muy comparable; integración más estrecha si el repo vive en GitLab; runners siempre self-hosted salvo SaaS.
- **Jenkins**: motor general, mayor flexibilidad plug-in, UX dura, auto-hospedado.
- **CircleCI, Buildkite, Drone, Tekton, Argo Workflows**: alternativas con enfoques distintos (contenedores nativos, orquestación cloud-native).

### Ventajas / limitaciones

**Ventajas**: cero fricción si ya usas GitHub; marketplace amplio; OIDC a clouds sin secretos de larga vida; reusable workflows a nivel organización; attestations SLSA integradas.

**Limitaciones / riesgos**:
- **Seguridad de la supply chain** del propio pipeline: una action de tercero sin pin a SHA puede ejecutar código arbitrario con los permisos del `GITHUB_TOKEN`.
- **Costo**: minutos privados tienen precio no trivial a volumen; larger runners aún más. ARC + self-hosted a menudo gana en coste pero añade operación.
- **Lock-in de sintaxis** (aunque la lógica suele ser portable).
- Hay anti-patrones comunes (secretos en logs, `pull_request_target` mal usado) que son fallas de seguridad reales.

### Relación con el programa

- Es el motor de todos los pipelines del capstone (D5).
- Se integra con **Docker** (D6) para build/publish de imágenes.
- Se integra con **Terraform/AWS** (D7) vía OIDC.
- Se integra con **Argo CD** (D8) escribiendo manifests en un repo de infra.
- Es el punto de aplicación de la mayoría de controles de **DevSecOps** (D9).

## 2. Prerrequisitos

| Tipo | Contenido |
|------|-----------|
| Obligatorios | Curso **git-and-github** completo (al menos `gh-01` … `gh-07`, idealmente `gh-12`). T-1.1, T-1.4 (testing). |
| Recomendados | T-2.6 (Bash), T-5.1 (definiciones CI/CD), nociones básicas de YAML. |
| Complementarios | T-6 básico (Docker) para los módulos de build/publish de imágenes. |

## 3. Organización (4 niveles)

El curso tiene **15 módulos**. Detalle en `ROADMAP.md`.

- **Nivel 1 — Fundamentos** (5): modelo mental, sintaxis, eventos, acciones del marketplace, secretos/variables.
- **Nivel 2 — Intermedio** (4): matrices y dependencias entre jobs, caché y artefactos, reusables (composite + reusable workflows), environments y approvals.
- **Nivel 3 — Avanzado** (3): self-hosted runners y ARC, OIDC a clouds y permisos, autoría de actions (JS, Docker, composite).
- **Nivel 4 — Producción empresarial** (3): hardening de seguridad del pipeline, supply chain (SBOM, attestations, firma), platform patterns (workflows requeridos a nivel org, políticas, control de costo).

## 4. Entregables del curso

- Repo con pipeline de CI completo para una app Python (lint, test con matriz, build).
- Reusable workflow a nivel organización + composite action propia.
- Pipeline de release que publica imagen a GHCR firmada con cosign y con attestation SLSA.
- Pipeline que despliega a AWS vía OIDC sin usar access keys.
- Self-hosted runner funcional en un cluster Kubernetes local (kind/k3d) con ARC.

## 5. Evaluación

- **Conceptual**: diferenciar `pull_request` vs `pull_request_target` y el riesgo asociado; explicar el flujo OIDC entre GHA y AWS; qué garantiza y qué no una attestation SLSA.
- **Operativa**: diseñar y depurar un workflow con jobs dependientes, caché, matriz y environment con approval; convertir un workflow a reusable; configurar ARC.
- **Arquitectónica**: justificar hosted vs self-hosted vs ARC para una org; elegir modelo de reutilización (composite vs reusable workflow vs starter); definir política mínima de seguridad obligatoria a nivel org.

## 6. Recursos

A verificar en Fase 4:

- Documentación oficial de GitHub Actions (`docs.github.com/actions`).
- Especificación de contextos y expresiones (`contexts`, `expressions`).
- Documentación de **Actions Runner Controller** (ARC) en `github.com/actions/actions-runner-controller`.
- Especificación **SLSA** (`slsa.dev`) y acción `actions/attest-build-provenance`.
- Sigstore / cosign (`docs.sigstore.dev`).
- Guía oficial de seguridad: "Security hardening for GitHub Actions".
