# Teoría — PromQL: fundamentos

PromQL (Prometheus Query Language) es un lenguaje funcional sobre series de tiempo. Toda expresión se evalúa en un instante `t`; el resultado se "proyecta" en el tiempo cuando se grafica un rango `[t0, t1]` paso a paso (`step`).

---

## 1. Tipos de expresión

Una expresión PromQL devuelve uno de 4 tipos. Confundirlos es la fuente #1 de errores "`parse error`" o resultados vacíos.

| Tipo | Descripción | Ejemplo |
|------|-------------|---------|
| **Instant vector** | Conjunto de series, cada una con **1 muestra** en el instante `t`. | `http_requests_total` |
| **Range vector** | Conjunto de series, cada una con **N muestras** en una ventana `[t−range, t]`. | `http_requests_total[5m]` |
| **Scalar** | Un número de punto flotante sin dimensión. | `3.14`, `scalar(up)` |
| **String** | Cadena. Casi solo se usa internamente (p. ej. `label_replace`). | `"foo"` |

**Regla práctica**:
- Dashboards y alertas se evalúan sobre **instant vectors**.
- Las funciones de counter (`rate`, `increase`, `irate`) toman **range vector** → devuelven **instant vector**.
- No se puede graficar un range vector directamente (`Error executing query: invalid expression type "range vector"`).

```promql
# OK — instant vector
rate(http_requests_total[5m])

# ERROR — range vector no se grafica
http_requests_total[5m]
```

---

## 2. Selectors y matchers

Un selector filtra series por nombre y labels. Los matchers de label son:

| Matcher | Significado | Ejemplo |
|---------|-------------|---------|
| `=` | igual | `job="api"` |
| `!=` | distinto | `env!="dev"` |
| `=~` | regex (RE2, **anclada**) | `instance=~".*api.*"` |
| `!~` | regex negada | `path!~"/health|/metrics"` |

Puntos clave:

- El **nombre de la métrica** es un label especial `__name__`. `{__name__=~"http_.*"}` selecciona todas las métricas que empiezan por `http_`.
- Las regex están **ancladas** (equivalen a `^...$` implícito).
- Un selector sin matchers (`{}`) es inválido; debe haber al menos uno que **no** matchee cadena vacía.

```promql
# equivalentes
http_requests_total{job="api"}
{__name__="http_requests_total", job="api"}

# todas las series del job "api" en instancias que contengan "canary"
{job="api", instance=~".*canary.*"}
```

---

## 3. Ventanas de tiempo: range vectors `[5m]`

Añadir `[duration]` a un selector lo convierte en range vector: cada serie trae las muestras capturadas en los últimos `duration`.

```promql
# Las muestras de los últimos 5 minutos de la serie up{job="api"}
up{job="api"}[5m]
```

Unidades: `ms`, `s`, `m`, `h`, `d`, `w`, `y`. Se pueden combinar: `[1h30m]`.

**Elección de la ventana**:

- Mínimo útil: **≥ 4 × scrape_interval** (si `scrape_interval=15s`, usar `[1m]` o más).
- Para alertas: ventanas cortas (`[5m]`) → reactivas, ruidosas.
- Para gráficos de "tendencia": ventanas largas (`[1h]`, `[6h]`) → suavizadas.

---

## 4. Modificadores temporales: `offset` y `@`

Permiten evaluar una expresión en otro instante.

```promql
# requests ahora vs hace 1 hora
rate(http_requests_total[5m])
  / ignoring()
rate(http_requests_total[5m] offset 1h)

# evaluar la expresión siempre en un timestamp fijo (ej. snapshot post-incidente)
rate(http_requests_total[5m] @ 1700000000)

# @ start() y @ end(): atan la evaluación al inicio/fin del rango de la gráfica
max_over_time(rate(http_requests_total[5m])[1h:] @ start())
```

Usos típicos: comparación con "ayer", "semana pasada", baselines.

---

## 5. Funciones sobre counters: `rate`, `irate`, `increase`

Un **counter** solo crece (y se resetea a 0 cuando reinicia el proceso). No tiene sentido graficar su valor absoluto: lo que importa es *qué tan rápido crece*.

### `rate(v[d])`

Tasa promedio por segundo durante `d`. Maneja los resets de counter correctamente. Es la función #1 que se usa.

```promql
# requests por segundo, promediado en los últimos 5 min
rate(http_requests_total[5m])
```

### `increase(v[d])`

Delta absoluto en `d`. Equivale a `rate(v[d]) * d_en_segundos`.

```promql
# requests totales en la última hora
increase(http_requests_total[1h])
```

### `irate(v[d])`

Tasa instantánea: usa **solo las 2 últimas muestras**. Reacciona de inmediato pero es muy ruidoso.

```promql
# visualmente útil en Explore, pero NO para alertas
irate(http_requests_total[1m])
```

**Resumen de uso**:

| Función | Cuándo |
|---------|--------|
| `rate()` | Dashboards generales, alertas, SLO queries. **Default**. |
| `increase()` | Reportes de volumen total ("¿cuántos requests en la última hora?"). |
| `irate()` | Exploración ad-hoc, sensibilidad a spikes recientes. **Nunca en alertas**. |

