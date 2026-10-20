# tf-14 — Platform patterns, drift management y refactoring a escala

## Identificación

- **ID:** `tf-14-platform-patterns-drift-and-refactoring-at-scale`
- **Curso:** `terraform`
- **Nivel:** producción
- **Duración estimada:** 6 h
- **Prerrequisitos:** `tf-09-providers-deep-and-lifecycle`, `tf-11-remote-backends-and-locking`, `tf-12-testing-and-policy-as-code`, `tf-13-cicd-and-opentofu`.

## Objetivo

Operar Terraform como una **plataforma interna**: publicar módulos "golden" versionados, controlar drift de forma continua, refactorizar código a escala sin recrear recursos y definir el **contrato IaC** que gobierna la autonomía de los equipos de producto frente a los controles de la organización.

## Alcance

Este módulo cubre:

- **Module registry interno**: self-hosted con Git tags, Artifactory, o un registry nativo (TF Registry Protocol). SemVer de módulos.
- **Golden paths**: módulos opinionados por tipo de workload (p. ej. "microservicio EKS"), scaffolds (`cookiecutter`, Backstage templates).
- **Drift detection** continuo (job programado con `terraform plan -refresh-only`) y respuesta operativa: **reconcile** (aceptar el estado real), **adopt** (traer a HCL un cambio hecho fuera), o **revert** (re-aplicar lo declarado).
- **Import blocks** masivos para adoptar infra legada (`-generate-config-out`).
- `moved` + `removed` para renombrar/sacar recursos del state sin impacto.
- Estrategia de upgrade entre majors de providers (p. ej. AWS provider v4→v5).
- **Policy-as-code a escala**: biblioteca Rego compartida, versionada.
- **Gobernanza**: quién puede aprobar `apply` en producción, cómo se audita.

Lo que **no** cubre:
- Pipeline CI/CD de Terraform (ver `tf-13`).
- Testing nativo de módulos (ver `tf-12`).

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`**:
  - `01-internal-module-registry-via-git-tags/` — publicar y consumir un módulo versionado desde un bare git repo local (`git::file://...?ref=v1.0.0`), simulando un registry interno sin red.
  - `02-import-blocks-for-legacy-adoption/` — adoptar recursos existentes con `import {}` + `-generate-config-out`.
  - `03-moved-and-removed-refactor/` — renombrar y sacar recursos del state con `moved {}` y `removed {}` sin destruir.
- **`activities/`**:
  - `01-adopt-legacy-infra-via-import/` (guided-lab) — adoptar 3 recursos pre-existentes y terminar con un plan limpio.
  - `02-platform-contract-adr/` (independent, architecture) — redactar el ADR del contrato de plataforma IaC de una org ficticia.
- **`resources/links.md`** — referencias verificables.

## Conceptos internos (fundamentos)

- Un **módulo "golden" bien hecho** es **opinionado pero mínimo**. Si abstrae todo, se vuelve inflexible y los equipos lo evitan copiando a mano; si abstrae poco, no agrega valor sobre usar providers directamente. El sweet spot es: *fija las decisiones no negociables de la org* (naming, tags obligatorios, encryption, logging, políticas IAM mínimas) y *deja libres las decisiones de producto* (tamaños, replicas, variables de app).
- El **drift sistemático** rara vez es una limitación de Terraform; suele ser una **señal organizacional**: alguien tiene permisos de consola que no debería, un sistema externo (SCP, controller, operador K8s) modifica atributos sin coordinarse, o el módulo deja fuera algo que la gente necesita y "lo arregla a mano". La solución estructural es cerrar el permiso o incorporar el atributo al módulo, no `ignore_changes` eterno.
- `import {}` + `-generate-config-out` convierten "adoptar un recurso al state" en una operación con revisión en PR (no un comando mágico en una consola). Esta es la diferencia práctica frente al `terraform import` imperativo.
- `moved {}` y `removed {}` son **declaraciones del plan**, no modificaciones del state imperativas: viven en el código, pasan por review, y Terraform los interpreta durante `plan`. Esto los hace auditables y reversibles.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar cuándo un drift debe ser *reconciled*, *adopted* o *reverted*. Diferenciar `moved` de `terraform state mv`. Diferenciar `import {}` de `terraform import`. Justificar SemVer en módulos. |
| Operativa | Publicar un módulo con tag `v1.0.0`, consumirlo pinned, bumpear a `v1.1.0` sin romper consumers. Adoptar un conjunto de recursos legados con `import {}` + `-generate-config-out`. Refactorizar un stack con `moved` sin destroy+create. |
| Arquitectónica | Diseñar el **contrato de plataforma IaC** de una org: qué expone un golden module, qué queda libre, cómo se versiona, cómo se gobierna el apply en prod, qué se audita, qué métricas se miden. |

## Entregables

1. Módulo "golden" versionado y publicado en el registry local (ejemplo 01).
2. ADR del contrato de plataforma IaC (actividad 02).
3. Ejercicio de adopción de legacy infra completado (actividad 01) con plan limpio final.

## Criterios de evaluación

- El módulo golden tiene un README con inputs/outputs documentados, está tagueado con SemVer y se consume con `?ref=vX.Y.Z` (no `main`).
- El ADR enumera: scope del contrato, decisiones (al menos 5), trade-offs explícitos entre autonomía de dev y control de seguridad, SLOs de la plataforma (p. ej. "p95 time-to-prod para un nuevo microservicio", "% de stacks sin drift"), y métricas de éxito.
- La actividad de import termina con `terraform plan` reportando `No changes` sobre los tres recursos adoptados.
- Capacidad de **defender** el contrato: para cualquier regla ("no se puede desplegar sin pasar por el módulo X"), articular qué problema resuelve y qué libertad sacrifica.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-internal-module-registry-via-git-tags/` (es el fundamento operativo).
3. Reproduce `examples/02-import-blocks-for-legacy-adoption/`.
4. Reproduce `examples/03-moved-and-removed-refactor/`.
5. Haz la actividad `activities/01-adopt-legacy-infra-via-import/`.
6. Haz la actividad `activities/02-platform-contract-adr/` (es la que consolida la competencia arquitectónica).

## Siguiente

Este es el último módulo del curso de Terraform. El siguiente paso natural es aplicar el contrato al **capstone** del programa: la infra del proyecto final debe consumir al menos un golden module propio y defender su gobernanza.
