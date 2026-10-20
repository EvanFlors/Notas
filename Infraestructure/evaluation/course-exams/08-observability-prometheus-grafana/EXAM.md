# Examen de certificación — Curso **Prometheus + Grafana** (observability)

- **Nivel evaluado:** intermedio-avanzado (módulos `obs-05` a `obs-15`, con prerrequisitos de `obs-01` a `obs-04`).
- **Duración:** 90–120 min.
- **Umbral de aprobación:** 70% ponderado **y** ≥ 50% por dimensión **y** 0 red flags activas (ver `competency-matrix.yaml`).
- **Dimensiones evaluadas:** conceptual + operativa + arquitectónica (`todas`).
- **Entorno:** 100% local. Requiere `promtool` (binario oficial de Prometheus ≥ 2.50) y `amtool` (de Alertmanager ≥ 0.27) para la validación automática. Grafana no es obligatorio (los dashboards se entregan como JSON exportado). **Si `promtool`/`amtool` no están instalados**, el ejercicio operativo se marca como **SKIP** (`operative/validate.sh` emite `SKIP: promtool missing` y la parte operativa se corrige manualmente contra `operative/VALIDATION.md`, no se otorga puntaje máximo en los criterios de validación automática).
- **Idioma:** enunciados en español; código, PromQL, YAML, nombres de métricas y comandos en inglés.
- **Entrega:** carpeta del examen con `operative/solution/` + `answers.md` + `architectural/ADR-001-observability-platform.md`.

> **Reglas de integridad.** Puedes consultar documentación oficial de Prometheus, Grafana, Loki, Alertmanager, SRE Workbook y man pages. **No** puedes consultar un LLM durante la parte operativa; sí para validar la teoría previa a responder (declararlo en `answers.md`). **Prohibido** incluir secretos reales: usa placeholders `__REDACTED__` y variables de entorno.

---

## Distribución del puntaje

| Parte | Dimensión | Peso |
|-------|-----------|------|
| Preguntas conceptuales (Q1–Q12) | conceptual | 35% |
| Ejercicio operativo (`operative/`) | operativa | 40% |
| Ejercicio arquitectónico (`architectural/`) | arquitectónica | 25% |

Un examen con < 50% en cualquiera de las tres dimensiones es **no aprobado** aunque el ponderado supere 70%. Cada red flag activa (ver `competency-matrix.yaml`) rebaja 1 nivel al criterio donde aparezca; dos o más → no aprobado.

---

## Parte 1 — Preguntas conceptuales (35%)

Formato: respuesta corta/explicación en `answers.md`. Se busca **razonamiento** (por qué, qué pasaría si, cuándo preferirías X sobre Y). Longitud sugerida: 5–12 líneas por respuesta. Las preguntas evalúan una competencia dominante indicada entre paréntesis.

### Q1 (C1) — counter vs gauge vs histogram

> Un ingeniero mide la latencia de un endpoint HTTP con un `Summary` llamado `http_latency_seconds` que expone cuantiles `0.5/0.95/0.99` y lo agrega entre 10 réplicas con `avg by (path)(http_latency_seconds{quantile="0.99"})`. **Por qué** ese p99 agregado es matemáticamente inválido, y qué cambia si el mismo diseño usa un `Histogram` consultado con `histogram_quantile(0.99, sum by (le, path)(rate(http_latency_seconds_bucket[5m])))`. Menciona el rol de los *native histograms* como alternativa.

### Q2 (C2) — rate / irate / increase

> Tienes `http_requests_total` (counter). Explica **cuándo preferirías** `rate()[5m]`, `irate()[1m]`, e `increase()[1h]`, y qué pasa si la ventana de `rate()` cae por debajo de `2 × scrape_interval`. ¿Por qué `rate()` sobre un gauge siempre está mal, y por qué `deriv()` sobre un counter también?

### Q3 (C3) — relabel vs metric_relabel

> Describe la diferencia entre `relabel_configs` y `metric_relabel_configs` en términos de **cuándo** se aplican y **qué** pueden modificar. Luego: un `node_exporter` nuevo introdujo `node_scrape_collector_duration_seconds` con 400 series por target por una label `collector` muy chismosa. ¿Dónde la filtras y por qué no en el otro lugar? Da la snippet mínima.

### Q4 (C4,C10) — alerta por síntoma vs causa

> El equipo tiene esta alerta activa en producción:
>
> ```yaml
> - alert: HighCPU
>   expr: avg by (instance) (rate(node_cpu_seconds_total{mode!="idle"}[5m])) > 0.85
>   for: 2m
>   labels: { severity: page }
> ```
>
> **Por qué** esta alerta es, en términos de SRE Workbook, un bug — no una señal útil. Rediseña: cita qué SLI usarías, qué SLO plausible, y por qué una alerta multi-window multi-burn-rate (MWMBR) elimina la mayoría de falsos positivos sin perder sensibilidad. No es necesario escribir las reglas aún (lo harás en OP-task-3).

