# Lección — Exporters y relabeling

> Nivel intermedio. Prerrequisitos: `obs-02`, `obs-03`.

## 1. El problema que resuelven los exporters

Prometheus solo sabe hacer una cosa: `GET /metrics` sobre HTTP y parsear texto en formato Prometheus. Si el sistema a monitorear no habla ese protocolo (y la mayoría del software legacy, bases de datos, sistemas operativos y dispositivos de red **no**), hace falta un intermediario que traduzca su estado interno a `metric_name{labels} value`.

Ese intermediario es un **exporter**: un proceso HTTP pequeño que, cuando recibe `/metrics`, consulta la fuente (el OS, una DB, una API) y escupe el resultado en formato Prometheus. Los exporters son el "driver" común del ecosistema — por eso Prometheus escaló tan rápido: en vez de pedirle a cada vendor que instrumente su producto, se escribió un exporter y listo.

Dos reglas prácticas:

1. **Si ya existe un exporter oficial o reconocido, úsalo.** Reinventarlo cuesta tiempo y suma cardinalidad por tus propias decisiones de labels.
2. **El exporter corre lo más cerca posible del target.** `node_exporter` corre en el nodo, `postgres_exporter` como sidecar de Postgres o en la misma red privada. Si lo pones lejos, mides también red.

## 2. Catálogo mínimo que debes conocer

| Exporter | Qué expone | Dónde corre |
|----------|------------|-------------|
| `node_exporter` | Hardware y OS: CPU, memoria, disco, red, filesystem, loadavg | **Un proceso por nodo** host |
| `cAdvisor` | Métricas por contenedor (CPU/RAM/net/fs) | Un daemon por nodo; en K8s viene integrado en el kubelet |
| `blackbox_exporter` | Probes activos HTTP(S), TCP, ICMP, DNS, gRPC | Central (actúa como proxy que Prometheus apunta a cada target) |
| `mysqld_exporter` | Estado del server MySQL (`SHOW GLOBAL STATUS`, replication) | Sidecar o host dedicado |
| `postgres_exporter` | Pg stats (`pg_stat_*`, replication lag, locks, bloat) | Sidecar o host dedicado |
| `redis_exporter` | `INFO`, keyspace, slowlog | Sidecar |
| `nginx-prometheus-exporter` | Lee el endpoint `stub_status` o `/api` de NGINX Plus | Sidecar |
| `snmp_exporter` | Traduce SNMP a métricas (switches, routers, UPS, impresoras) | Central (consulta cada device por SNMP) |
| `cloudwatch_exporter` | Pide métricas a CloudWatch y las re-expone | Central (una instancia por cuenta/región) |

`cadvisor`, `blackbox` y `snmp_exporter` tienen un patrón distinto al resto: no exponen las métricas de "sí mismos", sino que **actúan como proxy** hacia un target que se les pasa por parámetro de query. Eso cambia la configuración del scrape (necesita `relabel` para pasar el target).

## 3. Formato de texto y endpoints: lo que un exporter garantiza

Un `/metrics` bien hecho cumple:

```
# HELP node_cpu_seconds_total Seconds the CPUs spent in each mode.
# TYPE node_cpu_seconds_total counter
node_cpu_seconds_total{cpu="0",mode="idle"} 123456.78
node_cpu_seconds_total{cpu="0",mode="user"} 1234.56
```

- `# HELP` describe la métrica (humanos y UIs).
- `# TYPE` fija el tipo (`counter`, `gauge`, `histogram`, `summary`, `untyped`).
- Una línea por serie temporal, labels ordenados *dentro de la serie*, valor como float.

Los exporters también exponen una métrica meta útil: `scrape_duration_seconds` y, para el blackbox, `probe_success` que vale `1`/`0`.

## 4. Writing a custom exporter (resumen)

Cuando no existe exporter para la fuente que quieres medir (API interna, dispositivo exótico, cálculo custom), lo escribes. La forma correcta es:

- Usar la librería oficial del lenguaje (`client_golang` en Go es el estándar de facto; `prometheus_client` en Python para scripts rápidos).
- Implementar el patrón **Collector**: una clase que al ser invocada por el registro genera las series. En Python:

```python
# English code, Spanish prose.
from prometheus_client import CollectorRegistry, Gauge, start_http_server
from prometheus_client.core import GaugeMetricFamily

class CoffeeMachineCollector:
    def collect(self):
        # Query the source on-demand (not on a loop).
        state = query_coffee_machine()
        g = GaugeMetricFamily(
            "coffee_beans_grams",
            "Grams of beans currently in the hopper",
            labels=["machine"],
        )
        g.add_metric([state.machine_id], state.beans_grams)
        yield g

registry = CollectorRegistry()
registry.register(CoffeeMachineCollector())
start_http_server(9876, registry=registry)
```

