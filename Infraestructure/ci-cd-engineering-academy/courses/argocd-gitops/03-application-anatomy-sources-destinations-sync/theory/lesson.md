# Lección — Anatomía de la `Application` de Argo CD

> 12 secciones. Léelo entero una vez antes de ir a ejemplos y actividades.

---

## 1. Qué es `Application` y dónde vive

`Application` es un **Custom Resource** del grupo `argoproj.io`, versión `v1alpha1`. Es un objeto Kubernetes como cualquier otro:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: capstone-api-dev
  namespace: argocd            # SIEMPRE en el namespace donde corre Argo CD
spec:
  project: default
  source:
    repoURL: https://github.com/acme/capstone-infra.git
    path: envs/dev/api
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: capstone-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Dos cosas que suelen sorprender:

1. **El `Application` vive en el namespace de Argo CD** (típicamente `argocd`), *no* en el namespace donde se despliega la app. El `destination.namespace` dice dónde se *aplican los recursos*; `metadata.namespace` dice dónde *vive el Application CR mismo*.
2. Argo CD trata `Application` como la unidad de reconciliación. El `application-controller` escucha estos CRs, obtiene manifests del `repo-server`, los compara con el estado real del cluster target, y actúa.

La versión del `apiVersion` (`v1alpha1`) suena a inmaduro, pero es estable *de facto* y así se mantendrá por compatibilidad; no esperes un `v1` próximo.

---

## 2. `spec.source` — de dónde salen los manifests

```yaml
spec:
  source:
    repoURL: https://github.com/acme/capstone-infra.git
    path: envs/dev/api
    targetRevision: main
```

Tres campos obligatorios:

| Campo | Qué dice | Detalles |
|-------|----------|----------|
| `repoURL` | Repo Git (https o ssh) o repo Helm/OCI | Debe estar registrado en Argo CD (`argocd repo add` o declarativo). Repos públicos no requieren credenciales. |
| `path` | Carpeta dentro del repo | Argo CD renderiza *todo* lo que esté en esa carpeta (recursive por defecto). Puede ser `.` para repo entero. |
| `targetRevision` | Qué ref/tag/commit obtener | Branch (`main`), tag (`v1.4.2`), commit SHA (`a1b2c3d`), o `HEAD`. **Elección crítica** (ver §4). |

Campos adicionales según tipo de fuente (plain YAML, Helm, Kustomize, Jsonnet) se verán en `argo-04`. Esta lección se queda en el caso "directory".

### 2.1 Qué hace Argo CD con `source`

- El `repo-server` clona el repo (o usa su caché), hace checkout de `targetRevision`, entra en `path`, y renderiza manifests.
- Devuelve YAML planos al `application-controller`.
- Esto implica: el `repo-server` necesita conectividad al repo; Argo CD **no clona el repo en el `application-controller`**. Es un detalle de arquitectura que facilita cachear por repo+ref.

---

## 3. `spec.destination` — a qué cluster y namespace

```yaml
destination:
  server: https://kubernetes.default.svc
  namespace: capstone-dev
```

| Campo | Qué significa |
|-------|---------------|
| `server` | URL del API server del cluster target. `https://kubernetes.default.svc` es "este mismo cluster" (in-cluster). |
| `name` | Alternativa a `server`: nombre lógico de un cluster registrado. Útil para no hardcodear URLs. **No uses `server` y `name` al mismo tiempo**. |
| `namespace` | Namespace donde se aplican los recursos **que no definan su propio `metadata.namespace`**. Si el YAML del repo trae namespace explícito, ese gana (y puede causar sorpresas en multi-namespace Applications). |

Si el namespace no existe, Argo CD *no* lo crea por defecto — hay que o crearlo aparte, o usar el sync option `CreateNamespace=true` (§6.4).

### 3.1 Clusters externos

Registrar un cluster adicional:

```bash
argocd cluster add my-prod-context
```

Esto crea un `Secret` en el namespace `argocd` con `type: Opaque` y label `argocd.argoproj.io/secret-type: cluster`. Multi-cluster se profundiza en `argo-08`.

