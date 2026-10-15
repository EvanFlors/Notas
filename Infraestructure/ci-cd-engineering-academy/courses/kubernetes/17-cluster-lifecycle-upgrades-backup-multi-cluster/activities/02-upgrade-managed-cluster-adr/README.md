# k8s-17-02 — ADR: estrategia de upgrade para un cluster managed

## 1. Identificación

- **ID:** `k8s-17-02-upgrade-managed-cluster-adr`
- **Tecnología:** kubernetes
- **Módulo:** `17-cluster-lifecycle-upgrades-backup-multi-cluster`
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** architecture (independent)

## 2. Contexto

Un ADR (Architecture Decision Record) documenta **qué** se decidió, **por qué**, en **qué contexto** y **qué consecuencias** trae. Es el entregable que separa "lo discutimos en una reunión" de "la organización puede recordar y auditar la decisión 2 años después".

Esta actividad te da un **perfil organizacional** (ver §4) y te pide decidir: **in-place o blue/green cluster** para su próximo upgrade. Debes escribir el ADR correspondiente.

No hay respuesta única "correcta" — hay respuestas **defendibles**. El validador comprueba **estructura** del ADR, no la elección final.

## 3. Objetivos

- Elegir in-place vs blue/green **justificando** con el perfil.
- Documentar la decisión en un ADR con todas las secciones requeridas.
- Enumerar al menos 2 alternativas descartadas con razón explícita.
- Declarar RPO/RTO esperados y plan de rollback.
- Especificar métricas de éxito concretas y observables.

## 4. Prerrequisitos

- Haber hecho k8s-17-01 (backup/restore práctico).
- Haber leído la lección §6, §10, §12.
- Editor de texto. No se requiere infraestructura.
- **Costos**: 0 USD.

## 5. Instrucciones

### 5.1 Perfil del escenario

Lees el perfil completo en `starter/CONTEXT.md`. Síntesis:

- **Empresa**: SaaS B2B de billing. 50 ingenieros. Equipo plataforma = 4 personas.
- **Cluster**: EKS en `eu-west-1`, versión actual **1.28**, objetivo **1.31** (3 saltos de minor).
- **Workloads**: 30 microservicios stateless (Deployments + HPA), 2 StatefulSets (Postgres y Redis — ambos operados por operators), Kafka externo (MSK managed, fuera del cluster).
- **SLO público**: 99.9% mensual = **43 min de downtime tolerado por mes**.
- **Ventanas de mantenimiento**: domingos 02:00–06:00 UTC. 2 ventanas disponibles antes del plazo regulatorio.
- **Plazo**: 1.28 cae fuera de soporte EKS en **8 semanas**. Hay que llegar a 1.31 antes.
- **Costo tolerable extra para la operación**: hasta ~20% del costo mensual durante la ventana.
- **Observabilidad**: Prometheus Operator + Grafana + Loki + Tempo activos.
- **GitOps**: Argo CD gestiona todos los workloads desde un repo.
- **DR previo**: hay backups Velero cross-region, nunca restaurados a producción.

### 5.2 Escribe el ADR

Crea el archivo `starter/ADR-001-upgrade-strategy.md` con las siguientes secciones **obligatorias** (titulares exactos; el validador los busca):

1. `# ADR-001: ` (título, debe empezar con este prefijo)
2. `## Status` — `Proposed`, `Accepted` o `Superseded by ADR-XXX`.
3. `## Context` — resumen del perfil con tus propias palabras, al menos 5 líneas.
4. `## Decision` — in-place O blue/green, **explícito**. Debe contener literalmente alguna de las frases "in-place" o "blue/green".
5. `## Consequences` — positivas y negativas, mínimo 3 bullets.
6. `## Alternatives Considered` — al menos 2 alternativas descartadas con el por qué de cada una.
7. `## RPO and RTO` — objetivos numéricos para la ventana de upgrade (p. ej. "RPO 1 h", "RTO 90 min").
8. `## Rollback Plan` — pasos concretos si algo rompe.
9. `## Success Metrics` — métricas observables (p. ej. "error rate 5xx post-upgrade ≤ pre-upgrade", "p99 latency < X ms", "0 restarts anómalos en 24h").

El validador comprueba la presencia de cada sección, no el contenido de prosa; pero el ADR es tuyo — un revisor humano juzgará calidad.

### 5.3 Valida

```bash
bash tests/validate.sh
```

## 6. Resultado esperado

Un archivo `starter/ADR-001-upgrade-strategy.md` que:

- Está bien formateado en Markdown.
- Tiene las 9 secciones obligatorias.
- Elige explícitamente in-place o blue/green.
- Es coherente con el perfil (p. ej. elegir blue/green con un presupuesto justo y SLO relajado sería incoherente — un revisor humano lo marcará aunque pase el validador).

## 7. Criterios de aceptación

| # | Criterio |
|---|----------|
| 1 | Existe `starter/ADR-001-upgrade-strategy.md`. |
| 2 | El título empieza por `# ADR-001:`. |
| 3 | Están las 9 secciones (Status, Context, Decision, Consequences, Alternatives Considered, RPO and RTO, Rollback Plan, Success Metrics). |
| 4 | `Decision` contiene literalmente "in-place" o "blue/green". |
| 5 | `Alternatives Considered` enumera al menos 2 opciones con razón. |
| 6 | `RPO and RTO` incluye valores numéricos. |

## 8. Validación

```bash
bash tests/validate.sh
```

El validador imprime OK/FAIL por sección y sale con exit code 0 si todo pasa.

## 9. Preguntas de reflexión

1. Si cambiara el SLO a 99.99% (4 min/mes), ¿cambiarías la elección? ¿Por qué?
2. Si no hubiera Argo CD, ¿cómo cambia el costo relativo de blue/green?
3. Postgres y Redis están en el cluster: ¿cómo cambia esto el riesgo de blue/green vs in-place?
4. ¿Qué pedirías al equipo de DBA/datos **antes** de ejecutar la decisión?
5. Si la organización ya tiene cultura de "nunca hemos restaurado un backup", ¿lo haces durante este upgrade o antes?

## 10. Extensiones

- Escribe un **ADR-002** sobre política permanente ("todos los upgrades de aquí en adelante se harán vía X") y relaciónalo con ADR-001.
- Diseña el **playbook ejecutable** del upgrade elegido, nivel de detalle "ingeniero de guardia nocturno".
- Agrega una tabla de **riesgos** con probabilidad × impacto y mitigaciones.

## 11. Limpieza

No hay recursos a limpiar — es documentación. Si quieres borrar el borrador local:

```bash
rm -f starter/ADR-001-upgrade-strategy.md
```
