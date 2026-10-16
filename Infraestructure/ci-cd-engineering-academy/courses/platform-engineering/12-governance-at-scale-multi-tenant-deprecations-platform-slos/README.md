# plat-12 — Gobernanza a escala: multi-tenancy, deprecations y platform SLOs

## Identificación

- **ID:** `plat-12-governance-at-scale-multi-tenant-deprecations-platform-slos`
- **Curso:** `platform-engineering`
- **Nivel:** producción
- **Duración estimada:** 5 h
- **Prerrequisitos:** `plat-09` (self-service infra con Crossplane), `plat-10` (scorecards), `plat-11` (métricas DORA/SPACE + platform-as-product).

## Objetivo

Interiorizar **cómo se opera una plataforma interna a escala sin que se convierta ni en jaula ni en caos**. Al terminar deberías poder diseñar y defender el **modelo de gobernanza** de una plataforma — multi-tenancy, política de *deprecations*, SLOs de la propia plataforma, cadencia de releases, versionado de contratos (XRDs, templates, APIs internas), *inner-source* y comunicación — y entregar un **plan de año uno** que resista tres escenarios adversariales (crecimiento rápido, *hiring freeze*, consolidación post-merger).

Este módulo es el **capstone** del curso: integra todo lo anterior (TT/Cognitive, golden paths, Backstage, catalog, templates, scorecards, Crossplane, métricas) en un modelo operativo coherente.

## Alcance

Este módulo cubre:

- **Multi-tenancy** en todas sus capas: namespaces de Kubernetes, cloud *projects/accounts* (GCP/AWS/Azure), **Argo CD `AppProjects`**, y permisos por *owner* en Backstage (RBAC y plugin de permissions).
- **Deprecation policy** disciplinada: ciclo **anuncio → warn → remove** con **TTL** explícito; distinción **soporte / mantenimiento / legacy**; cómo deprecar un *template* del scaffolder sin romper flujos vivos.
- **Platform SLOs** del propio IDP: uptime de Backstage, latencia del scaffolder, *freshness* del software catalog, MTTR en incidentes de la plataforma. Cómo escribir SLIs/SLOs/*error budgets* y *burn-rate alerts* para la plataforma misma.
- **Release cadence** del equipo de plataforma: continuo con *feature flags* vs trimestral; cuándo elegir cada una.
- **Versionado de contratos**: XRDs de Crossplane, *templates* del scaffolder, APIs internas; **SemVer + changelog** como contrato, no como cortesía.
- **Inner-source** real: patrones de contribución desde equipos de producto al repo de plataforma, **CODEOWNERS**, SLAs de maintainers, escala *trusted-committer*.
- **Comunicación**: changelog público interno, canal de Slack, *office hours*, *lunch & learn* y por qué sin esto el valor de la plataforma se evapora.
- **Cuándo no construir plataforma**: equipo < 3, baja variabilidad, bajo volumen, o cuando el *overhead* supera al ahorro.
- **Maduración organizacional**: del Centro de Excelencia al platform team real; de "equipo que impone" a "equipo que facilita".

Lo que **no** cubre (ya se vio en módulos previos o queda fuera del curso):

- Construir el Backstage inicial → `plat-04`.
- Diseñar scorecards y métricas → `plat-10`, `plat-11`.
- Instrumentar DORA con eventos de CI/CD → `plat-11`.
- SRE puro (toil, oncall, postmortems clásicos) — se asume conocido.

Este módulo es **mayoritariamente conceptual**. No se levanta infraestructura. Las dos actividades son documentos de arquitectura: un **ADR de gobernanza** y un **plan de año uno** que defender contra tres escenarios.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-deprecation-policy-sample/` — política ejemplar de *deprecations*: ciclo, TTLs, clasificación soporte/mantenimiento/legacy, cadencia de comunicación y un caso completo (template Backstage v1 → v2).
  - `02-platform-slo-definition/` — definición concreta de SLOs: Backstage uptime, latencia del scaffolder, *catalog freshness*, MTTR. SLI, objetivo, cálculo de *error budget* y *burn-rate alerts*.
  - `03-inner-source-guidelines/` — guía de contribución *inner-source*: CODEOWNERS, expectativas de PR, SLAs de maintainers, *scope boundaries* y escala *trusted committer*.
- **`activities/`** — dos actividades **independientes** (sin dependencia entre sí):
  - `01-governance-adr/` — redactar un ADR de gobernanza cubriendo multi-tenancy, deprecation policy, SLOs, release cadence, versionado de contratos e inner-source.
  - `02-year-one-plan/` — redactar el **plan de año uno** de la plataforma, con breakdown trimestral y defensa contra 3 escenarios (crecimiento rápido, hiring freeze, consolidación post-merger).
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué una plataforma **sin SLO propio** es irresponsable con sus consumidores. Distinguir **soporte / mantenimiento / legacy** y defender un **TTL** de deprecation para cada estado. Nombrar las 4 capas donde se materializa el multi-tenancy. |
| Operativa (sin infra) | Dado un IDP ficticio con 50 servicios, 8 equipos y 3 regiones, proponer el **modelo de tenants** (namespaces, AppProjects, cloud projects, permisos Backstage) con fronteras claras. Diseñar un **changelog** para una XRD con breaking change. |
| Arquitectónica | Redactar un **ADR de gobernanza** con secciones de multi-tenancy, deprecations, SLOs, release cadence, versionado, inner-source, consecuencias y alternativas. Defender un **plan de año uno** contra 3 escenarios adversariales. |

## Criterios de evaluación

- Define, con sus propias palabras, qué es un **error budget** y por qué la plataforma misma debe tener uno.
- Articula un **ciclo de deprecation** completo con TTLs explícitos para cada estado.
- Describe los **4 planos** de multi-tenancy (K8s namespaces, cloud accounts, Argo CD AppProjects, Backstage permissions) sin confundirlos entre sí.
- Explica cómo el **inner-source** permite **escalar sin crecer el platform team linealmente**.
- Nombra al menos tres situaciones donde **no** construir plataforma es la respuesta correcta.
- Entrega las dos actividades con sus validadores estructurales en verde.
- Defiende su **plan de año uno** contra los 3 escenarios en una conversación de 30 min.

## Entregables

- **ADR de gobernanza** (`GOVERNANCE-ADR.md`) con las 9 secciones requeridas (sale de la actividad `01-governance-adr`).
- **Plan de año uno** (`YEAR-ONE-PLAN.md`) con breakdown Q1–Q4, defensa de 3 escenarios y métricas de éxito (sale de la actividad `02-year-one-plan`).
- Un conjunto de **SLOs definidos** para la propia plataforma (recogidos dentro del ADR, inspirados en `examples/02-platform-slo-definition/`).

## Siguiente módulo

Este es el **último módulo** del curso `platform-engineering`. No hay siguiente módulo dentro del curso. Las vías de continuación recomendadas son:

- Volver a `plat-11` y pulir el **dashboard DORA + canvas platform-as-product** con el aprendizaje de este módulo.
- Pasar al curso `opentelemetry` si aún no se ha hecho (`otel-01` en adelante) — el *observability* del propio IDP se construye con las mismas herramientas que recomiendas a tus equipos.
- Pasar al curso `sre-foundations` (si existe) para profundizar en *error budgets*, *toil* y *reliability engineering* más allá del contexto de plataformas internas.

El **cierre honesto** del curso: la plataforma nunca está "terminada". Está **operando**, **evolucionando** y **deprecando** al mismo tiempo. Este módulo te da el marco para que esa evolución no se vuelva ni jaula ni caos.
