# Lección: PromQL avanzado, recording rules y control de cardinalidad

> **ID:** `obs-10-promql-advanced-recording-rules-cardinality` · **Nivel:** avanzado · **Duración:** 4 h
> **Prerrequisitos:** `obs-04`, `obs-07`.

---

## 1. Introducción intuitiva

Imagina un dashboard del capstone con doce paneles. Cada panel muestra el mismo numerador — la *tasa de errores HTTP por servicio* — pero cortado por una dimensión distinta: endpoint, método, versión, zona. Y encima tienes dos alertas: una de burn-rate rápido (ventana 5 min) y otra lento (ventana 1 h), ambas comparando esa tasa contra el error budget. **Todas** esas superficies corren la misma expresión costosa:

```promql
sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))
  /
sum by (service) (rate(http_requests_total[5m]))
```

Cada evaluación cruza miles de series. Dashboards la lanzan en cada refresh; las alertas la lanzan cada 30 s. Multiplica eso por N servicios y N viewers abiertos y verás la CPU del Prometheus al 90% permanentemente — hasta que un día alguien añade la label `user_id` a `http_requests_total` por error, la cardinalidad se multiplica por 10 000, y el proceso muere por OOM en producción un viernes.

Este módulo trata esos dos problemas, que están **conectados**:

1. **Pre-calcular lo caro**: *recording rules* que evalúan la expresión una vez por intervalo y la guardan como serie nueva. Dashboards y alertas consumen `service:http_errors:ratio5m` en vez de la expresión larga.
2. **Controlar lo que entra**: la *cardinalidad* es el multiplicador oculto. Un ofensor nuevo puede destruir la TSDB antes de que nadie lo note. Hay que saber detectarlo rápido y cortarlo con `metric_relabel_configs: action: drop`.

Ambos problemas se resuelven con la misma mentalidad: **tratar las series como un recurso escaso y la expresión como un contrato público**.

---

## 2. PromQL avanzado — vectores y binary operations

Un `instant vector` es un conjunto de series con el mismo timestamp. Un `range vector` es un conjunto de series donde cada serie trae un trozo de historia `[5m]`. Las operaciones binarias (`+ - * / and or unless`) y las comparaciones (`== != > < >= <=`) actúan **por par de series**: dos series se emparejan si **todas sus labels no `__name__` coinciden exactamente**.

Esta regla por defecto es muy estricta. Ejemplo que **no** empareja aunque "obviamente debería":

```promql
# A: http_requests_total{job="api", method="GET", status="500"}
# B: http_requests_total{job="api", method="GET"}
# A y B tienen distinto set de labels (A tiene status, B no) → vector vacío.
```

Las herramientas para controlar el matching son `on(...)`, `ignoring(...)`, `group_left(...)`, `group_right(...)`.

### 2.1 `on` e `ignoring`

- `on(l1, l2)` — considera **solo** esas labels para emparejar.
- `ignoring(l1)` — considera **todas menos** esas labels.

```promql
rate(http_requests_total{status=~"5.."}[5m])
  / ignoring(status)
rate(http_requests_total[5m])
```

Resultado: ratio de errores por combinación de las demás labels (`job`, `method`, `instance`, …), ignorando `status` para el matching.

### 2.2 `group_left` y `group_right` (many-to-one y one-to-many)

Cuando el lado izquierdo tiene más series que el derecho (o viceversa), hay que decir *qué lado* es el "many" y qué labels extra copiar del "one".

```promql
# Enriquecer una métrica con metadata de 'kube_pod_info' (tiene un valor "1" por pod).
sum by (pod) (rate(container_cpu_usage_seconds_total[5m]))
  * on(pod) group_left(node, namespace)
kube_pod_info
```

Lectura: *"empareja por `pod`; el lado izquierdo es 'many', el derecho 'one'; además copia `node` y `namespace` del lado derecho al resultado"*.

Reglas prácticas:

- Si `promql` te devuelve `many-to-many matching not allowed` → necesitas `group_left` o `group_right`.
- Si te devuelve vector vacío cuando esperabas datos → casi siempre falta `ignoring(...)` o las labels no coinciden.

