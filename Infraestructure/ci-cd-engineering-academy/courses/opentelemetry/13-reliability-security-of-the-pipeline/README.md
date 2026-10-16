# otel-13 — Confiabilidad y seguridad del pipeline

## Identificación

- **ID:** `otel-13-reliability-security-of-the-pipeline`
- **Curso:** `opentelemetry`
- **Nivel:** producción
- **Duración estimada:** 4 h
- **Prerrequisitos:** `otel-09-collector-deployment-patterns-agent-vs-gateway`, `otel-10-sampling-head-tail-probabilistic-parent-based`.

## Objetivo

Operar el pipeline OTel con garantías de **confiabilidad** (nada se pierde silenciosamente ante caídas, spikes o backpressure del backend) y **seguridad** (transporte cifrado, autenticación mutua donde toca, PII scrubbed antes de salir del Collector, multi-tenant respetado). Al terminar debes poder tomar un Collector "funcionando" y endurecerlo hasta que resista una auditoría: TLS end-to-end, auth entre hops, memory_limiter y batch dimensionados, cola persistente en disco, retries con backoff, alertas sobre sí mismo, procesos de upgrade seguros, y pipelines de scrubbing/redacción documentados.

## Alcance

Este módulo cubre:

- **TLS** entre SDK/agent, agent/gateway, gateway/backend; certificados server-side y client-side (**mTLS**).
- **Autenticación**: `Bearer` headers, mTLS, OIDC (con `oauth2clientauthextension`), rotación de credenciales.
- **Tenancy multi-tenant**: `X-Scope-OrgID` para Mimir/Loki; routing por tenant con el `routing` processor.
- **Backpressure**: `memory_limiter` (soft/hard limit), `batch` (size/timeout), `sending_queue` persistente en disco (`file_storage` extension).
- **Retries** con backoff exponencial; qué errores son retriables.
- **Self-observability**: métricas `otelcol_*` (queue size, dropped spans/metrics/logs, exporter failures); alertas Prometheus sobre el propio Collector.
- **Versioning** del Collector y **upgrade seguro** (compatibilidad de config, deprecations, blue/green de gateway).
- **PII scrubbing** con `attributes` processor (`delete`, `hash`) o OTTL (`transform`) para reglas más expresivas.
- **Redacción** de headers y query params con el `redaction` processor.
- Límites a **baggage** y a atributos (tamaño, cardinalidad).
- **Chaos testing** del pipeline con `toxiproxy` o `tc` (latencia, cortes, drops).
- **Costos del transporte**: compression `gzip` vs `zstd` en OTLP, cardinalidad en labels.

Lo que **no** cubre (lo verás en el siguiente):

- Governance de semconv, cost-control cross-signal y vendor-neutral strategy → `otel-14`.
- Operator CRs para Collector en K8s → `otel-12` (si no lo tomaste, aquí asumimos compose).
- Policy enforcement (OPA/Kyverno) sobre configs del Collector → curso DevSecOps.

## Materiales

- **`theory/lesson.md`** — lección profunda, 12 secciones. Lee entera antes de los ejemplos.
- **`examples/`** — tres ejemplos reproducibles con `docker compose`:
  - `01-tls-and-mtls/` — Collector gateway con TLS server-side, luego mTLS cliente. Genera certs self-signed con OpenSSL; demuestra `tls.insecure=false` tanto en receptor como en exporter.
  - `02-persistent-queue-backpressure/` — `memory_limiter` + `batch` + `sending_queue` persistente en disco (`file_storage`). Simula backend caído, reinicia el Collector y verifica que la cola sobrevive.
  - `03-pii-scrubbing-ottl/` — `attributes` processor con `hash`/`delete`, `redaction` processor para headers, y OTTL `transform` para reglas por regex. Entrada controlada con `telemetrygen`, exporter `debug` muestra el output limpio.
