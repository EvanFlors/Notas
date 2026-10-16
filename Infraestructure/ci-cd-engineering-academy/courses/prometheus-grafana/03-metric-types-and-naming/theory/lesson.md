# Lección — Tipos de métricas y naming en Prometheus

## 1. Punto de partida

En `obs-02` montamos Prometheus + Grafana + un target y vimos pasar texto por `/metrics`. En esta lección aprendemos a **leer**, **tipar** y **nombrar** ese texto correctamente. El modelo de datos de Prometheus es muy simple en apariencia:

```
<metric_name>{<label>="<value>", ...}  <float_value>  [timestamp]
```

Pero detrás de esta línea hay dos decisiones de diseño que condicionan todo lo que viene después: **qué tipo de métrica es** y **cómo se nombra**. Equivocarse en cualquiera de las dos convierte el stack en un museo de números poco útiles — o peor, en una TSDB que crece sin control.

## 2. El formato de texto, en una línea

Prometheus scrapea `/metrics` esperando algo así:

```
# HELP http_requests_total Total HTTP requests processed.
# TYPE http_requests_total counter
http_requests_total{method="GET",status="200"} 1027
http_requests_total{method="POST",status="500"} 3
```

- `# HELP` describe la métrica (texto libre).
- `# TYPE` declara el tipo (`counter`, `gauge`, `histogram`, `summary`, `untyped`).
- Después vienen una o más líneas, una por cada combinación única de labels.

Cada combinación `(nombre, {labels})` es **una serie** independiente en la TSDB. Esto importa mucho cuando lleguemos a cardinalidad.

## 3. Counter — lo que solo crece

Un **counter** es un número que **solo sube** (o se resetea a cero cuando el proceso reinicia). Ejemplos naturales:

- `http_requests_total` — nº de requests recibidos desde el arranque.
- `process_cpu_seconds_total` — segundos de CPU consumidos.
- `node_network_receive_bytes_total` — bytes recibidos por una interfaz.

El **valor absoluto de un counter casi nunca es lo que te interesa**. Lo que te interesa es la **tasa**: cuántos por segundo en los últimos N minutos. Para eso Prometheus da dos funciones:

- `rate(http_requests_total[5m])` — tasa suavizada per-segundo en la ventana.
- `increase(http_requests_total[1h])` — equivalente a `rate * 3600`, el incremento total en la ventana.

Convención: **el counter termina en `_total`**. Si ves `http_requests` sin `_total`, es un bug de naming.

Nunca uses `rate()` sobre un gauge. Y nunca uses `delta()` (que es la equivalente para gauge) sobre un counter: ambas funciones esperan el tipo opuesto.

## 4. Gauge — lo que sube y baja

Un **gauge** representa un valor instantáneo que puede moverse en cualquier dirección:

- `node_memory_MemAvailable_bytes` — memoria libre en bytes.
- `node_filesystem_free_bytes` — espacio en disco libre.
- `kube_deployment_status_replicas` — réplicas vivas de un deployment.
- `queue_depth` — nº de ítems pendientes en una cola.

Un gauge **no se agrega con `rate()`**. Se agrega con `avg`, `max`, `min`, `sum`, `quantile_over_time`, etc. Un gauge con sufijo `_total` casi siempre es un bug: `_total` implica monotonía.

## 5. Histogram — para medir distribuciones (latencia, tamaños)

Un **histogram** mide una distribución (típicamente latencia o tamaño de respuesta) exponiendo tres artefactos por cada métrica base:

```
# TYPE http_request_duration_seconds histogram
http_request_duration_seconds_bucket{le="0.1"}  120
http_request_duration_seconds_bucket{le="0.5"}  430
http_request_duration_seconds_bucket{le="1.0"}  980
http_request_duration_seconds_bucket{le="+Inf"} 1005
http_request_duration_seconds_count             1005
http_request_duration_seconds_sum               325.4
```

- `*_bucket{le="X"}` — cuántas observaciones fueron **menores o iguales que X**. Son **acumulativos**: `le="0.5"` incluye todo lo de `le="0.1"`.
- `*_count` — total de observaciones.
- `*_sum` — suma de los valores observados.

Cuantiles se calculan con `histogram_quantile()`:

```
histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))
```

La clave es que **los buckets son agregables cross-target**: puedes sumarlos entre instancias, servicios, regiones, y luego calcular el p95 global. Esto hace que histogram sea el tipo preferido para RED metrics.

