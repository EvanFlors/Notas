# gcp-08 — Lección: Cloud Operations y Audit Logs

> 12 secciones. Mayoritariamente conceptual. Prerrequisitos: `gcp-04`, `gcp-07`, `aws-12`.

---

## 1. Por qué observabilidad "nativa" en GCP y no solo Prometheus/Grafana

En AWS el reflejo típico es "monto Prometheus + Grafana + Loki y me olvido de CloudWatch". En GCP la ecuación cambia porque:

1. **Cloud Logging** ingiere automáticamente los logs de **Cloud Run**, **Cloud Functions**, **GKE** (vía fluentbit sidecar), **Compute Engine** (si pones el agent), **App Engine** y todos los servicios managed, sin instalar nada. El coste de "no usarlo" es tirar logs ya pagados.
2. **Cloud Monitoring** incluye **SLOs nativos** sobre servicios managed (Cloud Run request count/latency, GKE, Cloud SQL). Montar un SLO sin Prometheus toma minutos.
3. **Cloud Trace** admite OTLP directo desde el OTel SDK sin exporter propietario.
4. **Audit Logs** son el equivalente de CloudTrail — y los `Admin Activity` son **gratis**, **siempre on**, no se pueden desactivar. Esto es un *property* del plano de control: no hay forma de que un atacante borre su rastro de "quién creó qué".

La conclusión práctica: **empieza con Cloud Operations**. Si en algún momento el equipo necesita algo que el stack GCP no da (dashboards muy custom, retention a 5 años barata, agregación cross-cloud), **añade** Prometheus/Grafana en paralelo, con el **OTel Collector** haciendo fan-out. No montes Prometheus/Grafana *en vez de* Cloud Ops por costumbre; es trabajo doble.

> **Idea clave:** en GCP la observabilidad baseline la tienes casi gratis. Lo que cuesta es **lo que decides retener** (log volumen, métricas custom, span rate) y **lo que decides auditar** (Data Access logs).

---

## 2. Nombres actuales y mapeo mental con AWS

| GCP (Cloud Operations) | AWS equivalente | Notas |
|------------------------|-----------------|-------|
| Cloud Logging | CloudWatch Logs | GCP indexa por campos estructurados nativamente. |
| Cloud Monitoring | CloudWatch Metrics + Alarms | SLOs nativos; metrics scopes multi-project. |
| Cloud Trace | AWS X-Ray | Cloud Trace ingiere OTLP directamente. |
| Cloud Profiler | CodeGuru Profiler (parcial) | Profiles continuos CPU/heap sin overhead notable. |
| Error Reporting | — (parcial en CW Insights) | Agrupa stack traces de errores. |
| Audit Logs (Admin Activity) | CloudTrail management events | **Gratis**, siempre on. |
| Audit Logs (Data Access) | CloudTrail data events | Opt-in, puede ser caro. |
| Log sinks a BigQuery/GCS/Pub/Sub | CloudWatch subscription filters | Más tipado: BigQuery es ciudadano de primera clase. |
| Log Analytics (SQL sobre log buckets) | CloudWatch Logs Insights | Log Analytics es SQL BigQuery, mucho más expresivo. |

> **Trampa de nombres:** "Stackdriver" era el nombre viejo. Hoy es **Cloud Operations suite** y los subservicios se llaman `Cloud Logging`, `Cloud Monitoring`, etc. Documentación antigua que diga "Stackdriver Logging" sigue siendo correcta conceptualmente pero el servicio actual no se llama así.

---

## 3. Cloud Logging: log buckets, sinks y log-based metrics

### 3.1 Buckets

Cada project arranca con dos buckets:

- **`_Required`**: Admin Activity + System Event + Access Transparency. Retención **400 días fijos**. **Gratis**. No se puede borrar ni modificar su retención.
- **`_Default`**: todo lo demás (application logs, Data Access si está activo). Retención **30 días por defecto**, configurable hasta **3650 días**. **50 GiB/mes gratis** por project; después se cobra.

Puedes crear **buckets custom** para separar flujos (p. ej. un bucket `audit-long` con retención 400 días, y un `_Default` reducido a 7 días para apps noisy).

### 3.2 Sinks: router de logs

Un **sink** es una regla `(filtro, destino, inclusion/exclusion)` que decide a dónde se **copia** (o **excluye**) un log. Destinos posibles:

