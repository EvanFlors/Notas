# Lección — Sync strategies, waves y hooks en Argo CD

> **Tiempo estimado de lectura:** 60–75 min. Prosa en español, bloques de código y campos de API en inglés (tal como aparecen en la CRD de Argo CD).

Argo CD no es "un `kubectl apply` continuo". Es un reconciliador con un modelo de **política de sync**, **orden** y **ciclo de vida** que decide qué, cuándo y en qué orden hacer `apply` cuando `desired != live`. Esta lección cubre esos tres ejes y las palancas asociadas: `syncPolicy`, `syncOptions`, `sync-wave`, `hook`, sync windows y `retry`.

---

## 1. El reconciliation loop en 90 segundos

El `application-controller` corre un loop por cada `Application`. En cada iteración:

1. Pide al `repo-server` que **renderice** el manifest desde la fuente (`spec.source` o `spec.sources`): si es Helm hace `helm template`, si es Kustomize hace `kustomize build`, si es plain YAML lo copia tal cual. Resultado: lista de objetos "desired".
2. Pide al API server la versión **live** de esos objetos (y detecta huérfanos si está configurado).
3. Calcula un **diff** campo a campo, con exclusiones (`spec.ignoreDifferences`, `argocd.argoproj.io/compare-options`) y modo de merge (client-side vs server-side).
4. Marca `syncStatus` ∈ {`Synced`, `OutOfSync`, `Unknown`} y `health` ∈ {`Healthy`, `Progressing`, `Degraded`, `Suspended`, `Missing`, `Unknown`}.
5. Si está `automated` y el estado es `OutOfSync`, dispara un **sync**: aplica recursos **en el orden** que determine *sync waves* y *hooks*. Si está en manual, se queda a la espera de un `argocd app sync` o un click en la UI.

Dos ideas que vale la pena anclar antes de seguir:

- **Sync** ≠ **health**. Un recurso puede estar `Synced` pero `Degraded` (p. ej. un `Deployment` con `replicas: 3` pero sólo 1 pod `Ready` por `CrashLoopBackOff`); y puede estar `OutOfSync` pero `Healthy` (el runtime está sano, simplemente no refleja el repo todavía).
- **Argo CD no es Helm**. No hace `helm install`; hace `helm template | kubectl apply`. Esto significa que **los hooks de Helm no se ejecutan** bajo Argo CD. Para ciclo de vida: usar los hooks *de Argo CD* (siguiente sección).

---

## 2. Manual sync vs automated sync

El bloque clave vive en `spec.syncPolicy`.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: web-dev
spec:
  project: dev
  source:
    repoURL: https://github.com/acme/infra
    path: envs/dev/web
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: web-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
      - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

Si **omites `automated:`**, Argo CD **no sincroniza solo**. Un `OutOfSync` se queda ahí hasta que alguien lo apruebe. Es el default seguro para producción.

Sub-flags de `automated`:

- **`prune: true`** — Argo CD **borra** del cluster los recursos que ya no existen en Git. Sin esto, borrar un `Deployment` del repo deja el `Deployment` corriendo indefinidamente ("drift silencioso"). Con esto, es importante entender que renombrar un recurso = borrar + crear.
- **`selfHeal: true`** — ante drift en el cluster (p. ej. alguien hizo `kubectl edit`), Argo CD **revierte** inmediatamente al estado del repo. Muy útil en dev. Debatido en prod: durante un incidente, un operador tocando `replicas` para contener fuego verá cómo Argo CD le pone los replicas del repo. Mitigación: apagar `selfHeal` en prod, o acotar con sync windows, o combinar con una ventana de mantenimiento donde `selfHeal` sí esté activo.
- **`allowEmpty: true`** — permite que la Application sincronice a "sin recursos" (p. ej. un path que quedó vacío). Default `false` para proteger contra "`git mv` accidental que vacía la carpeta". Normalmente se deja `false`.

Un patrón **muy habitual** por entorno:

| Entorno | `automated` | `prune` | `selfHeal` | `allowEmpty` | Sync window |
|---------|-------------|---------|------------|--------------|-------------|
| dev     | sí          | sí      | sí         | no           | 24/7 allow  |
| stg     | sí          | sí      | no         | no           | 24/7 allow  |
| prod    | no (manual) | n/a     | n/a        | n/a          | allow en ventana de release, deny fuera |

---

## 3. Sync windows (ventanas de mantenimiento)

Viven en `AppProject`, no en `Application`. Permiten decir "sincroniza solo martes 10:00–12:00 UTC" o "deniega auto-sync fuera de horario laboral", a nivel de proyecto completo o filtrando `applications`, `clusters`, `namespaces` con globs.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: prod
  namespace: argocd
spec:
  sourceRepos: ["https://github.com/acme/infra"]
  destinations:
    - server: https://kubernetes.default.svc
      namespace: web-prod
  syncWindows:
    - kind: allow
      schedule: "0 10 * * 2"      # martes 10:00
      duration: 2h
      applications: ["web-prod"]
      manualSync: true
    - kind: deny
      schedule: "* * * * *"
      duration: 24h
      applications: ["web-prod"]
      manualSync: false
```

Interpretación: por default, deny; dentro de la ventana `allow`, se puede sincronizar (y `manualSync: true` permite al operador forzar un sync incluso dentro de deny, útil para hotfixes).

Las sync windows son la palanca que convierte "Argo CD en producción" en algo auditable: cada sync queda registrado y existe una política explícita sobre cuándo puede ocurrir.

---

## 4. Sync options

Controlan **cómo** se hace el apply. Van en `spec.syncPolicy.syncOptions` (Application-wide) o en la anotación `argocd.argoproj.io/sync-options` por recurso (más granular). Las más relevantes:

- **`CreateNamespace=true`** — Argo CD crea el namespace de destino si no existe. Sin esto, el primer sync falla con "namespace not found". Es idiomático activarlo salvo que el namespace lo gestione *otra* Application (patrón "namespace-as-code").
- **`ApplyOutOfSyncOnly=true`** — solo aplica los recursos que el diff marca como `OutOfSync`. Más rápido en Applications grandes y reduce ruido en los event logs del cluster.
- **`ServerSideApply=true`** — usa Server-Side Apply (SSA) de Kubernetes en vez de client-side. SSA delega la fusión al API server y evita la bomba del `last-applied-configuration` annotation (que puede sobrepasar el límite de 1 MiB en recursos grandes). **Recomendado por defecto** en instalaciones modernas (K8s ≥ 1.22).
- **`RespectIgnoreDifferences=true`** — hace que `spec.ignoreDifferences` también se respete durante el *sync* (no solo durante el diff). Sin esto, Argo CD podría "corregir" el campo ignorado al aplicar.
- **`PruneLast=true`** — difiere las eliminaciones al final del sync. Útil cuando un recurso nuevo depende de que algo viejo siga vivo hasta el último momento (p. ej. migrar un `Service` sin cortar tráfico mientras los pods viejos aún existen).
- **`Validate=false`** — salta la validación OpenAPI client-side. Útil para CRDs instalados en el mismo sync (chicken-and-egg: la CRD aún no existe cuando se valida un CR).
- **`Replace=true`** — hace `kubectl replace` en vez de `apply`. Rara vez necesario; útil para campos inmutables.
- **`SkipDryRunOnMissingResource=true`** — útil combinado con CRDs recién instaladas.

Las opciones se combinan como lista:

```yaml
syncOptions:
  - CreateNamespace=true
  - ServerSideApply=true
  - ApplyOutOfSyncOnly=true
  - PruneLast=true
```

A nivel de recurso individual, se puede anular con la anotación:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-options: Prune=false,SkipDryRunOnMissingResource=true
```

---

## 5. Sync waves — ordenar recursos dentro de una Application

