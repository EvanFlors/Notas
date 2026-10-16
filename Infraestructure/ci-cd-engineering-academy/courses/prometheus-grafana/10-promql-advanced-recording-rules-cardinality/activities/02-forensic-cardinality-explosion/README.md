# Actividad 02 — Forense de cardinality explosion (OOM)

## 1. Identificación

- **ID:** `obs-10-02-forensic-cardinality-explosion`
- **Tecnología:** `prometheus-grafana`
- **Módulo:** `10-promql-advanced-recording-rules-cardinality`
- **Dificultad:** advanced
- **Duración estimada:** 60–90 min
- **Tipo:** independent

## 2. Contexto (incidente)

**Fecha:** 02:14 UTC. **Resumen:** Prometheus crasheó por OOM. El dashboard de meta-observabilidad muestra que `prometheus_tsdb_head_series` subió de 180 k a **4.2 M** en los 30 minutos previos al crash. En el último release de la app `checkout-service` se añadieron nuevas métricas RED.

Lo que te dejaron antes del crash:

- `starter/evidence/tsdb-status.json` — snapshot del endpoint `/api/v1/status/tsdb` 2 minutos antes del OOM.
- `starter/evidence/metrics-sample.txt` — un `curl /metrics` capturado contra `checkout-service`.
- `starter/prometheus.yml` — el `prometheus.yml` actual, sin ninguna defensa, scrapeando `checkout-service`.

**Tu misión** (sin pistas directas de la solución):

1. Identificar el `__name__` ofensor.
2. Identificar la **label** culpable.
3. Aplicar la contención (`metric_relabel_configs: action: drop`) en `starter/prometheus.yml` para que, al reiniciar Prometheus, la basura **no vuelva a entrar**.
4. Documentar en `starter/FIX.md` cuál es la fix definitiva aguas arriba.

Esta actividad es **independiente**: no se te dan los comandos exactos. Se te dan datos y herramientas.

## 3. Objetivos

- Diagnosticar la métrica ofensora cruzando evidencia.
- Identificar la label culpable y argumentar por qué nunca debió ser label.
- Aplicar `metric_relabel_configs: action: drop` sobre la métrica ofensora en el `scrape_config` correcto.
- Escribir en `starter/FIX.md` (≤ 10 líneas) qué cambio debe hacerse en el productor.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` secciones 5, 6 y 7.
- `bash`, `grep`, `awk`, `sort`, `uniq` — herramientas estándar.
- Opcional: `jq` para interpretar `tsdb-status.json` más cómodamente.
- Opcional: `promtool check config` para validar que el `prometheus.yml` final es válido.

**Costos**: ninguno (ejercicio totalmente offline).

## 5. Instrucciones (sin solución)

### 5.1 Reconocer el terreno

```bash
cd courses/prometheus-grafana/10-promql-advanced-recording-rules-cardinality/activities/02-forensic-cardinality-explosion
ls starter/evidence/
```

### 5.2 Preguntas que debes responderte, en orden

1. **¿Qué métrica tiene más series?** Mira `tsdb-status.json` → `data.seriesCountByMetricName`.
2. **¿Qué label genera más valores únicos?** Mira `tsdb-status.json` → `data.labelValueCountByLabelName`.
3. **¿La ofensora emite esa label?** Confírmalo en `metrics-sample.txt`.
4. **¿En qué `scrape_config` entra?** Mira `prometheus.yml`.
5. **¿Es suficiente dropear la métrica o hace falta más?** Decide: `drop` de la métrica entera, o `labeldrop` de la label (preservando la métrica sin esa dimensión)?

### 5.3 Herramientas útiles (bash puro, sin Prometheus corriendo)

```bash
# Top métricas por series según el snapshot
jq -r '.data.seriesCountByMetricName[] | "\(.value)\t\(.name)"' starter/evidence/tsdb-status.json | sort -rn | head

# Top labels por nº de valores únicos
jq -r '.data.labelValueCountByLabelName[] | "\(.value)\t\(.name)"' starter/evidence/tsdb-status.json | sort -rn | head