Reglas no negociables al escribir un exporter:

- **No pre-calcules en un loop.** Consulta la fuente *cuando Prometheus scrapea*. Si la fuente es lenta, pon un caché corto (TTL = scrape interval).
- **Nunca uses labels de alta cardinalidad** (user_id, request_id, timestamps). Mide **características**, no instancias.
- **Expón `up`-like metrics y errores**: si tu exporter falla al consultar la fuente, emite `my_exporter_scrape_errors_total` y una métrica `my_exporter_up`.

## 5. Anatomía del pipeline de un scrape

```
service_discovery  →  relabel_configs  →  HTTP scrape  →  metric_relabel_configs  →  TSDB
     (SD)              (sobre target)      (/metrics)        (sobre cada muestra)
```

Interpretar bien el pipeline es la clave de todo este módulo:

- **SD** entrega targets *potenciales* con un conjunto de labels `__meta_*`.
- **`relabel_configs`** actúa sobre **targets** (antes del scrape): puede cambiar `__address__`, dropear el target, derivar `job`/`instance`, mapear meta-labels a labels permanentes.
- **El scrape** devuelve series con sus labels.
- **`metric_relabel_configs`** actúa sobre **muestras** (después del scrape): puede dropear series individuales (por nombre o labels), renombrar labels de métricas, o filtrar por `__name__`.
- **TSDB** persiste lo que queda.

> Si no se dropea un target en `relabel_configs`, se paga el scrape (CPU, red). Si no se dropea una métrica en `metric_relabel_configs`, se paga el storage (RAM, disco).

## 6. `relabel_configs`: sintaxis completa y acciones

La forma general:

```yaml
relabel_configs:
  - source_labels: [__meta_kubernetes_pod_label_app]
    separator: ;
    regex: (.+)
    target_label: app
    replacement: $1
    action: replace
```

Campos:

- `source_labels`: lista de labels de entrada; se concatenan con `separator` (`;` por defecto).
- `regex`: regex RE2 **anclado** (`^...$` implícito). El default es `(.*)`.
- `action`: qué hacer si matchea (o no, según la acción).
- `target_label`: el label a escribir (para `replace` y `hashmod`).
- `replacement`: la plantilla con backrefs `$1`, `$2` (default `$1`).
- `modulus`: solo para `hashmod`.

### Acciones

| Acción | Qué hace |
|--------|----------|
| `replace` (default) | Si matchea, escribe `replacement` renderizado en `target_label` |
| `keep` | Mantiene el target **solo si** matchea |
| `drop` | Descarta el target si matchea |
| `labelmap` | Para cada label cuyo nombre matchee `regex`, crea un nuevo label con el nombre `replacement` (útil con `__meta_kubernetes_pod_label_(.+)` → `$1`) |
| `labeldrop` | Dropea labels cuyo nombre matchee `regex` |
| `labelkeep` | Deja solo labels cuyo nombre matchee `regex` |
| `hashmod` | Calcula `hash(source_labels) mod modulus` y lo pone en `target_label` (sharding) |
| `lowercase` / `uppercase` | Normaliza case |

## 7. `metric_relabel_configs`: la red de seguridad

Idéntica sintaxis que `relabel_configs`, pero se aplica a cada **muestra** devuelta por el scrape. Las acciones útiles son `drop` y `labeldrop`. Caso típico:

```yaml
metric_relabel_configs:
  # The app shipped a metric with per-request-id label — kill it until the fix lands.
  - source_labels: [__name__]
    regex: 'myapp_request_latency_seconds.*'
    action: drop
  # Drop a noisy label from an exporter we do not control.
  - regex: 'kubelet_runtime_operation_duration_seconds_bucket'
    source_labels: [__name__]
    action: drop
```

**Reglas de uso**:

- Si puedes arreglar la fuente (parchear el exporter, cambiar la app), hazlo. `metric_relabel_configs` es la mitigación, no el fix.
- No lo uses para dropear por `instance` o `job` — eso va en `relabel_configs` dropeando el target.
- Documenta cada regla con un comentario que explique **por qué** y hasta cuándo.

## 8. Labels mágicos a honrar

Los labels con prefijo `__` **no persisten**: solo existen durante relabel. Los más usados:

- `__address__` — `host:port` del target; relabel puede cambiarlo (p. ej. apuntar a Blackbox en vez de al target real).
- `__scheme__` — `http` o `https`.
- `__metrics_path__` — por defecto `/metrics`, pero `cAdvisor` o `blackbox` usan otro.
- `__param_<name>` — define un parámetro de query en la URL del scrape (clave para blackbox: `__param_target`).
- `__meta_*` — labels inyectados por el SD provider (`__meta_kubernetes_*`, `__meta_ec2_*`, etc.).
- `__tmp_*` — convención para variables intermedias que luego se descartan solas (siempre son `__`-prefixed → no persisten).
- `__name__` — nombre de la métrica (visible como label en `metric_relabel_configs`).

## 9. Patrones idiomáticos

**Pattern 1 — Probe HTTP con Blackbox**:

```yaml
- job_name: blackbox_http
  metrics_path: /probe
  params:
    module: [http_2xx]
  static_configs:
    - targets:
      - https://example.com
      - https://api.example.com/health
  relabel_configs:
    - source_labels: [__address__]
      target_label: __param_target        # pasa URL como ?target=
    - source_labels: [__param_target]
      target_label: instance              # label legible en Grafana
    - target_label: __address__
      replacement: blackbox-exporter:9115 # Prometheus habla con blackbox
```

**Pattern 2 — Mapear labels K8s a labels de métrica**:

```yaml
relabel_configs:
  - action: labelmap
    regex: __meta_kubernetes_pod_label_(.+)
  - source_labels: [__meta_kubernetes_namespace]
    target_label: namespace
  - source_labels: [__meta_kubernetes_pod_name]
    target_label: pod
```

**Pattern 3 — Mantener solo pods con annotation**:

```yaml
relabel_configs:
  - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
    action: keep
    regex: "true"
```

**Pattern 4 — Sharding con `hashmod`** (reparte targets entre N Prometheus):

```yaml
relabel_configs:
  - source_labels: [__address__]
    modulus: 4
    target_label: __tmp_shard
    action: hashmod
  - source_labels: [__tmp_shard]
    regex: ^0$        # este Prometheus es shard 0
    action: keep
```

## 10. Depuración de relabel

Síntomas y causas típicos:

- **"Mi target aparece pero `health=down`"** → el relabel cambió `__address__` a algo que no responde (clásico olvidando el `replacement` en el patrón blackbox).
- **"Mi target no aparece"** → algún `keep` lo descartó. Ve a `/service-discovery` en la UI de Prometheus y revisa qué labels tenía y qué pasó.
- **"Veo `instance=blackbox-exporter:9115` en todos"** → te faltó la línea que mapea `__param_target` → `instance`.
- **"La métrica sigue ahí tras el drop"** → `metric_relabel_configs` requiere restart o reload (`SIGHUP`/`/-/reload`). Verifica con `/status/config`.

Herramienta clave: **UI `/service-discovery`** muestra, para cada target, los labels **antes** y **después** del relabel. Es el único debugger que necesitas.

## 11. Cardinalidad y relabel como herramienta de contención

El motivo #1 de incidentes en Prometheus en la vida real es la **cardinality explosion**: una métrica nueva con una label como `request_id` o `pod_hash` dinámico multiplica las series por N.

Secuencia defensiva, por orden de preferencia:

1. **Instrumentación**: fix en el código (quitar la label tóxica).
2. **`metric_relabel_configs`**: drop en el scraper hasta que el fix llegue a producción.
3. **`sample_limit`** por scrape: límite duro que falla el scrape si se excede (último freno).

Para detectar la métrica culpable: `topk(10, count by (__name__)({__name__!=""}))` y, para labels dentro de una métrica: `topk(5, count by (label_x) (metric_name))`.

## 12. Checklist operativo

Antes de mergear un cambio a `prometheus.yml`:

- [ ] Cada `job_name` tiene al menos un `relabel_configs` que normaliza o filtra.
- [ ] Blackbox y proxys similares mapean `__param_target` → `instance`.
- [ ] Los labels custom (`team`, `env`, `service`) están presentes en todos los jobs.
- [ ] Hay `scrape_timeout` menor que `scrape_interval`.
- [ ] Si se usan secrets (bearer tokens para exporters cloud), vienen de env vars o archivos; **nunca** inline.
- [ ] Se corrió `promtool check config prometheus.yml` sin errores.
- [ ] Tras `curl -X POST localhost:9090/-/reload`, los targets quedan `health=up`.
- [ ] Se documentó cada regla de relabel con un comentario (qué, por qué, cuándo revisar).
