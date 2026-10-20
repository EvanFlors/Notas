# argo-05-sync-strategies-waves-and-hooks — Sync strategies, waves y hooks

## Identificación

- **ID:** `argo-05-sync-strategies-waves-and-hooks`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `argo-03-application-anatomy-sources-destinations-sync` (y por transitividad `argo-02`, `argo-01`). Conocimiento de `Deployment`, `Job`, `Namespace` en Kubernetes.

## Objetivo

Controlar el **cómo** y el **cuándo** del sync en Argo CD: elegir entre sync manual y automated (con `prune`, `selfHeal`, `allowEmpty`), aplicar **sync options** por entorno, ordenar recursos con **sync waves**, orquestar operaciones de ciclo de vida con **resource hooks** (`PreSync`, `Sync`, `PostSync`, `SyncFail`, `PostDelete`), y configurar **retry + backoff** para que el reconciliador tolere fallos transitorios sin aullar.

## Temas y subtemas

1. **Manual sync vs automated.**
   - `syncPolicy: {}` (manual) — el default.
   - `syncPolicy.automated.prune` — Argo CD borra recursos retirados del repo.
   - `syncPolicy.automated.selfHeal` — Argo CD revierte cambios manuales en el cluster.
   - `syncPolicy.automated.allowEmpty` — permite reconciliar hacia "sin recursos" sin bloquear.
2. **Sync windows** — ventanas de permitido/denegado (`allow` / `deny`) por `AppProject`, con `schedule` cron, `duration`, `applications`, `clusters`, `namespaces`, `manualSync`.
3. **Sync options** (en `syncPolicy.syncOptions` o anotación `argocd.argoproj.io/sync-options` por recurso):
   - `CreateNamespace=true`
   - `ApplyOutOfSyncOnly=true`
   - `ServerSideApply=true`
   - `RespectIgnoreDifferences=true`
   - `PruneLast=true`
   - `Validate=false`, `Replace=true`, `SkipDryRunOnMissingResource=true` (menciones).
4. **Sync waves** — anotación `argocd.argoproj.io/sync-wave: "<int>"` para ordenar recursos *dentro de una Application*.
5. **Resource hooks**:
   - `PreSync`, `Sync`, `PostSync`, `SyncFail`, `PostDelete`.
   - Anotación `argocd.argoproj.io/hook`.
   - `argocd.argoproj.io/hook-delete-policy`: `HookSucceeded`, `HookFailed`, `BeforeHookCreation`.
6. **Retry y backoff** — `syncPolicy.retry` con `limit`, `backoff.duration`, `backoff.factor`, `backoff.maxDuration`.
7. **Herramientas de operación** — `argocd app sync --dry-run`, `--prune`, `--force`, `--replace`, `argocd app sync -l app.kubernetes.io/instance=<app>`.

## Conceptos internos (fundamentos)

- **El reconciliador** del `application-controller` corre un loop: calcula desired (output del `repo-server` renderizando la fuente) vs live (lo que el API server devuelve) y produce un diff. `OutOfSync` dispara un sync si está `automated`; manual lo pone en espera.
- **Sync waves ordenan recursos de la misma Application**, no entre Applications (para eso están los `App-of-Apps`, `ApplicationSet` + sync waves, o `SyncWave` dentro del padre). Dentro de la wave, el orden es por `kind` (p. ej. `Namespace` < `CustomResourceDefinition` < `ServiceAccount` < `Role` < `Deployment`) y luego por nombre.
- **Hooks son recursos Kubernetes normales** (típicamente `Job`) con una anotación. Argo CD los *aplica*, espera a su completion (si es `Job`/`Pod`) y continúa según resultado. Los hooks `PreSync` ejecutan **antes** de la wave 0; `PostSync` **después** de que todos los recursos del sync reporten `Healthy`.
- **`selfHeal: true` revierte cambios manuales inmediatamente**. En producción, durante un incidente, un operador haciendo `kubectl scale` para contener fuego verá al segundo cómo Argo CD le pone los replicas originales. Es correcto por diseño; sorprende si no está documentado. Por eso suele apagarse en prod o acotarse con sync windows.
- **`prune: true` sin `PruneLast=true`** puede intentar borrar un recurso del que algo depende antes de que el replacement esté sano. `PruneLast=true` difiere la eliminación al final del sync, reduciendo blast radius en reconciliaciones amplias.
- **`ServerSideApply=true`** delega la fusión de campos al API server (SSA de Kubernetes). Es la opción recomendada hoy: evita el "last-applied-configuration" annotation bomb y maneja mejor campos gestionados por varios controllers.
- **Retry con backoff exponencial** es anti-flapping: ante errores transitorios (webhook de admisión lento, imagen aún no pulled), el controller no satura ni al cluster ni al operador humano con notificaciones.