### 2.3 Subqueries y por qué doler

Una subquery `expr[5m:30s]` convierte un instant vector en range vector evaluando `expr` cada 30 s en los últimos 5 min. **Son caras**: equivalen a correr `expr` N veces. Usarlas en dashboards es sintoma de "esto debería ser una recording rule".

---

## 3. Recording rules — pre-calcular lo caro

Una recording rule corre una expresión PromQL en cada `evaluation_interval` (default 1 min) y guarda el resultado como **una serie nueva** con el nombre que tú elijas.

```yaml
# prometheus.rules.yml
groups:
  - name: slo-ingredients
    interval: 30s
    rules:
      - record: job:http_requests:rate5m
        expr: sum by (job) (rate(http_requests_total[5m]))

      - record: job:http_errors:ratio5m
        expr: |
          sum by (job) (rate(http_requests_total{status=~"5.."}[5m]))
            /
          sum by (job) (rate(http_requests_total[5m]))
```

### 3.1 Convención de naming (crucial)

Formato: `level:metric:operations`.

- `level` — nivel de agregación (`job`, `instance`, `node`, `cluster`, `service`).
- `metric` — nombre lógico (sin `_total`, sin unidades, sin ruido).
- `operations` — qué operaciones se hicieron, separadas por `_` (`rate5m`, `ratio5m`, `sum1h`, `p99_5m`).

Ejemplos legítimos:

- `job:http_requests:rate5m`
- `service:http_errors:ratio5m`
- `instance:node_cpu:utilisation5m`
- `cluster:namespace:pod_cpu:sum_rate5m` (multi-nivel, de `kubernetes-mixin`).

El beneficio del formato: **se lee la cardinalidad del resultado solo con mirar el nombre**. `job:http_requests:rate5m` promete una serie por `job`. Si de pronto trae 10k series, algo está mal con el nombre o con el expr.

### 3.2 Dashboards + alertas sobre la misma expresión

Antes:

```promql
# dashboard panel
sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))
  /
sum by (service) (rate(http_requests_total[5m]))

# alert rule — misma expresión, se re-evalúa cada 30s
expr: ( sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))
      / sum by (service) (rate(http_requests_total[5m])) ) > 0.05
```

Después:

```promql
# dashboard panel
service:http_errors:ratio5m

# alert rule
expr: service:http_errors:ratio5m > 0.05
```

Ganancia: **una** evaluación por intervalo, no una por panel + una por alerta.

### 3.3 Cuándo *no* hacer recording rule

- Resultados que casi no se consultan (overhead > ahorro).
- Métricas que ya son baratas (`up{}`, counters sin agregación).
- Si la expresión sigue experimental, mejor dejarla ad-hoc hasta que estabilice.

### 3.4 Testear reglas con `promtool`

```bash
promtool check rules prometheus.rules.yml
promtool test rules tests/rule_test.yml
```

Un archivo de test (`rule_test.yml`) describe series de entrada sintéticas y assertions sobre el output esperado — igual que un unit test. Esto se exige en `obs-09` para alertas y aquí para recording rules.

---

## 4. ¿Por qué pre-calcular? (coste real)

Supón `http_requests_total` con 50 000 series activas y una expresión con un `rate(…[5m])` + `sum by (service)`. El coste por evaluación es aproximadamente:

- CPU: proporcional a `series × muestras_en_ventana`.
- RAM: proporcional al tamaño del vector intermedio.

Con un dashboard de 12 paneles y 3 viewers simultáneos y una alerta cada 30 s, esa expresión se evalúa unas **80 veces/min**. Con recording rule: **2 veces/min**. La diferencia se traduce directamente en CPU del Prometheus — y en la factura de la máquina si está en cloud.

Trade-off: cada recording rule **crea nuevas series** (una por combinación de las labels del `by`). Si tu recording rule es `by (service, instance, path, method)` sobre 10 servicios × 100 instancias × 50 paths × 5 métodos, acabas de añadir 250 000 series por métrica derivada. **La disciplina de `by (...)`** importa.

---

## 5. Cardinalidad — el modelo mental correcto

