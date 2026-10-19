# jk-05 — Agents distribuidos y Kubernetes plugin

## Identificación

- **ID:** `jk-05-agents-distributed-builds-kubernetes-plugin`
- **Curso:** `jenkins`
- **Nivel:** intermedio
- **Duración estimada:** 3 h
- **Prerrequisitos:** `jk-02` (install + pipeline), curso **kubernetes** ≥ Nivel 2.

## Objetivo

Operar builds distribuidos con **agents efímeros**, especialmente en Kubernetes. Al terminar deberías poder modelar un `podTemplate` con uno o varios contenedores, consumirlo desde un `Jenkinsfile` declarative, y defender por qué cada build en un entorno limpio elimina la clase entera de bugs "funcionó ayer, no hoy".

## Alcance

Este módulo cubre:

- Tipos de agent en Jenkins: **permanent** (SSH, inbound JNLP), **ephemeral** (Docker por build), **cloud** (EC2/GCE/Azure plugins).
- Concepto de **node**, **label** y **executor**: cómo el controller distribuye trabajo.
- **Kubernetes plugin**: cada build spawnea un Pod con un contenedor `jnlp` (habla con el controller) + los contenedores que necesite tu build (`maven`, `node`, `kaniko`, `terraform`...).
- Dos formas de declarar el `podTemplate`: **global** (en la configuración del cloud) e **inline** (`agent { kubernetes { yaml '...' } }` dentro del `Jenkinsfile`).
- Problemas comunes: controller sobrecargado, agent timeouts, Pods *pending* por falta de capacity, imágenes grandes que ralentizan el pull.
- Comparación con **GitHub Actions Runner Controller (ARC)**: mismo patrón arquitectónico, distinto plano de control.
- Cuándo preferir ephemeral (siempre que se pueda) y cuándo mantener permanent (hardware específico, licencias atadas a nodo, GPU dedicada).

Lo que **no** cubre (se verá después):

- JCasC, Job DSL y gobierno de plugins → `jk-06`.
- Hardening, RBAC y credenciales → `jk-07`.
- Operación a escala y migración → `jk-08`.

Este módulo es **mayoritariamente conceptual + lab reproducible en kind + ADR**. El lab de `kind` es **opcional**: si `kind` no está disponible, los validadores recorren la actividad en modo estructural (YAML del pod + Jenkinsfile) y la saltan sin fallar.

## Materiales

- **`theory/lesson.md`** — lección con 10 secciones: tipos de agent, labels/executors, modelo del Kubernetes plugin, podTemplate inline vs global, multi-container, comparación con ARC, troubleshooting, criterios de elección.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución obligatoria):
  - `01-k8s-plugin-podtemplate/` — `podTemplate` mínimo con un solo contenedor de build y el `jnlp` sidecar.
  - `02-multi-container-agent/` — `podTemplate` con `maven` + `kaniko` + `jnlp`, invocados por nombre desde el pipeline.
  - `03-ephemeral-vs-permanent-tradeoffs/` — tabla de decisión con criterios de seguridad, reproducibilidad, coste y latencia.
- **`activities/`** — dos actividades **independientes**:
  - `01-run-pipeline-on-k8s-agent/` — definir `podTemplate.yaml` + `Jenkinsfile` que lo consume; validación estructural obligatoria, lab en `kind` opcional.
  - `02-arc-vs-jenkins-k8s-adr/` — ADR comparando **Kubernetes plugin de Jenkins** vs **ARC de GitHub Actions** para un equipo que ya corre K8s.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre agent permanente, efímero Docker y efímero K8s; por qué `jnlp` es el contenedor que habla con el controller; qué es un `label` y cómo rutear builds. |
| Operativa | Escribir un `podTemplate` multi-contenedor y consumirlo desde un `Jenkinsfile` declarative con `agent { kubernetes { yaml ... } }`. |
| Arquitectónica | Justificar ephemeral vs permanent con criterios de seguridad, reproducibilidad y coste. Comparar Kubernetes plugin con ARC y recomendar uno para un escenario concreto. |

## Criterios de evaluación

- Dado un `Jenkinsfile` con `agent { kubernetes { yaml ... } }`, identificar los contenedores del Pod y qué paso corre en cada uno.
- Explicar por qué el controller **no** debe ser también agent en prod.
- Nombrar 3 problemas típicos de un `podTemplate` mal dimensionado (requests/limits, image pull, timeouts).
- Entregar las dos actividades con sus validadores estructurales en verde.

## Entregables

- **`podTemplate.yaml` + `Jenkinsfile`** del lab `jk-05-01` validados estructuralmente.
- **ADR `ADR-ARC-VS-K8S-PLUGIN.md`** del lab `jk-05-02`.

## Costos

**Ninguno obligatorio.** El lab se diseña contra `kind` local; si no está disponible, se valida la estructura y se omite la ejecución. No se requiere cluster gestionado ni cuenta cloud.

## Siguiente módulo

→ `jk-06-plugins-jcasc-job-dsl-blue-ocean` — configuración como código del controller.