### Q5 (C6) — dashboard inútil

> Un dashboard de servicio tiene: (i) un heatmap de `rate(http_request_duration_seconds_bucket[5m])` sin eje Y de buckets, (ii) un panel "CPU" con una sola serie `node_cpu_seconds_total` sin `rate()`, (iii) una variable `$instance` tipo `query` que lista 4 000 instances sin filtro por `$job`. Explica **qué está mal** en cada caso y **qué cambiarías** para que sea una vista útil para on-call. (Una línea por panel es suficiente para el "qué cambiarías".)

### Q6 (C1,C5) — triage de cardinalidad

> Dado el siguiente top-10 (`topk(10, count by (__name__)({__name__!=""}))`):
>
> | métrica | series |
> |---|---|
> | `apiserver_request_duration_seconds_bucket` | 1_480_000 |
> | `http_request_duration_seconds_bucket{path=~".+"}` (label `path` cardinalidad 90k) | 920_000 |
> | `go_sql_stats{query_hash=~".+"}` | 410_000 |
> | `nginx_ingress_controller_request_duration_seconds_bucket{host="..."}` | 220_000 |
>
> Para cada entrada, indica: **drop / keep / renombrar / recordear** y por qué. Para la segunda, propón la acción concreta (dónde se recorta `path`).

### Q7 (C2) — PromQL join

> Quieres el error rate 5xx **por servicio y por versión** combinando dos métricas: `http_requests_total{status=~"5.."}` (viene del request handler, no tiene label `version`) y `app_build_info{service, version}` (gauge con valor 1). Escribe la query usando `on()/group_left()` justificando qué label se mueve y por qué `group_left` y no `group_right`. ¿Qué ocurre si hay dos versiones activas simultáneamente (canary)?

### Q8 (C4,C10) — MWMBR a defender

> Dadas estas dos reglas para un SLO de disponibilidad 99.9% / 30 d:
>
> ```yaml
> - alert: SLOBurnFast
>   expr: ( sum(rate(http_requests_total{status=~"5.."}[1h])) / sum(rate(http_requests_total[1h])) ) > (14.4 * 0.001)
>         and
>         ( sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) ) > (14.4 * 0.001)
>   for: 2m
> - alert: SLOBurnSlow
>   expr: ( sum(rate(http_requests_total{status=~"5.."}[6h])) / sum(rate(http_requests_total[6h])) ) > (6 * 0.001)
>         and
>         ( sum(rate(http_requests_total{status=~"5.."}[30m])) / sum(rate(http_requests_total[30m])) ) > (6 * 0.001)
>   for: 15m
> ```
>
> Explica **qué garantiza** la combinación de las dos ventanas (larga + corta) y **qué deja de garantizar** si borras la ventana corta. ¿Por qué 14.4 y 6? ¿Qué le añadirías para que sobreviva a un re-despliegue con pocas peticiones (low-traffic)?

### Q9 (C7) — long-term store

> Una org tiene 60M series activas, retención requerida 13 meses, 3 regiones, 6 equipos. Compara **Thanos sidecar + querier + compactor** vs **Grafana Mimir** vs **VictoriaMetrics cluster** para esta carga. Indica, para cada uno, un *motivo técnico y uno operativo* por el que lo elegirías o descartarías. Explica qué pierdes y qué ganas al pasar de federation hierárquica clásica a `remote_write`.

### Q10 (C8) — Operator no ve mi ServiceMonitor

> Instalaste `kube-prometheus-stack` con `releaseName=kps`. Creaste un `ServiceMonitor` en el namespace de tu app pero el target no aparece en `/targets`. En orden, lista **cuatro** causas probables (desde la más común a la más sutil) y para cada una, el comando o campo que lo verifica. No uses "revisa los logs" como respuesta.

### Q11 (C9) — Loki vs instrumentar

> Para una métrica de "número de 500 en el servicio X por path", ¿cuándo prefieres una **log-based metric** derivada de Loki (p. ej. con un recording rule LogQL) vs **instrumentar directo** con `prometheus_client`? Da dos criterios a favor de cada opción y una regla práctica para la decisión. ¿Por qué poner `request_id` como label en Loki es tan malo como en Prometheus, pero por una razón distinta?

### Q12 (C11) — contrato de observabilidad

> Vas a defender ante Platform un "contrato de observabilidad de servicio". Enumera cinco cláusulas que exigirías (p. ej. "cada servicio debe exponer un `*_build_info` con `version` y `commit`") y para cada una: **por qué** reduce costo o fatigue o mejora onboarding. ¿Qué cláusula es más fácil de aplicar por CI (`promtool test rules`, lint de dashboards) y cuál requiere revisión humana?

---

## Parte 2 — Ejercicio operativo (40%)

Ver `operative/README.md`. Cinco tareas secuenciales sobre un *starter* con:

