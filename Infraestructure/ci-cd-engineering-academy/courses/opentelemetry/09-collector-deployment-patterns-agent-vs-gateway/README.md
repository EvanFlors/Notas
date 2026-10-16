# otel-09 — Collector deployment patterns: agent vs gateway

## Identificación

- **ID:** `otel-09-collector-deployment-patterns-agent-vs-gateway`
- **Curso:** `opentelemetry`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `otel-08-collector-architecture-receivers-processors-exporters`.

## Objetivo

Diseñar la **topología de despliegue** del OpenTelemetry Collector en producción. Al terminar debes poder dibujar, justificar y desplegar un pipeline que use el patrón **agent + gateway**, decidir cuándo añadir un sidecar o prescindir del Collector, dimensionar el gateway bajo carga variable y proteger la ingesta ante caídas de red con **queue persistence** en disco.

## Alcance

Este módulo cubre:

- **Cuatro patrones** de despliegue del Collector:
  - `agent` por nodo (DaemonSet en K8s): recibe local, enriquece con metadata del nodo/pod, envía a gateway.
  - `gateway` centralizado (Deployment + Service): batch grande, compresión, retry, sampling tail-based, único punto de salida al backend.
  - `sidecar` por pod: raro, útil para apps que no pueden hablar OTLP al host.
  - **Sin Collector** (SDK → backend directo): sencillo, acoplado al backend.
- **Escalado horizontal** del gateway con HPA (CPU, memoria y queue depth) y por qué el agent escala *verticalmente* con el nodo.
- **Back-pressure** y `sending_queue` con `storage` en disco (file_storage extension).
- **Health check extension** (`health_check`) y probes de K8s.
- **Versión y upgrades**: contrato de compatibilidad entre Collector y SDK; estrategia de upgrade por capas (gateway primero, agent después, o viceversa).
- **Distros** del Collector: `otelcol` (Core), `otelcol-contrib`, `ADOT` (AWS), `Grafana Alloy` (fork con lineage de OTel Collector + Prometheus Agent + Promtail).

Lo que **no** cubre (siguientes módulos):

- Políticas de **sampling** en el gateway → `otel-10`.
- Elección y configuración de backends concretos (Tempo, Jaeger, Loki) → `otel-11`.
- **OTel Operator** y CRs `OpenTelemetryCollector` / `Instrumentation` → `otel-12`.

## Materiales

- **`theory/lesson.md`** — 12 secciones. Léela antes de los ejemplos.
- **`examples/`**:
  - `01-daemonset-agent-plus-deployment-gateway/` — manifiestos kind + DaemonSet agent + Deployment gateway + Service; el agent envía al gateway por nombre DNS.
  - `02-queue-persistence-disk/` — Collector con `file_storage` extension y `sending_queue.storage: file_storage` para sobrevivir caídas de backend.
  - `03-adot-vs-otel-contrib/` — tabla comparativa + ConfigMap de ejemplo con distros, cuándo elegir cada uno.
- **`activities/`**:
  - `01-deploy-agent-gateway-in-kind/` — **guided-lab**. Despliega cluster kind, aplica agent (DaemonSet) + gateway (Deployment), genera telemetría de prueba y comprueba que el gateway la recibió. Validador automático.
  - `02-tradeoffs-adr/` — **independent**. Escribe un ADR (Architecture Decision Record) que justifica la topología para tres escalas (10 / 1k / 100k RPS). Validador comprueba estructura y presencia de secciones obligatorias.
- **`resources/links.md`** — docs oficiales del Collector, blog posts de patterns, ADOT, Alloy.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué pierde un deploy **agent-only** y qué pierde uno **gateway-only**; explicar por qué el agent "ve" la metadata del nodo que el gateway no ve; distinguir compresión gRPC `gzip` de deduplicación de batching; explicar por qué `sending_queue` sin storage se pierde al reiniciar el Pod. |
| Operativa | Desplegar DaemonSet agent + Deployment gateway + Service en kind; activar `file_storage` y verificar persistencia; configurar `health_check` y probes; dimensionar HPA sobre gateway con métricas útiles. |
| Arquitectónica | Elegir y defender una topología dadas tres escalas; decidir cuándo un sidecar es correcto; evaluar trade-offs ADOT vs otelcol-contrib vs Alloy; planificar un upgrade sin pérdida. |

## Criterios de evaluación

- Cluster kind con DaemonSet `otel-agent` y Deployment `otel-gateway` ambos Ready; agent envía OTLP al Service del gateway; gateway exporta a backend `debug` o `file` observable.
- Collector con `file_storage` + `sending_queue.storage` configurado y verificable: al tirar el backend simulado y volverlo a levantar, no hay pérdida de la cola persistida.
- `ADR.md` de la Actividad 02 con las secciones **Contexto / Decisión / Alternativas consideradas / Consecuencias / Trade-offs por escala (10/1k/100k RPS)** y una decisión justificada por escala.
- Explicación escrita (en el ADR o cuaderno aparte) de qué distro del Collector eligirías por entorno (self-hosted on-prem, AWS, GCP, multi-cloud) y por qué.

## Secuencia recomendada

1. Lee `theory/lesson.md` completa (~60 min).
2. Reproduce `examples/01-daemonset-agent-plus-deployment-gateway/`. Observa en el log del gateway los spans emitidos por el agent.
3. Reproduce `examples/02-queue-persistence-disk/`. Mata el backend, mata el Collector, levanta ambos y confirma que la cola sobrevivió.
4. Lee `examples/03-adot-vs-otel-contrib/`.
5. Haz la Actividad 01 y pasa el validador.
6. Haz la Actividad 02. No consultes `solution/` mientras escribes el ADR.

## Siguiente

→ `otel-10-sampling-head-tail-probabilistic-parent-based`: dónde cae el sampling en esta topología y cómo diseñarlo para costo + señal.

## Notas sobre entorno

- Requiere **kind** (≥ 0.22) y **kubectl** (≥ 1.29). Los ejemplos están pensados para una sola máquina.
- Si no tienes `kind` o Docker disponible, los scripts hacen **SKIP** con mensaje claro y el validador reporta `SKIPPED` sin romper el flujo.
- Todo lo generado va a `/tmp/otel-09-*` y los scripts incluyen limpieza (`cleanup.sh`) idempotente.
- No se suben secretos: ningún ejemplo requiere tokens de SaaS; el "backend" en los labs es un exporter `debug` o `file`.
