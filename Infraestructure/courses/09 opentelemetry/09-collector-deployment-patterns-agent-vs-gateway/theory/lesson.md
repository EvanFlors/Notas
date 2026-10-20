# otel-09 — Teoría: patrones de despliegue del Collector

> Lectura de ~60 min. Nivel avanzado. Asume `otel-08` (receivers / processors / exporters) ya comprendido.

---

## 1. Por qué la topología importa

El Collector es, nominalmente, un binario que recibe telemetría y la reenvía. Visto así, podría dar la impresión de que *dónde* lo despliegas es un detalle operativo. No lo es. La topología decide:

- **Qué metadata se adjunta** y en qué momento (lo que ve el proceso que corre junto al workload no es lo mismo que lo que ve un Pod central).
- **Dónde absorbes el pico** (buffer local pequeño por nodo vs buffer grande central).
- **Qué pierdes si algo cae** (SDK → directo = pérdida; agent sin disco = pérdida al reiniciar; gateway sin disco = pérdida al evictar).
- **Cuánto cuesta** (el gateway concentra batching → ahorro de ancho de banda y requests al backend).

Un pipeline de observabilidad "bien dimensionado" en papel puede perder el 20 % de los traces si está mal **topologizado**. Este módulo trata exactamente ese problema.

```
   SDK                            SDK                            SDK
    │                              │                              │
    │ OTLP                         │ OTLP                         │ OTLP
    ▼                              ▼                              ▼
┌─────────┐                 ┌─────────────┐                   (no Collector)
│  Agent  │  ─── OTLP ───►  │   Gateway   │  ───►  Backend(s)       │
│ (node)  │                 │ (central)   │                         ▼
└─────────┘                 └─────────────┘                     Backend
   nodo N                     Deployment                           ▲
                              + HPA + queue                     riesgo
```

---

## 2. Los cuatro patrones canónicos

### 2.1 Agent por nodo (DaemonSet en K8s)

Un Collector corre en cada nodo y recibe telemetría de los procesos locales. En K8s se despliega como **DaemonSet**.

**Para qué sirve bien:**

- Enriquecer con metadata **del nodo**: `host.name`, `k8s.node.name`, `cloud.availability_zone`, uptime, kernel version.
- Enriquecer con metadata **del pod** mediante `k8sattributes` processor (consulta a la API de K8s con cache local).
- Recibir señales *no-OTLP* locales: `filelog` (logs de containers desde `/var/log/pods`), `hostmetrics` (CPU, mem, disk, net del nodo), `kubeletstats`.
- Absorber el primer pico sin cruzar la red cluster.
- Minimiza la latencia que ve el SDK (OTLP a `localhost:4317` nunca falla por red externa).

**Para qué sirve mal:**

- Tail-based sampling (necesita ver un trace *completo* y los spans de un trace nacen en nodos distintos).
- Agregación cross-pod (p. ej. dedupe, cardinalidad global).
- Exportar directamente a muchos backends con credenciales distintas (multiplica fugas potenciales).

**Escalado:** vertical, con el nodo. No tiene sentido tener dos agents por nodo.

### 2.2 Gateway central (Deployment + Service)

Uno o varios Collectors detrás de un **Service** que agrupa, procesa pesado y exporta al backend.

**Para qué sirve bien:**

- Batching grande (reduce RPS al backend por 10x–100x).
- Compresión (gzip / zstd en el exporter OTLP).
- **Tail-based sampling** (requiere ver spans completos → necesita que todos los spans de un trace lleguen al mismo Pod del gateway; `load_balancing` exporter resuelve esto).
- Punto único de credenciales al backend (un secret, no N).
- Retry con backoff grande y queues en disco.
- Routing por tenant, por severidad, por tipo de signal.

**Para qué sirve mal:**

- Captura de metadata local del nodo (ya no la "ve"; depende de que el agent se la haya adjuntado antes).
- Punto único de falla si está mal replicado.

**Escalado:** horizontal con **HPA** sobre CPU, memoria o **métricas custom** del propio Collector (`otelcol_exporter_queue_size`, `otelcol_processor_batch_batch_send_size`).

### 2.3 Sidecar por pod

Un Collector como container adicional en el mismo Pod del workload. Comparten `localhost` y lifecycle.

**Cuándo tiene sentido:**

- Apps que **no pueden** hablar OTLP (p. ej. solo producen un formato propietario y necesitas traducirlo en el borde más cercano).
- **Aislamiento** fuerte por aplicación (una app ruidosa no afecta al agent del nodo).
- Casos de **multi-tenant** donde cada pod necesita credenciales/filtros propios.

