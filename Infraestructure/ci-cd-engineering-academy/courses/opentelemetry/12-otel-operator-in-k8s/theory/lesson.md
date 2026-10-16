# otel-12 — Teoría: OpenTelemetry Operator en Kubernetes

> **Lectura previa.** `k8s-14-operators-and-crds` (qué es un operador y cómo reconcilia) y `otel-09-collector-deployment-patterns` (agent vs gateway, sidecar, procesadores).

El Operator convierte toda la operación de OTel en Kubernetes en un ejercicio de **recursos declarativos**: en vez de componer Helm charts + ConfigMaps + Deployments a mano, el estudiante aplica un `OpenTelemetryCollector` y un `Instrumentation`, y el Operator se encarga del resto.

---

## 1. Qué es el OTel Operator y por qué existe

El **OpenTelemetry Operator** (repo `open-telemetry/opentelemetry-operator`) es un operador Kubernetes que:

- Define dos **CRDs** principales: `OpenTelemetryCollector` y `Instrumentation` (más `OpAMPBridge` como experimental).
- Reconcilia cada CR hacia **objetos nativos**: `ConfigMap`, `Deployment`/`DaemonSet`/`StatefulSet`, `Service`, `ServiceAccount`, `ClusterRole(Binding)`, `HorizontalPodAutoscaler`, `PodDisruptionBudget`, `Ingress`.
- Implementa un **mutating admission webhook** que, viendo annotations en un Pod (`sidecar.opentelemetry.io/inject`, `instrumentation.opentelemetry.io/inject-<lang>`), inyecta containers / initContainers / env vars antes de que el Pod se cree.

**Por qué existe** si ya hay un Helm chart oficial:

| | Helm "manual" | OTel Operator |
|---|---|---|
| Instalación | `helm install` renderiza templates una vez | Instala CRDs + Deployment del Operator |
| Cambio de config | Editas `values.yaml` → `helm upgrade` | Editas el CR → el Operator reconcilia |
| Auto-inject SDK | No existe (debes modificar manifests de cada app) | Annotation en el Pod → el webhook inyecta todo |
| Target Allocator | Debes templarlo y mantener la coordinación | `spec.targetAllocator.enabled: true` |
| Garantías ante drift | Ninguna; si editas el Deployment generado, queda editado | El Operator **revierte** cambios manuales |
| Blast radius | Un chart por release; granular | Un Operator por cluster; afecta a todas las instancias |
| Debug | `helm get manifest` | `kubectl describe otelcol`, logs del Operator |

Elección: Helm para instalaciones pequeñas / "una sola gateway"; Operator cuando hay **muchas instancias**, **mixing de modes** (agent + gateway + sidecar), o se quiere **auto-inject**.

---

## 2. Dependencias e instalación

### cert-manager

El webhook del Operator necesita **TLS** (porque el API server rechaza webhooks sin certs válidos). La forma recomendada de proveerlo es **cert-manager**: el Operator crea un `Certificate` que cert-manager materializa en un `Secret`, y el webhook lo monta.

Alternativa: `--self-signed-tls` en el Operator (genera su propio cert). Es útil en kind/dev pero cert-manager es el camino de producción porque además te deja rotar.

Instalación típica en kind:

```bash
# cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.0/cert-manager.yaml
kubectl wait --for=condition=Available --timeout=180s deploy -n cert-manager --all

# OTel Operator
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
kubectl wait --for=condition=Available --timeout=180s deploy -n opentelemetry-operator-system --all
```

Verifica:

```bash
kubectl get crds | grep opentelemetry
# opentelemetrycollectors.opentelemetry.io
# instrumentations.opentelemetry.io
# opampbridges.opentelemetry.io
```

---

## 3. CR `OpenTelemetryCollector` — anatomía

El shape mínimo:

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: gateway
  namespace: observability
spec:
  mode: deployment       # deployment | daemonset | sidecar | statefulset
  replicas: 2
  image: otel/opentelemetry-collector-contrib:0.111.0
  config:
    receivers:
      otlp:
        protocols:
          grpc: {endpoint: 0.0.0.0:4317}
          http: {endpoint: 0.0.0.0:4318}
    processors:
      batch: {}
    exporters:
      debug: {verbosity: basic}
    service:
      pipelines:
        traces: {receivers: [otlp], processors: [batch], exporters: [debug]}
