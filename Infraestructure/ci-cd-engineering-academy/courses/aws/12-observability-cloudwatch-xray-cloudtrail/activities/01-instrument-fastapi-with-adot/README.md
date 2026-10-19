# Actividad 01 — Instrumentar FastAPI con ADOT (config.yaml multi-exporter)

## 1. Identificación

- **ID:** `aws-12-01-instrument-fastapi-with-adot`
- **Tecnología:** `aws`
- **Módulo:** `aws-12-observability-cloudwatch-xray-cloudtrail`
- **Dificultad:** advanced
- **Duración estimada:** 60–75 min
- **Tipo:** guided-lab (independiente de la actividad 02)

## 2. Contexto

Tu equipo tiene una app **FastAPI** instrumentada con OpenTelemetry. Está en EKS y necesita publicar:

- **Trazas** a **X-Ray** (el equipo de SRE central las consume).
- **Métricas** a **CloudWatch (EMF)** *y* a **Prometheus** (dashboards Grafana corporativos).
- **Logs** a **CloudWatch Logs** (retention policy de ops).

En vez de tocar código, el patrón AWS-nativo es **ADOT Collector**: una distro del OTel Collector contrib con los exporters `awsxray`, `awsemf` y `awscloudwatchlogs` incluidos. Tu entregable es la configuración (`config.yaml`) que materializa ese pipeline, más una justificación en `NOTES.md`.

Esta actividad **no despliega nada en AWS**. La validación es estructural y, si tienes **Docker + LocalStack** instalados, hace un smoke opcional contra CloudWatch Logs de LocalStack.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la documentación**:

- Escribir un `config.yaml` con `receivers.otlp` (gRPC+HTTP), `processors.batch` y `processors.memory_limiter`.
- Definir **tres pipelines** separados en `service.pipelines` (traces/metrics/logs).
- Elegir el exporter correcto por signal (`awsxray` para traces, `awsemf` para métricas que van a CloudWatch, `prometheusremotewrite` para métricas a Prometheus, `awscloudwatchlogs` para logs).
- Justificar en 5 bullets por qué el dual-write a CloudWatch + Prometheus facilita migraciones.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (en particular §7 y §8).
- Haber recorrido `../../examples/02-adot-collector-eks/`.
- Herramientas: `bash`, un editor YAML/Markdown. **Opcional**: `docker` + `localstack` para el smoke.

**Costos:** cero. El smoke opcional usa LocalStack free tier (CloudWatch Logs básico).

## 5. Instrucciones

### 5.1 Preparar directorio

```bash
mkdir -p /tmp/aws-12-adot
cd /tmp/aws-12-adot
```

### 5.2 Escribe `config.yaml`

Partiendo de `starter/config.yaml` (plantilla con TODOs), completa:

- `receivers.otlp.protocols.grpc.endpoint: 0.0.0.0:4317`
- `receivers.otlp.protocols.http.endpoint: 0.0.0.0:4318`
- `processors.batch` con `timeout` y `send_batch_size`.
- `processors.memory_limiter` con `limit_mib` razonable.
- `exporters`: al menos `awsxray`, `awsemf`, `awscloudwatchlogs` y `prometheusremotewrite`.
- `service.pipelines.traces` → `[awsxray]`.
- `service.pipelines.metrics` → `[awsemf, prometheusremotewrite]`.
- `service.pipelines.logs` → `[awscloudwatchlogs]`.
- Todos los pipelines llevan `[memory_limiter, batch]` como processors mínimos.

Copia el archivo final a `/tmp/aws-12-adot/config.yaml`.

### 5.3 Escribe `NOTES.md`

Un documento Markdown con **al menos 5 bullets numerados** (`1.`…`5.`) explicando:

1. Por qué un **DaemonSet** y no un **Deployment** en EKS.
2. Qué ventaja da **dual-write** (CloudWatch + Prometheus) durante una migración de dashboards.
3. Qué pasa si **omito `memory_limiter`** y hay un pico de traces.
4. Cómo se autentica el Collector contra AWS (**IRSA / Pod Identity**, **sin keys**).
5. Qué **política IAM mínima** necesita (al menos 4 acciones nombradas).

Guarda como `/tmp/aws-12-adot/NOTES.md`.

### 5.4 Valida

```bash
bash tests/validate.sh /tmp/aws-12-adot
```

El validador comprueba:

- `config.yaml` existe y es YAML parseable (Python).
- Contiene los receivers, processors, exporters y pipelines requeridos.
- `NOTES.md` existe con al menos 5 bullets numerados y menciona IRSA/Pod Identity.
- (Opcional, si Docker + LocalStack están disponibles) crea un log group en LocalStack para demostrar conectividad; si no, hace **SKIP** con mensaje claro.

## 6. Resultado esperado

- `config.yaml` válido YAML, pasa los greps estructurales.
- `NOTES.md` con 5 bullets justificando decisiones.
- Validador en verde (incluyendo el SKIP del smoke si no hay LocalStack).

## 7. Criterios de aceptación

- **Funcionalidad:** validador estructural pasa.
- **Calidad:** cada exporter está en el pipeline **correcto** por signal.
- **Reproducibilidad:** otra persona puede tomar tu `config.yaml` y entender a dónde va cada signal.
- **Seguridad:** `config.yaml` **no** contiene access keys ni secrets ni account IDs reales.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-12-adot
```

## 9. Preguntas de reflexión

1. ¿Por qué `awsemf` escribe métricas como **logs** en vez de llamar directamente a `PutMetricData`?
2. ¿Qué cambia si en vez de `prometheusremotewrite` usas el exporter `otlp` apuntando a un gateway Prometheus con OTLP ingest nativo?
3. Si un pod del Collector OOM-ea, ¿qué telemetría se pierde? ¿Cómo lo mitigas?
4. ¿Cuándo tiene sentido añadir un **gateway** central Collector delante del DaemonSet?
5. ¿Qué diferencia práctica hay entre `batch.timeout: 5s` y `batch.timeout: 30s` a nivel de **coste CloudWatch**?

## 10. Extensiones

- Añade un exporter secundario `otlp/tempo` para traces (dual-write X-Ray + Tempo).
- Añade un `receiver.prometheus` para scrapear los `/metrics` de los exporters externos y reenviarlos.
- Añade un `processor.attributes` que inyecte `deployment.environment` desde una env var.

## 11. Limpieza

```bash
rm -rf /tmp/aws-12-adot
# Si usaste el smoke con LocalStack:
docker rm -f localstack-aws12 2>/dev/null || true
```

El validador también limpia su propio contenedor al terminar.
