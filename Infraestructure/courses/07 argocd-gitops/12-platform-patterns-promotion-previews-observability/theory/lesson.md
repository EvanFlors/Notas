# Lección: GitOps como plataforma — promoción, previews, drift y observabilidad

> **ID:** `argo-12-platform-patterns-promotion-previews-observability` · **Nivel:** producción · **Duración:** 5 h
> **Prerrequisitos:** `argo-07`, `argo-09`, `argo-11`.

---

## 1. Introducción intuitiva

Hasta aquí sabes **cómo** funciona Argo CD: Application, ApplicationSet, Projects, secretos vía ESO, hardening. Pero una plataforma no se juzga por si "funciona en el feliz camino" — se juzga por lo que pasa cuando *doce equipos* la usan a la vez durante seis meses: ¿quién puede mergear a `prod`? ¿cuánto tarda un cambio en llegar a `stg`? ¿qué pasa si alguien hace `kubectl scale` a mano? ¿cómo nace un ambiente nuevo? ¿cómo se destruye? ¿quién recibe el alerta cuando una Application lleva 20 minutos *Degraded*?

Este módulo es el **contrato operativo** que convierte a Argo CD en plataforma. Hay cuatro bloques:

1. **Promoción**: cómo un cambio viaja de `dev` → `stg` → `prod`.
2. **Previews**: cómo cada PR levanta su propio ambiente y lo tira al cerrarse.
3. **Drift**: cómo decides si auto-corregir, dejar y alertar, o pausar.
4. **Observabilidad**: cómo *ves* qué está haciendo Argo CD, no solo tus apps.

El error más común en empresas que adoptan GitOps es resolver (1) y olvidar los otros tres. Resultado: funciona seis meses, luego hay un incidente, nadie entiende por qué, y vuelven a `kubectl apply` desde Jenkins.

---

## 2. Fundamentos

### 2.1 Repo de código vs repo de infra

El principio GitOps es *Git como fuente de verdad del estado deseado del cluster*. ¿Qué repo?

- **Repo de código** (`org/service-foo`): contiene el código fuente, el Dockerfile, los tests. Un cambio aquí produce una **imagen** publicada en un registry.
- **Repo de infra** (`org/platform-manifests`): contiene Applications, ApplicationSets, Helm values por entorno, Kustomize overlays. Un cambio aquí produce un **despliegue**.

Los dos repos existen por motivos operativos, no estéticos:

- **Ownership**: `CODEOWNERS` del repo de infra puede exigir aprobación de SRE para tocar `envs/prod/*`.
- **Blast radius**: un developer con write en su repo de código no puede desplegar accidentalmente a `prod`.
- **Compliance**: la cadena "quién mergeó qué a prod" se audita en *un* repo.
- **Multi-service**: el repo de infra agrega N servicios; cada uno con su equipo, pero el "plano" de ambientes vive en un sitio único.

Variantes:

- **Monorepo infra** único (una línea para toda la org).
- **Infra por tenant** (`platform-manifests-teamA`, `platform-manifests-teamB`), bootstrapped por un meta-ApplicationSet.
- **Co-ubicado** (code y manifests en el mismo repo): aceptable para equipos pequeños, mal escalable.

### 2.2 Qué modifica el pipeline

En el modelo canónico el pipeline **no despliega**. Hace tres cosas:

1. Build + test del código.
2. Build + firma de la imagen (`cosign sign`).
3. **Commit al repo de infra** con el nuevo tag (`values.yaml: image.tag: v1.2.3`).

Argo CD ve el commit y reconcilia. El pipeline **no tiene** credenciales del cluster. Esta es la razón arquitectónica de GitOps: el blast radius de un pipeline comprometido es "escribe en Git" (reversible, auditado), no "escribe en 50 clusters" (irreversible, catastrófico).

### 2.3 Promoción = mover una ref

Promover **no es** "copiar manifests de un sitio a otro". Promover es **mover una referencia** que `dev`, `stg` y `prod` leen distinto. Hay tres formas canónicas:

| Estrategia | Qué cambia al promover | Repo visual |
|---|---|---|
| **Branch-based** | `git merge dev → stg → main` | Un folder; el branch decide ambiente |
| **Folder/overlay** | PR que edita `envs/stg/values.yaml` | `envs/dev/`, `envs/stg/`, `envs/prod/` |
| **Image updater** | Un bot escribe commits que bumpan `image.tag` | Mismo repo de infra, pero el humano no commitea |