Una serie en Prometheus es una **tupla única** `(métrica_nombre, label1=valor1, label2=valor2, ...)`. La TSDB mantiene en RAM un índice invertido label→series + chunks de datos activos. El consumo de RAM crece **lineal con el número de series activas** (series "activas" = series con escrituras en las últimas ~2 h de la head block).

Regla gruesa de orden de magnitud:

| series activas | RAM aprox Prometheus | Observación |
|----------------|----------------------|-------------|
| 100 k          | ~1–2 GB              | tamaño pequeño sano |
| 1 M            | ~4–8 GB              | revisar top ofensores |
| 10 M           | ~40–80 GB            | zona de riesgo |
| 100 M          | prácticamente imposible single-node | → `obs-11` long-term store |

Cada **label nueva** multiplica. Si una métrica tiene 3 labels con 10, 20 y 5 valores → `10 × 20 × 5 = 1000` series máximo. Añadir una cuarta label con 100 valores → `100 000`. Añadir `user_id` con 1M usuarios → **1 000 000 000** series potenciales. Prometheus muere.

### 5.1 Las fuentes más comunes de cardinalidad explosiva

1. **IDs únicos como labels**: `user_id`, `request_id`, `trace_id`, `order_id`, `session_id`.
2. **Timestamps en labels**: `created_at`, cadenas de fecha ("2026-10-15T12:00:00").
3. **User agents** sin normalizar: cada versión de navegador → una serie.
4. **Paths de alta variabilidad**: `/users/123/orders/456` sin agrupar por template (`/users/:id/orders/:id`).
5. **Labels del sistema SD no filtrados**: `__meta_kubernetes_pod_label_pod_template_hash` sin `labeldrop`.
6. **Error messages completos**: `error="connection refused: 10.0.0.42:5432 after 3 retries"` cambia por cada IP/puerto.
7. **Multi-tenant mal diseñado**: `tenant_id` con 100 k tenants + 50 métricas = 5 M series.

### 5.2 La regla práctica

> Si no puedes decir *a priori* cuántos valores distintos tomará una label, **no debería ser label**.

- Un `status` HTTP: ~10 valores → OK.
- Un `method`: 5–8 valores → OK.
- Un `endpoint` (templated): ~decenas → OK.
- Un `user_id`: potencialmente infinito → NO.

Alternativa para dimensiones de alta cardinalidad: moverlo a **logs** (Loki) o **traces** (Tempo) donde el modelo de datos sí lo soporta.

---

## 6. Troubleshooting de cardinalidad — queries diagnósticas

Prometheus se auto-monitorea. Las métricas internas `prometheus_tsdb_*` revelan el estado real.

### 6.1 Métricas clave

```promql
# Series activas en la head block (RAM-resident)
prometheus_tsdb_head_series

# Chunks en head
prometheus_tsdb_head_chunks

# Series añadidas desde el inicio
prometheus_tsdb_head_series_created_total

# Tiempo de evaluación de reglas
prometheus_rule_evaluation_duration_seconds
```

Alerta útil ya misma:

```yaml
- alert: TSDBHeadSeriesTooHigh
  expr: prometheus_tsdb_head_series > 2000000
  for: 10m
  annotations:
    summary: "Prometheus TSDB head series above 2M — investigate cardinality"
```

### 6.2 Top ofensores por métrica (query maestra)

```promql
topk(10, count by (__name__)({__name__!=""}))
```

Lectura: *"para cada métrica, cuenta cuántas series tiene; devuelve las 10 con más series"*. Es la primera query a correr cuando algo huele mal.

### 6.3 Top labels por métrica sospechosa

Una vez identificada una métrica (p. ej. `my_app_requests_total` con 2M series), para ver qué label es la culpable:

```promql
count by (user_id) (my_app_requests_total)
count by (path) (my_app_requests_total)
count by (status) (my_app_requests_total)
```

La que devuelva miles de series es la ofensora.

### 6.4 Endpoint `/api/v1/status/tsdb`

Prometheus expone en HTTP:

```bash
curl -s http://localhost:9090/api/v1/status/tsdb | jq .
```

Devuelve:

