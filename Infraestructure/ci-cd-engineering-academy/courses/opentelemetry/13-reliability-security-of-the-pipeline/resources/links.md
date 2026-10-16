# Recursos — `otel-13-reliability-security-of-the-pipeline`

> Verifica fecha de consulta. El Collector mueve rápido; nombres de processors/extensiones cambian ocasionalmente.

## Documentación oficial del Collector

- **OpenTelemetry Collector** — overview. <https://opentelemetry.io/docs/collector/>
- **Configuration** — modelo YAML, pipelines, extensions. <https://opentelemetry.io/docs/collector/configuration/>
- **Deployment patterns** (agent / gateway / sidecar). <https://opentelemetry.io/docs/collector/deployment/>
- **CHANGELOG del contrib** — leer antes de upgrade. <https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/CHANGELOG.md>

## Seguridad y auth

- **TLS configuration** — `configtls` del Collector. <https://github.com/open-telemetry/opentelemetry-collector/tree/main/config/configtls>
- **bearertokenauth extension**. <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/extension/bearertokenauthextension>
- **oauth2clientauth extension**. <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/extension/oauth2clientauthextension>
- **basicauth extension**. <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/extension/basicauthextension>

## Reliability

- **memory_limiter processor**. <https://github.com/open-telemetry/opentelemetry-collector/tree/main/processor/memorylimiterprocessor>
- **batch processor**. <https://github.com/open-telemetry/opentelemetry-collector/tree/main/processor/batchprocessor>
- **file_storage extension** (persistent queue). <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/extension/storage/filestorage>
- **Exporter helper (sending_queue + retry_on_failure)**. <https://github.com/open-telemetry/opentelemetry-collector/tree/main/exporter/exporterhelper>

## Multi-tenancy y routing

- **routing processor**. <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/routingprocessor>
- **Grafana Mimir: multi-tenancy** (`X-Scope-OrgID`). <https://grafana.com/docs/mimir/latest/references/architecture/components/multi-tenancy/>
- **Grafana Loki: multi-tenancy**. <https://grafana.com/docs/loki/latest/operations/multi-tenancy/>

## PII, redaction, OTTL

- **attributes processor**. <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/attributesprocessor>
- **redaction processor**. <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/redactionprocessor>
- **transform processor + OTTL**. <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/transformprocessor>
- **OTTL spec and functions**. <https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/pkg/ottl/README.md>

## Self-observability y SLOs

- **Internal telemetry del Collector**. <https://opentelemetry.io/docs/collector/internal-telemetry/>
- **Google SRE Workbook — SLOs cap. 2**. <https://sre.google/workbook/implementing-slos/>
- **Multi-window multi-burn-rate alerts (Google SRE)**. <https://sre.google/workbook/alerting-on-slos/>

## Chaos y testing

- **toxiproxy** — latency/drop/slice injection TCP. <https://github.com/Shopify/toxiproxy>
- **telemetrygen** — load generator incluido en contrib. <https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/cmd/telemetrygen>
- **tc / netem** — Linux traffic control para chaos de red. <https://man7.org/linux/man-pages/man8/tc-netem.8.html>

## Operación: versioning y upgrade

- **Release cadence** del Collector (mensual). <https://github.com/open-telemetry/opentelemetry-collector/blob/main/docs/release.md>
- **Deprecation policy**. <https://github.com/open-telemetry/opentelemetry-collector/blob/main/docs/deprecation.md>

## Costos y compresión

- **OTLP compression** (gzip/zstd/snappy). <https://opentelemetry.io/docs/specs/otlp/#compression>
- **High-cardinality in Prometheus** — por qué duele. <https://prometheus.io/docs/practices/naming/>

## PKI self-signed con OpenSSL

- **OpenSSL cookbook** (Ivan Ristic — gratis). <https://www.feistyduck.com/library/openssl-cookbook/>