Elección correcta: depende de la org. Elección frecuente mal: mezclar las tres sin un contrato.

### 2.4 Drift

Drift = diferencia entre `desired` (Git) y `live` (cluster). Hay tres sabores:

- **Benigno**: HPA cambió `replicas`, cert-manager añadió una annotation. Se resuelve con `spec.ignoreDifferences` (`argo-03`).
- **Operacional**: alguien hizo `kubectl edit` para apagar un fuego. Se decide política: `selfHeal: true` lo revierte; `selfHeal: false` lo preserva y alerta.
- **Adversario**: un atacante o un controller mal configurado introduce manifests. Prevención: Projects estrictos (`argo-06`) + Kyverno/OPA; detección: `OutOfSync` prolongado + alerta.

### 2.5 Observabilidad de Argo CD

Argo CD **es** un sistema distribuido con sus propios SLOs. "Mis apps están sanas" no implica "Argo CD está sano": puede estar reconciliándolas con 20 min de delay. Métricas clave (sec. 7):

- `argocd_app_info{sync_status,health_status}` — estado por Application.
- `argocd_app_reconcile_bucket` — histograma de latencia de reconciliación.
- `argocd_cluster_info` — N de clusters, apps por cluster, caché age.
- `argocd_app_sync_total{phase}` — syncs exitosos vs fallidos.
- `argocd_git_request_total` — fetches a Git y errores.

Sin esto, operas a ciegas.

---

## 3. Contexto histórico

- **2018–2019**: Argo CD y Flux emergen con el patrón "una Application manual por app". Promoción = humano edita YAML.
- **2020**: Weaveworks introduce **image-automation-controller** en Flux; aparece **argocd-image-updater** como proyecto separado (no core).
- **2021**: **ApplicationSet** pasa de incubating a core en Argo CD. El PR generator abre la puerta a **preview environments** nativos.
- **2022**: **notifications-controller** se integra como componente oficial de Argo CD (antes era `argocd-notifications` separado).
- **2023**: Progressive sync de ApplicationSet (`strategy: RollingSync`) GA. Multi-source Applications GA.
- **2024+**: Backstage + Argo CD plugin maduros; patrones "golden path" en IDPs convergen a "template → crea folder en infra repo → ApplicationSet lo recoge".

La lección histórica: el ecosistema **convergió** en que *el humano no edita manifests de ambientes de arriba*. Lo edita un bot (image updater), un merge (branch promotion), o un IDP (Backstage template). El humano decide la **política**; la ejecución está automatizada.

---

## 4. Promoción entre ambientes

### 4.1 Branch-based

Un repo de infra, tres branches: `dev`, `stg`, `main` (prod). Tres Applications apuntan al mismo `path`, cada una con `targetRevision` distinto:

```yaml
# dev
spec: { source: { repoURL: ..., path: platform/foo, targetRevision: dev } }
# stg
spec: { source: { repoURL: ..., path: platform/foo, targetRevision: stg } }
# prod
spec: { source: { repoURL: ..., path: platform/foo, targetRevision: main } }
```

Promover `dev → stg`: `git checkout stg && git merge dev && git push`. Argo CD lo ve y sincroniza stg.

**Ventajas**: simple, el DAG de Git *es* el pipeline de promoción, cualquier `git log stg..main` muestra qué falta por promover.
**Desventajas**: si `dev` y `stg` difieren por *configuración* (p. ej. tamaño del cluster), el merge se complica con conflictos permanentes; branch per-env no escala bien a 10+ ambientes.

Encaja bien cuando los ambientes son **copias** del mismo stack con solo `image.tag` diferente.

### 4.2 Folder/overlay-based con ApplicationSet

Un branch (`main`), tres folders:

```
envs/
  dev/values.yaml
  stg/values.yaml
  prod/values.yaml
```

Un `ApplicationSet` con **Git generator** `directories`:

```yaml
generators:
  - git:
      repoURL: https://github.com/org/platform-manifests
      revision: HEAD
      directories: [ { path: envs/* } ]
template:
  metadata:
    name: '{{path.basename}}-foo'
  spec:
    source:
      repoURL: https://github.com/org/platform-manifests
      path: 'charts/foo'
      helm:
        valueFiles: [ '../../{{path}}/values.yaml' ]
    destination: { namespace: '{{path.basename}}' }
```