**Costos:** multiplica el overhead (un Collector por pod); operativamente pesado. Suele descartarse salvo caso justificado. Lo gestiona bien el **OTel Operator** mediante inyección.

### 2.4 Sin Collector

El SDK exporta OTLP directamente al backend (self-hosted o SaaS).

**Cuándo tiene sentido:**

- Prototipos y demos.
- Un único servicio, un único backend, baja escala.
- Dev local.

**Qué pierdes:**

- Buffer central → cada SDK sufre caídas de backend por su cuenta.
- Enriquecimiento centralizado (Resource attributes consistentes).
- Routing / sampling / filtrado sin tocar el código de la app.
- Protección de credenciales: cada app lleva token del backend.

Buena práctica: incluso en dev, correr un Collector `otelcol-contrib` local con `debug` exporter ayuda a entender qué emite el SDK.

---

## 3. Agent + gateway: el patrón de referencia

El patrón recomendado en producción es **agent + gateway**:

```
┌────────────┐    OTLP      ┌─────────────────┐  OTLP + gzip
│ App (SDK)  │ ─(localhost)►│ Agent (node)    │ ────────────►  ┌──────────────┐
└────────────┘              │ k8sattributes   │                │ Gateway      │
                            │ batch pequeño   │                │ batch grande │
                            └─────────────────┘                │ tail-sampling│
                              x N nodos                        │ queue+disk   │
                                                               └──────┬───────┘
                                                                      │ OTLP
                                                                      ▼
                                                                  Backend(s)
```

Reparto de responsabilidades típico:

| Capa    | Responsabilidades                                                |
|---------|------------------------------------------------------------------|
| Agent   | Recibir OTLP local; `k8sattributes`; `resourcedetection`; `batch` chico; `memory_limiter`; `filelog`/`hostmetrics` si aplica. |
| Gateway | `batch` grande; `tail_sampling`; `attributes` (redacciones, PII); `routing`; `sending_queue` + `file_storage`; exporters al backend. |

Trucos útiles:

- El agent envía al gateway por **DNS del Service** (`otel-gateway.observability.svc.cluster.local:4317`).
- Compresión en el **agent → gateway** suele ser `gzip`; algunos equipos usan `none` dentro del cluster para gastar menos CPU y confiar en el ancho de banda interno; en **gateway → backend** siempre compresión.
- Si el gateway se cae, el agent se queda sin destino: configurar `sending_queue` en el agent con tamaño pequeño pero > 0 absorbe caídas cortas; el `retry_on_failure` hace el resto.

---

## 4. Dimensionamiento y escalado del gateway

El agent escala con el nodo (añades nodo → DaemonSet lo cubre). El **gateway** escala horizontalmente. Hay cuatro señales útiles para HPA:

1. **CPU** — barato, aproximación OK si los batches son uniformes.
2. **Memoria** — útil cuando se usa tail-sampling (buffer in-memory de traces).
3. **`otelcol_exporter_queue_size`** — la cola crece si el backend no da abasto: señal temprana.
4. **`otelcol_processor_batch_batch_send_size`** — latencia de batch como proxy de saturación.

Ejemplo de HPA (3 → 10 pods, target CPU 70 %):

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: { name: otel-gateway, namespace: observability }
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: otel-gateway
  minReplicas: 3
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target: { type: Utilization, averageUtilization: 70 }
```

Dimensionado grueso (regla de dedo, ajustar con benchmarking real):

| Escala           | Agents       | Gateway replicas | Notas |
|------------------|--------------|------------------|-------|
| 10 RPS, 1 nodo   | 1 (opcional) | 1 (o ninguno)    | Patrón **sin Collector** o solo agent es defendible. |
| 1 000 RPS, 10 nodos | 10 (DaemonSet) | 2–3 | HPA activo; empezar con 3, auto a 5. |
| 100 000 RPS, 100 nodos | 100 (DaemonSet) | 10–20, varias AZ | Tail-sampling con `load_balancing` + batching + `file_storage` imprescindible. |

Reglas clave:

- **Siempre** `memory_limiter` *antes* de cualquier processor que acumule (batch, tail_sampling).
- Nunca el gateway en el mismo nodo que el workload crítico (afinidad / taints).
- **PodDisruptionBudget** `minAvailable: 2` para el gateway.

---

## 5. Back-pressure y queue persistence

### 5.1 Qué pasa cuando el backend se cae

Flujo por default:

1. Exporter intenta enviar.
2. Falla → entra a `sending_queue` (in-memory).
3. `retry_on_failure` reintenta con backoff.
4. Si la cola se llena → el exporter **drops** (y suma a métricas `otelcol_exporter_send_failed_spans`).
5. Processors previos (batch, tail_sampling) se encogen por `memory_limiter` → el receptor OTLP comienza a devolver `RESOURCE_EXHAUSTED` → el SDK aplica back-pressure.

Mientras el pipeline esté *en vivo*, el back-pressure funciona. **El problema aparece si el Collector reinicia**: la cola in-memory se evapora.

### 5.2 File storage extension

La solución es persistir la cola en disco con `file_storage`:

```yaml
extensions:
  file_storage:
    directory: /var/lib/otelcol/storage
    timeout: 1s
    compaction:
      directory: /var/lib/otelcol/storage
      on_start: true

