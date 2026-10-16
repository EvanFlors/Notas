# Flux v2 como alternativa a Argo CD

> Prerrequisitos: `argo-01`, `argo-04`, `argo-07`, `argo-11`.
> Duración de lectura: ~60 min. Práctica (ejemplos + actividades): ~3 h.

Este módulo asume que ya **operas Argo CD** con comodidad. El objetivo no es "aprender Flux desde cero" sino **mapear** cada concepto que ya dominas al equivalente de Flux, entender dónde las dos herramientas divergen filosóficamente, y decidir con criterio cuándo cada una gana.

---

## 1. Posicionamiento: por qué existen dos "ganadores" GitOps

Argo CD y Flux resuelven el mismo problema — reconciliar Kubernetes desde Git — con dos culturas distintas:

- **Argo CD** nació en Intuit (2018) con mentalidad "producto": UI primera, API gRPC, modelo de **Application** monolítico, SSO integrado, experiencia operador-céntrica. La UI permite **sincronizar, hacer rollback, inspeccionar diff** — operaciones de día a día sin tocar Git.
- **Flux** nació en Weaveworks (quien acuñó el término GitOps). Flux v1 era monolítico; **Flux v2** (2020) es un **toolkit modular de controllers** (`fluxcd/flux2`) construido sobre un patrón común (`fluxcd/pkg`). Cultura "**GitOps-only**": no hay UI con write porque **toda** operación debe pasar por Git. Si quieres hacer rollback, revierte el commit. Si quieres sincronizar fuera de ciclo, `flux reconcile` desde CLI o anota el CR.

Ambos están **graduados por la CNCF**. Ambos tienen comunidades grandes y mantenimiento sano. La elección no es "cuál es mejor" sino "cuál encaja mejor con tu organización".

---

## 2. Arquitectura: cinco controllers vs un `application-controller`

Argo CD es, en esencia, **tres procesos**: `argocd-server` (API/UI/gRPC), `application-controller` (reconcilia Applications) y `repo-server` (renderiza manifests). Más Redis, more ApplicationSet controller y notifications controller como "add-ons" en el mismo deployment.

Flux v2 descompone el problema en **cinco controllers independientes**, cada uno con su propio CRD y responsabilidad única (patrón "Unix small tools"):

| Controller | CRs que gestiona | Responsabilidad |
|---|---|---|
| **source-controller** | `GitRepository`, `OCIRepository`, `HelmRepository`, `HelmChart`, `Bucket` | Descarga, verifica e indexa fuentes. Expone un servidor HTTP interno que sirve el artifact (tarball) a los otros controllers. |
| **kustomize-controller** | `Kustomization` | Lee el artifact de un `source`, hace `kustomize build`, aplica vía SSA, hace health check, prune. |
| **helm-controller** | `HelmRelease`, `HelmChart` | Ejecuta `helm install/upgrade/rollback` real contra el cluster. Los `HelmChart`s intermedios los crea él mismo a partir de `HelmRelease`. |
| **notification-controller** | `Provider`, `Alert`, `Receiver` | Envía eventos a Slack/Teams/GitHub/webhook y recibe webhooks externos para disparar reconciliación. |
| **image-reflector** + **image-automation** | `ImageRepository`, `ImagePolicy`, `ImageUpdateAutomation` | Escanea registries, aplica políticas (semver/alfabético/regex) y **commitea** al repo de infra el nuevo tag. |

El patrón es siempre el mismo: **un CR describe el estado deseado**, el controller lee ese CR + el objeto referenciado (`sourceRef`, `chart`, `imageRepositoryRef`) y actúa. **No hay un "Application" que agrupe todo** — un release Helm es `HelmRepository` + `HelmRelease` (2 CRs); un overlay Kustomize es `GitRepository` + `Kustomization` (2 CRs). La composición es por referencia explícita.

### Diagrama