```

Nota: desde `v1beta1` la config es un **mapa tipado** (antes era un string YAML embebido en `v1alpha1`). Esto permite al Operator validar y referenciar sub-campos.

Objetos reconciliados por este CR:

- `ConfigMap gateway-collector-<hash>` — con la config renderizada.
- `Deployment gateway-collector`.
- `Service gateway-collector` (ClusterIP, expone 4317 / 4318).
- `ServiceAccount gateway-collector`.
- RBAC si la config declara receivers que lo requieren (p. ej. `k8sattributes`).

### Modes

| Mode | Workload | Caso de uso |
|---|---|---|
| `deployment` | `Deployment` + Service | Gateway central; procesado pesado; batching antes de exporter remoto. |
| `daemonset` | `DaemonSet` | Agent por nodo; capta `hostmetrics`, `filelog` del nodo, OTLP de apps co-ubicadas. |
| `sidecar` | Inyectado como container | Un Collector por Pod; aislamiento máximo; para apps que no pueden hablar a un gateway (p. ej. TLS/mTLS complicado). |
| `statefulset` | `StatefulSet` | Processors stateful: **tail sampling** (necesita ver todos los spans de un trace en el mismo collector), **Target Allocator** (identidad estable). |

El modo `sidecar` se activa anotando el **Pod** con `sidecar.opentelemetry.io/inject: "<ns>/<otelcol-name>"`.

---

## 4. CR `Instrumentation` — auto-inject del SDK

El `Instrumentation` CR declara, por lenguaje, qué SDK inyectar y a dónde apuntar:

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: default-instr
  namespace: demo
spec:
  exporter:
    endpoint: http://gateway-collector.observability:4318
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "1.0"
  python:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-python:0.47b0
    env:
      - name: OTEL_LOGS_EXPORTER
        value: otlp
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:2.8.0
```

Para activarlo en un Pod se añade **una annotation** por lenguaje:

```yaml
annotations:
  instrumentation.opentelemetry.io/inject-python: "true"
  # o "default-instr" (nombre del CR), o "ns/name", o "false"
```

### Qué hace el mutating webhook

En el momento de crear el Pod, el webhook mutador:

1. Lee la annotation `inject-python=true` y resuelve el CR `Instrumentation` aplicable (por nombre o default en el namespace).
2. Añade un **initContainer** `opentelemetry-auto-instrumentation-python` que copia el SDK + wheels a un `emptyDir`.
3. **Monta** ese `emptyDir` en el container de la app en `/otel-auto-instrumentation-python`.
4. Inyecta **env vars**: `PYTHONPATH`, `OTEL_SERVICE_NAME` (de `app.kubernetes.io/name` o `k8s.deployment.name`), `OTEL_RESOURCE_ATTRIBUTES` (con `k8s.*`), `OTEL_EXPORTER_OTLP_ENDPOINT`, propagators, sampler.
5. Deja el container de la app sin tocar su image: todo viene del initContainer.

Resultado: la app **no cambia**. Si estaba hecha con FastAPI/requests/psycopg2, aparece auto-instrumentada en el gateway. Esto es *zero-code instrumentation*.

Limitaciones: el proceso de la app debe ejecutar `python` (no un binario compilado); el `PYTHONPATH` debe honrarse (no sirve con virtualenvs que lo "pisen"); la cobertura depende del catálogo de `opentelemetry-instrumentation-*` del SDK.

---

## 5. Target Allocator — scrape Prometheus distribuido

**Problema:** con N réplicas de Collector y un receiver `prometheus`, cada réplica scrape *todos* los targets → métricas duplicadas N veces.

**Solución clásica (Prometheus HA):** `honor_labels` + deduplicación en el remote-write backend. Caro y frágil.

**Solución del Operator:** un sidecar `targetallocator` que:

1. Descubre todos los targets (`PodMonitor`, `ServiceMonitor` del Prometheus Operator; o `scrape_configs` estáticos).
2. Los **particiona entre las réplicas** usando una estrategia (`consistent-hashing`, `least-weighted`, `per-node`).
3. Expone un HTTP server; cada réplica del Collector pregunta "cuáles targets me tocan a mí".
4. Reasigna cuando una réplica cae / entra (reconfig dinámica).

Shape:

```yaml
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: prom-scraper
spec:
  mode: statefulset        # REQUERIDO para Target Allocator
  replicas: 3
  targetAllocator:
    enabled: true
    allocationStrategy: consistent-hashing
    prometheusCR:
      enabled: true        # descubre PodMonitor/ServiceMonitor del Prometheus Operator
      podMonitorSelector: {}
      serviceMonitorSelector: {}
  config:
    receivers:
      prometheus:
        config:
          scrape_configs: []   # el TA inyecta los que descubre
    exporters:
      prometheusremotewrite:
        endpoint: http://mimir:9009/api/v1/push
    service:
      pipelines:
        metrics: {receivers: [prometheus], exporters: [prometheusremotewrite]}
```

Por qué **statefulset:** cada réplica tiene un hostname estable (`prom-scraper-collector-0`, `-1`, `-2`); el TA mapea targets por identidad.