---

## 4. `targetRevision` — la trampa de `HEAD`

Este es el tema que más errores causa en los primeros meses de GitOps.

### 4.1 Qué significa cada valor

- **Branch** (`main`, `release/1.4`, `dev`): "el commit más reciente de este branch". Mutable: cuando alguien mergea, Argo CD se entera y sincroniza.
- **Tag** (`v1.4.2`): "este commit, el que el tag apunta". **Semánticamente inmutable** por convención, pero técnicamente alguien puede mover un tag (`git tag -f`) — nunca lo hagas.
- **Commit SHA** (`a1b2c3d4...`): "exactamente este commit". Realmente inmutable (si cambia el contenido, cambia el SHA).
- **`HEAD`**: "lo que esté en el branch default del repo *ahora*". Si el `default branch` del repo es `main`, equivale a `main`; si alguien cambia el default a `develop`, Argo CD empieza a seguir `develop` sin avisar.

### 4.2 Por qué `HEAD` es trampa

```yaml
# TRAMPA — no uses esto para "producción"
targetRevision: HEAD
```

Problemas:

1. **Depende del branch default del repo** — un cambio administrativo en GitHub puede mover tu "producción" sin PR, sin aprobación, sin trazabilidad.
2. **Oculta la intención**: leyendo el manifiesto no sabes de qué branch realmente despliegas.
3. **Rompe el modelo mental** "cada ambiente apunta a un ref conocido".

Donde `HEAD` *puede* usarse legítimamente: en apps "sandbox" muy efímeras, o en pruebas locales. En producción, nunca.

### 4.3 Criterio por caso

| Caso de uso | `targetRevision` recomendado |
|-------------|------------------------------|
| Ambiente `dev` que se mueve con cada merge | **Branch** (`main` o `dev`) |
| Ambiente `prod` que se promueve por release | **Tag** (`v1.4.2`) |
| Artefacto reproducible (post-mortem, bisect) | **Commit SHA** completo |
| Preview environment por PR | **Branch** del PR (típicamente generado por ApplicationSet) |
| Prueba efímera local | `HEAD` (está bien, es desechable) |

> **Regla:** si el `Application` tiene nombre `*-prod` o `*-stg`, su `targetRevision` **no** debe ser `HEAD`. Esto se puede validar en CI (ver `examples/03-diff-in-ci`).

---

## 5. `spec.project`

```yaml
spec:
  project: default
```

El `project` apunta a un `AppProject` (otro CR de Argo CD). El `AppProject` **restringe** qué puede hacer esta Application:

- Qué repos puede usar (`sourceRepos`).
- A qué clusters y namespaces puede desplegar (`destinations`).
- Qué recursos cluster-scoped puede o no puede crear (`clusterResourceWhitelist/Blacklist`).
- Qué roles existen y qué pueden hacer (RBAC propio del project).

El `AppProject default` que viene con Argo CD por defecto es `*/*` — permite todo. Está bien para empezar; en una org real, se diseña un project por equipo o por bounded context. Esto se trata en profundidad en `argo-06-projects-rbac-and-boundaries`.

---

## 6. `spec.syncPolicy` — cómo y cuándo se aplica

Hay dos grandes modos: **manual** (sin `syncPolicy.automated`) y **automated**.

### 6.1 Manual

```yaml
spec:
  syncPolicy: {}      # o directamente omitir
```

Argo CD detecta drift pero **no actúa**. La Application queda `OutOfSync` hasta que un humano haga `argocd app sync` o clickee "Sync" en la UI. Útil para producción, pre-flight review, cambios con cambio de schema de DB.

### 6.2 Automated

```yaml
spec:
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
```

- `automated.prune: true` — si eliminas un recurso del repo, Argo CD lo elimina del cluster. **Sin esto, los recursos huérfanos quedan vivos**. Es el default razonable para dev; en prod se evalúa.
- `automated.selfHeal: true` — si alguien modifica algo con `kubectl edit`, Argo CD lo revierte. Garantiza que Git siempre gana; a veces molesta durante incidentes (ver §6.6).
- `automated.allowEmpty: false` — bloquea un sync que resultaría en eliminar *todos* los recursos (defensa anti-fat-finger: alguien borró `path/` por error).

