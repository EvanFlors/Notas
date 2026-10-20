# REFERENCE — jk-05-02-arc-vs-jenkins-k8s-adr

> Una **referencia** razonada. No es la única respuesta correcta.

---

# ADR 001 — Modelo de agents de CI: Jenkins + Kubernetes plugin vs GitHub Actions + ARC

## Estado

Propuesto (Q4). Objetivo: ser Aceptado tras revisión de Platform + Dev Experience antes del siguiente planning trimestral.

## Contexto

Operamos un **Jenkins LTS** on-prem con ~120 pipelines activos, Shared Libraries internas maduras (step `standardBuild()`, cobertura, firma de artefactos, deploy a Argo CD). Los repos viven en **GitHub Enterprise Cloud**. El Platform team ha provisionado un cluster **Kubernetes** nuevo, infrautilizado.

Los **agents actuales** son VMs permanentes con Docker: contamination acumulada, parcheo manual, horas desperdiciadas en incidentes "funcionó ayer, no hoy". Hay que migrar.

Dos opciones serias:

- **A)** Jenkins + **Kubernetes plugin**: cada build spawnea un Pod efímero; el controller se queda; las Shared Libraries se preservan intactas.
- **B)** Migrar progresivamente a **GitHub Actions + ARC**: el plano de control pasa a GitHub.com; los agents son Pods efímeros gestionados por ARC en el mismo cluster; las Shared Libraries se portan a reusable workflows en 2–3 trimestres.

Shared Libraries son el activo que condiciona esta decisión: representan ~2 años de trabajo del Platform team y encapsulan convenciones (firma Cosign, deploy a Argo, políticas de retention).

## Decisión

**Opción híbrida con fases**, no "todo A" ni "todo B":

- **Fase 1 (0–3 meses)**: Jenkins + Kubernetes plugin para **todos los pipelines actuales**. Migrar los agents de VMs permanentes a Pods efímeros. Mantener Shared Libraries. Beneficio inmediato: elimina la contamination.
- **Fase 2 (3–9 meses)**: ARC desplegado **en paralelo** en el mismo cluster, para **pipelines nuevos** (greenfield) y para repos que lo pidan explícitamente. Cualquier reusable workflow nueva nace en ARC, no en Shared Library.
- **Fase 3 (9–18 meses)**: Dual-run selectivo de 3–5 pipelines críticos (mismo pipeline en ambas plataformas) para validar paridad y confianza del equipo.
- **Fase 4 (18+ meses)**: Decisión de corte. Si > 70% de los pipelines están ya en ARC con incident rate aceptable, planificar retirada de Jenkins. Si no, se queda — sin forzar.

### Dimensiones comparadas

| Dimensión | Jenkins + K8s plugin | ARC |
|-----------|----------------------|-----|
| **Control plane** | Self-hosted (nuestra operación) | GitHub.com (SaaS, no operamos) |
| **Agent plane** | Pods efímeros en nuestro cluster | Pods efímeros en nuestro cluster |
| **Networking** | Controller debe ver API server; Pod debe ver controller (JNLP tunnel) | Pod sale a GitHub (webhook) — más fácil detrás de NAT |
| **Escalado** | Driven por cola Jenkins + plugin | Driven por `RunnerScaleSet` + webhook GitHub |
| **Gobernanza** | Shared Libraries con CODEOWNERS, versioning por tag | Reusable workflows + required workflows + permissions a nivel org |
| **Inercia operativa** | Alta (Jenkins ya conocido; ~120 pipelines no reescribibles de un día para otro) | Baja/media (equipo nuevo con la plataforma) |
| **Coste** | Operar controller Jenkins (patching, HA manual, upgrades LTS) | GitHub Actions minutes (si no auto-hosted) + operar ARC |
| **Observabilidad** | Prometheus plugin + logs al stack existente | Métricas ARC + GitHub Actions logs (menos integradas al stack) |

### Pods efímeros: común en ambas

Ambas opciones usan el mismo patrón arquitectónico (Pod por build, workspace efímero, cold-start aceptable). La diferencia es **quién orquesta la cola** (Jenkins controller vs ARC + GitHub).

## Consecuencias

### Positivas

- Fase 1 **captura todo el valor de la limpieza** sin tocar las Shared Libraries ni los pipelines.
- Fase 2 permite al equipo **aprender ARC con bajo riesgo** antes de comprometer migraciones grandes.
- La decisión de corte en Fase 4 es **basada en evidencia**, no en ideología.
- Shared Libraries se portan solo cuando están pagadas por un pipeline que las necesita en ARC.

### Negativas

- **Dos plataformas en paralelo** = sobrecarga cognitiva y operativa durante 6–18 meses.
- Riesgo de **estancamiento**: la Fase 4 puede posponerse indefinidamente si nadie empuja.
- GitHub.com como control plane introduce dependencia SaaS para CI (impacto en incidentes GitHub).
- ARC con GitHub Enterprise Cloud puede requerir repensar OIDC federation y secret scopes.

## Alternativas descartadas

### Alt A: "Todo a Jenkins + Kubernetes plugin", sin plan de salida

- **Por qué no**: congelamos el futuro en una herramienta cuyo momentum ha caído respecto a GHA/GitLab. Las Shared Libraries se vuelven una barrera de salida mayor cada mes. En 3 años el equipo de Platform será de los pocos que saben Jenkins.

### Alt B: "Migrar todo a ARC ya"

- **Por qué no**: 120 pipelines no se migran bien en 1 trimestre. Reescribir Shared Libraries bajo presión produce reusable workflows mediocres. El riesgo de romper el flujo de deploy a prod no se compensa por el beneficio.

### Alt C: Seguir con VMs permanentes

- **Por qué no**: la contamination y el parcheo manual ya son el bug #1 reportado por SRE. Perpetuar el modelo no es neutral, es activo.

### Alt D: GitLab CI

- **Por qué no**: los repos están en GitHub y no hay plan de mover. Introducir GitLab solo para CI añade un tercer plano de control.

## Criterios de corte para Fase 4

- % pipelines migrados a ARC con 30 días estables.
- Incident rate (p75) comparable entre Jenkins y ARC.
- Confianza del equipo (encuesta anónima) ≥ 7/10.
- Shared Libraries portadas o retiradas (ninguna "huérfana" bloqueando).

Si estos criterios no se cumplen, Jenkins se queda. La decisión de retirar se vuelve a tomar en 12 meses.