Comparación mental: `rate` es `increase / seconds`. `irate` es `(last - prev) / (ts_last - ts_prev)`.

---

## 6. Funciones sobre gauges

Un **gauge** sube y baja. `rate()` sobre un gauge es **inválido** (daría negativos o valores sin sentido físico). Para gauges se usan funciones `*_over_time`:

| Función | Qué hace |
|---------|----------|
| `avg_over_time(v[d])` | Promedio de las muestras en la ventana. |
| `max_over_time(v[d])` | Máximo en la ventana. |
| `min_over_time(v[d])` | Mínimo en la ventana. |
| `sum_over_time(v[d])` | Suma de las muestras. |
| `stddev_over_time(v[d])` | Desviación estándar. |
| `last_over_time(v[d])` | Última muestra conocida (útil con series intermitentes). |
| `deriv(v[d])` | Derivada por segundo (regresión lineal) — tendencia instantánea. |
| `predict_linear(v[d], t)` | Proyección: valor estimado dentro de `t` segundos. |
| `clamp_min(v, x)` / `clamp_max(v, x)` | Trunca a un piso/techo. |
| `absent(v)` | 1 si `v` no devuelve ninguna serie; de otro modo nada. Útil para alertas "no estoy recibiendo métricas". |

```promql
# memoria libre media en 10 min
avg_over_time(node_memory_MemAvailable_bytes[10m])

# ¿cuándo se llenará el disco (0 bytes libres) si la tendencia actual continúa, en 4 horas?
predict_linear(node_filesystem_avail_bytes[1h], 4*3600) < 0

# nunca se recibe un scrape de este target
absent(up{job="payments"})
```

---

## 7. Agregadores con `by` / `without`

Los agregadores reducen un instant vector agrupando series. **Sin `by`/`without` colapsan a UNA serie**.

| Agregador | Qué hace |
|-----------|----------|
| `sum` | Suma. |
| `avg` | Promedio. |
| `max`, `min` | Extremos. |
| `count` | Cantidad de series. |
| `stddev`, `stdvar` | Dispersión. |
| `topk(k, expr)` | Las k series con mayor valor. |
| `bottomk(k, expr)` | Las k series con menor valor. |
| `quantile(φ, expr)` | Cuantil φ sobre los valores de las series. **No es `histogram_quantile`**. |

### `by` y `without`

- `sum by (job)(x)` → agrupa por `job`, descarta el resto.
- `sum without (instance)(x)` → agrupa por todo **menos** `instance`.

Son duales: `by (A, B)` ≡ `without (todo-menos-A-B)`.

```promql
# tasa total por job (colapsa instance y method)
sum by (job) (rate(http_requests_total[5m]))

# tasa por método descartando la dimensión instance
sum without (instance) (rate(http_requests_total[5m]))

# top-5 pods por CPU
topk(5, sum by (pod) (rate(container_cpu_usage_seconds_total[5m])))
```

**Error típico**: olvidar `by (le)` dentro de `histogram_quantile` → cuantil erróneo o `NaN`.

---

## 8. Histogramas y `histogram_quantile`

Un histogram clásico expone series:

```
http_request_duration_seconds_bucket{le="0.1"} 123
http_request_duration_seconds_bucket{le="0.5"} 456
http_request_duration_seconds_bucket{le="+Inf"} 789
http_request_duration_seconds_count 789
http_request_duration_seconds_sum 234.5
```

Los buckets son **acumulativos**: `le="0.5"` incluye todas las muestras ≤ 0.5s. `le="+Inf"` ≡ `_count` total.

### Fórmula canónica

```promql
histogram_quantile(
  0.95,
  sum by (le, job) (rate(http_request_duration_seconds_bucket[5m]))
)
```

Reglas:

1. Siempre `rate()` **sobre** `_bucket` (es un counter).
2. Siempre `sum by (le, ...)`: `le` **nunca** se puede eliminar.
3. El cuantil es una **estimación por interpolación lineal** dentro del bucket; su precisión depende de la granularidad de los buckets.
4. Para `summary`, `histogram_quantile` es inválido (los cuantiles ya vienen pre-calculados por target y no son agregables).

```promql
# p99 por path y método
histogram_quantile(0.99,
  sum by (le, path, method) (rate(http_request_duration_seconds_bucket[5m])))

# latencia media (OJO: no es un cuantil, es rate(sum)/rate(count))
rate(http_request_duration_seconds_sum[5m])
  /
rate(http_request_duration_seconds_count[5m])
```

---

## 9. Operadores binarios y matching

### Aritméticos y de comparación

```promql
# ratio de errores
sum(rate(http_requests_total{code=~"5.."}[5m]))
  /
sum(rate(http_requests_total[5m]))

# series donde el ratio supera 1%
(
  sum by (job) (rate(http_requests_total{code=~"5.."}[5m]))
    /
  sum by (job) (rate(http_requests_total[5m]))
) > 0.01
```

### Matching entre vectores

Para operar dos instant vectors, PromQL hace **matching de labels**. Por defecto, las series se emparejan por **todos** los labels (menos `__name__`).