- **Otro log bucket** (incluido en otro project — útil para "central log project").
- **BigQuery dataset**: análisis SQL, retención semi-eterna barata.
- **Cloud Storage bucket**: archive a precio Nearline/Coldline.
- **Pub/Sub topic**: para streaming hacia otro sistema (Datadog, Splunk, SIEM).
- **Logging bucket en otro project** (para arquitecturas multi-project con `log-sink-project`).

> **Patrón canónico**: `_Default` corto (7–30 días) + sink a BigQuery para "lo que quieras indexar barato" + sink a GCS Coldline para "lo que solo necesitas para auditoría a largo plazo".

### 3.3 Exclusion filters: el principal control de costo

Un sink puede ser **inclusion** (lo que entra en el destino) o **exclusion** (lo que **no** se ingiere en el bucket). Ejemplo típico de exclusión en `_Default`:

```
resource.type="k8s_container"
severity<WARNING
textPayload=~"health|readiness|probe"
```

Esto evita que los health checks de GKE llenen el bucket. El impacto en factura puede ser 10×–100×.

### 3.4 Log-based metrics

Una **log-based metric** convierte un patrón de log en una métrica de Cloud Monitoring. Dos tipos:

- **Counter**: cada log que matchee suma 1.
- **Distribution**: extrae un número del log (p. ej. latencia en ms) y lo acumula como histograma.

Ejemplo counter: contar `ERROR` logs por servicio.

Ejemplo distribution: extraer `http_request.latency` de los logs de acceso.

Las log-based metrics custom cuentan hacia tu quota de métricas custom en Cloud Monitoring; úsalas con criterio.

---

## 4. Cloud Monitoring: metrics scopes, dashboards y alerting policies

### 4.1 Metrics scope

Un **metrics scope** es una vista agregada de métricas de **varios projects** desde un project "scoping". Útil cuando tienes `prod-eu`, `prod-us`, `stg` y quieres un dashboard unificado sin duplicar métricas.

### 4.2 Dashboards

Dashboards son JSON. Puedes versionarlos en Git y aplicarlos con `gcloud monitoring dashboards create`. Un dashboard típico de un servicio Cloud Run:

- Request count (por revisión).
- Request latency p50/p95/p99.
- Error rate (5xx / 4xx).
- Container CPU/memoria.
- Cold start count.
- Billable instance time.

### 4.3 Alerting policies

Una **alerting policy** son 3 piezas:

1. **Condition(s)**: cuándo disparar. Puede ser:
   - Threshold sobre métrica (`metric_absence`, `threshold`, `mql`).
   - Log match (log-based alert, sobre un filtro de Cloud Logging).
   - SLO burn rate.
2. **Notification channel(s)**: a dónde ir. Email, SMS, Slack, PagerDuty, Pub/Sub, webhook.
3. **Documentation**: texto que acompaña la notificación. **Crítico**: aquí va el runbook, enlace al dashboard, dueño de la alerta.

Esqueleto JSON:

```json
{
  "displayName": "checkout-5xx-high",
  "combiner": "OR",
  "conditions": [
    {
      "displayName": "5xx rate > 1% during 5m",
      "conditionThreshold": {
        "filter": "resource.type=\"cloud_run_revision\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\"",
        "comparison": "COMPARISON_GT",
        "thresholdValue": 0.01,
        "duration": "300s",
        "aggregations": [
          {"alignmentPeriod": "60s", "perSeriesAligner": "ALIGN_RATE"}
        ]
      }
    }
  ],
  "notificationChannels": ["projects/PROJECT_ID/notificationChannels/CHANNEL_ID"],
  "documentation": {
    "content": "Runbook: ... | Dashboard: ... | Owner: team-checkout",
    "mimeType": "text/markdown"
  },
  "alertStrategy": {
    "autoClose": "1800s"
  }
}
```

> **Antipatrón habitual**: alertas sin `documentation`. Un oncaller a las 3am mira una alerta sin runbook y pierde 20 minutos buscando el dashboard. Documentación obligatoria.

### 4.4 SLOs nativos

Para servicios Cloud Run / GKE / Cloud SQL puedes definir **SLOs** declarativos:

```json
{
  "displayName": "checkout availability 99.9%",
  "serviceLevelIndicator": {
    "requestBased": {
      "goodTotalRatio": {
        "goodServiceFilter": "metric.type=\"run.googleapis.com/request_count\" metric.labels.response_code_class!=\"5xx\"",
        "totalServiceFilter": "metric.type=\"run.googleapis.com/request_count\""
      }
    }
  },
  "goal": 0.999,
  "rollingPeriod": "2592000s"
}
```

Luego creas **alertas sobre el error budget burn rate** (p. ej. "si consumes 2% del budget en 1 hora, alerta P2"). Esto evita el ruido de "cada 5xx dispara una alerta".

---

## 5. Cloud Trace y Cloud Profiler

### 5.1 Cloud Trace

Ingiere **spans** (OpenTelemetry OTLP, Zipkin, legacy Cloud Trace API). Visualiza traces distribuidos: una request HTTP a Cloud Run → RPC a Cloud SQL → llamada a Firestore, con latencia por span.

**Pricing**: 2.5M spans/mes gratis; después por millón. Un servicio Cloud Run modesto raramente excede el free tier si samplea razonablemente (1–10% típico).

### 5.2 Cloud Profiler

Profiling **continuo** de CPU, heap, allocation y wall time. Agent liviano embebido en la app (SDKs Go, Java, Python, Node, Ruby). Muestra flame graphs y permite comparar entre versiones.

Útil para encontrar la función que de repente consume el 30% del CPU tras un deploy.

---

## 6. OpenTelemetry → Cloud Trace vía Collector

El patrón recomendado **no** es que la app hable directamente a Cloud Trace. Es:

```
┌────────────┐  OTLP   ┌──────────────────┐  OTLP/gRPC   ┌─────────────┐
│  App       │────────►│  OTel Collector  │─────────────►│ Cloud Trace │
│  (OTel SDK)│         │  (sidecar o      │              └─────────────┘
└────────────┘         │   deployment)    │  OTLP        ┌─────────────┐
                       │                  │─────────────►│ Jaeger /    │
                       │  processors:     │              │ Grafana     │
                       │   batch          │              │ Tempo       │
                       │   memory_limiter │              └─────────────┘
                       │   resource       │
                       └──────────────────┘
```

Por qué el Collector en medio:

- **Vendor-agnóstico**: la app solo conoce OTLP. Mañana cambias Cloud Trace por Jaeger / Tempo / Honeycomb cambiando *una* config del Collector, sin tocar código.
- **Fan-out**: puedes exportar al mismo tiempo a Cloud Trace **y** a Jaeger local para debug.
- **Procesamiento**: `batch` (reduce RPC count), `memory_limiter` (protege contra bursts), `resource` (añade atributos como `env=prod`), `tail_sampling` (quédate con el 100% de traces lentos y el 1% del resto).
- **ADOT (AWS Distro for OpenTelemetry)** es un fork vendor-friendly del upstream OTel Collector; su binario también funciona perfectamente en GCP y en multi-cloud. En este módulo lo usamos para enfatizar que el Collector es portable.

Configuración mínima del Collector para exportar a Cloud Trace:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317

processors:
  batch:
    send_batch_size: 512
    timeout: 5s
  resource:
    attributes:
      - key: deployment.environment
        value: prod
        action: upsert

exporters:
  googlecloud:
    project: PROJECT_ID
    retry_on_failure:
      enabled: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, resource]
      exporters: [googlecloud]
