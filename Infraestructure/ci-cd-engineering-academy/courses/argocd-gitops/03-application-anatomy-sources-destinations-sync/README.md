# argo-03 — Anatomía de la Application: sources, destinations, sync

## Identificación

- **ID:** `argo-03-application-anatomy-sources-destinations-sync`
- **Curso:** `argocd-gitops`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `argo-02-install-and-first-application` (Argo CD instalado y una primera Application sana).

## Objetivo

Entender el **Custom Resource `Application` de Argo CD** en profundidad: cada campo del `spec`, su efecto operativo y las trampas clásicas. Al terminar deberías poder diseñar un manifiesto `Application` desde cero, predecir su comportamiento, y leer un `argocd app diff` como quien lee un plan de Terraform.

## Alcance

Este módulo cubre:

- `apiVersion: argoproj.io/v1alpha1`, `kind: Application` — por qué el `kind` vive en el namespace de Argo CD y qué significa.
- `spec.source` — `repoURL`, `path`, `targetRevision` (branch / tag / commit / `HEAD`).
- `spec.destination` — `server`, `namespace`, `name`.
- `spec.project` — qué es un AppProject y por qué `default` no es suficiente a largo plazo (profundiza `argo-06`).
- `spec.syncPolicy` — manual vs **automated** con `prune` y `selfHeal`; `syncOptions` básicos.
- `spec.ignoreDifferences` — convivir con otros controllers (HPA, VPA, operators) que mutan campos del `spec`.
- `spec.info` y `annotations` — metadata operativa.
- **UI de recursos**: tree view, diff view, logs; cómo esta información se corresponde con el modelo.
- `argocd app diff` desde CLI — como herramienta de preview en CI.

Lo que **no** cubre (se verá después):
- Sources Helm / Kustomize / Jsonnet / Multi-source → `argo-04`.
- Sync waves, hooks, estrategias finas → `argo-05`.
- AppProjects en detalle y RBAC → `argo-06`.
- ApplicationSets (generar Applications a escala) → `argo-07`.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-application-spec-walkthrough/` — recorrer un manifiesto Application campo a campo.
  - `02-ignore-hpa-replicas/` — por qué `replicas` suele ir en `ignoreDifferences` cuando hay HPA, y cómo hacerlo.
  - `03-diff-in-ci/` — usar `argocd app diff` como gate en pipeline.
- **`activities/`**:
  - `01-write-application-manifest/` — **guided-lab**: escribir y validar un `Application` para el capstone.
  - `02-diagnose-out-of-sync/` — **independent / debug**: recibes un Application `OutOfSync` real; debes diagnosticar la causa (branch móvil, HPA mutando `replicas`, cambio manual con `kubectl`) y proponer la corrección.
- **`resources/links.md`** — documentación oficial y referencias verificables.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar cada campo del `spec.Application` y su efecto. Justificar por qué `targetRevision: HEAD` es una trampa en producción. Diferenciar sync status vs health status (del módulo anterior) y cómo `ignoreDifferences` interactúa con ambos. |
| Operativa | Escribir un `Application` válido para una app del capstone; usar `argocd app diff` para predecir cambios antes de sync; configurar `ignoreDifferences` para que un HPA no cause falsas desviaciones. |
| Arquitectónica | Decidir, por caso, si `targetRevision` debe ser branch (ambiente), tag (release) o commit (artefacto reproducible). Diseñar política de sync inicial (manual/auto, prune, selfHeal) por entorno. |

## Criterios de evaluación

- Manifiesto `Application` del capstone revisado y validado por `kubectl apply --dry-run=server`.
- Explicación escrita (en el ADR o un comentario del manifiesto) de por qué `replicas` va en `ignoreDifferences` cuando el `Deployment` tiene un HPA.
- Diagnóstico correcto del escenario `OutOfSync` de la actividad 02, identificando causa raíz y aplicando la corrección mínima.

## Secuencia recomendada

1. Lee `theory/lesson.md` entero (una pasada).
2. Repasa `examples/01-application-spec-walkthrough/`.
3. Lee `examples/02-ignore-hpa-replicas/` — es el pitfall más común en el día a día.
4. Haz la actividad `01-write-application-manifest/` (guiada).
5. Lee `examples/03-diff-in-ci/`.
6. Haz la actividad `02-diagnose-out-of-sync/` (independiente, es la que valida comprensión real).
7. Vuelve a `theory/` a responder las preguntas de reflexión sin consultar.

## Nota sobre el entorno

Los ejemplos y actividades que requieren un cluster asumen **`kind` + Argo CD** instalados en el módulo `argo-02`. Si no están disponibles, cada script detecta la ausencia y continúa con un modo "offline": validación estructural de YAML, parsing con `kubectl --dry-run=client`, y revisión por `kubeconform` cuando esté instalado. **No se requiere nube ni credenciales**.

## Siguiente

→ `argo-04-sources-helm-kustomize-jsonnet-multisource`: cómo cambia el `spec.source` cuando la fuente es Helm, Kustomize o varias combinadas.