- `seriesCountByMetricName` — top 10 métricas por series.
- `labelValueCountByLabelName` — top labels por nº de valores únicos.
- `memoryInBytesByLabelName` — RAM aproximada por label.
- `seriesCountByLabelValuePair` — series por pareja `label=valor`.

Es **la primera parada** en un incidente. No necesitas PromQL, solo `curl`.

---

## 7. El fix: `metric_relabel_configs` con `action: drop`

Dropear **antes** de scrapear (en `relabel_configs`) sirve para elegir qué targets scrapear. Dropear **después** de scrapear — una vez las muestras están llegando — se hace con `metric_relabel_configs` en el scrape job. Se evalúa por muestra, antes de persistir en TSDB.

```yaml
scrape_configs:
  - job_name: my-app
    static_configs:
      - targets: ["app:8000"]
    metric_relabel_configs:
      # Caso 1: dropear una métrica entera que explotó.
      - source_labels: [__name__]
        regex: my_app_requests_by_user_total
        action: drop

      # Caso 2: dropear SOLO la label 'user_id' de todas las métricas (conserva la métrica, pierde la dimensión).
      - action: labeldrop
        regex: user_id

      # Caso 3: dropear muestras con un valor concreto de una label.
      - source_labels: [path]
        regex: /healthz|/metrics
        action: drop
```

**Importante**: `metric_relabel_configs` es la red de seguridad. La fix definitiva es **eliminar la label en el código del productor** (Python app, exporter custom, etc.). El drop solo evita que la basura entre a tu TSDB; el productor sigue generando basura.

Pattern completo cuando el incidente ya pasó:

1. `topk + count by (__name__)` → identificar métrica.
2. `count by (label)` → identificar label.
3. `metric_relabel_configs: action: drop` → cortar el sangrado (hot-fix, re-start Prometheus).
4. PR en la app → eliminar la label del instrumentation code.
5. Documentar en runbook: "nunca label por user_id, usar exemplars/traces".

---

## 8. Native histograms vs classic histograms

### 8.1 El problema de los classic histograms

Un `histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))` requiere **buckets** definidos de antemano: `0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10`. Cada bucket es **una serie**: `http_request_duration_seconds_bucket{le="0.005"}`, `{le="0.01"}`, etc. Si tienes 10 buckets × 50 endpoints × 5 métodos × 100 instancias = **250 000 series** solo por histogram.

Además, los buckets son fijos — si la realidad cae entre buckets grandes, pierdes resolución.

### 8.2 Native histograms (sparse)

Prometheus ≥ 2.40 (y GA progresiva desde 2024+) soporta **native histograms**: un único slot de serie que almacena buckets exponenciales *sparse* (solo guarda buckets no vacíos). Beneficios:

- **1 serie por histogram** en vez de N.
- Resolución configurable (`schema` controla la finura).
- `histogram_quantile()` sigue funcionando — con la misma firma.
- Suma y agregación nativas sin romper la matemática (lo que summary nunca podía).

### 8.3 Trade-offs y estado

- Requiere **cliente** que lo emita (`prometheus_client` Python lo soporta via `prometheus_client ≥ 0.19` con `_create_sample_native_histogram`).
- Requiere **storage y protocolo** del lado Prometheus (habilitado con `--enable-feature=native-histograms`).
- Grafana lo entiende si el data source Prometheus está actualizado.
- OTel ingest nativo lo preserva.
- Migración gradual: una misma métrica puede exponer **ambos** formatos temporalmente.

Regla de decisión: si estás diseñando *greenfield* y tu stack lo soporta → native. Si tu histogram ya está en producción con 100k series de buckets, migrar es un proyecto, no un commit.

---

## 9. Diseño: la "capa de ingredientes"

El patrón que escala en organizaciones medianas:

```
┌────────────────────────────────────────────────────────────┐
│ Dashboards (Grafana)         Alertas (Prometheus)          │
│       ▲                              ▲                     │
│       │ consume ingredientes         │                     │
│       └──────────────┬───────────────┘                     │
│                      │                                     │
│         ┌────────────▼────────────┐                        │
│         │  RECORDING RULES         │  "ingredientes"       │
│         │  level:metric:op         │  pre-calculados       │
│         │  (job:http_errors:ratio5m, service:latency:p99…) │
│         └────────────┬────────────┘                        │
│                      │                                     │
│         ┌────────────▼────────────┐                        │
│         │  Métricas raw de apps / exporters                │
│         │  (http_requests_total, container_cpu_…)          │
│         └─────────────────────────┘                        │
└────────────────────────────────────────────────────────────┘
```

Un dashboard nuevo no debería tocar `http_requests_total` directamente — debería consumir `service:http_errors:ratio5m` y `service:http_requests:rate5m`. Si no existe el ingrediente que necesita, se añade primero a la recording rule. Esto obliga a que la "cocina" (recording rules) sea el lenguaje común entre equipos y evita que cada dashboard reinvente el mismo PromQL mal.

Este patrón es la base del módulo `obs-14` (SLOs): las burn-rate alerts consumen `service:slo:error_budget_ratio` que **tiene que** ser un recording rule — no se puede evaluar la misma expresión gigante 4 veces (una por ventana) cada 30 s.

---

## 10. Preguntas de evaluación

1. ¿Por qué `rate(X[5m]) / rate(Y[5m])` devuelve vector vacío aun si ambos tienen datos? Da dos razones distintas.
2. ¿Qué significa la siguiente recording rule y qué cardinalidad genera? `job:http_requests:rate5m = sum by (job) (rate(http_requests_total[5m]))`.
3. Observas `prometheus_tsdb_head_series` subiendo linealmente desde las 14:00 h. ¿Qué 2 queries corres primero y en qué orden?
4. Un `metric_relabel_configs: action: drop` sobre una métrica evita que entre a TSDB, pero *no* resuelve la causa raíz. Explica por qué, y qué debería hacerse en paralelo.
5. ¿Qué garantiza native histograms que classic histograms no? Da dos propiedades concretas.
6. `group_left` vs `group_right` — ¿cuándo usas cada uno? Da un ejemplo con `kube_pod_info`.
7. Diseñaste `service:http_errors:ratio5m by (service, path, method, status)`. ¿Qué falla con este diseño? ¿Cómo lo corregirías?

---

## 11. Antipatrones y errores comunes

- **Recording rule con `by (user_id)`**: pre-calcula la basura; multiplica el problema por el nº de intervalos de retención.
- **Nombres sin convención**: `my_metric_rate` no dice ni nivel ni ventana — ingobernable a los 6 meses.
- **Mezclar `on()` sin `group_left`**: errores silenciosos; el vector vacío parece "no data" en el panel.
- **No alertar sobre `prometheus_tsdb_head_series`**: te enteras del OOM cuando ya pasó.
- **Dropear métricas ofensoras sin PR en el productor**: la próxima que la toque, vuelve. El drop vive para siempre en `prometheus.yml` sin contexto.
- **Instrumentar con `label=request_id`** porque "era útil para debug": el debug se hace con traces, no con cardinality en métricas.
- **Confiar en que "lo veremos en Grafana" cuando crezca la cardinalidad**: no se ve. Se ve cuando el proceso muere.

---

## 12. Resumen y cierre

Dos competencias centrales:

1. **Hablar en recording rules.** El PromQL caro no vive repetido en dashboards y alertas: vive en una capa de ingredientes con nombres convencionales (`level:metric:op`). Dashboards y alertas consumen esos ingredientes. Un cambio en la fórmula se hace **en un lugar**.
2. **Vigilar la cardinalidad activamente.** `prometheus_tsdb_head_series` con alerta; `topk + count by (__name__)` en el runbook; `metric_relabel_configs` como red de seguridad; disciplina de labels en el productor. La cardinality explosion es la causa #1 de incidentes operativos en Prometheus — y es la más evitable.

Las recording rules que diseñes aquí son la base explícita de `obs-14` (SLOs) y de `obs-15` (platform governance). Las técnicas de troubleshooting de cardinalidad son la base de `obs-11` (long-term store) y de `obs-12` (Prometheus Operator), donde la cardinalidad entrante se multiplica porque todo K8s empuja labels al scrape.