Limitación histórica: los buckets son fijos (los decides al instrumentar). Pocos → poco detalle; muchos → mucho coste de series.

## 6. Summary — por qué casi siempre lo evitarás

Un **summary** calcula los cuantiles **en el cliente** antes de exponerlos:

```
# TYPE http_request_duration_seconds summary
http_request_duration_seconds{quantile="0.5"}   0.21
http_request_duration_seconds{quantile="0.95"}  0.84
http_request_duration_seconds{quantile="0.99"}  1.42
http_request_duration_seconds_count             1005
http_request_duration_seconds_sum               325.4
```

El problema: **los cuantiles no se pueden promediar ni sumar**. Si tienes 10 réplicas del servicio, no existe operación matemáticamente válida para obtener "el p95 global" a partir de los p95 locales de cada réplica. Prometheus no inventará algo que mienta: simplemente no puedes agregar.

Por eso la regla práctica es: **usa histogram salvo que tengas una razón muy fuerte para summary** (por ejemplo, un target único donde los buckets no te sirven y necesitas un cuantil exacto local).

## 7. Native histograms — la alternativa moderna

Desde ~Prometheus 2.40 (experimental) y estable en versiones recientes, existen los **native histograms** (también llamados *sparse histograms*):

- Representación **sparse**: no se predefinen buckets; se usan buckets exponenciales de resolución configurable que crecen según se observa.
- **Mucho más eficiente** en storage y RAM que un histogram clásico de 10-20 buckets.
- Interoperables con `histogram_quantile()` (en versiones recientes de PromQL).
- Soportados en librerías cliente modernas.

Cuándo elegirlos: cuando tu librería y versión de Prometheus los soportan, para métricas con **alta variedad de valores** (latencias, tamaños), especialmente a escala. En Nivel 3 veremos las implicaciones de cardinalidad y migración.

## 8. Naming — una convención simple pero estricta

El patrón oficial es:

```
<namespace>_<subsystem>_<name>_<unit>
```

Ejemplos canónicos:

| Métrica | Lectura |
|---|---|
| `node_memory_MemAvailable_bytes` | ns `node`, subsistema `memory`, name `MemAvailable`, unidad `bytes` |
| `http_requests_total`            | ns `http`, name `requests`, sufijo `_total` (counter) |
| `http_request_duration_seconds`  | ns `http`, name `request_duration`, unidad `seconds` |
| `process_cpu_seconds_total`      | ns `process`, name `cpu`, unidad `seconds`, counter |

Reglas:

- **Singular**, no plural (`http_request_duration`, no `http_requests_durations`).
- **`snake_case`**, nunca camelCase.
- **Sufijo de unidad obligatorio** cuando aplica. Las unidades canónicas son:
  - `_total` — counters (monótonos).
  - `_bytes` — tamaños. Nunca `_kb`, `_mb`, `_gb`.
  - `_seconds` — duraciones. Nunca `_ms`, `_minutes`, `_hours`.
  - `_ratio` — proporciones entre 0 y 1 (no entre 0 y 100).
  - `_info` — métrica de valor fijo `1` cuya razón de existir son sus labels (metadata).
- Si el counter mide "cosas" (requests, errors), termina en `_total`. Si mide "bytes" ya enviados / "segundos" ya consumidos, usa `_bytes_total` o `_seconds_total`.

### Anti-patrones frecuentes

| Mal | Bien | Por qué |
|---|---|---|
| `httpRequests` | `http_requests_total` | camelCase y falta sufijo counter |
| `latency_ms` | `request_duration_seconds` | unidad no canónica |
| `disk_usage_percent` | `disk_usage_ratio` | ratio 0..1 estándar |
| `queue_size_total` | `queue_size` | `size` es un gauge, no monótono |
| `requests` | `http_requests_total` | nombre genérico, sin contexto |

## 9. Labels — significado y cardinalidad

Una **label** es una dimensión que diferencia series dentro de una misma métrica. Pero cada combinación de labels **genera una serie nueva** en la TSDB. La fórmula mental es:

```
nº de series = producto cartesiano de (valores posibles de cada label)
```

Un `http_requests_total{method, status, path}` donde:
- `method` tiene ~5 valores.
- `status` tiene ~10 valores.
- `path` tiene 50 endpoints.

→ **2500 series** por target. Multiplicado por 10 instancias → 25 000 series. Manejable.

Ahora añade `user_id` como label con 1 M usuarios: **2.5 × 10⁹ series**. La TSDB implosiona.

### Reglas de oro