| Modificador | Efecto |
|-------------|--------|
| `on (l1, l2)` | Emparejar **solo** por esos labels. |
| `ignoring (l1)` | Emparejar por todos **menos** esos. |
| `group_left` | Lado izquierdo tiene cardinalidad **mayor** (many-to-one). |
| `group_right` | Lado derecho tiene cardinalidad **mayor** (one-to-many). |

```promql
# añadir info de versión a cada serie de requests (join 1:N)
rate(http_requests_total[5m])
  * on (instance) group_left (version)
  node_app_info

# comparar error rate con un budget definido por job
sum by (job) (rate(http_errors_total[5m]))
  / on (job)
sum by (job) (rate(http_requests_total[5m]))
```

El error típico `many-to-many matching not allowed` se arregla con `group_left`/`group_right` **del lado con más series**.

---

## 10. Subqueries `[5m:1m]`

Una subquery evalúa una expresión instant repetidamente en una ventana, generando un range vector sintético.

```promql
# máximo del rate(5m) durante la última hora, muestreado cada 1 min
max_over_time(
  rate(http_requests_total[5m])[1h:1m]
)
```

Sintaxis: `expr[range:step]`. Si se omite el step, se usa el `evaluation_interval`.

**Costo**: Prometheus evalúa el inner `expr` 60 veces (1h / 1min). Caras y repetidas → **recording rule** (`obs-10`).

---

## 11. `rate` vs `irate` vs `increase` y anti-patrones

### Comparativa concreta

Supongamos un counter que crece 1 por segundo, con `scrape_interval=15s`. En los últimos 5 min hay 20 muestras.

| Query | Resultado | Interpretación |
|-------|-----------|-----------------|
| `rate(c[5m])` | ~1.0 | tasa promedio en 5 min |
| `increase(c[5m])` | ~300 | incremento absoluto en 5 min (= rate × 300s) |
| `irate(c[1m])` | ~1.0 | tasa calculada con las 2 muestras más recientes |

Si de repente el counter se congela 2 min y luego dispara 120 en el último scrape:

| Query | Resultado |
|-------|-----------|
| `rate(c[5m])` | ~1.4 (suaviza) |
| `irate(c[1m])` | ~8.0 (reacciona al spike) |

### Anti-patrones

```promql
# MAL: rate sobre un gauge → sin sentido físico
rate(node_memory_MemFree_bytes[5m])     # BUG

# BIEN: deriv sobre un gauge
deriv(node_memory_MemFree_bytes[5m])

# MAL: delta sobre un counter → ignora resets, puede dar negativos
delta(http_requests_total[5m])          # BUG

# BIEN: increase (sabe de resets)
increase(http_requests_total[5m])

# MAL: histogram_quantile sin le en by → cuantil inválido
histogram_quantile(0.95, sum by (job) (rate(x_bucket[5m])))   # BUG
# BIEN
histogram_quantile(0.95, sum by (le, job) (rate(x_bucket[5m])))

# MAL: ventana demasiado corta → NaN intermitente
rate(http_requests_total[15s])         # con scrape_interval=15s

# MAL: irate en alertas → flaps
# BIEN: rate con for: 5m
```

---

## 12. Depurar queries vacías

Cuando una query devuelve "No data" o "Empty query result", seguir este orden:

1. **¿Existe la métrica?**
   ```promql
   {__name__=~"http_requests.*"}
   ```
   Si vacío → el nombre está mal o la instrumentación no está exponiendo.
2. **¿Los labels son correctos?** Quitar los matchers uno a uno hasta que aparezcan series.
   ```promql
   http_requests_total                     # ¿hay algo?
   http_requests_total{job="api"}          # ¿y filtrando por job?
   http_requests_total{job="api", code="200"}
   ```
3. **¿Hay datos en el rango?** Revisar en Prometheus UI → *Status → Targets*. Un target `DOWN` reciente no tendrá muestras.
4. **¿Se aplicó una función inválida?** `rate()` sobre un gauge produce resultados tipo cero o constantes raras; `histogram_quantile` sin `le` produce `NaN`.
5. **¿La ventana es demasiado corta?** `rate(x[10s])` con `scrape_interval=15s` falla.
6. **¿La métrica se renombró/droppeó por relabel?** Revisar `metric_relabel_configs`.

**Herramientas**:

- Prometheus UI → `/graph` → modo *Table* muestra las series crudas.
- Prometheus UI → `/targets` para ver estado de scrape.
- `promtool query instant http://localhost:9090 'expr'` desde CLI.
- `promtool check metrics < file` para validar el formato de un `/metrics`.

---

## Resumen operativo (chuleta)

```promql
# RED metrics para un servicio HTTP
# Rate
sum by (job) (rate(http_requests_total[5m]))

# Errors (ratio)
sum by (job) (rate(http_requests_total{code=~"5.."}[5m]))
  /
sum by (job) (rate(http_requests_total[5m]))

# Duration (p95)
histogram_quantile(0.95,
  sum by (le, job) (rate(http_request_duration_seconds_bucket[5m])))
```

Con estos 3 patrones + los operadores binarios se cubre > 80% de PromQL en producción.
