# REFERENCE — aws-12-01-instrument-fastapi-with-adot

> Una **referencia** razonada. No es la única respuesta correcta.

## config.yaml

Ver `./config.yaml` en este directorio. Puntos clave:

- **OTLP gRPC + HTTP** ambos activos: coste cero y da flexibilidad al cliente.
- **`memory_limiter` antes de `batch`** en la cadena de processors: si falta memoria, se dropean batches en vez de OOM-ear el pod.
- **Pipeline `metrics` con 2 exporters** (`awsemf` + `prometheusremotewrite`) — ésta es la decisión de diseño clave: dual-write.
- **`resource_to_telemetry_conversion: true`** en `awsemf` para que los atributos del Resource se conviertan en dimensions de la métrica EMF.

## NOTES.md modelo

1. **DaemonSet, no Deployment.** Un pod por nodo permite que las apps envíen a `localhost:4317`, añade atributos de nodo automáticamente y el blast-radius de un fallo es un solo nodo (vs un Deployment central que es SPoF).
2. **Dual-write facilita migraciones.** Dashboards nuevos se construyen contra Prometheus mientras los existentes en CloudWatch siguen vivos. Cuando todos los dashboards estén migrados, se retira el exporter `awsemf` sin tocar la aplicación.
3. **Sin `memory_limiter` el Collector OOM-ea.** Un pico de traces (p. ej. tras un deploy con bug) satura la cola interna y Kubernetes mata el pod. El `memory_limiter` dropea batches primero y mantiene el proceso vivo (perder algo de telemetría es preferible a perderla toda).
4. **Autenticación: IRSA / Pod Identity.** El ServiceAccount del DaemonSet tiene un rol IAM asociado. El Collector obtiene credenciales temporales vía el **IMDS** o el **webhook de IRSA** — sin access keys estáticas en el YAML ni en Secrets.
5. **IAM mínima.** Al menos: `xray:PutTraceSegments`, `xray:PutTelemetryRecords`, `logs:CreateLogStream`, `logs:PutLogEvents`, `cloudwatch:PutMetricData`. Idealmente scope por log group ARN y por región, nunca `*`.

## Variantes aceptables

- `batch.timeout` entre `3s` y `30s` según volumen (menor timeout = menos latencia, más llamadas AWS).
- `prometheusremotewrite.endpoint` con auth sigv4 (si Prometheus está detrás de un APIGW AWS) o `basic_auth` extension.
- Añadir `processor.resource` para inyectar `deployment.environment` es recomendado pero no imprescindible.
- `log_stream_name` por host usando `{HostName}` placeholder.

## Antipatrones

- Poner **access keys** en el YAML (nunca).
- Omitir `memory_limiter`.
- Un único pipeline mezclando traces + metrics + logs (los pipelines son por signal, no por fuente).
- Enviar `awsemf` y `awscloudwatchlogs` al **mismo log group** — chocan y los metric filters se duplican.