### 6.3 Política por ambiente — guía inicial

| Ambiente | `automated` | `prune` | `selfHeal` |
|----------|-------------|---------|-----------|
| `dev` | sí | sí | sí |
| `stg` | sí | sí | sí |
| `prod` | **no** (manual approval) | sí (si manual) | típicamente **no** |

Esto es un punto de partida razonable; `argo-05` lo matiza con sync windows y `argo-06` con RBAC + aprobación.

### 6.4 `syncOptions`

Opciones que afinan el comportamiento de `kubectl apply`:

```yaml
spec:
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
      - ServerSideApply=true
      - RespectIgnoreDifferences=true
      - PruneLast=true
```

- `CreateNamespace=true` — crea `destination.namespace` si no existe.
- `ApplyOutOfSyncOnly=true` — en lugar de re-aplicar todos los recursos, aplica solo los que están OutOfSync (mejor para apps grandes).
- `ServerSideApply=true` — usa server-side apply (reconciliación por `managedFields`). Importante para convivir con controllers que mutan recursos.
- `RespectIgnoreDifferences=true` — garantiza que `ignoreDifferences` también se respete *durante* el `apply`, no solo en el diff (ver §7).
- `PruneLast=true` — borra recursos al final, después de aplicar los nuevos. Útil cuando un recurso nuevo necesita existir antes de borrar el viejo.

### 6.5 `retry`

```yaml
spec:
  syncPolicy:
    retry:
      limit: 3
      backoff:
        duration: 10s
        factor: 2
        maxDuration: 3m
```

Útil cuando el sync falla por un race condition típico (p. ej. CRD no listo todavía).

### 6.6 `selfHeal` durante un incidente

Escenario clásico: producción está caída, un operador hace `kubectl scale deploy/api --replicas=10` para desahogar. Si `selfHeal: true` está activo, Argo CD *reverterá* ese scale al valor del repo. El operador se enoja.

Soluciones honestas:

- Para `replicas` específicamente: usar HPA y añadir `replicas` a `ignoreDifferences` (ver §7). Es la respuesta correcta.
- Si realmente hay que intervenir manualmente: `argocd app set <app> --sync-policy none` apaga el self-heal mientras dura el incidente; luego se restaura.
- No es GitOps "puro", pero es honesto operacionalmente. La alternativa es un cambio por PR durante el incidente, lo cual es el ideal pero no siempre viable.

---

## 7. `spec.ignoreDifferences` — convivir con otros controllers

El problema: muchos recursos de Kubernetes tienen campos que son escritos por *otros* controllers, no por el autor del YAML:

- `Deployment.spec.replicas` es escrito por el **HPA** si existe uno.
- `Deployment.spec.template.spec.containers[].resources` puede ser escrito por **VPA** en modo `Auto`.
- Recursos gestionados por operators (p. ej. `ServiceMonitor`) ganan annotations.
- `kubectl.kubernetes.io/last-applied-configuration` lo escribe `kubectl` client-side-apply.

Sin `ignoreDifferences`, Argo CD ve "el `replicas` en el cluster es 7, pero el YAML en Git dice 3 → OutOfSync" y, con `selfHeal`, bajaría a 3 cada vez que el HPA sube.

### 7.1 Sintaxis

```yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
```

- `group` + `kind` identifican el recurso (puedes añadir `name` para apuntar a uno específico).
- `jsonPointers` lista rutas JSON Pointer dentro del objeto a ignorar.
- Alternativa: `jqPathExpressions` para expresiones más potentes.
- Alternativa: `managedFieldsManagers` para ignorar todos los campos gestionados por *otro* field manager (útil con server-side apply).

### 7.2 Patrón HPA + Deployment

```yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      name: capstone-api         # opcional, para apuntar solo a este
      jsonPointers:
        - /spec/replicas
  syncPolicy:
    syncOptions:
      - RespectIgnoreDifferences=true    # importante en server-side apply
```

