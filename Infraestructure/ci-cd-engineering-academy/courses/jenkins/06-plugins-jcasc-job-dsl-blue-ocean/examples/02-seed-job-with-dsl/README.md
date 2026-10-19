# Ejemplo 02 — Seed job con Job DSL

Objetivo: ver cómo un único *seed job* genera múltiples jobs reales usando Job DSL.

Este ejemplo **no se ejecuta**. Es material de lectura y análisis.

## Archivos

- `seed-jobs.groovy` — DSL que crea un `folder`, dos `pipelineJob` y un `multibranchPipelineJob`.

## Patrón

1. En `jenkins.yaml` (ver ejemplo 01) hay un `pipelineJob('seed')` que ejecuta este script.
2. Al correr el seed, Job DSL interpreta el `.groovy` y crea/actualiza los jobs listados.
3. Jobs no listados en el DSL quedan en estado "huérfano" (configurable: eliminar, deshabilitar, ignorar).

## Qué genera

| DSL | Resultado |
|-----|-----------|
| `folder('legacy')` | Carpeta `legacy/` para agrupar jobs heredados. |
| `pipelineJob('legacy/batch-nightly')` | Pipeline con `Jenkinsfile` desde Git, trigger cron. |
| `pipelineJob('legacy/manual-release')` | Pipeline con parámetro, sin trigger (manual). |
| `multibranchPipelineJob('product/checkout')` | Multibranch sobre un repo GitHub. Autoconfigura ramas con `Jenkinsfile`. |

## Diferencia vs Multibranch "a mano"

- Un *Multibranch Pipeline* creado a mano por UI vive solo en el `$JENKINS_HOME`.
- El mismo *Multibranch Pipeline* definido por Job DSL vive en Git como código, se recrea si borras el `$JENKINS_HOME`, y se revisa por PR.

## Cuándo usar `pipelineJob` vs `multibranchPipelineJob`

- `pipelineJob`: un único job apuntando a una rama concreta de un repo. Útil para jobs operativos o legacy sin convención de branching.
- `multibranchPipelineJob`: un job por rama que tenga `Jenkinsfile`. Lo moderno para repos de producto.
