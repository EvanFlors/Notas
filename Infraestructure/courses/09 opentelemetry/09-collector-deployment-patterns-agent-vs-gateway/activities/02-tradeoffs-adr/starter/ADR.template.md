# ADR-XXX: Topología del OpenTelemetry Collector

## Status

Proposed | Accepted | Rejected  (elige una)

## Contexto

Describe el problema: por qué necesitamos decidir una topología, qué workloads cubre, qué backends están en juego, qué restricciones existen (SaaS vs self-hosted, SLOs de observabilidad, presupuesto).

## Decisión

Enuncia la decisión en una o dos frases claras.

## Alternativas consideradas

- Patrón **sin Collector** — por qué sí / por qué no.
- Patrón **sidecar** — por qué sí / por qué no.
- Patrón **agent-only** — por qué sí / por qué no.
- Patrón **gateway-only** — por qué sí / por qué no.
- Patrón **agent + gateway** — por qué sí / por qué no.

## Consecuencias

- Positivas (al menos 3).
- Negativas (al menos 2, de verdad; si no hay, revisa).

## Trade-offs por escala

### 10 RPS (startup, 1 cluster, 3 nodos)

Patrón elegido; replicas; processors por capa; `sending_queue` sí/no; qué pasa si el backend se cae 5 min.

### 1000 RPS (empresa mediana, 1 cluster, 10 nodos)

Patrón elegido; replicas; HPA sí/no y señal; processors por capa; `sending_queue` + `file_storage` sí/no; qué pasa si el backend se cae 5 min.

### 100000 RPS (empresa grande, 3 clusters, 100 nodos cada uno)

Patrón elegido; replicas; HPA (min/max y señal); tail-sampling + `load_balancing`; `file_storage` sí/no; multi-AZ; qué pasa si el backend se cae 5 min; coste estimado del batching + compresión.

## Distro por entorno

| Entorno | Distro elegida | Justificación (1 línea) |
|---------|----------------|-------------------------|
| …       | …              | …                       |
| …       | …              | …                       |

## Revisión

- Fecha de próxima revisión: …
- Métricas / eventos que dispararían una revisión anticipada: …