Integración con Prometheus Operator: el TA aprende los `PodMonitor`/`ServiceMonitor` existentes del cluster — permite reutilizar la configuración declarativa que ya se tiene y migrar de Prometheus → Collector sin reescribir monitors.

---

## 6. Receivers "k8s-native"

El Operator no define receivers, pero habilita unos muy útiles del Collector contrib que *solo tienen sentido en K8s*:

- **`k8sobjects`** — hace `watch` de recursos (Events, Pods, Deployments) y los emite como **logs**. El uso típico: `k8sobjects` sobre `events.v1.k8s.io` → Loki, para tener `kubectl get events` buscable e histórico.
- **`k8s_cluster`** — métricas de inventario (nodes, pods ready, replicas desired/available). Correrlo **en una sola réplica** (StatefulSet replicas=1) para no duplicar.
- **`kubeletstats`** — contacta al kubelet local (DaemonSet) para métricas por container/pod (CPU, memory, filesystem).

Patrón común:

```
DaemonSet (agent):
  receivers: hostmetrics, kubeletstats, filelog, otlp
  exporters: otlp (→ gateway)

StatefulSet (gateway, replicas=3, TA):
  receivers: otlp, prometheus (TA), k8s_cluster (sólo en pod -0 vía scaling trick)
  processors: k8sattributes, batch, memory_limiter
  exporters: otlp/tempo, prometheusremotewrite/mimir, otlp/loki
```

---

## 7. `k8sattributes` processor

Enriquece telemetría con labels/annotations/metadata del Pod que la produjo. **Cómo funciona:**

- El Collector recibe spans/metrics/logs vía OTLP.
- `k8sattributes` extrae la **IP source** de la conexión (o atributos `net.peer.*` si llegan).
- Pregunta al API server: "¿qué Pod tiene esa IP?" (watch cacheado).
- Adjunta `k8s.pod.name`, `k8s.namespace.name`, `k8s.node.name`, `k8s.pod.uid`, y opcionalmente labels/annotations/container name.

Config típica:

```yaml
processors:
  k8sattributes:
    auth_type: serviceAccount
    passthrough: false
    extract:
      metadata:
        - k8s.namespace.name
        - k8s.pod.name
        - k8s.pod.uid
        - k8s.node.name
        - k8s.deployment.name
      labels:
        - tag_name: app
          key: app.kubernetes.io/name
          from: pod
    pod_association:
      - sources: [{from: resource_attribute, name: k8s.pod.ip}]
      - sources: [{from: connection}]
```

**RBAC mínimo** (el Operator lo genera automáticamente si detecta el processor): `get`, `list`, `watch` sobre `pods`, `namespaces`, y opcionalmente `nodes`, `replicasets`.

Dónde ponerlo: idealmente en el **agent (DaemonSet)**, porque ahí la conexión viene del Pod local (misma IP de nodo, source IP del Pod verdadero). Si está en el gateway y entre medias hay un Service con NAT, la IP source puede ser la del nodo y no la del Pod — romperá la correlación.

---

## 8. Patrón de referencia: stack completo

```
┌──────────────────── cluster ────────────────────┐
│                                                  │
│  cert-manager (ns cert-manager)                  │
│  OTel Operator (ns opentelemetry-operator-system)│
│                                                  │
│  ns observability:                               │
│    OpenTelemetryCollector/agent    mode=daemonset│
│      receivers: otlp, hostmetrics, filelog       │
│      processors: k8sattributes, batch            │
│      exporters: otlp → gateway                   │
│                                                  │
│    OpenTelemetryCollector/gateway  mode=statefulset
│      replicas: 3, TA enabled                     │
│      receivers: otlp, prometheus(TA)             │
│      processors: batch, memory_limiter           │
│      exporters: otlp/tempo, prw/mimir, otlp/loki │
│                                                  │
│  ns demo:                                        │
│    Instrumentation/default-instr                 │
│      python: image=..., endpoint=agent:4318      │
│    Deployment/app (annotation inject-python=true)│
│      → initContainer autoinstr + env OTEL_*      │
└──────────────────────────────────────────────────┘
```

El flujo de un trace de la app:

1. Request llega al Pod `app`.
2. El SDK (inyectado) crea spans y los envía por **OTLP HTTP** a `http://agent-collector.observability:4318` (o al agent DaemonSet local, si el `Instrumentation` apunta a `$(NODE_IP)`).
3. El agent añade `k8s.*` via `k8sattributes` y hace batch.
4. El agent exporta OTLP al gateway (statefulset).
5. El gateway dedupe/sampling/routing y empuja a Tempo + espejo a Datadog, etc.

---

## 9. Upgrade del Operator y de los Collectors

**Upgrade del Operator** (controller mismo):