Por default, Argo CD aplica los recursos en un orden canónico por `kind` (p. ej. `Namespace` → `NetworkPolicy` → `ResourceQuota` → `LimitRange` → `PodSecurityPolicy` → `Secret` → `ConfigMap` → `StorageClass` → `PersistentVolume` → `PersistentVolumeClaim` → `ServiceAccount` → `CustomResourceDefinition` → `ClusterRole` → `ClusterRoleBinding` → `Role` → `RoleBinding` → `Service` → `DaemonSet` → `Pod` → `ReplicationController` → `ReplicaSet` → `Deployment` → `HorizontalPodAutoscaler` → `StatefulSet` → `Job` → `CronJob` → `Ingress` → `APIService`). Para la mayoría de apps esto es suficiente.

Para control fino se usa la anotación:

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-5"
```

Reglas:

- Los recursos con **wave menor** se aplican primero.
- Dentro de la misma wave, se usa el orden canónico por `kind`.
- Argo CD **espera a que todos los recursos de la wave sean `Healthy`** antes de pasar a la siguiente.
- El default es wave `0`.
- Weights **negativos** son idiomáticos para "early" (BD, migraciones), **positivos** para "late" (ingress, smoke).

Ejemplo canónico "BD → app → ingress":

```yaml
# db-statefulset.yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-10"
---
# app-deployment.yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"
---
# ingress.yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "10"
```

Importante: sync waves **ordenan dentro de una Application**. Para ordenar *entre* Applications se usa `App-of-Apps` con sync waves en los `Application` padres, o `ApplicationSet` con `strategy` progresivo (ver `argo-07`).

---

## 6. Resource hooks — ciclo de vida del sync

Un **hook** es un recurso Kubernetes normal (típicamente `Job`, también `Pod`) marcado con la anotación `argocd.argoproj.io/hook: <tipo>`. Argo CD lo trata diferente: no cuenta para el diff del "desired state", se ejecuta en un momento específico del ciclo de sync y, según la delete-policy, se limpia después.

Tipos:

| Hook        | Cuándo corre                                                              | Si falla                                                                                    |
|-------------|---------------------------------------------------------------------------|---------------------------------------------------------------------------------------------|
| `PreSync`   | **Antes** de aplicar los recursos del sync (antes de wave 0 efectivo).    | El sync aborta; se marca `Failed`; se ejecutan hooks `SyncFail` si los hay.                 |
| `Sync`      | **Durante** el apply, en el mismo paso que los recursos regulares.        | El sync aborta.                                                                             |
| `Skip`      | Marca un recurso para **no** aplicarlo (útil para selección condicional). | n/a                                                                                         |
| `PostSync`  | **Después** de que todos los recursos reporten `Healthy`.                 | Marca el sync como `Failed` aunque los recursos estén sanos (útil para smoke que debe pasar).|
| `SyncFail`  | Si el sync falla por cualquier motivo (incluye `PreSync`/`Sync`).         | n/a (se usa para notificar o limpiar).                                                      |
| `PostDelete`| Al **eliminar** la Application (requiere Argo CD ≥ 2.10).                 | Impide finalización limpia; útil para desaprovisionar externos (BDs, DNS).                  |

Un hook de migración de BD canónico:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: migrate
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: migrate
          image: ghcr.io/acme/migrator:1.4.2
          command: ["sh", "-c", "echo migrating; sleep 2; echo done"]
```

Puntos finos:

- **`backoffLimit: 0`** evita que un `Job` fallido reintente dentro del propio `Job`. El retry debe ocurrir **a nivel de sync** (ver sección 8), no dentro del hook, para que Argo CD lo registre correctamente.
- **`restartPolicy: Never`** — necesario en `Pod`/`Job` para hooks; `Always` no tiene sentido en batch.
- Los hooks **no son parte del release** desde el punto de vista del "desired state". No aparecen en `argocd app manifests`; sí aparecen en los eventos de sync.

### Delete policies

Anotación `argocd.argoproj.io/hook-delete-policy`:

- **`BeforeHookCreation`** (default): borra el hook anterior justo antes de crear uno nuevo. Garantiza idempotencia al re-sincronizar.
- **`HookSucceeded`**: borra el hook una vez que termina con éxito. Ideal para no acumular `Job` completos; combina bien con `BeforeHookCreation`.
- **`HookFailed`**: borra el hook si falla (perderás los logs — raramente deseable).

El idiom más usado:

```yaml
argocd.argoproj.io/hook-delete-policy: BeforeHookCreation,HookSucceeded
```

Significa: "si el hook anterior aún existe, bórralo antes de crear el nuevo; si el nuevo hook completa con éxito, bórralo también". Si falla, se queda in situ y puedes `kubectl logs job/migrate` para depurar.

### Hooks + sync waves

Los hooks también respetan `sync-wave`. Dentro de la fase `PreSync` puedes ordenar varios hooks (p. ej. `backup` wave `-20`, `migrate` wave `-10`). Argo CD ejecuta en orden: `PreSync` por waves → `Sync` por waves → `PostSync` por waves.

---

## 7. Hook vs sync wave vs initContainer — cuándo cuál

Pregunta frecuente. Reglas de oro:

- **`initContainer`** — para preparar el **pod** (warm-up, descarga de assets, chequeo de dependencias que no bloquean a OTROS pods). Corre por réplica, en paralelo con los demás pods del rollout.
- **Sync wave** — para forzar un orden entre **recursos de la misma Application** sin bloquear el sync (p. ej. `Namespace` antes que `Deployment`). No ejecuta lógica, solo ordena apply.
- **Hook (`PreSync` Job)** — para ejecutar lógica **una vez por sync** que debe completar antes de que **ningún** pod nuevo arranque (migraciones de esquema, seeding, backups pre-release). Bloquea.

Caso de prueba: "migración de esquema de BD".

- `initContainer` ❌: la migración correría una vez por pod. Para `replicas: 3`, tres migraciones compitiendo. Mal.
- Sync wave ❌: ordena pero no ejecuta nada; el `Job` seguiría corriendo en paralelo con el `Deployment`.
- Hook `PreSync` ✅: una ejecución, bloqueante, antes del rollout. Si falla, el `Deployment` no se toca y el cluster sigue en estado previo. Ganador.

---

## 8. Retry y backoff

```yaml
spec:
  syncPolicy:
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

Semántica: hasta `limit` reintentos; el *delay* entre intentos es `duration * factor^(intento)`, acotado por `maxDuration`. Con los valores del ejemplo: 5s, 10s, 20s, 40s, 80s (y luego cap a 3 min).

Casos donde el retry es la diferencia entre "sync verde" y "pager a las 3 AM":

- Imagen aún no está pulled porque el registry va lento → retry.
- Webhook de admisión temporalmente caído → retry.
- `CRD` recién instalada aún no reconocida por el API server → retry.

Lo que **no** arregla:

- Un YAML inválido. Es error permanente; el retry solo lo repetiría.
- Una política de admisión que *siempre* rechaza. Idem.

---

## 9. Operación: `argocd app sync` útil del día a día

El sync no es solo "pulsa el botón". El CLI tiene palancas para control fino:

- `argocd app sync <app> --dry-run` — simula el sync, muestra el diff resultante, no toca el cluster.
- `argocd app sync <app> --prune` — fuerza prune aunque la política no lo tenga activo (útil para limpieza puntual).
- `argocd app sync <app> --force` — equivale a `kubectl replace --force` (recrear). Último recurso.
- `argocd app sync <app> --replace` — SSA replace.
- `argocd app sync <app> --resource Deployment:web` — sincroniza solo un recurso específico.
- `argocd app sync <app> -l app.kubernetes.io/instance=web` — por label selector.
- `argocd app sync <app> --async` — no bloquea esperando a `Healthy`.
- `argocd app rollback <app> <history-id>` — revierte a una revisión anterior conocida (`argocd app history <app>` para listar).

Combinación útil en CI que *valida* sin aplicar:

```sh
argocd app sync web-prod --dry-run --local . --loglevel info
```

---

## 10. Política de sync por entorno — patrón recomendado

Juntando todo lo anterior, un patrón defendible:

**Dev** — iteración rápida, zero fricción:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
    - ApplyOutOfSyncOnly=true
  retry:
    limit: 5
    backoff: {duration: 5s, factor: 2, maxDuration: 3m}
```