```
          ┌────────────┐  webhook
Git ◄─────┤notification├─────────► Slack / GitHub / …
  ▲       └────────────┘
  │
  │ commit (tag bump)
  │
┌─┴──────────┐    reads     ┌─────────────────┐
│image-      │              │ source-         │ ← pulls Git/OCI/Helm/S3
│automation  │              │ controller      │
└─────▲──────┘              └────────┬────────┘
      │                              │ serves tarball (internal HTTP)
      │ reads tag                    ▼
┌─────┴──────┐              ┌─────────────────┐     ┌─────────────────┐
│image-      │              │ kustomize-      │     │ helm-            │
│reflector   │─scans─ Reg   │ controller      │     │ controller       │
└────────────┘              │ (SSA apply)     │     │ (helm upgrade)   │
                            └────────┬────────┘     └────────┬─────────┘
                                     │                       │
                                     └──────┬────────────────┘
                                            ▼
                                      Kubernetes API
```

---

## 3. `source-controller` en detalle

El `source-controller` es la **capa de ingestión**. Se encarga de que, cuando otro controller pida "dame la versión actual del artefacto X", exista una tarball indexada por digest.

**Fuentes soportadas**:

- **`GitRepository`** — URL + ref (branch/tag/commit/semver) + opcional `secretRef` para auth (SSH keypair o HTTPS basic/token). Soporta `ignore` (análogo a `.gitignore` del source) y `include` (sub-paths).
- **`OCIRepository`** — artefactos OCI (manifests publicados en un registry, p. ej. `ghcr.io/org/manifests:v1.2.3`). Patrón que gana adopción porque **registries ya existen** en toda org y manejan firma (Cosign).
- **`HelmRepository`** — URL de un chart repo clásico (`https://charts.bitnami.com/bitnami`) **o** un registry OCI (`oci://ghcr.io/org/charts`).
- **`Bucket`** — S3/GCS/Azure/MinIO como fuente. Útil cuando el repo de verdad vive detrás de un pipeline que publica tarballs.

Cada `source` reconcilia en su intervalo (`spec.interval`, p. ej. `1m`). Al detectar cambio, actualiza `status.artifact` con la nueva revisión y los demás controllers lo consumen vía referencia.

**Observación clave**: la URL interna del artifact es un servidor HTTP dentro del namespace `flux-system`. Si quieres debuggear, `kubectl -n flux-system port-forward svc/source-controller 9090` y verás los artefactos listados.

---

## 4. `kustomize-controller` y el CR `Kustomization`

`Kustomization` (CR de Flux, **no** confundir con `kustomization.yaml` de Kustomize) es el equivalente directo de **Argo CD Application** cuando la source es plain YAML o Kustomize.

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: podinfo
  namespace: flux-system
spec:
  interval: 10m
  path: "./clusters/dev/podinfo"
  prune: true
  sourceRef:
    kind: GitRepository
    name: infra-repo
  targetNamespace: podinfo
  wait: true                        # bloquea hasta kstatus Ready
  timeout: 2m
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: podinfo
      namespace: podinfo
  dependsOn:
    - name: cert-manager-crds       # orden entre Kustomizations
  serviceAccountName: tenant-sa     # impersonation (multi-tenancy)
```

Puntos a interiorizar:

- `prune: true` ≡ `syncPolicy.automated.prune` de Argo CD. Si quitas un recurso del Git, Flux lo borra.
- `wait: true` + `healthChecks` ≡ hooks de sincronización y espera por salud.
- `dependsOn` ordena **entre `Kustomization`s** — equivalente de sync waves pero cross-Application.
- `serviceAccountName` activa **impersonation**: Flux aplicará como ese SA, no como el SA del controller. Esto es el núcleo del modelo multi-tenancy (ver §7).

**Apply strategy**: por defecto SSA (server-side apply) con `fieldManager: kustomize-controller`. Esto es *más limpio* que el client-side apply que Argo CD usó históricamente (Argo CD también soporta SSA pero no es default universal).

---

## 5. `helm-controller` y el CR `HelmRelease`

Aquí ocurre la **diferencia filosófica más visible** con Argo CD.

Argo CD, al declarar `source.helm`, **no corre `helm install`**: hace `helm template` + apply. Consecuencia: los hooks `pre-install/pre-upgrade/post-install` no se ejecutan como Helm hooks nativos (hay que reescribirlos como Argo CD hooks con `argocd.argoproj.io/hook`).

Flux, con `helm-controller`, **ejecuta Helm real**. Un `HelmRelease` resulta en `helm install` (primer apply) o `helm upgrade` (siguientes). Hooks nativos funcionan. `helm history` muestra las revisiones. `helm rollback` es llamado por el controller cuando `spec.rollback` está activado y una upgrade falla.

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: podinfo
  namespace: flux-system
spec:
  interval: 10m
  url: https://stefanprodan.github.io/podinfo
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: podinfo
  namespace: podinfo
spec:
  interval: 5m
  chart:
    spec:
      chart: podinfo
      version: ">=6.0.0 <7.0.0"
      sourceRef:
        kind: HelmRepository
        name: podinfo
        namespace: flux-system
  install:
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
      remediateLastFailure: true
  rollback:
    cleanupOnFail: true
  values:
    replicaCount: 2
    ingress:
      enabled: false
```