- Es un Deployment en `opentelemetry-operator-system`. `kubectl apply` del manifest nuevo lo reemplaza.
- Las **CRDs** evolucionan: `v1alpha1 → v1beta1` ya ocurrió. El manifest trae `conversion webhook`; cert-manager debe estar sano para que funcione.
- Riesgo: si el Operator nuevo introduce defaults distintos, los CRs existentes pueden re-renderizar su ConfigMap → **rollout** de todos los Collectors (visible). Siempre leer el changelog.

**Upgrade del Collector** gestionado por un CR:

- Dos vías:
  1. **Pin explícito**: `spec.image: otel/opentelemetry-collector-contrib:0.112.0`. Cambias la línea, aplicas, el Operator rollinguptea.
  2. **Image por default del Operator**: si no seteas `spec.image`, el Operator usa su default. Upgrade del Operator → cambio implícito del default → rollout masivo.
- Preferir **(1)** en producción para que el upgrade del Operator no mueva Collectors.
- Si cambias **config** (`spec.config`), el Operator genera un ConfigMap con hash nuevo → rollout.
- `spec.upgradeStrategy: none` desactiva el auto-upgrade implícito desde el default del Operator.

**Rollback**: `kubectl apply` del CR anterior. Como el ConfigMap tiene hash, el Operator vuelve al estado previo.

---

## 10. Operator vs Helm "manual"

| Criterio | Helm | Operator |
|---|---|---|
| Curva | Baja (YAML + values) | Media (CRDs, webhooks, cert-manager) |
| Drift protection | Ninguna | Reconciliación continua |
| Auto-inject SDK | Imposible declarativo | Nativo |
| Target Allocator | A mano, duplica métricas sin él | `enabled: true` |
| Multi-collector | Múltiples releases | Múltiples CRs, un controller |
| GitOps | Perfecto (Argo/Flux aplican charts) | También (CRs son YAML) |
| Debug | `helm get manifest`, `--dry-run` | `kubectl describe otelcol`, logs del Operator |
| Blast radius de bug | Al chart afectado | Al Operator entero → todos los Collectors |
| Dependencias | Ninguna | cert-manager (recomendado) |

**Regla práctica**:

- 1-2 Collectors, sin auto-inject, sin TA → **Helm**.
- Más de 2, o se quiere auto-inject, o se quiere TA → **Operator**.
- Entorno enterprise con decenas de teams generando telemetría → **Operator** sí o sí.

---

## 11. Observabilidad del propio stack

El Operator y los Collectors exponen métricas Prometheus:

- Operator: `/metrics` en el puerto `8080` del Pod del controller — contadores de reconcile, errores, admisiones.
- Collectors: `/metrics` en `:8888` por default — `otelcol_receiver_accepted_spans`, `otelcol_exporter_sent_spans`, `otelcol_processor_batch_batch_size_trigger_send`.

Signo canónico de un pipeline sano: `receiver_accepted ≈ exporter_sent + processor_dropped`. Si `receiver_refused` crece, hay backpressure (memory_limiter o el exporter remoto está lento).

---

## 12. Errores comunes y cómo diagnosticarlos

| Síntoma | Causa típica | Diagnóstico |
|---|---|---|
| El CR `OpenTelemetryCollector` queda sin Deployment generado | Webhook del Operator caído (cert-manager mal) | `kubectl get events -n <ns>`; `kubectl describe otelcol`; logs del Operator |
| Annotation `inject-python=true` no inyecta nada | No existe `Instrumentation` en el namespace / name mal referenciado | `kubectl describe pod` — no hay initContainer `opentelemetry-auto-instrumentation-python`; comprobar `Instrumentation` CR |
| `k8sattributes` no adjunta atributos | RBAC faltante o `pod_association` mal (IP no coincide, hay NAT) | logs del Collector `connection refused` o `pod not found for ip` |
| Target Allocator no distribuye | `prometheusCR.enabled: true` pero no hay Prometheus Operator CRDs | `kubectl get podmonitor` → `error: the server doesn't have a resource type`; instalar Prometheus Operator CRDs |
| Rollout masivo tras upgrade del Operator | `spec.image` no fijado → defaults cambiaron | pinear `spec.image` en todos los CRs |
| Dos réplicas del gateway duplican métricas | No se usó TA; receiver `prometheus` activo en N réplicas | pasar a `statefulset` + `targetAllocator.enabled` |

---

### Resumen

El OTel Operator es la forma madura de operar OTel en K8s: convierte Collectors y SDKs en recursos declarativos reconciliados, resuelve el scrape distribuido (TA), y permite auto-inject sin tocar las apps. El costo es una dependencia más (cert-manager) y un controller más que mantener; a cambio, el stack se opera por `kubectl apply`.