exporters:
  otlp:
    endpoint: backend:4317
    sending_queue:
      enabled: true
      num_consumers: 10
      queue_size: 10000
      storage: file_storage   # ← la clave

service:
  extensions: [file_storage]
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlp]
```

Con esto, al reiniciar el Pod la cola se recupera desde disco. En K8s, `/var/lib/otelcol/storage` debe estar en un volumen persistente (`emptyDir` sirve para un StatefulSet simple; para supervivencia de reschedules, `PersistentVolumeClaim`). Para el **agent (DaemonSet)**, `hostPath` es aceptable (el nodo es la unidad de persistencia).

### 5.3 Cuándo no activarlo

- Dev/CI (overhead I/O innecesario).
- Si la red al backend es extremadamente estable y la pérdida ante reinicio puntual es aceptable para la organización.

En producción con SLOs sobre observabilidad, activarlo es default.

---

## 6. Health check extension y probes

El Collector expone un endpoint de salud con la **extension `health_check`**:

```yaml
extensions:
  health_check:
    endpoint: 0.0.0.0:13133
    path: /

service:
  extensions: [health_check]
```

Los probes de K8s:

```yaml
livenessProbe:
  httpGet: { path: /, port: 13133 }
  initialDelaySeconds: 10
readinessProbe:
  httpGet: { path: /, port: 13133 }
  periodSeconds: 5
```

Buena práctica: usar `readinessProbe` para quitar el Pod del Service durante draining (`SIGTERM` → health degrade → service drena → `SIGKILL`), evitando pérdida de spans en vuelo.

Complementos útiles:

- **`pprof`** extension (puerto 1777) — profiling bajo demanda.
- **`zpages`** extension (puerto 55679) — introspección de pipelines por HTTP.

---

## 7. Compatibilidad de versiones y upgrades

El Collector se versiona independientemente de los SDK. Reglas prácticas:

- **OTLP wire format** es estable (v1); un SDK v1.20 habla con un Collector v0.90 sin problemas.
- La **config YAML** no es estable: cambia entre versiones minor (receivers que renombran campos, processors que se mueven de core a contrib, etc.). Revisa el **changelog** de cada upgrade.
- Entre `otelcol` (core) y `otelcol-contrib`, la **misma** configuración no siempre es portable (contrib trae componentes extra).

Estrategia de upgrade en topología agent+gateway:

1. **Gateway primero**: menor número de Pods, más fácil de rollback. Si pasa, agents a continuación.
2. Usa **rolling update** con `maxSurge: 1`, `maxUnavailable: 0` en el gateway.
3. Para DaemonSet (agent) usa `updateStrategy: RollingUpdate` con `maxUnavailable: 1` (un nodo a la vez).
4. Monitorea `otelcol_processor_dropped_spans` y `otelcol_exporter_send_failed_spans` **antes y después** del upgrade.

Si un upgrade rompe la config, el Pod no arranca → readinessProbe falla → el Service no envía tráfico allí. Por eso los probes son críticos.

---

## 8. Distros del Collector

El binario `otelcol` tiene varias "distros". Elegir la correcta ahorra sorpresas.

| Distro | Mantenedor | Qué trae | Cuándo usar |
|--------|------------|----------|-------------|
| `otelcol` (Core) | OTel upstream | Receivers/processors/exporters mínimos estables (OTLP, batch, memory_limiter, logging). | Casos muy simples o cuando quieres mínima superficie. |
| `otelcol-contrib` | OTel upstream | **Todo** lo anterior + componentes de la comunidad (prometheus, loki, tail_sampling, k8sattributes, filelog, hostmetrics, datadogexporter, etc.). | **Default** salvo que tengas razón para lo contrario. |
| **ADOT** (AWS Distro for OpenTelemetry) | AWS | Fork con componentes AWS (XRay, CloudWatch EMF, Prometheus remote write con SigV4), ciclo de soporte formal. | Workloads en AWS que quieren soporte vendor y exporters nativos AWS. |
| **Grafana Alloy** | Grafana Labs | Sucesor del Grafana Agent; integra lineage de OTel Collector + Prometheus Agent + Promtail en un binario con lenguaje de configuración propio (River / Flow). | Stack Grafana (Mimir/Tempo/Loki) y organizaciones que ya usaban Grafana Agent. |
| Vendor-específicas | Splunk, Honeycomb, Datadog, Sumo Logic… | Core/contrib + extras propios + telemetría de uso. | Si el vendor es el destino y quieres soporte end-to-end. |

**Idea clave**: la portabilidad del *pipeline* se mantiene porque las piezas estándar (OTLP, batch, memory_limiter, tail_sampling…) existen en todas las distros. Lo que cambia es la "última milla" (exporters propietarios, extensiones de seguridad).

**Alloy caveat**: Alloy no es "más Collector"; su lenguaje de config es distinto. Portabilidad conceptual sí; portabilidad de YAML no.

---

## 9. Multi-tenancy y routing

Casos reales:

- Separar `prod` / `staging` → backends distintos.
- Separar por equipo → tenants distintos del backend.
- Separar por costo → spans con `priority: low` van a cold storage.

Patrón: `routing` processor en el gateway según atributo del Resource (`deployment.environment`, `service.namespace`, `tenant.id`). Pipelines distintas por salida.

```yaml
processors:
  routing:
    from_attribute: deployment.environment
    default_exporters: [otlp/default]
    table:
      - value: prod
        exporters: [otlp/prod]
      - value: staging
        exporters: [otlp/staging]
