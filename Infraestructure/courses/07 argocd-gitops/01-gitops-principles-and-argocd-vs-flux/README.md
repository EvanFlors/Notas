# argo-01 — Principios de GitOps y Argo CD vs Flux

## Identificación

- **ID:** `argo-01-gitops-principles-and-argocd-vs-flux`
- **Curso:** `argocd-gitops`
- **Nivel:** fundamentos
- **Duración estimada:** 2 h
- **Prerrequisitos:** curso **kubernetes** ≥ Nivel 2 (Deployments, RBAC, CRDs). Curso **git-and-github** completo recomendado.

## Objetivo

Construir el **modelo mental correcto** de **GitOps** *antes* de instalar Argo CD o Flux: qué significan los **4 principios de OpenGitOps** (declarative, versioned & immutable, pulled automatically, continuously reconciled), por qué el modelo **pull** reduce la superficie de credenciales frente al **push** tradicional, cuál es la diferencia filosófica entre **Argo CD** y **Flux**, y cómo reconocer el **"GitOps-washing"** — pipelines que llevan la etiqueta pero violan los principios.

Al terminar este módulo deberías poder, sin consultar docs:

- Enunciar los 4 principios de OpenGitOps y dar un ejemplo de violación de cada uno.
- Explicar por qué `kubectl apply` desde un pipeline de CI **no** es GitOps.
- Dibujar el flujo **push vs pull** y argumentar la diferencia en términos de credenciales, drift y rollback.
- Comparar Argo CD y Flux a nivel filosófico (UX, modularidad, "GitOps-only").
- Escribir un ADR corto defendiendo la elección Argo CD vs Flux con criterios concretos.

Este módulo es deliberadamente **"antes de instalar nada"**: todo el contenido se completa sin cluster, sin Argo CD, sin Flux. La instalación y la primera Application se cubren en `argo-02`.

## Alcance

Este módulo cubre:

- **Push vs pull** como modelos de entrega.
- **OpenGitOps principles**: declarative, versioned & immutable, pulled automatically, continuously reconciled — definición, implicación operativa y violación típica de cada uno.
- Separación **repo de código** vs **repo de infra/manifests**: por qué suelen ser repos distintos.
- "**CI builds artifacts, CD reconciles state**" — por qué la frontera entre CI y CD cambia bajo GitOps.
- **Argo CD vs Flux** a nivel filosófico: UX, modularidad, "GitOps-only", requisitos operativos.
- Anti-patrones: **GitOps-washing** (pipelines que parecen GitOps pero no lo son).

Lo que **no** cubre (vendrá después):

- Instalar Argo CD, crear la primera `Application` → `argo-02`.
- Anatomía del CR `Application` (sources, destinations, sync policies) → `argo-03`.
- Secretos en GitOps (SOPS/Sealed Secrets/ESO/Vault) → `argo-09`.
- Flux operativo (install, `Kustomization`, `HelmRelease`) → `argo-13`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones (≈ 90 min de lectura reflexiva).
- **`examples/`** — ejemplos conceptuales (no requieren cluster):
  - `01-push-vs-pull-diagram/` — diagramas ASCII anotados de los dos modelos de entrega, con el camino de las credenciales en cada uno y la implicación de blast radius.
  - `02-opengitops-principles-walkthrough/` — recorrido comentado por los 4 principios de OpenGitOps con ejemplo y violación típica de cada uno.
- **`activities/`** — dos actividades **independientes y conceptuales**:
  - `01-identify-gitops-washing/` — **independent, análisis**. Produce `MAP.md` auditando 5 escenarios y clasificando cuáles son GitOps, cuáles son GitOps-washing y qué principio violan.
  - `02-adr-argocd-vs-flux-first-pass/` — **independent, arquitectura**. Produce `ADR.md` argumentando una primera elección Argo CD vs Flux para una organización dada.
- **`resources/links.md`** — docs oficiales de OpenGitOps, Argo CD, Flux, y lecturas de referencia.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Enunciar los 4 principios OpenGitOps sin consultar; distinguir push vs pull; identificar GitOps-washing en un pipeline arbitrario. |
| Operativa | Auditar un pipeline existente contra los 4 principios y señalar qué violación tiene (y cómo repararla sin reescribirlo todo). |
| Arquitectónica | Defender razonadamente la elección Argo CD vs Flux para una organización con restricciones concretas (tamaño, cultura, requisitos de UX, estado del tooling). |

## Criterios de evaluación

- Lección leída y preguntas de evaluación respondidas (`theory/lesson.md` §12).
- Actividad 01 entregada: `MAP.md` con los 5 escenarios clasificados, principio violado y propuesta de corrección.
- Actividad 02 entregada: `ADR.md` con contexto, decisión, consecuencias, alternativas descartadas y las 7 respuestas obligatorias.
- `tests/validate.sh` de cada actividad pasa (estructural; semántica contra `solution/`).

## Secuencia recomendada

1. Lee `theory/lesson.md` completo (una pasada, sin consultar nada externo).
2. Reproduce mentalmente `examples/01-push-vs-pull-diagram/` — contrasta con la lección.
3. Recorre `examples/02-opengitops-principles-walkthrough/` — identifica el principio y su violación en cada caso.
4. Haz la actividad `01-identify-gitops-washing/` — practica el ojo clínico contra escenarios ambiguos.
5. Haz la actividad `02-adr-argocd-vs-flux-first-pass/` — practica el criterio profesional (ADR).
6. Responde las preguntas de evaluación de la lección sin re-leer.

## Siguiente

→ `argo-02-install-and-first-application`: instalar Argo CD en un cluster local, acceder por UI/CLI, conectar un repo público y gestionar la primera `Application` con sync manual y luego automático.