Promover `dev → stg`: PR que edita `envs/stg/values.yaml` cambiando `image.tag`. `CODEOWNERS` exige revisor adecuado.

**Ventajas**: un solo branch, cada ambiente es un *overlay* explícito con sus propios valores (replicas, resources, flags), diff en PR muestra exactamente qué cambia en stg, extensible a N ambientes sin fricción.
**Desventajas**: más carpetas, el "qué está en dónde" requiere leer YAMLs (no `git log`), riesgo de drift entre overlays si el equipo no es disciplinado.

Encaja bien cuando ambientes **difieren legítimamente** (tamaños, feature flags, endpoints).

### 4.3 Image updater

`argocd-image-updater` es un controller aparte que:

1. Observa Applications con una annotation (`argocd-image-updater.argoproj.io/image-list: foo=ghcr.io/org/foo`).
2. Hace `docker pull` al registry buscando tags nuevos que cumplan una regla (`strategy: semver`, `latest`, `regex`).
3. Dos modos de **write-back**:
   - **argocd**: edita el objeto Application en Kubernetes (anti-GitOps en el estricto; el valor está en el cluster, no en Git).
   - **git**: hace commit al repo de infra actualizando `.argocd-source-foo.yaml` o un `values.yaml`. **Este** es el GitOps correcto.

Promover ya no es un `git merge` humano: es un bot commiteando al branch de `dev` (y, con reglas, también a `stg`/`prod`).

**Ventajas**: cero intervención humana en el ciclo "nueva imagen → desplegada en dev"; combinable con firma + Kyverno para rechazar imágenes no firmadas.
**Desventajas**: commits automáticos ensucian `git log`; el bot necesita credenciales de write al repo de infra (otro secreto a proteger); si la regla `semver` es laxa, se auto-despliegan versiones no probadas.

Encaja bien en **dev** o **stg** cuando el equipo publica imágenes muchas veces por día. **Para prod** se prefiere combinarlo con approval manual (PR en vez de direct push).

### 4.4 Mezcla recomendada

El patrón más visto en 2026:

- **dev**: image updater con `write-back: git` + branch `dev` + auto-sync.
- **stg**: PR auto-generado por image updater al branch `stg` (requiere review mínima).
- **prod**: PR *humano* que mergea `stg → main`; `CODEOWNERS` SRE; sync automático tras merge; opcional `argo-rollouts` canary.

Esto da velocidad abajo y disciplina arriba. Es el **contrato** que escribirás en la actividad `01-platform-contract-adr`.

---

## 5. PR previews end-to-end

### 5.1 Objetivo

Cada PR al repo de **código** levanta un ambiente aislado con esa versión del código, URL única (`https://pr-123.preview.example.com`), y se destruye al mergear o cerrar el PR.

### 5.2 Mecánica

`ApplicationSet` con **PR generator**:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata: { name: foo-previews }
spec:
  generators:
    - pullRequest:
        github:
          owner: org
          repo: foo
          tokenRef: { secretName: github-token, key: token }
        requeueAfterSeconds: 60
  template:
    metadata:
      name: 'foo-pr-{{number}}'
    spec:
      project: previews
      source:
        repoURL: https://github.com/org/foo
        targetRevision: '{{head_sha}}'
        path: deploy/preview
        helm:
          parameters:
            - { name: image.tag,  value: 'pr-{{number}}' }
            - { name: ingress.host, value: 'pr-{{number}}.preview.example.com' }
      destination:
        server: https://kubernetes.default.svc
        namespace: 'pr-{{number}}'
      syncPolicy:
        automated: { prune: true, selfHeal: true }
        syncOptions: [ CreateNamespace=true ]