- **`activities/`** — dos actividades:
  - `01-harden-collector/` — **guided-lab**. Partes de un Collector `insecure: true` sin colas ni scrubbing; endurecerlo con TLS, Bearer auth, memory_limiter, sending_queue persistente, PII scrubbing. El validador inspecciona la config final y confirma los siete controles.
  - `02-define-pipeline-slo/` — **independent**. Diseñar los SLOs del Collector como sistema (uptime, latencia extremo-a-extremo, drop rate aceptable), elegir SLIs y las métricas `otelcol_*` que los miden, y escribir alertas Prometheus que disparan el error budget. Entregable: `SLO.md` con tabla + reglas Prometheus. El validador comprueba estructura y presencia de secciones requeridas.
- **`resources/links.md`** — docs oficiales de Collector, procesadores de seguridad, OTTL, Mimir multi-tenant, OpenSSL.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué `memory_limiter` *debe* ir primero en la pipeline y por qué `batch` *después* de él. Diferenciar entre `sending_queue` en memoria y persistente en disco. Explicar la diferencia entre `insecure: true` en receiver vs en exporter. Justificar `hash` sobre `delete` en PII (observabilidad vs cumplimiento). |
| Operativa | Generar certs self-signed con OpenSSL y configurar mTLS en receiver y exporter. Configurar `file_storage` extension y verificar que la cola sobrevive un restart. Escribir reglas OTTL para scrubbing. Interpretar `otelcol_exporter_queue_size` y `otelcol_processor_refused_spans` para diagnosticar backpressure. |
| Arquitectónica | Diseñar la matriz "hop × mecanismo de confianza" (SDK→agent, agent→gateway, gateway→backend). Definir SLOs del propio Collector y las alertas que los operacionalizan. Planificar un upgrade seguro del gateway sin perder spans en vuelo. |

## Criterios de evaluación

- Pipeline del Ejemplo 01 arrancando con mTLS; `curl -k` falla, `curl` con certs cliente OK.
- Ejemplo 02: el backend se detiene por 2 minutos; el Collector se reinicia; al volver el backend, los datos acumulados en disco se entregan sin pérdida.
- Ejemplo 03: `telemetrygen` produce spans con `http.request.header.authorization` y `user.email`; el exporter `debug` muestra esos campos redactados/hasheados.
- Actividad 01: `tests/validate.sh` verifica siete controles sobre la config final.
- Actividad 02: `SLO.md` tiene las secciones requeridas (SLIs, SLOs, error budget, alertas, playbook) y las reglas Prometheus referencian métricas `otelcol_*` reales.

## Secuencia recomendada

1. Lee `theory/lesson.md` entera (~1 h 20 min).
2. Reproduce `examples/01-tls-and-mtls/` (requiere `openssl`; si no lo tienes, el bootstrap imprime `SKIP` y continúa).
3. Reproduce `examples/02-persistent-queue-backpressure/`.
4. Reproduce `examples/03-pii-scrubbing-ottl/`.
5. Actividad 01 en modo guiado; usa la lección como referencia.
6. Actividad 02 sin consultar más que `resources/links.md` — es la que valida comprensión arquitectónica.

## Siguiente

→ `otel-14-platform-patterns-vendor-neutral-cost-and-semconv-governance`: cómo el pipeline endurecido es la base para el contrato vendor-neutral de la plataforma.

## Notas sobre entorno

- Requiere **docker + docker compose** y **openssl** (para los certs del Ejemplo 01 y la Actividad 01). Si falta `openssl`, los scripts imprimen `SKIP` con instrucciones.
- Imagen del Collector usada: `otel/opentelemetry-collector-contrib:0.110.0` (fija la versión; ver §9 de la lección sobre upgrade). Si no está disponible localmente, docker la bajará (~200 MB).
- Todos los artefactos de ejecución viven en `/tmp/otel13-*/` para no ensuciar el repo. Cada ejemplo y actividad incluye su `clean.sh`.
- **No se usan secretos reales**: todas las credenciales son placeholders inofensivos (`dev-bearer-token-not-a-secret`).
