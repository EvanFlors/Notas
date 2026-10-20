# aws-12 — Lección: Observabilidad nativa en AWS (CloudWatch, X-Ray, CloudTrail) y su convivencia con OTel

> 10 secciones. Prerrequisitos: `aws-04`, `aws-10`, y haber visto al menos `opentelemetry-01`.

---

## 1. Las tres superficies de observabilidad en AWS

AWS no entrega una única plataforma de observabilidad: entrega **tres servicios distintos** que a menudo se confunden:

1. **CloudWatch** — logs, metrics, alarms, dashboards. Operacional: *"¿qué está pasando en mi app ahora?"*.
2. **X-Ray** — trazas distribuidas. Debugging: *"¿por qué ESTE request tardó 2 s?"*.
3. **CloudTrail** — auditoría de llamadas a la API de AWS. Seguridad y compliance: *"¿quién borró este bucket?"*.

Son **ortogonales**. CloudWatch no sabe quién llamó a `s3:DeleteBucket`; CloudTrail no sabe cuánta CPU consume tu Lambda; X-Ray no reemplaza las métricas agregadas. En producción, **los tres están siempre activos**.

> **Punto clave:** CloudTrail nunca se "apaga por coste". Los **management events** son gratis (o casi) y son el único registro de qué pasó en tu cuenta.

---

## 2. CloudWatch Logs: el modelo que paga por byte

La unidad primitiva es el **log event**: un timestamp + un string de hasta 256 KiB. Los eventos viven en **log streams** y los streams se agrupan en **log groups**. La retención es por **log group** (de 1 día a `never-expire`).

El modelo de precios tiene **tres componentes**:

1. **Ingestión** (`USD/GB` por byte ingresado). El componente dominante.
2. **Storage** (`USD/GB-mes`). Pequeño comparado con ingestión pero crece con retención larga.
3. **Logs Insights queries** (`USD/GB escaneado`). Barato por query, caro si corres queries sobre meses de datos.

**Consecuencia práctica:** la decisión de observabilidad en AWS **empieza por la retención** y por **qué filtras antes de enviar**. Enviar `DEBUG` de todo a CloudWatch durante 30 días es, literalmente, encender dinero.

### Patrón de retención por tier

| Tier | Retention | Ejemplos |
|------|-----------|----------|
| Hot (debug corto) | **7 días** | `/aws/lambda/<fn>` con DEBUG en dev, access logs ALB en staging |
| Warm (ops normal) | **30 días** | logs de aplicación en prod a nivel INFO, API Gateway access logs |
| Cold (compliance) | **90–400 días** | CloudTrail management, VPC flow logs sampled, audit logs |
| Nunca expira | `0` (never) | muy raramente justificado; preferible exportar a S3 con lifecycle |

---

## 3. Metric filters: convertir texto en métrica sin reinstrumentar

Un **metric filter** parsea cada log event entrante contra un **pattern** y, si matchea, **publica una métrica** CloudWatch. Permite derivar métricas de código **que no instrumentaste** sin tocar el binario.

Ejemplo mental: tu app imprime `ERROR status=5xx latency=1234ms`. Un filter con pattern `[level=ERROR, status=5xx, ...]` incrementa un contador `App/5xxCount` por cada match.

**Trade-offs:**

- Es **más barato que PutMetricData** desde la app si ya pagas por el log event.
- La **cardinalidad** la define el filter (dimensions), no la app — útil para controlarla.
- No sustituye instrumentación nativa: si solo te importa la métrica, loguear + filter es un atajo caro vs un contador OTel.

---

## 4. CloudWatch Logs Insights: queries ad-hoc caras

Logs Insights es un **lenguaje de query** (pipe-syntax, un poco como Splunk) sobre logs ya ingresados. Útil para investigar, no para dashboards de alta frecuencia.

```
fields @timestamp, @message
| filter level = "ERROR"
| stats count() by bin(5m)
| sort @timestamp desc
| limit 100
```

Coste: `~0.005 USD/GB escaneado`. Suena poco hasta que haces una query sobre 90 días × 500 GB/día = 45 TB → 225 USD por una sola query. Por eso **Logs Insights no sustituye a Loki/ELK** cuando el volumen es alto: la economía rompe.

---

## 5. CloudWatch Alarms: static, anomaly, composite

Una **alarma** evalúa una métrica contra una condición durante N datapoints en un periodo. Tres tipos:

1. **Static threshold.** `Errors > 5 for 2 of 3 datapoints over 5 minutes`. El 90 % de las alarmas útiles.
2. **Anomaly detection.** AWS entrena un modelo sobre la métrica y alarma si se sale de la banda. Útil para métricas con estacionalidad (ventas, logins).
3. **Composite alarm.** Combina alarmas existentes con lógica booleana (`ALARM(a) AND ALARM(b)`). **Reduce ruido**: solo alarma si *varias* señales concuerdan.

### Dos parámetros infravalorados

- `datapoints_to_alarm` **vs** `evaluation_periods`. Permite "2 de 3" para evitar flaps.
- `treat_missing_data`. Si tu app no emite por un bug, `missing` por default es `missing` (no alarma). En SLOs críticos puede ser preferible `breaching` para notar el apagón.

---

## 6. EMF: la forma barata de métricas custom

**Embedded Metric Format** permite escribir métricas **dentro de un log event JSON** con una sección `_aws.CloudWatchMetrics`. CloudWatch Logs extrae esas métricas automáticamente al ingerir.