```

Cuando el PR se cierra: el PR generator deja de emitir ese item, el ApplicationSet elimina la Application, y con `prune: true` el namespace entero (si tiene labels de ownership) desaparece. Para garantía extra:

- Añadir **`finalizers.argocd.argoproj.io/resources-finalizer`** a la Application template para que el delete en cascada borre recursos no `prune`-eables.
- Usar un namespace por PR (`pr-{{number}}`) para `delete namespace` como `cleanup` definitivo si queda huérfano.

### 5.3 Requisitos

- Imagen de la rama del PR publicada por el pipeline (tag `pr-123`).
- DNS wildcard apuntando al ingress (`*.preview.example.com → LB`).
- Secretos de la preview distintos de los de prod (ESO leyendo de un path dedicado, p. ej. `secret/data/previews/*`).
- `AppProject` `previews` con `destinations: pr-*` namespaces y `sourceRepos` limitado al repo del servicio.

### 5.4 Trampas comunes

- **Costo**: cada PR = pods + DB + cache. Sin TTL o quota, un equipo activo mantiene 40 previews. Mitigación: `ResourceQuota` por namespace y job que cierra PRs stale (> 7 días sin update).
- **Datos**: una preview no puede compartir DB con prod. O usas un seed script, o un DB-per-PR vía operator (postgres-operator, cnpg), o un snapshot restore acotado.
- **Secrets**: nunca copiar secretos de prod a previews. ESO + path dedicado.
- **DNS**: sin wildcard, cada preview requiere crear/eliminar un record (lento, propenso a race conditions).

---

## 6. Drift reconciliation

### 6.1 Qué es drift

Argo CD compara `desired` (output del `repo-server` renderizando el source) con `live` (lo que `kubectl get` devuelve). Si difieren en campos relevantes, la Application está `OutOfSync`.

### 6.2 Política por ambiente

| Ambiente | `automated` | `selfHeal` | Alerta drift |
|---|---|---|---|
| **dev** | sí | sí | no (ruido) |
| **stg** | sí | sí | sí, baja prioridad |
| **prod** | sí **con cuidado** | discutible | sí, alta prioridad |

`selfHeal: true` en prod **revierte** cambios manuales durante incidentes — poderoso pero puede eliminar un parche de emergencia que alguien aplicó a mano. Dos escuelas:

- *Autosanador estricto*: `selfHeal: true` en prod, y el runbook de incidentes exige que todo parche vaya primero a Git. Fuerza disciplina.
- *Alerta y pausa*: `selfHeal: false` en prod, pero cualquier drift genera alerta y una `SyncWindow` denegadora puede pausar sync automático durante incidentes.

Ambas son defendibles; mezclar sin pensar es desastre.

### 6.3 ignoreDifferences

Para drift benigno estructural:

```yaml
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers: [ /spec/replicas ]       # HPA
    - group: ""
      kind: Secret
      jqPathExpressions: [ '.data["ca.crt"]' ]  # cert-manager rotando CA
```

Sin esto, un cluster con HPA siempre está `OutOfSync` después del primer scale.

### 6.4 Sync windows

`AppProject.spec.syncWindows` permite ventanas (`allow` o `deny`) por horario/día. Útil para "no sincronizar prod viernes 17h–lunes 8h" sin cambiar la política de las apps.

---

## 7. Observabilidad de Argo CD mismo

### 7.1 Fuentes

- `argocd-application-controller` expone `:8082/metrics` (Prometheus).
- `argocd-server` expone `:8083/metrics`.
- `argocd-repo-server` expone `:8084/metrics`.
- `argocd-notifications-controller` expone `:9001/metrics`.
- `argocd-applicationset-controller` expone `:8080/metrics`.

Habilitadas por default en la instalación oficial; solo hay que crear `ServiceMonitor` (o `PodMonitor`) para Prometheus Operator.

### 7.2 Métricas que importan

Del `application-controller`:

| Métrica | Qué dice | Alerta |
|---|---|---|
| `argocd_app_info{sync_status,health_status}` | Vector por app con labels de estado | app `Degraded` > 10 min |
| `argocd_app_reconcile_bucket` | Histograma de latencia de reconciliación | p99 > 60s |
| `argocd_app_sync_total{phase}` | Counter de syncs exitosos/fallidos | tasa de `Failed` sobre total |
| `argocd_app_k8s_request_total{response_code}` | Llamadas al API server, por código | spike de 5xx |
| `argocd_cluster_info{server}` | Clusters conectados, caché age | caché age > 5 min |
| `argocd_git_request_total{repo,request_type}` | Fetches a Git, errores | tasa de errores |
| `workqueue_depth{name="app_reconciliation_queue"}` | Backlog del reconciler | > 100 sostenido |

Del `repo-server`:

- `argocd_repo_pending_request_total` — requests en cola (manifest render).
- `argocd_git_request_duration_seconds` — latencia de operaciones Git.

### 7.3 Dashboards oficiales

- Grafana ID **14584** — "Argo CD" (comunidad).
- Grafana ID **19993** — "Argo CD Operational" (más denso).
- Carpeta `examples/dashboards/` del repo oficial Argo CD en GitHub.

### 7.4 SLOs internos recomendables

- *Reconciliation freshness*: 99% de apps reconciliadas en los últimos 3 min.
- *Sync success rate*: 99% de syncs no fallidos en una ventana rolling 24h (excluyendo errores de la propia app).
- *Repo-server availability*: 99.9%.

Sin SLOs internos, Argo CD "funciona o no funciona" subjetivamente.

---

## 8. notifications-controller

### 8.1 Modelo

Un controller aparte lee anotaciones en Applications y manda notificaciones por *services* (slack, webhook, email, teams, telegram, grafana). Config vive en `argocd-notifications-cm` ConfigMap.

### 8.2 Piezas

- **service.<name>**: endpoint (webhook URL, Slack token, SMTP).
- **template.<name>**: cuerpo de la notificación (Go template con `.app`, `.context`).
- **trigger.<name>**: condiciones (`when: app.status.sync.status == 'OutOfSync'`) y `send: [template]`.
- **subscriptions**: anotación en la Application o default por project.

### 8.3 Ejemplo mínimo (fragmento)

```yaml
service.webhook.ops: |
  url: https://ops.example.com/argocd-events
  headers:
    - name: Authorization
      value: Bearer $ops-token
template.app-degraded: |
  webhook:
    ops:
      method: POST
      body: |
        { "app": "{{.app.metadata.name}}", "health": "{{.app.status.health.status}}" }
trigger.on-degraded: |
  - when: app.status.health.status == 'Degraded'
    send: [app-degraded]
```

Y anotación en la Application:

```yaml
metadata:
  annotations:
    notifications.argoproj.io/subscribe.on-degraded.webhook: ops
```

### 8.4 Buenas prácticas

- Subscripciones **por project** (default), no por app (menos ruido en manifests).
- Rate-limit en el servicio consumidor; una tormenta de drift puede inundar Slack.
- Templates separados por severidad: `on-sync-failed` (prod only), `on-degraded` (todos), `on-deployed` (dev noisy, prod cuidadoso).

---

## 9. ApplicationSet progressive sync

Un ApplicationSet con muchos targets puede causar un "big bang": todos los clusters/ambientes se actualizan a la vez. `spec.strategy` lo controla:

```yaml
spec:
  strategy:
    type: RollingSync
    rollingSync:
      steps:
        - matchExpressions:
            - { key: envLabel, operator: In, values: [dev] }
        - matchExpressions:
            - { key: envLabel, operator: In, values: [stg] }
          maxUpdate: 10%
        - matchExpressions:
            - { key: envLabel, operator: In, values: [prod] }
          maxUpdate: 1
```

Mecánica: el ApplicationSet aplica los steps en orden; dentro de un step respeta `maxUpdate`; espera a que las Applications del step estén `Healthy` antes de pasar al siguiente. Esto convierte un rollout de 50 clusters en un canary ordenado dev → stg → prod.

Trampas:

- Los steps **no retroceden**: si prod falla, el ApplicationSet se detiene pero no revierte dev/stg. El rollback se hace en Git (revert commit).
- `envLabel` tiene que estar en las labels generadas (`template.metadata.labels`).

---

## 10. Fundamentos internos (lo que suele no explicarse)

### 10.1 Repo-server, caché y commits automáticos

El `repo-server` cachea resultados por `(repoURL, revision, path, parameters-hash)`. Un commit al branch "tapa" la caché: la siguiente reconciliación re-renderiza. Image updater explota esto: commit → caché inválida → render → sync.

Pero: polling default = 3 min. Para reaccionar en segundos hay que configurar **webhook** del repo a `argocd-server/api/webhook` (soportado para GitHub, GitLab, Bitbucket, Gitea).

### 10.2 Finalizers y el "fantasma del namespace"

Cuando un ApplicationSet elimina una Application con `prune: true`, los recursos se borran. Pero el **namespace** no se borra automáticamente (fue creado por `syncOptions: CreateNamespace=true`, pero no es "owned" por la Application). Resultado: namespaces vacíos acumulados. Opciones:

- Añadir `resources-finalizer.argocd.argoproj.io/background` para forzar delete en cascada.
- Modelar el namespace como un recurso más de la Application (manifest explícito en el chart) para que `prune` lo recoja.
- Job periódico que elimina namespaces `pr-*` sin Application viva asociada.

### 10.3 Image updater y la trampa de `latest`

`strategy: latest` ordena **por fecha de push al registry**, no por semver. Un rebuild de una imagen vieja la "promueve". Siempre preferir `semver` con `allow-tags: '^v\d+\.\d+\.\d+$'`.

### 10.4 Progressive sync y Health degradado

RollingSync espera `Healthy` para pasar al siguiente step. Si una app tiene `health.lua` mal escrito y nunca llega a `Healthy`, el rollout se queda colgado. Siempre validar los `health checks` custom antes de meterlos en producción.

### 10.5 Métricas y cardinalidad

`argocd_app_info` emite una serie por Application. Con 2 000 apps y 10 labels, Prometheus almacena 20 000 series por scrape. En clusters grandes la métrica se recorta con `metricRelabelings` para evitar explosión de cardinalidad.

---

## 11. Backstage e IDPs

El patrón "golden path":

1. Developer entra a Backstage → "Create new service".
2. Backstage template:
   - Crea repo de código con scaffold.
   - Crea PR al repo de infra añadiendo `envs/dev/foo/`, `envs/stg/foo/`, `envs/prod/foo/` desde una plantilla.
   - Opcional: crea `AppProject` y permisos.
3. Mergeado el PR, el ApplicationSet (Git generator) *descubre* la nueva carpeta y crea las Applications.
4. Backstage muestra el estado (Argo CD plugin consume `argocd-server/api`).

Resultado: el developer no toca Argo CD; la plataforma garantiza que *todas* las apps nazcan con el mismo contrato (ownership, project, overlays, previews, dashboards). Esta es la razón por la que GitOps + IDP escala a cientos de servicios.

Si no tienes Backstage, el patrón se replica con cookiecutter + PR automático desde CLI.

---

## 12. Síntesis y preguntas de evaluación

### Síntesis

Un GitOps de plataforma se define por **cuatro contratos**:

1. **Promoción**: cuál de las 3 estrategias (branch / folder / image updater), para qué ambientes, con qué approval.
2. **Previews**: PR generator + proyecto `previews` + TTL + quotas + DNS wildcard.
3. **Drift**: política de `selfHeal` por ambiente + `ignoreDifferences` disciplinado + sync windows en prod.
4. **Observabilidad**: `ServiceMonitor` en los 5 componentes + dashboards oficiales + notifications a Slack/webhook + SLOs internos.

Las piezas técnicas de Argo CD (`ApplicationSet`, `notifications-controller`, `argocd-image-updater`, métricas) son el *cómo*. Los contratos son el *qué*. Sin contratos escritos, Argo CD se vuelve "ese sistema raro que a veces revierte lo que hago".

### Preguntas

1. Un equipo quiere promoción por branch y previews por PR, pero el servicio tiene 12 ambientes "casi iguales". ¿Cuándo recomendarías migrar a folder/overlay? ¿Cuál es la señal clara de que branch-based no escala?
2. En prod, `selfHeal: true` revirtió un parche manual de SRE durante un incidente. ¿Es un bug o un feature? Justifica y proponeprevención (no "quitar selfHeal").
3. El pipeline publica una imagen nueva cada 5 min. `argocd-image-updater` llena `git log` con 300 commits/día. ¿Qué opciones hay para reducir ruido sin perder trazabilidad?
4. La métrica `argocd_app_reconcile_bucket` muestra p99 subiendo de 10s a 90s. Nombra 3 hipótesis y qué métricas correlacionadas confirmarían cada una.
5. Diseñas el contrato de PR previews para una org con 40 microservicios. ¿Cuántos namespaces esperas en pico? ¿Qué `ResourceQuota` default pondrías? ¿Qué job de limpieza automatizarías?
6. ¿Por qué `targetRevision: HEAD` es peligroso para producción, incluso cuando usas folder-overlay con un solo branch?
7. Un ApplicationSet con RollingSync (dev → stg → prod) se queda colgado en stg porque un health check custom nunca devuelve `Healthy`. ¿Cómo diagnosticas sin reiniciar nada? ¿Cómo prevendrías la próxima vez?
8. Backstage crea un PR al repo de infra para registrar un servicio nuevo. ¿Qué validaciones mínimas pondrías en CI del repo de infra para rechazar un PR mal formado?
9. Argo CD mismo está en el cluster que gestiona (self-managing). El `application-controller` se cae y las métricas desaparecen. ¿Cómo lo detectas sin dependencia circular?
10. Compara costos operativos de las 3 estrategias de promoción para una org de 5 equipos, 15 servicios, 3 ambientes. ¿Cuál recomiendas y por qué?