Sin `RespectIgnoreDifferences=true`, el `ignoreDifferences` **solo afecta al diff**, no al `apply`: Argo CD seguirá reaplicando `replicas: 3` cada sync. Es el pitfall número 2 de este módulo.

### 7.3 Patrón VPA en modo `Auto`

```yaml
- group: apps
  kind: Deployment
  jqPathExpressions:
    - '.spec.template.spec.containers[].resources'
```

### 7.4 Patrón operator que inyecta annotations

```yaml
- group: monitoring.coreos.com
  kind: ServiceMonitor
  jsonPointers:
    - /metadata/annotations
```

---

## 8. Metadata: `labels`, `annotations`, `spec.info`

```yaml
metadata:
  name: capstone-api-dev
  namespace: argocd
  labels:
    team: capstone
    env: dev
  annotations:
    argocd.argoproj.io/manifest-generate-paths: '.'
    notifications.argoproj.io/subscribe.on-sync-failed.slack: capstone-alerts
spec:
  info:
    - name: 'Runbook'
      value: 'https://wiki.acme.com/runbooks/capstone-api'
    - name: 'On-call'
      value: 'https://pagerduty.com/schedules/capstone'
```

- Labels permiten filtrar en UI y CLI (`argocd app list -l team=capstone`).
- `spec.info` renderiza en la UI de la Application como enlaces/metadata — ideal para runbooks, dashboards, on-call rotation.
- `argocd.argoproj.io/manifest-generate-paths` optimiza la detección de cambios cuando el repo tiene muchas apps (le dice a Argo CD "re-renderiza esta app solo si cambios tocan este path").

---

## 9. UI: tree, diff, logs

La UI de Argo CD organiza una Application en tres vistas principales:

- **Tree view**: grafo de recursos (de la `Application` → `Deployment` → `ReplicaSet` → `Pod`), con color por estado (synced/out-of-sync, healthy/degraded/progressing).
- **Diff view**: para cada recurso OutOfSync, muestra el YAML del repo vs el YAML del cluster, con un diff lado a lado. **Esta vista es la que debes aprender a leer**.
- **Logs**: para pods vivos, logs tailable directamente desde la UI. Útil para debugging rápido sin saltar a `kubectl`.

Equivalente en CLI:

```bash
argocd app get capstone-api-dev           # resumen (sync + health + resources)
argocd app diff capstone-api-dev          # diff repo vs cluster
argocd app logs capstone-api-dev          # logs agregados de pods
```

---

## 10. `argocd app diff` como herramienta

`argocd app diff` responde "qué cambiaría si sincronizara ahora". Es equivalente a `terraform plan`.

Usos:

- **Pre-sync humano**: antes de clickear Sync en prod, ver qué va a pasar.
- **En CI**: un job que corre `argocd app diff --revision <PR_HEAD>` y falla si hay recursos destructivos o cambios no esperados. Ver `examples/03-diff-in-ci`.
- **Debugging de "¿por qué está OutOfSync?"**: el diff responde literalmente qué campo difiere.

Flags útiles:

- `--revision <ref>` — diff contra una revisión arbitraria (no el `targetRevision` configurado).
- `--local <path>` — diff contra manifests locales (útil para "¿lo que acabo de escribir en mi laptop produciría drift?").
- `--server-side-generate` — rinde los manifests en el `repo-server` del cluster (asegura paridad con el render real que haría Argo CD).

Códigos de salida: `0` sin diffs, `1` con diffs, `>1` error. En CI se puede usar `|| true` para no fallar pero sí reportar, o deliberadamente dejar que `1` sea bloqueante.

---

## 11. Flujo completo end-to-end

Trazar lo que pasa desde "commit a Git" hasta "pod corriendo":