```

> **Para la actividad no se ejecuta esto**; solo se razona sobre el flujo y se escribe el JSON de la alerting policy que vigila la ingesta.

---

## 7. Audit Logs: Admin Activity, Data Access, System Event, Policy Denied

GCP produce **4 categorías** de audit logs:

| Categoría | Qué registra | Default | Pricing |
|-----------|--------------|---------|---------|
| **Admin Activity** | Cambios al plano de control: `CreateInstance`, `SetIamPolicy`, `DeleteBucket`. | **Siempre on**, no desactivable. | **Gratis**. |
| **Data Access** | Lecturas y escrituras de datos: `GetObject` en GCS, `SELECT` en BigQuery, `GetSecretValue`. | **Off por defecto** (excepto BigQuery data read, que está on). | Se cobra como logs normales (puede explotar). |
| **System Event** | Acciones automáticas del sistema: migración de VM, parche de GKE. | On, no desactivable. | Gratis. |
| **Policy Denied** | Acceso denegado por VPC Service Controls u Org Policy. | On, no desactivable. | Gratis. |

### 7.1 Por qué Admin Activity son gratis y Data Access no

Admin Activity son relativamente pocos eventos (nadie crea 10 million VMs/día). Data Access en un servicio como GCS o BigQuery puede ser **millones de eventos por minuto** si lo activas sin filtrar. El pricing refleja la realidad del volumen.

### 7.2 Activar Data Access selectivamente

Se activa por **servicio** y por **categoría** (`DATA_READ`, `DATA_WRITE`, `ADMIN_READ`), y se puede excluir **principals** (p. ej. no loguear las lecturas del service account que hace health checks). Ejemplo típico: activar `DATA_WRITE` en Cloud SQL y Secret Manager, pero no `DATA_READ` en GCS buckets grandes.

### 7.3 Export a BigQuery para análisis

Patrón canónico de un `logging-sink-project` (project dedicado a recibir logs de toda la org):

```
org-wide sink:
  filter: logName:"cloudaudit.googleapis.com"
  destination: bigquery.googleapis.com/projects/log-sink/datasets/audit_logs

retención en BigQuery:
  tabla particionada por día; delete partitions > 400 días.
```

Luego el equipo de seguridad corre queries como:

```sql
SELECT
  protoPayload.authenticationInfo.principalEmail AS who,
  protoPayload.methodName AS what,
  resource.labels.project_id AS project,
  timestamp
FROM `log-sink.audit_logs.cloudaudit_googleapis_com_activity_*`
WHERE
  _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY))
                   AND FORMAT_DATE('%Y%m%d', CURRENT_DATE())
  AND protoPayload.methodName LIKE "google.iam.admin.%"
ORDER BY timestamp DESC;
```

---

## 8. Log Analytics: SQL sobre log buckets

**Log Analytics** convierte un log bucket en una tabla queryable con SQL (BigQuery engine), sin necesidad de un sink. Ventajas:

- No duplicas datos (no hay sink hacia otro project).
- Pagas por scan como BigQuery.
- Las queries pueden `JOIN` con tablas BigQuery regulares (p. ej. una tabla de "service metadata").

Para activarlo: `gcloud logging buckets update _Default --location=global --enable-analytics`. A partir de ahí, consola de Logging → "Log Analytics" → SQL editor.

Query ejemplo (errores 5xx por servicio Cloud Run, última hora):

```sql
SELECT
  resource.labels.service_name,
  COUNT(*) AS err_count
FROM `project.global._Default._AllLogs`
WHERE
  timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  AND resource.type = "cloud_run_revision"
  AND httpRequest.status >= 500
