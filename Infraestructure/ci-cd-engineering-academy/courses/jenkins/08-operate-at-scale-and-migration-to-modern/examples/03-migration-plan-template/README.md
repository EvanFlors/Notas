# Ejemplo 03 — Plantilla de plan de migración

> Lectura y análisis. Plantilla de **inventario + clasificación + plan por fases** que un equipo real podría llenar.

## 1. Inventario de pipelines

Columnas obligatorias:

| Pipeline | Tipo | Última run | Owner | Repo | Branches activas | Credentials usados | Agents / podTemplates | Shared libs | Webhooks externos | Criticidad |
|----------|------|-----------|-------|------|------------------|--------------------|-----------------------|-------------|-------------------|------------|
| `orders-api-ci` | pipeline | ayer | backend | `orders-api` | `main`, `release/*` | `artifact-store`, `aws-prod` | `k8s/python-3.12` | `std-build@v3` | alta |
| `legacy-reports-nightly` | freestyle | hace 180 d | `?` (sin owner) | `?` | `?` | `?` | master executor | — | — |
| `docs-site-build` | pipeline | hoy | docs | `docs-site` | `main` | `netlify-token` | `k8s/node-20` | — | — | baja |
| ... | | | | | | | | | | |

Fuentes para rellenar:

- API Jenkins: `GET /api/json?tree=jobs[name,lastBuild[timestamp],url]`.
- Config XMLs del `JENKINS_HOME` (`jobs/*/config.xml`).
- Entrevistas con teams (para `owner` cuando el XML no dice nada).

## 2. Clasificación

Cada fila del inventario recibe una clase:

| Clase | Criterios de entrada | Acción |
|-------|----------------------|--------|
| **Retirar** | Sin runs ≥ 90 d, o sin owner tras 2 semanas de preguntar, o repo archivado, o duplicado funcional. | Backup XML a `/archive/`. Desactivar. Borrar en 30 d si nadie reclama. |
| **Consolidar** | ≥ 2 pipelines que hacen variaciones del mismo trabajo. | Refactor previo: 1 pipeline parametrizado. **Luego** migrar. |
| **Migrar** | Pipeline activo, con owner, no duplicado. | Entra en el plan por fases. |

Regla operativa: **cualquier `?` en columnas obligatorias → candidato automático a `Retirar`**. Si nadie lo defiende, no vale la pena migrarlo.

## 3. Plan por fases

### Fase 0 — Preparación (2 semanas)

- Inventario completo + clasificación.
- Target elegido con ADR aparte.
- Dual-run framework instalado (comparador, dashboard).
- Formación básica del equipo en el target.

### Fase 1 — Prueba (4 semanas)

- 2–3 pipelines **simples y críticos**: `docs-site-build`, `cli-tool-ci`.
- Dual-run completo.
- Objetivo: validar que el target funciona end-to-end y que el proceso de dual-run es manejable.

### Fase 2 — Volumen bajo (6–8 semanas)

- 30–40% de los pipelines a migrar, los más simples.
- Dual-run estándar (2–4 semanas por pipeline).
- Métricas: % migrado, tiempo medio por pipeline, incidentes.

### Fase 3 — Volumen alto (8–12 semanas)

- Pipelines complejos no críticos.
- Refactor de Shared Libraries → reusable workflows / Components / WorkflowTemplates.
- Reemplazo de `withCredentials` por OIDC federation.

### Fase 4 — Crítico (6–8 semanas)

- Pipelines de prod críticos.
- Dual-run largo (4–8 semanas).
- Gates manuales. Change advisory board si existe.

### Fase 5 — Corte y archivado (4 semanas)

- Último pipeline migrado + 4 semanas verde.
- Archivado histórico (logs/artefactos a storage de largo plazo).
- Apagado procedimentado (ver §10 de la teoría).
- Infra Jenkins descomisionada 30 días después.

## 4. Riesgos frecuentes y su mitigación

| Riesgo | Mitigación |
|--------|------------|
| Pipeline con dependencia oculta del `JENKINS_HOME` (cache local, archivo subido a mano). | Dry-run en un controller limpio durante Fase 1. |
| Plugin Jenkins sin equivalente directo en el target (p. ej. `Role Strategy` ↔ `environments`). | Mapear a mano; a veces requiere refactor del flujo. |
| Equipo que "no está listo" para el target. | Formación obligatoria en Fase 0 + pairing durante Fase 1. |
| Compliance que exige retención de logs 5+ años. | Export histórico a S3 Glacier con policy de retención antes de apagar. |
| OIDC federation mal scopeada (rol asumible por repos equivocados). | `sub` claim obligatorio (`repo:org/repo:ref:refs/heads/main`); revisar cada rol. |

## 5. Criterios de "éxito"

- 100% de pipelines marcados `migrar` están en el target y han pasado dual-run.
- 0 pipelines `retirar` quedan ejecutándose.
- 0 incidentes P1 atribuidos a la migración durante Fase 5.
- Equipo del pipeline firma por escrito "no quiero volver".
- Historial archivado y compliance satisfecho.
- ADR de migración vivo y versionado.

## 6. Criterios de "rollback"

Durante cada fase, el rollback es:

- Reactivar el webhook de Jenkins para el pipeline en cuestión.
- Dejar el workflow del target desactivado (sin borrarlo).
- Documentar la causa del rollback en el ADR como un hallazgo.

Un rollback **no es un fracaso** — es exactamente la razón del dual-run. Un rollback **frecuente** sí es un problema de diseño; revisar el plan.

## 7. Preguntas de autocomprobación

1. ¿Qué porcentaje de pipelines de un Jenkins con 5 años encima suelen ser candidatos a `Retirar`? ¿Por qué?
2. En Fase 1, ¿por qué eliges pipelines **simples y críticos** en lugar de **complejos y críticos** o **simples y no críticos**?
3. ¿Qué pasa el día que un pipeline "migrado" vuelve a correr en Jenkins durante el dual-run por un error de configuración de webhook? ¿Cómo lo detectas?
4. ¿Puedes empezar la Fase 5 si queda un pipeline en Fase 2 sin resolver? Justifica.
5. Si el target elegido pierde soporte dentro de 2 años (hipotético: GitHub cierra Actions), ¿qué parte de este plan te deja preparado para una segunda migración?
