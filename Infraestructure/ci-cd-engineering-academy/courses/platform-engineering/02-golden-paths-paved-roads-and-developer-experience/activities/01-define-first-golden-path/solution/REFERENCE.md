# REFERENCE — plat-02-01-define-first-golden-path

> Una **referencia** razonada del canvas. No es la única respuesta correcta — es un modelo contra el que compararte.

# Golden Path Canvas — "nuevo microservicio Python"

## 1. Caso de uso

Crear un **microservicio Python stateless** con endpoints HTTP (FastAPI), para dominios de negocio (pagos, catálogo, usuarios), desplegado en Kubernetes vía GitOps, con observabilidad y CI/CD listas desde el minuto cero.

## 2. Usuarios objetivo

- **Rol:** developers backend (senior y mid).
- **Equipos:** 8 equipos stream-aligned (pagos, catálogo, usuarios, pricing, orders, notifications, search, admin).
- **Volumen esperado:** ~12 microservicios nuevos / trimestre (basado en los últimos 90 días).
- **No objetivo (en este path):** data engineers, ML engineers, frontend.

## 3. Alcance

**Incluido:**

- Scaffolding de repo (template Backstage o cookiecutter como punto de partida).
- CI pipeline (lint `ruff` + test `pytest` + build imagen + firma `cosign` + push a registry interno).
- Chart Helm base + `values.yaml` por entorno (`dev`, `staging`, `prod`).
- Deploy GitOps con Argo CD (Application generada automáticamente).
- Observabilidad: logs estructurados JSON a stdout, métricas Prometheus (`/metrics`), traces OTel vía OTLP.
- Registro automático en el catálogo (`catalog-info.yaml` generado).
- TechDocs base: README + ADR template + runbook template.

**Fuera de scope (explícito):**

- Servicios stateful (DB embebida, cache local, filesystem).
- Workers async / consumers Kafka (los cubre otro path).
- Jobs batch / cron (los cubre otro path).

## 4. Criterios

- **Volumen:** 12 microservicios nuevos / trimestre entre 8 equipos. Alta frecuencia.
- **Variabilidad baja:** los últimos 12 microservicios compartían 80 % del scaffolding (FastAPI + logging JSON + Prometheus + Helm). Divergen en lógica de dominio, no en infraestructura.
- **Dolor compartido:** encuestas y entrevistas previas identifican el setup inicial (CI + Helm + observabilidad) como el principal consumidor de las primeras 2 semanas de un servicio nuevo.
- **Impacto medible:** tenemos TTP actual (p50 ≈ 9 días) y # de tickets de onboarding (promedio 6/servicio). El antes/después se puede medir.
- **Bajo riesgo de regresión:** el path crea servicios **nuevos**; no toca los existentes. Peor caso: el equipo re-genera el repo.

## 5. Métricas

Constelación de 4 métricas con valor objetivo:

| Métrica | Fórmula | Objetivo (T+2) |
|---------|---------|----------------|
| **time-to-production p50** | mediana de días desde `git init` a primer deploy prod | **< 2 días** (hoy ≈ 9) |
| **adopción** | % microservicios nuevos creados vía el path | **> 60 %** T+1, **> 80 %** T+2 |
| **tasa de errores de scaffolding** | fallos del scaffolder / ejecuciones | **< 5 %** |
| **platform NPS** (específico del path) | promotores − detractores | **≥ 30** T+2 |

Reportamos las 4 **en pareja**: adopción + NPS, TTP + error rate. Si una sube y su pareja baja, hay que investigar.

## 6. Long tail

Casos **excluidos** y postura:

- **Microservicio Go:** opción B **soportada** → otro golden path con el mismo contrato de interoperabilidad (observabilidad, catálogo, GitOps).
- **Microservicio Rust:** opción B **no soportada** por ahora → el equipo puede ir off-road, el platform team ofrece revisión amistosa pero no on-call ni upgrades.
- **Librería interna (sin HTTP):** fuera de scope de "microservicio" → otro path (`golden-path-python-library`).
- **Servicio C++ legacy existente:** no se migra forzosamente al path; se dejan como están hasta que el equipo quiera.

Postura global: **sin mandato en el primer trimestre**. Si en T+2 la adopción espontánea pasa el 80 %, consideraremos mandato selectivo para servicios que manejen PII.

## 7. Owner

- **Owner:** Ana López — Platform Lead (DRI).
- **Backup:** rotación trimestral entre los otros 2 ingenieros del platform team.
- **Versionado:** SemVer del template (`v1.0.0`, `v1.1.0`, ...). Cada repo generado graba la versión en `catalog-info.yaml`.
- **Changelog:** `CHANGELOG.md` en el repo del template + anuncio en `#platform-announcements` Slack.
- **Deprecations:** ciclo **anuncio (T=0) → warn en el scaffolder (T+3 meses) → remove (T+9 meses)**. Nunca sin herramienta `update-from-template` disponible.

## 8. Riesgos (antipatterns a evitar)

1. **"Golden path en papel"** → riesgo si no se dedica tiempo del platform team a mantenerlo. **Mitigación:** 20 % de capacidad del platform team dedicada al path durante el primer trimestre, revisión mensual.
2. **"Golden cage"** → riesgo si los equipos tienen que pedir permiso para variar cualquier cosa. **Mitigación:** cada bloque del scaffolder es opt-out; el `values.yaml` tiene *escape hatches* documentados.
3. **"Mandato prematuro"** → riesgo de forzar antes de medir adopción. **Mitigación:** mandato solo tras alcanzar adopción espontánea > 80 % y NPS ≥ 30.
4. **"Métrica única (solo TTP)"** → riesgo de optimizar velocidad y degradar calidad. **Mitigación:** la constelación de 4 métricas y revisión en pareja.
5. **"Long tail despreciado"** → riesgo de que equipos Rust/C++ se vuelvan shadow IT. **Mitigación:** canal explícito de buena vecindad, roadmap público del siguiente path.

## Comparación con tu canvas

- ¿Tus **8 secciones** están todas presentes y nombradas igual?
- ¿Tus métricas tienen **números**? ("mejor" no es número).
- ¿Nombras explícitamente **al menos 2 casos excluidos**?
- ¿Tu owner es **una persona**, no un equipo?
- ¿Tus riesgos cubren **al menos 3** antipatterns distintos de la lección?

Si cualquiera de las anteriores es "no", vuelve a la sección correspondiente.
