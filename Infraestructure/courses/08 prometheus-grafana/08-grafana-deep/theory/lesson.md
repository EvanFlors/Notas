# Lección — Grafana en profundidad

> 12 secciones. Lectura esperada: 70–90 min. Pre-requisitos: PromQL (`obs-04`) y exporters (`obs-05`).

---

## 1. Modelo mental de Grafana

Grafana es un **frontend** sobre data sources: no guarda métricas ni logs. Cada panel ejecuta una query en tiempo real contra el backend configurado (Prometheus, Loki, Tempo, Postgres, Elasticsearch, CloudWatch, …). Esto tiene tres implicaciones prácticas:

- Si el data source está lento, el dashboard está lento. No hay "caché mágico".
- Un dashboard **no es una fuente de verdad** de datos; sí lo es de *preguntas*.
- Las variables, los paneles y las anotaciones son JSON que vive en SQLite, Postgres o MySQL (según cómo se despliegue Grafana). Para operar en serio, ese JSON hay que **versionarlo**.

El flujo de un panel es: *browser → `/api/datasources/proxy/<uid>` → data source → respuesta → render en el browser*. Entender esto evita diseños que generan 50 queries pesadas por carga.

---

## 2. Data sources

Un data source es la conexión a un backend. Lo mínimo que necesita:

- `name` legible.
- `uid` **estable** (clave única — los dashboards referencian este UID).
- `url` (p. ej. `http://prometheus:9090`).
- Credenciales (si aplica).

```yaml
# provisioning/datasources/prometheus.yml
apiVersion: 1
datasources:
  - name: Prometheus
    uid: prom-main           # fijar UID — evita que los dashboards se rompan al reprovisionar
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    jsonData:
      timeInterval: 15s      # mismo valor que `scrape_interval`
      httpMethod: POST
```

Regla de oro: **nunca** dejes el UID auto-generado si versionas dashboards.

---

## 3. Paneles — cuándo usar cada tipo

| Panel            | Pregunta que responde                                   | Ejemplo RED                                  |
|------------------|---------------------------------------------------------|----------------------------------------------|
| `time series`    | "¿cómo evoluciona en el tiempo?"                        | `rate(http_requests_total[5m])`              |
| `stat`           | "¿cuál es el valor ahora?" (big number)                 | p95 actual                                    |
| `gauge`          | "¿qué tan cerca estoy del límite?"                      | % CPU, % memoria                              |
| `bar chart`      | "comparar valores discretos entre categorías"           | errores por `status_code`                     |
| `table`          | "lista detallada ordenable"                             | top 20 endpoints por latencia                 |
| `heatmap`        | "distribución a lo largo del tiempo"                    | histograma de latencia (buckets por minuto)   |
| `state timeline` | "estados discretos en el tiempo"                        | `up` por target (0/1)                         |
| `status history` | "estados discretos recientes compactados"               | health check cada 1 min                       |

**Antipatrón clásico:** `heatmap` sin eje Y legible — se ve "bonito" pero no comunica. Si no puedes decir en una frase qué muestra, elige otro panel.

---

## 4. Queries por panel, legend, overrides

Cada panel admite varias queries (`A`, `B`, `C`…). Para que la leyenda sea legible, usa `Legend format`:

```
{{job}} / {{instance}}
{{method}} {{handler}}
```

Si el nombre crudo (`http_requests_total{job="api",instance="api:8000"}`) aparece en la leyenda, perdiste la batalla.

**Overrides por serie** permiten pintar una métrica distinta sin crear otro panel: p95 en rojo, p50 en gris. Útil para dashboards densos. **No abuses**: 10 overrides en un panel es señal de que necesitas dos paneles.

---

## 5. Variables y templating

Las variables convierten dashboards estáticos en reutilizables. Los tipos relevantes:

- `query` — valores desde el data source (p. ej. `label_values(up, job)`).
- `custom` — lista fija (`prod,staging,dev`).
- `datasource` — permite elegir el data source (útil en multi-cluster).
- `interval` — ventanas (`1m,5m,15m,1h`).

**Chained variables**: una variable depende de otra. Ejemplo canónico — `$cluster` → `$namespace` → `$pod`:

```
Variable: cluster     query: label_values(up, cluster)
Variable: namespace   query: label_values(up{cluster="$cluster"}, namespace)
Variable: pod         query: label_values(up{cluster="$cluster",namespace="$namespace"}, pod)
```

**`__all`**: valor especial que expande a todos. **Peligro**: puede generar una query gigante. Mitiga con `All custom value` → p. ej. `.+` para regex.

**Intervals mágicos**:

- `$__rate_interval` — Grafana calcula un intervalo mínimo (`4 * scrape_interval`) seguro para `rate()`.
- `$__interval` — resolución del panel según zoom.
- `$__range` — rango completo visible (útil con `increase`).

---

## 6. Transformations

Las transformations se aplican **en el navegador** sobre el resultado de las queries, antes del render:

- `merge` — combina resultados de varias queries en una tabla.
- `join by field` — join tipo SQL por un campo (p. ej. unir `cpu` y `memory` por `pod`).
- `reduce` — colapsa series temporales a un valor (last, mean, max…) → perfecto para tablas tipo "top N".
- `filter by name/value` — oculta columnas o filas.