Diferencias prácticas:

| Tema | Argo CD (`source.helm`) | Flux (`HelmRelease`) |
|---|---|---|
| Comando subyacente | `helm template` + `kubectl apply` | `helm install/upgrade` reales |
| Hooks Helm nativos | **No** se ejecutan tal cual | **Sí** funcionan |
| `helm history` | Vacío (no hay release) | Completo |
| Rollback automático en fallo | Vía Argo CD sync policy | `spec.rollback` en el CR |
| Multi-source values (chart en repo A, values en repo B) | Nativo con `multi-source` | Vía `valuesFrom` referenciando ConfigMap/Secret, o usar `GitRepository` separado |

**Cuál es "mejor"**: depende. Argo CD gana cuando quieres **ignorar hooks problemáticos** de charts terceros. Flux gana cuando los charts asumen ejecución real de Helm (muchos charts de la CNCF).

---

## 6. `notification-controller`

Patrón: **Provider** describe un canal (Slack, Teams, GitHub, generic webhook), **Alert** filtra eventos de reconciliación por severidad/fuente y los envía al provider, **Receiver** expone un endpoint HTTP para recibir webhooks externos (p. ej. GitHub push) y disparar `flux reconcile`.

Comparación con Argo CD `notifications-controller`: equivalencia funcional cercana. Flux `Receiver` es más explícito que el patrón "webhook URL" de Argo CD.

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Provider
metadata: { name: slack-prod, namespace: flux-system }
spec:
  type: slack
  secretRef: { name: slack-webhook }
---
apiVersion: notification.toolkit.fluxcd.io/v1beta3
kind: Alert
metadata: { name: on-failure, namespace: flux-system }
spec:
  providerRef: { name: slack-prod }
  eventSeverity: error
  eventSources:
    - kind: Kustomization
      name: '*'
```

---

## 7. Multi-tenancy: `serviceAccountName` + impersonation

En Argo CD, la unidad de tenancy es **AppProject** (lista blanca de repos/destinations + RBAC propio). Argo CD aplica como el SA del `application-controller`, que suele tener permisos globales.

Flux usa un modelo distinto y, para muchos, **más limpio**: cada `Kustomization` o `HelmRelease` puede llevar `spec.serviceAccountName: tenant-sa`. El controller **impersona** ese SA al aplicar los recursos. Los permisos efectivos son los del SA del tenant, no los del controller.

Combinado con los flags `--no-cross-namespace-refs=true` y `--default-service-account=…`, la plataforma garantiza:

- Un tenant **no puede** referenciar un `GitRepository` fuera de su namespace.
- Un tenant **no puede** aplicar como un SA que no sea el suyo (porque el SA no existe en su namespace o no tiene los permisos).

Patrón canónico "**platform repo + tenant repo**":

```
cluster-config/              ← platform repo (gestionado por SRE)
  flux-system/               ← bootstrap
  tenants/
    team-a/
      namespace.yaml
      rbac.yaml              ← crea tenant-a SA + Role/RoleBinding
      git-repo.yaml          ← GitRepository que apunta al tenant-a repo
      kustomization.yaml     ← Kustomization con serviceAccountName: tenant-a-sa

team-a-workloads/            ← tenant repo (gestionado por team-a)
  apps/
    frontend/
    backend/
