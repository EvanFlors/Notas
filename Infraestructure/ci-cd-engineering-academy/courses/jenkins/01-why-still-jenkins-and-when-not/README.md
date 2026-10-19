# jk-01 — Por qué Jenkins sigue vivo y cuándo NO elegirlo

## Identificación

- **ID:** `jk-01-why-still-jenkins-and-when-not`
- **Curso:** `jenkins`
- **Nivel:** fundamentos
- **Duración estimada:** 2 h
- **Prerrequisitos:** curso **github-actions** (necesario para comparar modelos de CI/CD modernos).

## Objetivo

Entender por qué **Jenkins sigue siendo relevante** en 2026 —aunque pocos lo elijan para proyectos nuevos— y, sobre todo, **cuándo NO elegirlo**. El módulo entrena un criterio de decisión: Jenkins "gana por inercia", no por mérito técnico actual; evaluar "cambio de tooling" es, en realidad, evaluar **costo de migración vs costo de mantenerlo**. El entregable es un **ADR** justificado y una **estimación de costo** comparando ambos lados.

## Alcance

Este módulo cubre:

- **Historia resumida**: Hudson → fork a Jenkins en 2011; cómo esa herencia explica muchas rarezas de hoy (plugins, Groovy sandbox, freestyle vs pipeline).
- **Modelo mental**: controller + agents; `Jenkinsfile` (pipeline-as-code) vs freestyle legacy; `JENKINS_HOME` como "state blob" sin el que no se reproduce nada.
- **Por qué muchas enterprises siguen con Jenkins**:
  - Brownfield (miles de jobs ya escritos, equipos que los conocen).
  - Entornos **air-gapped** / on-prem donde SaaS CI no entra por compliance.
  - Flexibilidad extrema (plugin para casi todo).
  - **Enterprise support** de CloudBees.
  - Jenkins migrado a Kubernetes vía Kubernetes plugin — sigue siendo opción válida.
- **Comparación brutal** con GitHub Actions, GitLab CI, Argo Workflows, Tekton: UX, mantenimiento, seguridad, ecosystem, operaciones.
- **Cuándo NO elegir Jenkins para un proyecto nuevo**:
  - Greenfield cloud-native (sin deuda previa).
  - Expectativa de DX tipo SaaS (editor web, previsualización, marketplace moderno).
  - Equipo pequeño que no quiere mantener un controller.
  - Workloads 100% K8s-native (Argo Workflows / Tekton suelen encajar mejor).
- **Framework de decisión de migración**: inventario, clasificación (migrar / consolidar / retirar), dual-run, OIDC federation, criterios de salida; se profundiza en `jk-08`, aquí se **adopta como marco** para el ADR.

Lo que **no** cubre (se verá después):

- Instalación y primer pipeline → `jk-02`.
- Declarative Pipeline y `Jenkinsfile` detallado → `jk-03`.
- Shared Libraries → `jk-04`.
- Agents / Kubernetes plugin → `jk-05`.
- JCasC / plugins / Blue Ocean → `jk-06`.
- Seguridad y RBAC → `jk-07`.
- Operar en producción y ejecutar la migración → `jk-08`.

Este módulo es **enteramente conceptual + ADR + análisis de costo**. **No** se instala Jenkins. **No** se corre pipeline alguno. Las dos actividades son documentos escritos y validados estructuralmente. El único *tooling* es `bash`, `python3` y un editor Markdown.

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones: historia, modelo mental, por qué sigue vivo, comparación con 4 alternativas, cuándo NO elegirlo, framework de decisión migración.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-jenkins-vs-gha-vs-gitlab-vs-argo/` — tabla comparativa densa por dimensiones (UX, operación, seguridad, costo, extensibilidad, ecosistema).
  - `02-brownfield-vs-greenfield-decision/` — árbol de decisión narrado para "¿seguir con Jenkins, migrar, o greenfield directo a X?".
- **`activities/`** — dos actividades **independientes**:
  - `01-when-not-jenkins-adr/` — escribir un **ADR** de migración (framework "sí/no/más tarde") para un escenario dado.
  - `02-jenkins-cost-estimate/` — producir una **estimación de costo** comparando mantener vs migrar (horas + USD anuales) con tabla y análisis.
- **`resources/links.md`** — fuentes oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué parte de Jenkins es herencia histórica y qué parte sigue siendo valor real; distinguir pipeline-as-code de freestyle y por qué el segundo es anti-patrón hoy. |
| Operativa (sin infra) | Comparar Jenkins contra GHA/GitLab/Argo por dimensiones concretas; justificar o rechazar una propuesta "todo a Jenkins" o "fuera Jenkins ya" con argumentos. |
| Arquitectónica | Diseñar un ADR de migración (contexto, decisión, consecuencias, alternativas, rollback) y una estimación de costo anualizada con criterios claros. |

## Criterios de evaluación

- Dado un escenario de empresa (greenfield vs brownfield, tamaño de equipo, compliance, cloud vs on-prem), **recomendar** Jenkins / migrar / híbrido con justificación.
- Nombrar **3 razones legítimas** por las que una enterprise sigue con Jenkins en 2026.
- Nombrar **3 escenarios** en los que elegir Jenkins hoy es un error.
- Enumerar los **pasos del framework de migración** (inventario, clasificación, dual-run, OIDC, retirada).
- Entregar las dos actividades con los validadores estructurales en verde.

## Entregables

- **ADR** `ADR-JENKINS-DECISION.md` para el escenario asignado (sale de la actividad `01`).
- **Estimación** `COST-ESTIMATE.md` con tabla de horas y USD anuales, break-even de migración, y recomendación final (sale de la actividad `02`).

## Costos

**Ninguno.** Todo el módulo se desarrolla localmente contra archivos de texto. No se requiere cuenta en nube, ni Jenkins instalado, ni cluster alguno. Si en una fase posterior decides provisionar lo analizado:

- **Jenkins open source**: gratis (software); el coste es el **controller + agents + personas**.
- **CloudBees CI**: licencia enterprise, pricing por tier (no cubierto aquí).
- **GitHub Actions**: minutos gratis + pricing por minuto adicional.
- **GitLab CI SaaS**: minutos gratis por tier.
- **Argo Workflows / Tekton**: gratis (software); el coste es el cluster K8s.

## Siguiente módulo

→ `jk-02-install-ui-freestyle-vs-pipeline` — instalar Jenkins con Docker, recorrer la UI, hacer "hello world" en freestyle y en pipeline, e identificar por qué todo nuevo en 2026 debe ser pipeline.