## Competencias

- **Conceptual:** explicar cuándo activar `selfHeal` y cuándo no, por qué `PruneLast` existe, y qué garantiza (y qué no) un hook `PreSync` frente a un `initContainer`.
- **Operativa:** declarar una política de sync segura por entorno (prod: manual + approval; dev: auto + prune + selfHeal); añadir un hook `PreSync` para migración de BD con delete-policy correcta; ordenar recursos con sync waves para que la BD se cree antes que la app.
- **Arquitectónica:** diseñar la combinación de `AppProject` + sync windows + sync policies por ambiente para una organización multi-tenant; justificar las elecciones ante auditoría.

## Ejemplos

- `examples/01-automated-prune-selfheal/` — Application con `automated.prune=true`, `selfHeal=true` y `syncOptions` canónicas para dev.
- `examples/02-sync-waves-db-then-app/` — tres recursos (`Namespace`, `StatefulSet` que simula una BD, `Deployment` de la app) ordenados por `sync-wave` para que el `Deployment` sincronice **después** de que la "BD" esté sana.
- `examples/03-presync-migration-job/` — `Job` con anotación `argocd.argoproj.io/hook: PreSync` que debe completar antes de que el `Deployment` del app rote.

## Actividades

- `activities/01-prod-manual-dev-auto/` — Guided-lab: dadas dos Applications (`web-dev` y `web-prod`), el estudiante configura la primera con `automated` + `prune` + `selfHeal` + `CreateNamespace=true`, y la segunda con sync manual y un sync window que **deniega** auto-sync fuera de la ventana de release. Un validador comprueba las `spec.syncPolicy` resultantes y la existencia del sync window en el `AppProject`.
- `activities/02-add-migration-presync/` — Independent: el estudiante parte de un `Deployment` que apunta a una imagen que *requiere* un schema migrado y debe añadir un `Job` `PreSync` que corra `migrate up` antes del rollout. El validador instala la Application en un `AppProject` restringido, sincroniza, y verifica que el `Job` corre antes del `Deployment` y que la delete-policy es correcta.

## Entregables

- Dos Applications con políticas de sync diferenciadas por entorno (manifest + ADR corta justificando `selfHeal` on/off por entorno).
- App que ordena BD → migración (`PreSync`) → `Deployment` → smoke (`PostSync`) con sync waves y hooks demostrables en un cluster `kind`.

## Criterios de evaluación

- **Conceptual:** justificar en 3–5 bullets por qué `selfHeal` suele ir off (o acotado por sync window) en producción.
- **Operativa:** el entregable del lab 02 instala y sincroniza en kind con el `Job` corriendo antes del `Deployment`; el validador reporta OK.
- **Arquitectónica:** diseñar la combinación `syncPolicy + syncOptions + AppProject sync window` apropiada para un escenario dado (p. ej. "despliegues solo martes 10:00–12:00 UTC, con approval manual, retención de pruned resources por 24 h").

## Recursos

Ver `resources/links.md`.