```

El equipo de la plataforma controla **qué repos pueden reconciliar** y con **qué permisos**. El equipo del tenant controla **qué hay dentro de su repo**. Las dos cosas están segregadas por diseño.

---

## 8. CLI `flux` — comandos operativos

| Operación | Comando |
|---|---|
| Instalar | `flux install` (manifests) o `flux bootstrap github --owner=… --repository=…` (bootstrap commiteando a Git). |
| Precheck | `flux check --pre` y `flux check` (post-install). |
| Crear source Git | `flux create source git infra --url=https://… --branch=main --interval=1m`. |
| Crear Kustomization | `flux create kustomization apps --source=GitRepository/infra --path=./apps --prune=true --interval=10m`. |
| Reconciliar on-demand | `flux reconcile source git infra` seguido de `flux reconcile kustomization apps`. |
| Pausar | `flux suspend kustomization apps` (reconciliación detenida sin borrar nada). |
| Reanudar | `flux resume kustomization apps`. |
| Estado agregado | `flux get all -A`, `flux stats -A`. |
| Rastrear quién gestiona un recurso | `flux trace deployment podinfo -n podinfo`. |
| Logs | `flux logs --all-namespaces --level=error`. |
| Export para GitOps | `flux create kustomization … --export > apps.yaml` (nunca `kubectl create -f` en prod — commitea al repo). |

**Flujo canónico**: `--export` **siempre**. La CLI es una herramienta de scaffolding + inspección, no de operación.

---

## 9. Image automation — nativa en Flux, add-on en Argo CD

Flux incluye dos controllers que, combinados, implementan auto-bump de imágenes:

- `image-reflector-controller` escanea el registry y publica tags disponibles como `ImageRepository`.
- `image-automation-controller` lee `ImagePolicy` (semver/alfabético/regex) y, cuando el "tag ganador" cambia, **commitea** al repo de infra actualizando los manifests marcados.

El marker en el manifest es un comentario:

```yaml
spec:
  containers:
    - name: app
      image: ghcr.io/org/app:1.2.3  # {"$imagepolicy": "flux-system:app"}
```

El `ImageUpdateAutomation` describe cómo hacer el commit:

```yaml
apiVersion: image.toolkit.fluxcd.io/v1beta2
kind: ImageUpdateAutomation
metadata: { name: infra-main, namespace: flux-system }
spec:
  interval: 5m
  sourceRef: { kind: GitRepository, name: infra }
  git:
    checkout: { ref: { branch: main } }
    commit:
      author: { email: flux@acme.io, name: fluxcdbot }
      messageTemplate: "chore(images): {{range .Updated.Images}}{{println .}}{{end}}"
    push: { branch: main }
  update:
    path: ./clusters/dev
    strategy: Setters
```

**Diferencia con `argocd-image-updater`** (add-on separado de Argo CD):

| Tema | Flux (nativo) | `argocd-image-updater` |
|---|---|---|
| Dónde escribe | **Git** (commit al repo) | Git **o** Application CR directamente |
| Estrictez GitOps | Máxima: Git sigue siendo única fuente | Mode "argocd" rompe el principio |
| Instalación | `flux install` incluye todo | Add-on separado |
| Políticas | semver / alpha / regex | semver / regex / digest |

Para una org estrictamente GitOps, la nativa de Flux gana. Para una org con Argo CD ya operativa, el add-on es suficiente.

---

## 10. Filosofía "GitOps-only" (no UI con write)

Flux **no tiene UI oficial con operaciones de escritura**. Existen Weave GitOps OSS, Capacitor, k9s plugins — todos para **observar**. El cambio pasa por Git. Siempre.

Esto es **diseño deliberado**, no omisión. La consecuencia operativa:

- **No hay "sync" manual desde una UI**. `flux reconcile` desde CLI reactiva el loop, pero no cambia el estado deseado — solo acelera la detección.
- **No hay "rollback" desde UI**. Rollback = `git revert`.
- **No hay override desde UI**. Si quieres cambiar replicas, cambias el manifest y commiteas.

Para equipos acostumbrados a Argo CD, esto suena restrictivo. Para equipos que han sufrido "alguien hizo click en Sync a prod un viernes a las 6pm", suena **liberador**. No es una limitación técnica — es una política de operación materializada en el producto.

---

## 11. Comparación tabular Argo CD vs Flux v2

