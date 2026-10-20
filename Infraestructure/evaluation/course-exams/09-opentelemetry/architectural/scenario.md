# Ejercicio arquitectónico — Topología de Collector y sampling para "Pulpo Pay"

## Contexto

**Pulpo Pay** es una fintech latinoamericana que opera una plataforma de pagos
sobre Kubernetes (EKS, 4 clusters: `prod-mx`, `prod-co`, `prod-cl`, `stg`).

- **80 microservicios** en Python (FastAPI), Go y Node.
- **~45 000 requests/s** sostenido en `prod-mx` (región líder), con picos de
  2× en Black Friday / Buen Fin.
- Cada request toca en promedio 7 servicios (cadena de autorización +
  antifraude + ledger + notificaciones).
- Volumen estimado actual: **~320 000 spans/s** en `prod-mx`.
- SLO de latencia end-to-end: p99 < 400 ms.
- Backend actual de traces: **Grafana Tempo** self-hosted (S3).
- Backend de métricas: **Mimir** (OTLP ingest nativo habilitado).
- Backend de logs: **Loki**.
- Equipo de FinOps impuso un **cap de 25 000 spans/s** ingestados a Tempo.
  El resto debe descartarse en el pipeline.
- Compliance (regulador bancario): **100% de los traces con error** y
  **100% de los traces con latencia > p99** deben persistirse 90 días.
  PII (email del titular, PAN parcial, teléfono) **NO** puede llegar a
  Tempo ni a Loki.
- Red: cada cluster tiene salida restringida; solo el equipo de plataforma
  puede abrir egress adicional. mTLS obligatorio entre pods y hacia Tempo.

## Restricciones duras

1. No modificar código de las apps más allá de habilitar el SDK OTel
   (ya está en todos los servicios Python; los de Go/Node ya exportan OTLP).
2. Un único **contrato de telemetría**: las apps hablan OTLP; la plataforma
   decide el destino.
3. Presupuesto de memoria por nodo del Collector: **4 GiB** máximo.
4. El pipeline debe sobrevivir a una caída de Tempo de **30 min** sin pérdida.
5. Debe funcionar también en `stg` con 1/50 del tráfico, idealmente con la
   misma config parametrizada.

## Lo que debes entregar

### 1. Diagrama de topología

Mermaid o ASCII mostrando:

- Dónde corre el Collector (DaemonSet agent, Deployment gateway, sidecar,
  nada).
- Protocolos y puertos entre apps ↔ agent ↔ gateway ↔ backends.
- Dónde vive la queue persistente.
- Dónde se aplica el sampling y dónde el scrubbing de PII.

### 2. ADR (`adr.md`, 1 página, formato MADR o Nygard)

- **Contexto** (3–5 líneas).
- **Decisión** (topología elegida + sampling + scrubbing).
- **Alternativas consideradas** (mínimo 2, con razón de descarte).
- **Consecuencias** (positivas y negativas, cuantificadas cuando sea posible:
  memoria, latencia añadida, blast radius, costo de egress, operación).
- **Riesgos abiertos**.

### 3. Snippet `tail-sampling.yaml`

Fragmento YAML del `tail_sampling` processor (nivel gateway) con las
policies que satisfacen el compliance Y el cap de 25 000 spans/s.
Debe incluir:

- `decision_wait` y `num_traces` dimensionados y justificados en un
  comentario adyacente.
- Al menos tres policies: errores, latencia, probabilístico base.
- Comentario sobre dónde se aplicaría `redaction` / `attributes` processor
  para PII (antes o después del tail; defender la elección).

## Criterios de corrección

Ver §5.3 del `EXAM.md`. Las respuestas que elijan **agent-only** o
**gateway-only** sin considerar explícitamente la alternativa pierden
el criterio "Topología" automáticamente. Las que propongan head-based
sampling como solución única son descalificadas en "Sampling" porque
el enunciado exige visibilidad de errores desconocidos al momento del
root span.

## Preguntas de seguimiento (si la evaluación es live)

1. ¿Por qué el `tail_sampling` no puede vivir en el agent DaemonSet?
2. Si Tempo cae 30 min y la queue en disco se llena, ¿qué prefieres:
   drop o back-pressure al cliente? Defiéndelo.
3. Un vendor te ofrece su backend "a mitad de precio" pero requiere su
   propio agente. ¿Qué respondes y por qué?
4. ¿Cómo garantizas que `prod-cl` y `prod-mx` tomen la misma decisión
   de sampling para un trace que cruza regiones?