# Métricas que exponen una label concreta en el sample (p. ej. 'user_id')
grep 'user_id=' starter/evidence/metrics-sample.txt | awk '{print $1}' | awk -F'{' '{print $1}' | sort -u
```

Si no tienes `jq`, usa `python3 -m json.tool starter/evidence/tsdb-status.json | less`.

### 5.4 Aplicar la contención

Edita `starter/prometheus.yml`. Añade un bloque `metric_relabel_configs` en el `scrape_config` del `job_name: checkout-service` que **dropee la métrica ofensora**. El patrón canónico es:

```yaml
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: <NOMBRE_METRICA_OFENSORA>
        action: drop
```

Decisión alternativa: en vez de `drop` completo, puedes considerar `labeldrop` de la label culpable para conservar la métrica agregada:

```yaml
    metric_relabel_configs:
      - action: labeldrop
        regex: <NOMBRE_LABEL>
```

**Toma una decisión y justifícala en `FIX.md`.** En este incidente concreto, la métrica entera depende semánticamente de la label (sin la label, mide algo distinto); por eso `drop` de la métrica es la elección segura. Pero debes explicarlo tú.

### 5.5 Documentar la fix definitiva

Crea `starter/FIX.md` con:

- La **métrica** y la **label** culpables.
- Qué `metric_relabel_configs` aplicaste y por qué.
- Qué cambio debería hacerse en el **código** de `checkout-service` (eliminar la label `user_id` del instrumentation, y qué poner en su lugar — pista: exemplars + traces).
- Qué alerta de meta-observabilidad proponer para que esto no vuelva a pasar sin aviso.

### 5.6 Validar

```bash
bash tests/validate.sh
```

Debe terminar con `OK`.

## 6. Resultado esperado

- `starter/prometheus.yml` contiene un `metric_relabel_configs` con `action: drop` apuntando a la métrica ofensora identificada por el estudiante.
- `starter/FIX.md` existe y menciona la métrica y la label culpables.
- `promtool check config` pasa (si está instalado).

## 7. Criterios de aceptación

- [ ] Funcional: el `drop` está en el `scrape_config` correcto.
- [ ] Preciso: la métrica ofensora identificada coincide con la de la evidencia.
- [ ] Seguro: el regex del drop no es demasiado amplio (`.*` dropearía todo — el harness lo rechaza).
- [ ] Documentado: `FIX.md` explica el fix definitivo aguas arriba.
- [ ] Reproducible: `bash tests/validate.sh` termina con `OK`.

## 8. Validación

```bash
bash tests/validate.sh
```

El harness verifica:
- La evidencia está intacta (no borrada).
- `prometheus.yml` contiene un `action: drop` sobre `__name__` apuntando a la métrica correcta.
- El regex no es `.*` ni `.+` (sería demasiado amplio).
- `FIX.md` existe y menciona la métrica y la label.
- Opcionalmente, `promtool check config` pasa.

## 9. Preguntas de reflexión

1. ¿Por qué un `drop` por `metric_relabel_configs` es un **hot-fix** y no la cura?
2. Si el equipo del `checkout-service` insiste en poder consultar métricas "por usuario", ¿qué les propones en su lugar? Da dos alternativas con pros/contras.
3. ¿Qué alerta de meta-observabilidad hubieras tenido activa para detectar esto a los 5 min, no a los 30?
4. Si la label culpable fuera `tenant_id` en lugar de `user_id`, ¿cambiaría tu decisión? ¿Por qué?
5. En multi-tenant con cardinalidad legítima pero alta, ¿cuándo pasa de ser un problema de Prometheus a serlo de la arquitectura?

## 10. Extensiones

- **E1** — Añade a `prometheus.yml` un `sample_limit` y un `label_limit` por scrape job como defensa en profundidad; justifica los valores.
- **E2** — Diseña un pre-commit hook que corra `promtool check metrics` sobre el `/metrics` del `checkout-service` y falle si alguna label aparece con alta cardinalidad.
- **E3** — Escribe una alerta `MetricCardinalityExploding` que dispare si una métrica particular supera 100 k series en 10 min.
- **E4** — Simula el fix en el productor: toma el `metrics-sample.txt`, borra las líneas con `user_id`, verifica que `grep 'user_id'` ya no devuelve nada.

## 11. Limpieza

```bash
# Nada persistente. Si corriste promtool, no deja estado.
rm -f /tmp/obs10-02-* 2>/dev/null || true
```
