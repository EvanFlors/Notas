# argo-13-flux-as-alternative — Flux v2 como alternativa a Argo CD

## Identificación
- **ID:** `argo-13-flux-as-alternative`
- **Nivel:** producción
- **Duración estimada:** 4 h
- **Prerrequisitos:** `argo-01` (principios GitOps), `argo-04` (sources Helm/Kustomize), `argo-07` (ApplicationSets), `argo-11` (internals y seguridad de Argo CD)

## Objetivo
Entender Flux v2 a un nivel que permita **elegir fundamentadamente** entre Argo CD y Flux para una organización dada, y **portar un workload existente** de uno a otro cuando el caso de negocio lo justifique.

Al terminar el módulo, el estudiante puede:

- Describir la arquitectura modular de Flux v2 (los cinco controllers principales) y qué CR consume cada uno.
- Instalar Flux en un cluster, bootstrappear un repositorio Git como fuente de verdad, y sincronizar la primera `Kustomization`.
- Desplegar un chart Helm vía `HelmRelease` (y entender qué hace diferente respecto a Argo CD, que no corre `helm install`).
- Configurar **image automation** nativa (image-reflector + image-automation) y comparar con `argocd-image-updater`.
- Operar multi-tenancy con `Kustomization.spec.serviceAccountName` + impersonation.
- Justificar la elección Argo CD vs Flux con criterios objetivos (UX, SSO, image automation, modularidad, cultura "GitOps-only").

## Temas y subtemas

1. **Arquitectura Flux v2 — toolkit modular**
   - `source-controller`: `GitRepository`, `OCIRepository`, `HelmRepository`, `Bucket` (S3/GCS/MinIO).
   - `kustomize-controller`: CR `Kustomization` — renderiza y aplica (SSA).
   - `helm-controller`: CR `HelmRelease` — ejecuta `helm install/upgrade` (sí, aquí sí).
   - `notification-controller`: `Provider`, `Alert`, `Receiver` (Slack, GitHub, webhook, GitLab, Teams).
   - `image-reflector-controller` + `image-automation-controller`: `ImageRepository`, `ImagePolicy`, `ImageUpdateAutomation` — bump automático de tags por commit a Git.
2. **CLI `flux`**: `flux bootstrap github/gitlab`, `flux create source git`, `flux create kustomization`, `flux reconcile`, `flux suspend/resume`, `flux trace`, `flux stats`, `flux logs`.
3. **Multi-tenancy**: `Kustomization.spec.serviceAccountName` + impersonation + RBAC namespace-scoped; `--cluster-domain`, `--no-cross-namespace-refs`; patrón "tenant repo + platform repo".
4. **Filosofía "GitOps-only"**: no hay UI con write; todo cambio pasa por Git. Es diseño, no omisión. Herramientas de observación: `flux` CLI, `k9s`, Weave GitOps, Capacitor.
5. **Comparación tabular con Argo CD**: UX, SSO, image automation, sharding, multi-tenancy, ecosistema, curva de aprendizaje.
6. **Criterios de migración**: cuándo migrar, cuándo quedarse, patrón "ida y vuelta" (ambos leen los mismos manifests Kustomize/Helm, solo cambia el reconciliador).

## Conceptos internos (fundamentos)

- **No hay "Application" monolítica**: cada CR es independiente y pequeño. Un release Helm se expresa como `HelmRepository` + `HelmRelease`; un overlay Kustomize como `GitRepository` + `Kustomization`. Composición por referencia (`sourceRef`).
- **Server-side apply (SSA)** por defecto en `kustomize-controller`: evita el ownership madness del client-side apply.
- **`helm-controller` ejecuta Helm real**: hooks `pre-install/pre-upgrade` funcionan (a diferencia de Argo CD, que hace `helm template`).
- **Image automation = commit a Git**: `image-automation-controller` escribe un commit al repo de infra con el nuevo tag. La reconciliación la hace `kustomize-controller` leyendo ese commit — es GitOps estricto incluso para auto-updates. Argo CD Image Updater puede escribir a Git **o** actualizar la Application CR directamente (menos estricto).
- **Dependencias explícitas**: `Kustomization.spec.dependsOn` ordena recursos entre `Kustomization`s. Equivalente de sync waves pero cross-CR.
- **Health checks**: `Kustomization.spec.healthChecks` referencia recursos y `kstatus` decide "ready".
- **Suspend == pause**: `flux suspend kustomization foo` detiene reconciliación — útil en incidentes.

## Competencias

- **Conceptual**: explicar por qué Flux no tiene UI con write; qué resuelve cada controller; dónde se expresa la equivalencia de cada feature Argo CD.
- **Operativa**: instalar Flux, bootstrappear repo, desplegar un chart por `HelmRelease`, configurar image automation; portar un workload existente de Argo CD a Flux sin cambiar los manifests subyacentes.
- **Arquitectónica**: elegir Argo CD o Flux defendiendo los trade-offs; diseñar un plan de migración reversible.

## Ejemplos

- [`examples/01-flux-install-and-first-kustomization`](examples/01-flux-install-and-first-kustomization/) — install vía manifests, `GitRepository` + `Kustomization` sobre repo público, verificación.
- [`examples/02-helmrelease-in-flux`](examples/02-helmrelease-in-flux/) — `HelmRepository` + `HelmRelease` desplegando podinfo; comparación con Argo CD Helm source.
- [`examples/03-image-automation-in-flux`](examples/03-image-automation-in-flux/) — `ImageRepository` + `ImagePolicy` + `ImageUpdateAutomation`; demostración de bump automático con marker en manifests.

## Actividades

- [`activities/01-port-capstone-from-argocd-to-flux`](activities/01-port-capstone-from-argocd-to-flux/) — **independiente**. Toma la Application del capstone de `argo-04` y la reimplementa como `GitRepository` + `Kustomization` + `HelmRelease` en Flux. Validador comprueba presencia de CRs y reconciliación `Ready=True`.
- [`activities/02-choice-adr-final`](activities/02-choice-adr-final/) — **independiente** (ADR). Produce el ADR final del curso: Argo CD vs Flux para una organización concreta descrita, con decisión, consecuencias y plan de migración reversible.

## Entregables

1. Capstone portado a Flux (Kustomization + HelmRelease operando sobre el mismo repo de infra que Argo CD usaba).
2. ADR final de elección entre Argo CD y Flux, firmado y con fecha.

## Criterios de evaluación

| Dimensión | Criterio |
|---|---|
| Conceptual | Explica los cinco controllers y el CR que cada uno consume sin consultar notas. |
| Operativa | `flux get all -A` devuelve `Ready=True` sobre el workload portado. |
| Arquitectónica | El ADR final no es "lo que ya conozco" — enumera criterios medibles y los pondera. |

## Recursos

Ver [`resources/links.md`](resources/links.md).

## Notas

- Este módulo requiere `kind` y la CLI `flux` (`brew install fluxcd/tap/flux`). Los ejemplos y la actividad detectan la ausencia y **omiten limpiamente** (skip graceful) sin fallar — el aprendizaje de la lectura sigue siendo válido aunque no se ejecute el lab.
- Prosa en español, código y manifests en inglés (convención del programa).
