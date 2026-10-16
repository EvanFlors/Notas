# Lección — helm-10: Platform patterns, library charts, GitOps y la frontera con Kustomize

> Lección final del curso Helm. 12 secciones. El objetivo no es sumar features: es cerrar el modelo con las decisiones que una plataforma real tiene que tomar sobre Helm.

---

## 1. Helm como pieza de plataforma, no como script

Hasta aquí, cada módulo trató Helm como una herramienta: `helm install`, `helm upgrade`, un chart, una release. En producción multi-equipo, Helm deja de ser una herramienta y pasa a ser una **capa de la plataforma**:

- Varios equipos escriben charts, pero los **helpers** deberían ser los mismos (labels, selectors, nombres, probes, resources por default). Esa es la función del **library chart**.
- Nadie quiere que cada equipo decida *cómo* se renderiza y se aplica un chart. La plataforma elige: Helm "a mano", Argo CD, Flux, o un operador. Esa es la función del **contrato de plataforma**.
- El binario `helm` no es el único que ejecuta tus charts: Argo CD y Flux leen el mismo chart y lo renderizan con **otra semántica**. Hay que diseñar para ambos.
- A veces Helm no es la respuesta: Kustomize o un operador lo hacen mejor para casos concretos. Hay que saber reconocer esos casos.

Este módulo trata esas cuatro cosas.

---

## 2. Library charts: `type: library`

Un library chart es un chart especial:

- `Chart.yaml` declara `type: library` (en vez de `application`).
- **No produce manifests por sí mismo**. Si lo instalas, no pasa nada.
- Sus archivos en `templates/` deben empezar con `_` (p. ej. `_labels.tpl`) y contener solo bloques `{{- define "..." -}}`. Helm ignora los `_*.tpl` como manifest.
- Otros charts lo listan como `dependencies:` y lo invocan con `{{ include "lib.labels" . }}`.

Mental model: **una library de código compartida entre proyectos**, con versionado independiente. Esto evita el patrón "copia-pega `_helpers.tpl` entre 15 charts".

```yaml
# platform-lib/Chart.yaml
apiVersion: v2
name: platform-lib
type: library
version: 0.1.0
```

```gotemplate
{{/* platform-lib/templates/_labels.tpl */}}
{{- define "platform.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
platform.example.com/owner: {{ .Values.owner | default "unknown" }}
{{- end -}}
```

Consumo:

```yaml
# consumer/Chart.yaml
apiVersion: v2
name: consumer
type: application
version: 0.1.0
dependencies:
  - name: platform-lib
    version: 0.1.0
    repository: "file://../platform-lib"
```

```gotemplate
metadata:
  labels:
    {{- include "platform.labels" . | nindent 4 }}
```

Dos reglas de higiene:

1. **Versiona la lib como un producto**. SemVer estricto. Un `include` que cambia es un breaking change.
2. **No metas lógica de negocio en la lib**. Solo cosas transversales: labels, selectors, nombres, defaults de probes, snippets de securityContext. La lógica va en el chart application que la consume.

---

## 3. "Golden chart" de plataforma: un chart genérico vs chart por app

En equipos con muchas apps parecidas (HTTP APIs, workers), aparece la tentación de un **"golden chart"**: un único chart que todas las apps consumen pasando `values.yaml`. Tipo:

```yaml
# values.yaml del equipo de producto
image:
  repository: ghcr.io/acme/my-api
  tag: 1.4.2
ports: [8080]
env:
  - name: LOG_LEVEL
    value: info
```

Y el chart golden se encarga de Deployment + Service + Ingress + HPA + PDB + probes + resources + labels.

**Ventajas**: velocidad brutal para crear apps nuevas; uniformidad real; el equipo de plataforma itera sobre un único chart y todos reciben las mejoras.

**Riesgos**:

- **Over-abstracción**: cada nueva app pide un knob más; el chart termina siendo un "mini-Kubernetes" en `values.yaml`.
- **Breaking changes caros**: cambiar un default afecta a N apps a la vez.
- **Lifecycle acoplado**: todos actualizan la misma versión del chart o nadie actualiza.

Regla práctica: **golden chart cubre el 80%, chart por app para el 20% raro**. Y nunca un golden chart sin `values.schema.json` que delimite el contrato.