- **Label = dimensión útil para agregar o filtrar.** Si no vas a hacer `by (label)` o `{label="..."}`, no es una label.
- **Cardinalidad acotada y predecible.** Un valor "bounded" (status code, method, path estable) es OK. Un valor "unbounded" (user_id, request_id, trace_id, URL con query string, timestamps) es un bug.
- **Nunca** uses como label algo que crece con el tiempo o el número de usuarios.
- Si necesitas correlacionar con un ID específico, usa **exemplars** (se verán en `obs-07`) o un log con `trace_id`, no una label de métrica.

### El concepto `_info`

Para exponer metadata estática (versión del build, nombre de la imagen) sin inflar cardinalidad: una métrica `_info` con valor fijo `1` y las labels interesantes.

```
# TYPE app_build_info gauge
app_build_info{version="1.4.2", commit="a1b2c3", language="python"} 1
```

Se usa haciendo joins con `group_left` en PromQL (lo veremos en `obs-04`).

## 10. RED y USE — qué medir cuando no sabes qué medir

Dos frameworks que resumen la práctica:

### RED (Tom Wilkie) — para servicios que atienden requests

Para cada servicio HTTP/RPC, mide tres cosas:

- **R — Rate**: requests por segundo. `rate(http_requests_total[5m])`.
- **E — Errors**: tasa de errores. `rate(http_requests_total{status=~"5.."}[5m])`.
- **D — Duration**: distribución de latencia (histogram) → p50, p95, p99.

Con RED cubres el 80% de los dashboards de un servicio con 3 queries. El cuarto panel suele ser el error ratio (`errors / rate`) como SLI de disponibilidad.

### USE (Brendan Gregg) — para recursos físicos/lógicos

Para cada recurso (CPU core, disco, interfaz de red, pool de conexiones), mide:

- **U — Utilization**: tiempo ocupado. `rate(node_cpu_seconds_total{mode!="idle"}[5m])`.
- **S — Saturation**: trabajo encolado. `node_load1`, `node_filesystem_files_free`.
- **E — Errors**: errores del recurso. `node_network_receive_errs_total`.

USE funciona bien para infra; RED para apps. Un servicio real necesita ambos: RED en el borde (lo que el usuario siente), USE abajo (lo que puede causarlo).

### Elección rápida

| Qué estás midiendo | Framework | Tipo típico |
|---|---|---|
| Nº de requests HTTP | RED (R) | counter `_total` |
| Latencia de requests | RED (D) | histogram `_seconds` |
| Tasa de errores | RED (E) | counter `_total` (filtrable por `status`) |
| CPU usada | USE (U) | counter `_seconds_total` → `rate()` |
| Memoria disponible | USE (S) | gauge `_bytes` |
| Errores de red | USE (E) | counter `_total` |

## 11. Mini-auditoría — cómo leer un `/metrics` ajeno

Checklist mental cuando te enfrentas a `/metrics`:

1. **¿El `# TYPE` cuadra con el sufijo?** `*_total` que no sea `counter` es sospechoso. `*_bytes` sin unidad es sospechoso.
2. **¿Hay unidad canónica?** `latency` sin `_seconds` o `_milliseconds` es ambiguo.
3. **¿Hay labels de alta cardinalidad obvia?** Busca `user_id`, `request_id`, `trace_id`, `email`, `uuid`, `path` con IDs embebidos (`/users/12345`), `url` con query string.
4. **¿Hay summaries donde debería haber histograms?** Si el servicio corre en más de una instancia, los cuantiles no serán agregables.
5. **¿Qué falta para RED/USE?** Si es un servicio HTTP, ¿están los 3 (rate, errors, duration)? Si es infra, ¿los 3 USE?

En las actividades de este módulo haces exactamente esto, dos veces.

## 12. Resumen y lo que viene

Lo que llevas:

- 5 tipos de métrica (counter, gauge, histogram, summary, native histogram) y cuándo usar cada uno.
- Convención de naming estricta y sufijos canónicos.
- Reglas de cardinalidad y cómo detectar labels tóxicas.
- RED y USE como mapas mentales de "qué medir".

Lo que viene en **`obs-04-promql-fundamentals`**: aprender a **consultar** estas métricas. Toda la disciplina de este módulo tiene sentido porque PromQL asume que las métricas están bien tipadas y bien nombradas. Un counter mal declarado como gauge rompe `rate()`. Una label con alta cardinalidad hace que las queries exploten en memoria. Y un summary agregado produce resultados silenciosamente falsos.