```json
{
  "_aws": {
    "Timestamp": 1700000000000,
    "CloudWatchMetrics": [{
      "Namespace": "App/Checkout",
      "Dimensions": [["Service"]],
      "Metrics": [{"Name": "OrdersPlaced", "Unit": "Count"}]
    }]
  },
  "Service": "checkout",
  "OrdersPlaced": 1
}
```

Ventaja vs `PutMetricData`:

- **1 llamada log** vs **1 llamada métrica**: en Lambda ahorra latencia y coste de API.
- Las métricas se correlacionan con el log del que salieron.
- Librerías: `aws-embedded-metrics` para Python/Node/Java.

Es la vía recomendada en Lambda y en workloads con muchas métricas custom de baja cardinalidad.

---

## 7. X-Ray y su relación con OpenTelemetry

X-Ray es el **tracer propietario** de AWS. Modelo: **segments** (lo que hace un servicio) y **subsegments** (sub-operaciones: una query DB, una llamada HTTP). Sampling por **rules** (por defecto 1 req/s + 5 %).

El dilema histórico: si ya instrumentaste con **OpenTelemetry**, no quieres duplicar código con el SDK de X-Ray. Solución: **ADOT Collector** acepta OTLP, mapea el modelo OTel al modelo X-Ray y usa el **exporter `awsxray`**. Resultado: tu código habla OTel estándar; AWS ve "trazas X-Ray" sin saber de la diferencia.

### Diagrama ADOT en EKS

```
   FastAPI pod ─── OTel SDK ─── OTLP ──► ADOT Collector (DaemonSet) ──┬──► awsxray      ──► X-Ray
                                                                       ├──► awsemf       ──► CloudWatch Metrics (via Logs)
                                                                       ├──► awscloudwatchlogs ──► CloudWatch Logs
                                                                       └──► prometheusremotewrite ──► Prometheus/Mimir
```

Un único pipeline en el código, N exporters en el Collector. Dual-write a CloudWatch *y* a Prometheus durante una migración es trivial.

---

## 8. CloudWatch Agent vs ADOT Collector: cuándo cada uno

| Dimensión | **CloudWatch Agent** | **ADOT Collector** |
|-----------|----------------------|---------------------|
| Origen | Propietario AWS | Distro de **OTel Collector contrib** |
| Protocolos de entrada | StatsD, collectd, logs de archivo, procstat | **OTLP** (gRPC/HTTP), prometheus scrape, filelog, Jaeger, Zipkin |
| Destinos | CloudWatch (logs + metrics) | CloudWatch, X-Ray, Prometheus RW, cualquier backend OTel |
| Config | JSON propio AWS | YAML OTel estándar |
| Soporte | Solo AWS | Comunidad OTel + AWS |

**Regla:** CloudWatch Agent para servidores legacy sin OTel (métricas de SO, procesos). **ADOT** para todo lo nuevo (apps instrumentadas con OTel, apps que deben escribir también a Prometheus).

---

## 9. CloudTrail: por qué siempre debe estar on

CloudTrail registra **cada llamada a la API de AWS**: quién, cuándo, desde qué IP, con qué parámetros, con qué resultado. Tres tipos de evento:

1. **Management events** (gratis, uno habilitado por default): `RunInstances`, `CreateBucket`, `AssumeRole`, etc.
2. **Data events** (coste real): acceso a datos — `s3:GetObject`, `lambda:Invoke`, `dynamodb:GetItem`. Por volumen pueden ser caros; se habilitan selectivamente (p. ej. solo bucket con PII).
3. **Insights events** (modelo ML sobre management events): detecta anomalías de API — una explosión de `AssumeRole` denegados, por ejemplo.

### Organization trail

En multi-cuenta: un único **organization trail** desde la cuenta `management` (o `audit`) captura eventos de **todas** las cuentas miembro a un bucket central con **encriptación KMS** y **log file validation**. Es el pilar de auditoría del `aws-15-multi-account` y de cualquier framework de compliance (SOC 2, ISO 27001).

### Estructura típica de un evento

```json
{
  "eventVersion": "1.09",
  "eventTime": "2026-10-16T12:00:00Z",
  "eventSource": "s3.amazonaws.com",
  "eventName": "DeleteBucket",
  "awsRegion": "us-east-1",
  "sourceIPAddress": "203.0.113.42",
  "userIdentity": {
    "type": "AssumedRole",
    "principalId": "AROAEXAMPLE:session",
    "arn": "arn:aws:sts::123456789012:assumed-role/Admin/session"
  },
  "requestParameters": {"bucketName": "legacy-bucket"},
  "responseElements": null,
  "readOnly": false,
  "managementEvent": true
}
```

---

## 10. Costes: resumen operativo

| Servicio | Driver principal de coste | Palanca que importa |
|----------|---------------------------|---------------------|
| CloudWatch Logs | Ingestión (USD/GB) | Filtrar antes de enviar; retención por tier |
| CloudWatch Metrics | Custom metrics (dimensiones) | Controlar cardinalidad; usar EMF |
| CloudWatch Alarms | Nº alarmas | Composite alarms reducen cuenta |
| Logs Insights | GB escaneados por query | Scope temporal y campos; no reutilizar como dashboard |
| X-Ray | Trazas retenidas | Sampling rules agresivas (1 req/s + 5 %) |
| CloudTrail | Management: ~0; Data: USD/evento | Habilitar data events solo donde importa |

> **Idea para repetir:** la economía de la observabilidad en AWS se decide **antes** de que el byte llegue a CloudWatch. Instrumenta con OTel, filtra en el Collector (ADOT), y usa CloudWatch como un backend más — no como el único destino.