| Dimensión | Argo CD | Flux v2 |
|---|---|---|
| **Unidad** | `Application` (monolítica) | 5+ CRs pequeños, composición por referencia |
| **UI con write** | Sí (sync, rollback, override) | **No** por diseño |
| **SSO/OIDC** | Nativo (Dex incluido) | Vía el proveedor de K8s / impersonación |
| **Multi-tenancy** | `AppProject` (RBAC propio) | `serviceAccountName` + impersonation |
| **Helm** | `helm template` + apply (sin hooks nativos) | `helm install/upgrade` real (hooks funcionan) |
| **Image automation** | Add-on (`argocd-image-updater`) | **Nativo** (`image-automation-controller`) |
| **Sharding del controller** | Sí (`application-controller` shardable) | Cada controller escala independiente |
| **Notificaciones** | `notifications-controller` | `notification-controller` + `Receiver` para webhooks |
| **Bootstrap** | `kubectl apply -f install.yaml` + Application `self-managed` | `flux bootstrap` commitea manifests al repo (auto-managed desde segundo 1) |
| **CRs por release** | 1 `Application` | 2–3 CRs (`Source` + `Kustomization`/`HelmRelease`) |
| **Curva de aprendizaje** | Más baja (UI ayuda) | Más alta (todo CLI/CRs) |
| **Progressive delivery** | Argo Rollouts (del mismo proyecto) | Flagger (Weaveworks) — comparable |
| **Ecosistema** | ApplicationSets, Rollouts, Workflows, Events | Toolkit modular (más chico, más coherente) |
| **Backup** | Backup del namespace `argocd` (todo son CRs) | Backup del namespace `flux-system` + repo Git (es la fuente de verdad) |

Las dos son soluciones **viables en producción**. Ninguna es "la correcta" en abstracto.

---

## 12. Criterios de migración (ida y vuelta posibles)

Dato clave: **los manifests subyacentes no cambian**. Un chart Helm es un chart Helm; un overlay Kustomize es un overlay Kustomize. Lo que cambia es **el reconciliador**. Esto hace que la migración sea **reversible** si se planea bien.

**Elige Flux si**:

- Tu org valora GitOps estricto y quiere eliminar la tentación de "clickear en Sync".
- Image automation con commit a Git es un requisito (sin add-ons).
- Prefieres un toolkit modular y menos opinado sobre UX.
- Tu equipo ya opera por CLI con comodidad.
- Usas charts Helm que dependen de hooks nativos.

**Elige Argo CD si**:

- Tu org valora **UX operador**: diff visual, árbol de recursos, logs integrados.
- Tienes operadores no-SRE que necesitan visibilidad sin kubectl.
- SSO/OIDC integrado out-of-the-box es importante.
- Vas a usar ApplicationSets con generadores complejos (PR, SCM) sin construir tu propia tooling.
- El ecosistema Argo (Rollouts, Workflows, Events) te aporta.

**Patrón de migración reversible** (de Argo CD a Flux):

1. **No tocar los manifests**. Dejar el repo de infra intacto.
2. Instalar Flux en el cluster (puede convivir con Argo CD unos días).
3. Elegir **una Application** piloto de Argo CD. Suspenderla (`argocd app set --sync-policy none`). Crear la `GitRepository` + `Kustomization` o `HelmRelease` equivalente en Flux. Validar `Ready=True`.
4. Repetir por app. Al final, borrar las Applications de Argo CD y luego Argo CD.
5. Vuelta: idéntico pero en reverso. Suspender Flux, aplicar Applications, borrar Flux.

Clave: **nunca** dejar que ambos reconcilien el mismo recurso simultáneamente. El resultado es un ping-pong de SSA field manager y recursos marcados "modified".

---

## Resumen operacional

Flux v2 es **el mismo problema con una filosofía distinta**. No es "Argo CD peor" ni "Argo CD mejor" — es Argo CD con **otro contrato de UX**: más estricto en GitOps, menos amigable para operadores que viven en UIs, mejor para plataformas que quieren un toolkit modular. Entenderlo te hace mejor arquitecto GitOps aunque te quedes en Argo CD — porque te obliga a defender tu elección con criterios y no por inercia.

El entregable final del curso es el ADR que decide, para una organización concreta, cuál usar. Esa decisión es el verdadero objetivo de este módulo.