**Staging** — como dev pero sin `selfHeal` (el equipo QA necesita poder tocar y observar):

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: false
  syncOptions:
    - CreateNamespace=true
    - ServerSideApply=true
  retry: {limit: 3, backoff: {duration: 10s, factor: 2, maxDuration: 5m}}
```

**Prod** — manual con approval + sync window estrecha:

```yaml
# Application: sin automated
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=false   # NS gestionado por otra Application
      - ServerSideApply=true
      - PruneLast=true
      - RespectIgnoreDifferences=true
    retry: {limit: 2, backoff: {duration: 30s, factor: 2, maxDuration: 5m}}
```

Más la ventana en el `AppProject prod` (ver sección 3) permitiendo sync solo en el slot de release.

Este patrón se discute explícitamente en la ADR del entregable del lab 01.

---

## 11. Antipatrones y trampas conocidas

- **`selfHeal: true` + operador haciendo `kubectl edit` durante incidente** — Argo CD revierte en segundos; el operador se vuelve loco. Mitigación: política de "si tocas, abre un sync window `deny` primero" o apagar `selfHeal` en prod.
- **`prune: true` + `ApplicationSet` buggy que genera 0 Applications** — borra TODO. `allowEmpty: false` (default) protege, pero verifica tu generator.
- **Hook `PreSync` con `backoffLimit > 0`** — Argo CD cree que terminó bien antes de tiempo, o se confunde con los reintentos. Deja `backoffLimit: 0` y maneja retries en `syncPolicy.retry`.
- **Hooks de Helm esperados dentro de Argo CD** — no corren. Argo CD hace `helm template`, no `helm install`. Migrar a hooks de Argo CD.
- **Sync wave esperando a algo que nunca estará `Healthy`** — Argo CD se queda bloqueado en la wave. Debug con `argocd app get <app>` y mirando qué recurso está `Progressing`.
- **Sync window `deny` olvidado** — "nada se despliega", mucho tiempo buscando por qué. `argocd app get` incluye el estado del window; chequearlo primero.
- **`PruneLast=true` sin `prune: true`** — no hace nada. `PruneLast` es un modificador de `prune`.
- **CRD + CR en el mismo sync, sin `SkipDryRunOnMissingResource`** — falla la validación. Añadir la opción al CR.

---

## 12. Resumen — mapa mental

```
Application
├── spec.syncPolicy
│   ├── automated: {prune, selfHeal, allowEmpty}   ← política automática
│   ├── syncOptions: [CreateNamespace, SSA, ...]   ← cómo se aplica
│   └── retry: {limit, backoff}                    ← resiliencia a transitorios
│
├── spec.source(s) → repo-server renderiza manifests
│                     ├── recursos con sync-wave  ← orden intra-app
│                     └── recursos con hook       ← ciclo de vida
│                           PreSync → Sync → PostSync (SyncFail en error)
│                           + hook-delete-policy
│
└── spec.project → AppProject
                    └── syncWindows: allow/deny    ← cuándo se puede sincronizar
```

Decisiones a tomar explícitas:

1. ¿Automated o manual? → **por entorno**.
2. ¿Prune? → casi siempre sí (si no, drift silencioso al borrar).
3. ¿SelfHeal? → **sí en dev**, **debatible en stg**, **no en prod** (o con sync windows).
4. ¿Sync windows? → **sí en prod**, redundante en dev.
5. ¿Hooks `PreSync`? → sí para migraciones, backups, seeds que deben pasar antes del rollout.
6. ¿Retry? → siempre, 3–5 intentos con backoff exponencial corto.
7. ¿SSA? → sí por defecto en K8s moderno.

Lo que sigue en `argo-06` es cómo encajar todo esto con `AppProject` para RBAC real y boundaries de equipo.