- un `prometheus.yml` con dos jobs mal configurados,
- un endpoint `/metrics` sintético con problemas de tipo, nombre y cardinalidad,
- un `rules.yml` con una alerta single-window ingenua,
- un `alertmanager.yml` con routing plano sin inhibition.

Debes **corregir, instrumentar y validar** con `promtool` y `amtool`. Validación automática vía `operative/validate.sh`.

**Entregables en `operative/solution/`:**

1. `prometheus.yml` corregido (relabel por annotation, `metric_relabel_configs` para drop de cardinalidad, scrape intervals coherentes).
2. `metrics-fix.md` con el `/metrics` auditado (ver `operative/starter/metrics.txt`) y el diff propuesto por métrica (tipo, nombre, labels).
3. `rules.yml` con: (a) *ingredients* como **recording rules** (`job:http_requests:rate5m`, `job:http_request_errors:ratio_rate5m`, etc.), (b) **MWMBR alerts** (fast + slow) para un SLO 99.9%/30d, (c) alertas de síntoma, no causa, con `summary`, `description`, `runbook_url`. **Debe pasar** `promtool check rules` **y** `promtool test rules operative/solution/rules_test.yml`.
4. `rules_test.yml` con casos de test (`promtool test rules`) que verifiquen al menos: (i) no dispara con error rate 0, (ii) dispara `SLOBurnFast` cuando el error rate sostiene 1.5% por 5 min, (iii) no dispara `SLOBurnSlow` con un pico de 30 s. 
5. `alertmanager.yml` con route tree por severidad (page/ticket), `group_by`/`group_wait`/`group_interval`/`repeat_interval` justificados, al menos una regla de **inhibition** (page silencia ticket del mismo `service`), receivers con placeholders (`__REDACTED__`) — **ningún secreto real**. Debe pasar `amtool check-config`.
6. `dashboards/service-red.json` (export de Grafana) con 4 paneles RED (traffic/latency p95/latency p99/errors) usando las recording rules de (3) y una variable `$service`.
7. `notes.md` justificando cada decisión y pegando el output de `operative/validate.sh`.

---

## Parte 3 — Ejercicio arquitectónico (25%)

Ver `architectural/scenario.md`. Produces un **ADR** (`architectural/ADR-001-observability-platform.md`) justificando:

- elección de long-term store (Thanos / Mimir / VictoriaMetrics / none),
- estrategia multi-tenant y de retención (hot vs cold, downsampling),
- cómo entregas el "golden path" de observabilidad por servicio (ServiceMonitor + rules + dashboard autogenerados vía template),
- política de alertas (MWMBR, routing, inhibition, runbooks),
- governance y costos (series activas, logs ingested, egress).

---

## Rúbrica global

Cada criterio se puntúa en escala 0–3 según los descriptores de la **guía de corrección** (`operative/VALIDATION.md` para operativa, `architectural/scenario.md` para arquitectónica).

| Nivel | Puntaje | Descriptor general |
|-------|---------|--------------------|
| Insuficiente | 0 | Omitido, incorrecto o con red flag presente. |
| Básico | 1 | Reconoce el concepto pero lo aplica mecánicamente; sin razonamiento o con error relevante. |
| Competente | 2 | Correcto, justificado, trade-offs mencionados. |
| Experto | 3 | Correcto + anticipa modos de falla + propone verificación (promtool/amtool/dashboard preview en CI) + conecta con otras capas (SD, Operator, long-term store, costos). |

**Umbral:** 70% ponderado **y** ≥ 50% por dimensión **y** 0 red flags activas. Red flag ⇒ rebaja de 1 nivel al criterio donde aparezca; dos o más ⇒ no aprobado.

---

## Preguntas de seguimiento (sólo instructor, modalidad live)

Si el examen se corrige en vivo, el instructor puede escoger 2–3 de estas para distinguir memorización de comprensión:

1. "Enséñame en `/graph` qué devuelve `rate(http_requests_total[1s])` con `scrape_interval=15s` y por qué." (sobre Q2)
2. "Bajas el `scrape_interval` de 15s a 5s en un cluster con 1 M series. ¿Qué pasa con la RAM, con el disco y con el error de los `rate()` existentes?" (sobre C1, C7)
3. "Si marco una métrica como `honor_labels: true`, ¿qué puedes romper?" (sobre C3)
4. "Convierte tu MWMBR en una alerta que respete low-traffic sin perder sensibilidad en pico." (sobre Q8 / OP-task-3)
5. "Si borro la clave del long-term store y el `remote_write` entra en back-pressure, ¿qué métricas de Prometheus mismo te lo cuentan y qué pierdes?" (sobre Q9)
6. "Explica por qué `kube_pod_status_phase` + `up` no es un buen SLI de disponibilidad para una app HTTP." (sobre Q4, C10)
7. "Haz que tu `ServiceMonitor` sí sea visto por el Operator sin reinstalar el chart." (sobre Q10)

Ver `operative/VALIDATION.md` para el guión completo de corrección y los puntajes por criterio.
