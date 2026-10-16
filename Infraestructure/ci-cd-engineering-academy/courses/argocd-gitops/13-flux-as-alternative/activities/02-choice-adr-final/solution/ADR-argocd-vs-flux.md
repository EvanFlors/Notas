# ADR-013: Adoptar Argo CD como reconciliador GitOps estándar en Acme Platform

> Solución de referencia. Es solo un ejemplo defendible — tu ADR debe reflejar **tu** organización.

## Status
Accepted — 2026-10-15

## Context

Acme Platform es un equipo de plataforma de 8 SRE que opera 1 cluster de producción y 2 de pre-producción (`stg`, `dev`) para 12 equipos de producto (~70 developers). Workloads: 40 servicios HTTP (Go/Node/Python), 6 batch jobs, 4 add-ons de cluster (ingress-nginx, cert-manager, external-dns, Prometheus Operator). Cultura: developers desplieguan a `dev` sin review; `stg` requiere PR; `prod` requiere PR + aprobación de SRE.

Hoy el flujo es GitHub Actions → `kubectl apply` directo contra los clusters (anti-GitOps). Objetivos del cambio: eliminar credenciales largas en los runners, eliminar drift, dar visibilidad a product teams sin darles acceso directo a los clusters.

Decisión forzada ahora porque el equipo de seguridad acaba de rotar las creds y los runners han estado failing — es el momento de cambiar modelo, no de parchear.

## Decision Drivers

Criterios (ponderados por SRE lead + CTO):

- **UX operador para product teams no-SRE** — peso 35% (visibilidad de deploys, logs, diff sin kubectl).
- **SSO integrado con nuestro OIDC (Okta)** — peso 20% (requirement de seguridad).
- **Multi-tenancy con boundaries claros entre los 12 equipos** — peso 15%.
- **Curva de aprendizaje del equipo de plataforma** — peso 10% (ya conocen Argo CD de curso).
- **Image automation nativa** — peso 10%.
- **Ecosistema de rollouts progresivos** — peso 10% (ya evaluamos Argo Rollouts en argo-10).

Suma: 100%.

## Considered Options

1. **Argo CD** (operado durante argo-02 a argo-12 en los labs).
2. **Flux v2** (operado en argo-13 — porting del capstone + 3 ejemplos).
3. **Ambos simultáneos** (Flux para add-ons de plataforma, Argo CD para apps de producto): rechazado por complejidad operacional 2x sin beneficio claro.

## Decision Outcome

Opción elegida: **Argo CD**.

Puntaje (0–10 por criterio, × peso):

| Criterio | Peso | Argo CD | Flux |
|---|---:|---:|---:|
| UX operador no-SRE | 35% | 9 | 4 |
| SSO Okta | 20% | 9 | 6 |
| Multi-tenancy | 15% | 8 | 9 |
| Curva aprendizaje | 10% | 8 | 6 |
| Image automation | 10% | 6 | 9 |
| Progressive delivery | 10% | 9 | 8 |
| **Total ponderado** | | **8.3** | **5.95** |

El driver dominante (UX operador, 35%) empuja a Argo CD. Flux es técnicamente superior en image automation nativa, pero no compensa la pérdida en visibilidad para 70 developers que no van a usar kubectl. SSO con Okta vía Dex es out-of-the-box en Argo CD; en Flux requiere montar OIDC a nivel de K8s y entrenar a la gente en impersonation.

## Consequences

**Positivas:**
- Developers obtienen diff visual y árbol de recursos sin acceso al cluster — menos tickets a SRE.
- Rotación de creds de runners resuelta: GHA solo escribe al repo de infra (bumping tags), no al cluster.
- Pipeline de progressive delivery (Argo Rollouts + Prometheus analysis) encaja de forma natural.

**Negativas / riesgos:**
- Argo CD requiere operación propia (upgrades, backup del namespace `argocd`, hardening — ver argo-11).
- UI con "Sync" en prod es tentación — mitigamos con `syncPolicy.automated` + `syncWindows` + RBAC estricto en `prod`.
- Image automation requiere add-on `argocd-image-updater` (más piezas que Flux nativo).

## Exit Plan

Trigger de reevaluación: si (a) Argo CD causa > 2 incidentes/mes atribuibles a sí mismo, o (b) product teams siguen prefiriendo kubectl a los 6 meses, o (c) aparece requirement que Argo CD no cubre (OCI sources, p. ej.).

Pasos para migrar a Flux en reverso: usar el patrón del módulo 13 — una Application a la vez, suspender en Argo CD, aplicar `GitRepository` + `HelmRelease`/`Kustomization`, validar `Ready=True`, luego borrar la Application. Todos los charts/overlays actuales son reutilizables sin cambios (eso es por qué GitOps es reversible). Costo estimado: ~2 semanas-persona para 40 servicios.

## Autor y fecha
SRE Lead — 2026-10-15.