Diferencia con el library chart:
- Library chart = helpers reusables (no manifests). Consumido por charts application.
- Golden chart = chart application completo que apps consumen vía `values`.

Pueden coexistir: el golden chart interno usa el library chart interno.

---

## 4. Helm + Argo CD: cómo lo ejecuta Argo (y cómo lo rompe)

Argo CD trata un chart Helm como una **fuente de manifests**. En el `Application`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-api
  namespace: argocd
spec:
  destination:
    namespace: my-api
    server: https://kubernetes.default.svc
  source:
    repoURL: https://charts.example.com
    chart: my-api
    targetRevision: 1.4.2
    helm:
      releaseName: my-api
      valueFiles:
        - values-prod.yaml
      values: |
        replicaCount: 3
      parameters:
        - name: image.tag
          value: 1.4.2
  project: default
  syncPolicy:
    automated: {prune: true, selfHeal: true}
```

Lo crítico — y lo que la gente aprende tarde:

- Argo CD **no ejecuta `helm install`**. Lanza `helm template` (vía el Config Management Plugin interno o `helm render`), le mete los `values`/`valueFiles`/`parameters` y aplica el YAML con server-side apply.
- Por tanto, **no hay Secret de release de Helm en el cluster**. Las operaciones `helm list`, `helm history`, `helm rollback` no ven la app. El rollback se hace en Argo (`argocd app rollback`) o volviendo el commit en Git.
- Los **hooks de Helm** (`"helm.sh/hook": pre-install`) se mapean a hooks de Argo (`argocd.argoproj.io/hook: PreSync`). El mapeo no cubre todos los weights ni todas las delete-policies con la misma semántica. Las migraciones DB que funcionaban con `helm install --wait` pueden comportarse distinto bajo Argo.
- `releaseName` **no es** el `name` del `Application`. Si no lo pones, Argo CD usa el nombre del `Application` como releaseName virtual — eso cambia los nombres generados por `fullname` helpers.
- **No uses `--atomic`** en Argo: Argo tiene su propio modelo de sync + rollback. Los flags de la CLI de Helm no se pasan.

Patrón recomendado:

- Hooks que *tienen que* ejecutarse antes de aplicar: expresarlos **también** como `PreSync` de Argo (anotación extra) o migrarlos a `argo-rollouts`/Job gestionado fuera del chart.
- `helm test` no se ejecuta automáticamente desde Argo. Si quieres smoke, dispáralo desde el pipeline post-sync o usa `syncwaves` + un Job de test.
- Para N entornos, prefiere `ApplicationSet` con `valueFiles: values-{{env}}.yaml` sobre duplicar `Application`s.

---

## 5. Helm + Flux: `HelmRelease` v2

Flux ataca el mismo problema con otro diseño: un controlador (`helm-controller`) que **sí** ejecuta Helm server-side. En el cluster hay:

- Un `HelmRepository` o `OCIRepository` que apunta al origen del chart.
- Un `HelmRelease` que describe el release deseado.

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: example
  namespace: flux-system
spec:
  interval: 10m
  url: https://charts.example.com
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: my-api
  namespace: my-api
spec:
  interval: 5m
  chart:
    spec:
      chart: my-api
      version: 1.4.2
      sourceRef:
        kind: HelmRepository
        name: example
        namespace: flux-system
  values:
    replicaCount: 3
  install:
    remediation: {retries: 2}
  upgrade:
    remediation: {retries: 2, remediateLastFailure: true}
```

Consecuencias:

- Existe el **Secret de release** de Helm normal; `helm list -A` lo ve.
- Los **hooks de Helm funcionan tal cual** (no hay traducción como en Argo).
- `remediation` reemplaza a `--atomic`: define reintentos y qué hacer en el último fallo.
- `valuesFrom` permite inyectar valores desde `ConfigMap`/`Secret`, útil para separar config de código.

**Flux vs Argo con Helm, en una frase**: Flux ejecuta Helm; Argo lo imita. Si tus charts explotan los hooks a fondo, Flux duele menos. Si tu organización ya corre Argo para todo lo demás, usa Argo y acepta las trampas.

---

## 6. Helm + Kustomize: post-rendering

Hay dos formas legítimas de combinarlos:

**(a) `helm template | kustomize build`** — una pipe de shell, útil para GitOps "en frío" o para generar artefactos para auditoría:

```bash
helm template my-rel ./my-chart --values prod.yaml > /tmp/base/all.yaml
# kustomization.yaml referencia /tmp/base/all.yaml y aplica patches
kustomize build /tmp/overlay | kubectl apply -f -
```

**(b) `--post-renderer`** — la vía oficial. Helm renderiza, pasa stdout por un binario que modifica el YAML, y aplica/empaqueta el resultado:

```bash
# Helm 3 — path directo a ejecutable:
helm upgrade --install my-rel ./my-chart \
  --post-renderer ./kustomize-postrender.sh
```

Donde `kustomize-postrender.sh` lee stdin, lo escribe a disco, corre `kustomize build` en el overlay y escupe el resultado por stdout. El contrato es trivial: **binario que lee YAML por stdin, escribe YAML por stdout, exit 0**.

> **Nota Helm 4**: `--post-renderer` cambió para aceptar únicamente **plugins** de tipo `postrenderer/v1` (instalables con `helm plugin install`). Si estás en Helm 4 y no quieres empaquetar un plugin, el patrón (a) — `helm template | kustomize build` — es equivalente y portable entre v3 y v4.

¿Cuándo tiene sentido?

- Un chart de un tercero (ingress-nginx, cert-manager) que necesita un patch que no es expresable como `values` — por ejemplo, inyectar una `tolerations` específica, un `nodeSelector` o un sidecar en el controller del chart.
- Overrides corporativos (labels, imagePullSecrets, annotations de registro) que querrías aplicar **a todos los charts** uniformemente — un único `kustomize` reusable como post-renderer.
- Edición puntual sin forkear el chart.

Lo que **no** justifica un post-renderer:
- Añadir resources nuevos que podrían vivir como `extraManifests` en `values.yaml` del chart.
- Templating adicional que podrías mandar como PR al chart.

---

## 7. Cuándo migrar de Helm a Kustomize puro

Síntomas de que Helm sobra:

- Tu chart tiene un solo `values.yaml` real, el resto son copias del mismo con un valor cambiado. Un overlay de Kustomize sería 20 líneas.
- Nadie usa `helm rollback`; los rollbacks se hacen con `git revert`.
- Nadie publica el chart; solo lo consume el equipo que lo escribe.
- Los Go templates meten más bugs que valor (indentación, `null`, listas vacías).
- Eres el único consumidor y nadie va a leer `values.yaml` como "API pública".

En esos casos, Kustomize con **base + overlays por entorno** es más simple, menos frágil y encaja con GitOps sin fricción.

Síntomas de que Helm sigue siendo correcto:

- Distribuyes el chart a terceros (clientes, equipos ajenos).
- Hay release lifecycle real (hooks, `helm rollback`, `helm history`).
- `values.yaml` se parece a una API documentada con `values.schema.json`.
- Hay sub-charts y dependencias versionadas.

---

## 8. Cuándo migrar de Helm (o Kustomize) a un operador

Un chart es un "snapshot": al instalar, materializa un conjunto de recursos. **No reconcilia lógica de dominio**. Un operador es un controller con un CRD: sabe lo que es "una base de datos Postgres sana", observa continuamente y actúa.

Pistas de que el chart se queda corto:

- La operación requiere lógica más allá de "aplicar YAML": backup/restore condicional, failover, rolling schema migrations, re-sharding.
- El estado deseado no se puede expresar como YAML estático (depende de qué pasa en runtime).
- Hay varios charts del mismo producto, cada uno manejando una fase (install, upgrade, backup) — eso es un operador disfrazado.
- El usuario del producto no debería saber qué StatefulSet usas por detrás; quiere decir `kind: PostgresCluster` y nada más.

Casos típicos resueltos por operadores en vez de chart: Postgres (CloudNativePG), Kafka (Strimzi), Prometheus (Prometheus Operator ya envuelto en un chart), Elasticsearch (ECK), Cassandra (K8ssandra).

Patrón común: el **operador se instala con un chart** (Prometheus Operator se instala vía `kube-prometheus-stack`), pero los recursos de dominio se expresan como CRDs del operador, no como más templates Helm.

---

## 9. Gobernanza de charts internos como productos

Un chart interno que consumen 10 equipos **es un producto**. Y como todo producto necesita:

- **SemVer explícito** del `version` del chart (independiente de `appVersion` de la app):
  - `MAJOR`: breaking change de `values` o de recursos aplicados (un consumidor **tiene que** cambiar algo).
  - `MINOR`: feature nueva compatible (un `value` nuevo con default seguro).
  - `PATCH`: fix sin cambio de interfaz.
- **Deprecation policy**: antes de borrar un `value` o un recurso, marcarlo como deprecated (p. ej., `fail` controlado en el template con `required`), publicar warning, dar N minor versions antes de borrar.
- **Migration guides**: cada MAJOR trae un `MIGRATING.md` con el diff requerido en `values.yaml` del consumidor.
- **Changelog** real, no "update". `KEEPACHANGELOG.md` es un buen punto de partida.
- **`values.schema.json`** siempre. Un chart interno sin schema no tiene API; tiene un contrato implícito, que es la peor clase de contrato.
- **Soporte de versiones**: declarar explícitamente cuántas versiones MAJOR se mantienen (p. ej., "N y N-1 reciben patches").
- **Testing matrix**: `chart-testing` + `helm-unittest` corriendo en CI contra las versiones de Kubernetes que la plataforma soporta.

---

## 10. Patrones recomendados y antipatrones

**Recomendados:**

- Un library chart propio (`platform-lib`) que todos los charts internos declaran como dep. Centraliza labels, selectors y nombres.
- Un golden chart (`platform-app`) para el 80% de servicios HTTP estándar.
- Entornos como `valueFiles` separados (`values-dev.yaml`, `values-stg.yaml`, `values-prod.yaml`), no `--set` en pipeline.
- `--atomic` + `--wait` en CI/CD directo (sin GitOps). Con GitOps, equivalente nativo (Argo sync wave / Flux remediation).
- `values.schema.json` como contrato real.
- Post-renderer para patches corporativos uniformes.

**Antipatrones:**

- `_helpers.tpl` copiado-pegado entre charts.
- Un chart "mega-genérico" sin schema que termina siendo un intérprete de YAML.
- `--set` como mecanismo principal de override (frágil, invisible en el repo).
- Hooks de Helm que asumen `helm install` pero el pipeline usa Argo CD.
- Chart interno sin SemVer explícito ni changelog.
- Post-renderer que *añade* lógica que podría vivir en el chart.

---

## 11. Decidir Helm vs Kustomize vs operador — rúbrica rápida

| Pregunta | Si "sí" → preferir |
|---|---|
| ¿Distribuyes el chart a terceros / clientes? | **Helm** |
| ¿Necesitas release lifecycle (install/upgrade/rollback con revisiones)? | **Helm** |
| ¿Las variaciones por entorno son pequeñas (replica count, image tag, 2–3 flags)? | **Kustomize** |
| ¿Nadie fuera del equipo lee `values.yaml`? | **Kustomize** |
| ¿El estado deseado depende de runtime (backup conditional, failover, resharding)? | **Operador** |
| ¿La operación requiere lógica continua, no "aplicar y olvidar"? | **Operador** |
| ¿Hay varios charts "del mismo producto" en fases distintas? | **Operador** |

Ninguna respuesta es dogma: la rúbrica orienta, el contexto decide. El trabajo del ADR en la actividad 02 es exactamente ese: hacer la decisión explícita y justificada.

---

## 12. Síntesis para el curso

Al cerrar este módulo deberías poder:

- Diseñar y mantener un **library chart** interno.
- Decidir cuándo tiene sentido un **golden chart** y cuándo chart por app.
- Integrar Helm con **Argo CD** sabiendo que no ejecuta `helm install` y qué significa eso para hooks, release storage y rollback.
- Integrar Helm con **Flux** usando `HelmRelease` v2.
- Usar **post-renderers** y Kustomize para edición puntual sin ensuciar el chart.
- Reconocer los tres escenarios donde Helm **ya no** es la respuesta correcta (migrar a Kustomize puro, migrar a un operador, o cambiar la fuente de la verdad al controller del operador).
- Versionar un chart interno **como un producto** con SemVer, deprecation policy, changelog y migration guides.

Es la pieza que convierte Helm de "herramienta" en **plataforma**. Y, por simetría, es la pieza que te permite decidir cuándo *no* usarlo.
