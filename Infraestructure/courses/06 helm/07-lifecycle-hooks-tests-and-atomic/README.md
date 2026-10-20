# helm-07-lifecycle-hooks-tests-and-atomic — Lifecycle, hooks, tests y atomic

## Identificación

- **ID:** `helm-07-lifecycle-hooks-tests-and-atomic`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `helm-06-dependencies-and-umbrella-charts` (y por transitividad, los módulos previos del curso Helm).

## Objetivo

Controlar el ciclo de instalación y upgrade de un release con **hooks** (`pre-install`, `post-install`, `pre-upgrade`, `post-upgrade`, `pre-delete`, `post-delete`, `test`), diseñar **smoke tests** con `helm test`, y aplicar `--atomic` + `--wait` + `--timeout` para obtener **rollback automático** en pipelines de CD.

## Temas y subtemas

1. Modelo de hooks de Helm.
   - Los 7 tipos: `pre-install`, `post-install`, `pre-upgrade`, `post-upgrade`, `pre-delete`, `post-delete`, `test`.
   - Anotaciones (`helm.sh/hook`, `helm.sh/hook-weight`, `helm.sh/hook-delete-policy`).
   - Ordenamiento: por *weight* ascendente, luego por `kind` y nombre.
2. Delete policies.
   - `before-hook-creation` (default), `hook-succeeded`, `hook-failed`, `before-hook-creation,hook-succeeded` (idiom más usado).
3. Casos típicos de hook.
   - Migración de base de datos como `Job` `pre-upgrade,pre-install`.
   - Backup de base de datos antes de un upgrade mayor.
   - Limpieza (`post-delete`).
4. `helm test`.
   - Hook `test` + convención `templates/tests/`.
   - Pod efímero que ejerce el release y retorna 0/≠0.
5. Flags de install/upgrade que cambian el contrato.
   - `--wait` espera a que los recursos reporten `Ready`.
   - `--timeout` acota la espera.
   - `--atomic` = `--wait` + rollback automático en fallo.
   - `--cleanup-on-fail` elimina recursos nuevos creados por una revisión fallida.
6. Criterio hook vs `initContainer` vs operator.

## Conceptos internos (fundamentos)

- Los recursos declarados con `helm.sh/hook` **no son parte del release** en el sentido tradicional: no se incluyen en el "current manifest" tras éxito y, según la `hook-delete-policy`, pueden ser borrados del cluster. `helm get manifest <rel>` no los muestra; `helm get hooks <rel>` sí.
- Un hook es un **objeto Kubernetes normal** (Job, Pod, ConfigMap, …) con una anotación: Helm aplica el objeto, espera a que termine (en caso de Job/Pod), y continúa.
- `--atomic` compone dos primitivas: espera `--wait` (readiness de todos los recursos) y, si *cualquier* paso falla, ejecuta un `rollback` a la revisión previa (o `uninstall` si era la instalación #1).
- `--atomic` es el **default correcto en CI/CD**: un pipeline que no deja el cluster en estado parcial es la única garantía razonable sin intervención humana.

## Competencias

- **Conceptual:** distinguir hook vs recurso regular; explicar por qué `--atomic` combina espera y rollback.
- **Operativa:** declarar un `Job` de migración con `pre-install,pre-upgrade`, weight y delete-policy correctos; escribir un `helm test` que valide salud real; usar `--atomic --wait --timeout` en todos los `helm upgrade --install` de CI.
- **Arquitectónica:** justificar hook vs `initContainer` vs operator para un flujo dado (acoplamiento al release, idempotencia, paralelismo, blast radius).

## Ejemplos

- `examples/01-db-migration-hook/` — Chart mínimo con `Job` `pre-install,pre-upgrade` que simula una migración.
- `examples/02-helm-test-for-smoke/` — Chart con `templates/tests/test-connection.yaml` que ejerce el `Service` con `wget`.
- `examples/03-atomic-upgrade-flow/` — Demostración de `--atomic`: una revisión mala causa rollback automático y el cluster queda en la revisión previa.

## Actividades

- `activities/01-add-migration-hook-with-weight/` — Guided-lab: añadir hook de migración con weight y delete-policy a un chart existente; validador comprueba que el `Job` se ejecuta antes de los Pods del Deployment.
- `activities/02-write-helm-test-connection/` — Independent: el estudiante escribe `templates/tests/test-connection.yaml` que haga `wget` al `Service`; validador instala + corre `helm test` y asegura éxito.

## Entregables

- Chart con `Job` de migración declarado como hook `pre-install,pre-upgrade`.
- Chart con `helm test` de smoke que corre tras `helm install` y vuelve 0.
- Pipeline mental (o script) que usa `helm upgrade --install --atomic --wait --timeout 5m` como invocación por defecto.

## Criterios de evaluación

- **Conceptual:** explicar por qué una migración de esquema que *debe* bloquear al rollout entero es un buen candidato a hook, mientras que una tarea de warm-up específica de un Pod es un buen candidato a `initContainer`.
- **Operativa:** el `helm test` del entregable retorna 0 contra un release recién instalado en kind.
- **Arquitectónica:** defender por escrito el criterio hook vs `initContainer` vs operator para tres escenarios (migración de esquema, cache warming, failover de replica).

## Recursos

Ver `resources/links.md`.