```

---

## 10. Seguridad del borde

El Collector es un hop de red; aplicar higiene básica:

- **TLS** del agent al gateway dentro del cluster (service mesh o `tls` block del exporter OTLP).
- Secrets del backend como **K8s Secrets** montados por env var; nunca en el ConfigMap del Collector.
- **NetworkPolicy** restringiendo quién puede enviar al puerto 4317 del gateway (solo pods del namespace de app).
- RBAC mínimo para `k8sattributes` processor (solo `get`, `list`, `watch` de Pods del namespace relevante).
- Redacción de PII con `attributes` processor (`delete`, `hash`) **en el agent** si es posible, para que ni el gateway reciba el dato en claro.

---

## 11. Anti-patrones comunes

- **Agent-only con tail-sampling** — los spans de un trace están en nodos distintos; cada agent decide con información parcial → traces incompletos sistemáticos.
- **Gateway-only**, sin agent — pierdes `k8sattributes` locales a cada nodo y el SDK se vuelve dependiente de la red cluster para cada export.
- **Sidecar siempre que puedo** — multiplica Pods de Collector; coste operativo alto; sin ventaja clara.
- **`sending_queue` sin `storage`** en el gateway — al reiniciar, pérdida silenciosa.
- **Sin `memory_limiter`** — un spike OOM-kills el Collector y arrastra toda la observabilidad.
- **Config YAML con secretos en claro** committed a Git — rotar y mover a Secrets.
- **Mismo `service.name` en agent y gateway** — confusión total; cada capa debe reportarse como lo que es (`otel-agent`, `otel-gateway`).
- **Upgrade de agent y gateway a la vez** — si rompe, no hay escalón de rollback.

---

## 12. Ejercicio final — diseñar tres topologías

Antes de atacar la Actividad 02, dibuja (en papel o ASCII) la topología que recomendarías para cada caso:

1. **Startup, 10 RPS, 1 cluster k8s de 3 nodos, backend SaaS.**
   - ¿Agent? ¿Gateway? ¿Sin Collector? Justifica.
2. **Empresa mediana, 1 000 RPS, 1 cluster de 10 nodos, backend self-hosted (Tempo + Prometheus + Loki).**
   - Tamaño del batch; HPA sí/no; `file_storage` sí/no.
3. **Empresa grande, 100 000 RPS, 3 clusters en 3 AZ, backend multi (Tempo + Datadog), tail-sampling.**
   - Agent + gateway por cluster; cross-cluster routing; `load_balancing` exporter para tail-sampling consistente; `file_storage` obligatorio; HPA 10–50 pods; red policies por tenant.

Para cada una, define: patrón, número de replicas inicial, señales de HPA, qué processors en cada capa, y qué pasa si el backend se cae 5 minutos.

Esto es exactamente lo que la Actividad 02 pide formalizar como ADR.

---

**Siguiente paso:** `examples/01-daemonset-agent-plus-deployment-gateway/`.