1. Un commit llega al `repoURL` del `Application`.
2. Argo CD polea el repo periódicamente (default: 3 min; configurable) **o** recibe un webhook de GitHub/GitLab (recomendado para feedback rápido).
3. El `repo-server` detecta nueva revisión, renderiza manifests, los pone en caché.
4. El `application-controller` compara desired (del repo) vs live (del cluster).
5. Si hay diff → marca `OutOfSync`.
6. Si `syncPolicy.automated` está activo → aplica. Si manual → espera orden humana.
7. El apply ocurre vía la API de Kubernetes del cluster target, con credenciales del cluster registrado.
8. El cluster converge: `Deployment` crea `ReplicaSet` crea `Pod`.
9. Argo CD recalcula `Health` del árbol: pods ready → `Healthy`.
10. La UI se actualiza; si hay suscripciones de notifications, dispara Slack/webhook.

Si en el paso 6 Argo CD detectara que un campo ignorado difiere, no haría sync. Si *otro* field difiere, haría sync solo de los campos no ignorados (con server-side apply).

---

## 12. Pitfalls y preguntas de reflexión

### 12.1 Pitfalls (checklist mental)

- [ ] `targetRevision: HEAD` en una app `prod` o `stg` → **no**.
- [ ] `ignoreDifferences` sin `RespectIgnoreDifferences=true` en syncOptions → se ignora en el diff pero *no* en el apply.
- [ ] `destination.namespace` distinto de `metadata.namespace` del Application (ambos legítimos pero fáciles de confundir).
- [ ] `automated.selfHeal: true` sin HPA → fine. `selfHeal: true` con HPA y sin `ignoreDifferences` → caos.
- [ ] Olvidar `CreateNamespace=true` cuando el namespace target no existe → sync fallará con "namespace not found".
- [ ] `project: default` con `*/*` en producción → sin boundary alguno. Diseñar AppProject apropiado (`argo-06`).
- [ ] Dos Applications apuntando al *mismo* path del *mismo* repo → ambas van a reclamar los mismos recursos → "shared resource" warnings y conflictos.
- [ ] Manifests en el repo con `metadata.namespace` explícito, mientras `destination.namespace` dice otro → gana el del manifiesto. Fuente de confusión.

### 12.2 Preguntas de reflexión

Responde sin consultar la lección:

1. ¿Qué diferencia hay operativamente entre `targetRevision: main` y `targetRevision: HEAD` cuando el default branch del repo *es* `main`?
2. Tienes un `Deployment` con 3 réplicas en Git y un HPA configurado entre 2 y 10. El HPA sube a 7. Argo CD, con `selfHeal: true` y sin `ignoreDifferences`, ¿qué hace? ¿Qué cambia si añades `/spec/replicas` a `ignoreDifferences` *sin* `RespectIgnoreDifferences=true`?
3. ¿Por qué `metadata.namespace` del `Application` CR debe ser `argocd` (o donde corra Argo CD), independientemente de dónde se despliega la app?
4. Dado un `Application` manual (`syncPolicy: {}`), ¿Argo CD seguirá detectando drift? ¿Qué muestra la UI?
5. `argocd app diff --local ./rendered.yaml` ¿contra qué compara exactamente? ¿Y `--revision abc123`?
6. ¿Qué pasa si eliminas el `Application` CR del namespace `argocd`? ¿Se eliminan los recursos del cluster target? (Pista: depende de un finalizer: `resources-finalizer.argocd.argoproj.io`.)
7. Dos personas aplican el *mismo* commit con `argocd app sync` casi simultáneamente. ¿Qué ocurre? ¿Puede causar daño?
8. En qué escenario `allowEmpty: true` sería la elección correcta.

### 12.3 Resumen operativo

- `Application` = CR que define *qué sincronizar desde dónde hacia dónde*.
- `source` → de dónde (repo + path + ref).
- `destination` → a dónde (cluster + namespace).
- `syncPolicy` → cómo (manual vs auto, prune, selfHeal, opciones).
- `ignoreDifferences` → qué partes ignorar porque las toca otro controller.
- `targetRevision: HEAD` → trampa en prod/stg.
- `replicas` + HPA → casi siempre `ignoreDifferences` + `RespectIgnoreDifferences=true`.
- `argocd app diff` es tu `terraform plan`. Úsalo antes de sync y en CI.