Regla: si la transformación es **puramente visual** (ocultar columna) → transformation. Si implica agregar datos (sumar, promediar cross-series) → **hazlo en PromQL**, es más rápido y correcto.

---

## 7. Templating y repetición de paneles

Un panel puede **repetirse por variable** (`Repeat options → Variable: $service`): se renderiza una copia del panel por cada valor seleccionado. Igual con **filas** (`Repeat row for variable`).

Caso típico: dashboard "RED por servicio" con una fila repetida por `$service` que contiene 3 paneles (Rate, Errors, Duration). Un sólo dashboard sirve a 20 servicios.

**Trampa**: la repetición dispara N × queries. Con 50 servicios y 3 paneles por fila son 150 queries en cada carga. Compón con `__all` cuidadosamente.

---

## 8. Alerting UI (Grafana Alerting)

Desde Grafana 8 existe un motor de alertas unificado que puede evaluar queries de **cualquier** data source (no sólo Prometheus) y enrutar por Alertmanager (externo o embebido).

Partes:

- **Contact point** — dónde enviar (Slack, email, webhook, PagerDuty…).
- **Notification policy** — árbol de ruteo por labels.
- **Alert rule** — condición (query + umbral + duración + labels + annotations).
- **Silences** — mute temporal.

Coexiste con Alertmanager clásico de Prometheus. En este curso, Alertmanager "real" se cubre en `obs-09`; aquí sólo vemos Grafana Alerting como UI y su provisioning.

---

## 9. Provisioning

Todo lo que se puede hacer por UI puede **provisionarse** desde archivos YAML/JSON montados en `/etc/grafana/provisioning/`:

```
provisioning/
├── datasources/*.yml
├── dashboards/*.yml           (providers que apuntan a carpetas con *.json)
├── alerting/*.yml             (rules, contact points, policies)
└── plugins/*.yml
```

Dashboard provider típico:

```yaml
apiVersion: 1
providers:
  - name: default
    orgId: 1
    folder: Capstone
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: false
    options:
      path: /var/lib/grafana/dashboards
```

Con `allowUiUpdates: false` el dashboard aparece con badge **Provisioned** y no se puede editar por UI (sí "copiar como"). Esto es lo que convierte un dashboard en código.

---

## 10. Roles, permisos y folders

Grafana tiene tres roles org-level: `Viewer`, `Editor`, `Admin`. Para granularidad, se usan **folders**: los permisos se aplican por folder y los dashboards los heredan.

Patrón recomendado para una plataforma:

- Folder por equipo (`team-payments`, `team-growth`).
- Folder `Platform` sólo-lectura para dashboards transversales (SLOs, infra).
- Service accounts para automation (CI que publica dashboards).

Teams + folders + un provider de dashboards per team es lo que te permite escalar sin volverte el "DBA de dashboards" de toda la compañía.

---

## 11. Dashboards as code

Opciones, de menos a más declarativo:

1. **JSON exportado** (`Share → Export`) + commit → simple pero el JSON es verboso y frágil ante merges.
2. **[grizzly](https://grafana.github.io/grizzly/)** — CLI tipo `kubectl` para Grafana: `grr apply`, `grr diff`, `grr pull`. Trata dashboards, data sources y rules como "recursos".
3. **[grafonnet](https://grafana.github.io/grafonnet/)** — librería jsonnet oficial. Dashboards como funciones: parametrizables, componibles, DRY.

Ejemplo mínimo `grafonnet` (jsonnet):

```jsonnet
local g = import 'g.libsonnet';

g.dashboard.new('RED — api')
+ g.dashboard.withPanels([
    g.panel.timeSeries.new('Rate')
    + g.panel.timeSeries.queryOptions.withTargets([
        g.query.prometheus.new('prom-main', 'sum(rate(http_requests_total[$__rate_interval]))')
      ]),
  ])
```

Se renderiza con `jsonnet -J vendor dashboard.jsonnet > rendered.json` y luego `grr apply` lo publica.

Para 50+ servicios con el mismo patrón RED, `grafonnet` + templates es la única forma sostenible. JSON crudo escala mal.

---

## 12. Governance y antipatrones

Checklist mínimo para una plataforma madura:

- **Naming**: `<team>-<servicio>-<pregunta>` (p. ej. `payments-checkout-red`).
- **Ownership**: cada dashboard tiene un folder de equipo con dueño.
- **Code review**: todo cambio pasa por PR; CI valida (`jsonnet lint`, `grr diff`).
- **Retención**: dashboards sin visitas en 90 días → candidatos a archivar.
- **Golden path**: una plantilla "nuevo servicio → tiene su RED dashboard autogenerado" (ver `obs-15`).
- **Cost awareness**: queries caras + repeat → tormentas de carga en Prometheus. Monitoriza `prometheus_http_request_duration_seconds` por `handler="query_range"`.

Antipatrones frecuentes:

- Dashboard de "todo": 40 paneles, nadie lo entiende.
- Variables con `__all` por defecto que ejecutan queries de rango largo.
- Dashboards editados por UI que divergen del repo.
- Alertas definidas sólo en Grafana sin PR trail.

Si no puedes **borrar** un dashboard sin que alguien proteste… es que no estaba documentado. Diseña para el borrado.