GROUP BY 1
ORDER BY err_count DESC
LIMIT 20;
```

> **Trampa**: Log Analytics y BigQuery sinks **no son lo mismo**. Log Analytics es una vista SQL sobre el log bucket; un BigQuery sink **copia** los logs a BigQuery (otro project, otro pricing, otra retention). Si quieres `JOIN` masivo o retention a 5 años, sink a BigQuery. Si quieres queries ocasionales sin duplicar, Log Analytics.

---

## 9. FinOps de logs: el error habitual

El 80% de la factura inesperada de Cloud Logging viene de **5 patrones**:

1. **Health checks noisy** en GKE / Cloud Run (readiness/liveness pegándole al bucket).
2. **Debug logs en prod** olvidados tras un incidente (alguien subió `log_level=DEBUG` y nadie lo bajó).
3. **Data Access logs activados por accidente** en GCS con tráfico alto.
4. **Un servicio con un bug** que logea un stack trace por cada request.
5. **VPC Flow Logs** sin exclusion (muy voluminoso).

Mitigación — orden sugerido:

1. **Dashboard de ingesta por `resource.type`** (Cloud Monitoring tiene métrica `logging.googleapis.com/billing/bytes_ingested`).
2. **Alerta** si ingesta diaria > X GiB (p. ej. 2× la media).
3. **Exclusion filter** para los top 3 noisy sources identificados.
4. **Retención corta** (7–14 días) en `_Default`; sink a BigQuery para lo que necesites conservar.
5. **Revisión mensual** de ingesta vs facture (Billing export a BigQuery, dashboard de "cost by SKU").

---

## 10. SLI, SLO, error budget: el modelo de alerting moderno

**SLI** (Service Level Indicator): una métrica medible (p. ej. "porcentaje de requests con status < 500").

**SLO** (Service Level Objective): el valor objetivo (p. ej. "99.9% en 30 días").

**Error budget**: `1 - SLO` del tiempo. Para 99.9% en 30 días, el budget es 43m de downtime (0.1%).

**Burn rate alerts**: en vez de alertar por cada 5xx, alertas por **tasa a la que consumes el budget**:

- **Fast burn**: consumir 2% del budget en 1 hora → P1 (algo serio ahora).
- **Slow burn**: consumir 10% en 3 días → P2 (degradación progresiva).

Esto reduce el ruido de alertas enormemente y alinea con lo que importa: **el usuario**, no la métrica aislada.

En Cloud Monitoring, los SLOs se crean sobre **services** (que es un objeto Monitoring, no un `gcloud run services`). Un *service* puede ser:

- Automático: Cloud Run / GKE / App Engine ya son services detectados.
- Custom: definido por filtros sobre métricas.

Después del SLO defines **burn rate alerts** sobre él.

---

## 11. Fundamentos internos (lo que suele doler en producción)

1. **Admin Activity gratis es garantía estructural, no favor comercial.** La compliance de GCP depende de que esos logs existan siempre. Por eso no se desactivan ni se pueden filtrar en origen.
2. **Un sink `_Default` → BigQuery con filtro mal escrito puede duplicar coste.** El sink **copia**; no "mueve". Si el filtro es `""` (todo), vas a pagar logs *más* ingesta a BigQuery.
3. **Las log-based metrics custom cuentan como custom metrics.** Hay una quota (actualmente ~500 custom metric descriptors por project). Si creas 50 log-based metrics por servicio × 10 servicios, te quedas sin cuota en algo que creías "gratis".
4. **Las alertas sin SLO disparan ruido.** Un dashboard con 20 alertas de latencia por endpoint, sin SLO que las englobe, acaba silenciado por el oncaller. SLO + burn rate es el patrón que escala.
5. **El OTel Collector es el punto de desacoplo real.** La app no debería hablar directo con Cloud Trace, aunque sea el camino más corto. El día que la empresa decide "ahora todo va a Datadog", el cambio es un commit en el Collector; sin Collector es un refactor de todas las apps.
6. **Data Access logs en BigQuery `DATA_READ` son el patrón más caro observado**. Si activas `DATA_READ` para BigQuery en un data warehouse grande, puedes ver >100 GiB/día de logs solo de "quién hizo qué SELECT". Decisión consciente, no por defecto.

---

## 12. Alternativas y qué llevarse

### Alternativas al stack "Cloud Operations + Audit Logs"

- **Grafana + Loki + Prometheus + Tempo (self-hosted en GKE)**: control total, costo potencialmente menor a escala muy grande, pero overhead operativo real (upgrades, SLOs del propio stack de observabilidad).
- **Datadog / New Relic / Honeycomb vía OTel**: UX superior en search y en exemplars, pricing agresivo. Patrón: Collector exporta a Cloud Trace *y* al vendor en paralelo durante la migración.
- **Elasticsearch / OpenSearch**: para search avanzado en logs; en GCP se suele comprar como SaaS (Elastic Cloud en GCP marketplace).

### Qué llevarse en una frase

> Cloud Operations te da logs, métricas, traces y auditoría **baseline** casi gratis en GCP. **Admin Activity** siempre, gratis, inmutable. **Data Access** opt-in — selectivo, siempre con filtro y presupuesto. Instrumenta con **OpenTelemetry → Collector**: nunca directo al vendor. **SLOs + burn rate alerts** sustituyen al zoo de alertas por métrica. **Log sinks + exclusiones** son tu control principal de costo. Decide retención por bucket, no "para todos los logs".

### Qué sigue

- `gcp-09` — Organization/Folders/Projects y Cloud Identity; aquí es donde el **log sink org-wide** se vuelve ciudadano de primera.
- `gcp-10` — DevSecOps + FinOps: Billing export a BigQuery, dashboards de costo, Binary Authorization. La telemetría de este módulo alimenta esos dashboards.
