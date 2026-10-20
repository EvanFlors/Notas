#!/usr/bin/env bash
# Starter for activity 02: scaffold the ADR workspace.
# No `set -o pipefail` on purpose.
set -eu

BASE="${1:-/tmp/otel11-lab02}"
mkdir -p "$BASE"

cat > "$BASE/MESA-LOGISTICS-FACTS.md" <<'MD'
# Mesa Logistics — hechos de referencia

> No inventes datos: razona SIEMPRE a partir de los que están aquí.

- **Dominio:** entregas urbanas (same-day). Picos de carga 11:00–14:00 y 18:00–21:00.
- **Servicios:** 30 microservicios en Kubernetes (EKS). ~70% Python/FastAPI, 20% Go, 10% Java.
- **Escala:** ~2 000 RPS pico; **~400 M spans/día** proyectados (muestreo head 10%).
- **Equipos:** 6 equipos de producto; **1 equipo de platform de 3 personas** mantiene todo.
- **Estado actual:**
  - Prometheus + Grafana en producción (madurez alta).
  - Loki en piloto (3 servicios, 2 semanas).
  - NO hay backend de traces aún; cada equipo "mira logs".
- **Políticas:**
  - **No SaaS** para datos operacionales (PII de clientes, direcciones de envío).
  - Object storage self-hosted (MinIO on-prem).
  - Grafana es la UI canónica; no se adoptará otra sin ADR separado.
- **Presupuesto:** 2 nodos dedicados a backend de traces (16 vCPU, 64 GB RAM cada uno) + MinIO existente.
- **Horizonte:** decisión para los próximos **12–18 meses**. Reevaluación obligatoria si cambia la escala o la restricción de SaaS.
MD

cat > "$BASE/CRITERIA.md" <<'MD'
# Dimensiones típicas de la decisión (puedes añadir, no reducir)

1. **Costo total de propiedad (TCO)** — hardware + storage + ops a la escala dada.
2. **UX de búsqueda** — ¿se puede investigar un incidente sin salir del backend?
3. **Operabilidad** — ¿cuánto cuesta mantenerlo con un equipo de 3?
4. **Correlación cross-signal** — exemplars métricas↔traces, logs↔traces.
5. **Compatibilidad OTLP nativa** — ingesta OTLP sin shims ni adaptadores.
6. **Camino de evolución** — ¿aguanta 2–4× tráfico sin re-arquitectura?
7. **Riesgo de proyecto** — madurez upstream, cadencia de releases, comunidad.
8. **Lock-in de UI** — ¿la decisión obliga a usar otra herramienta?

Para cada criterio, define **peso** (1–5) y evalúa cada candidato con una nota (1–5) + justificación.
MD

cat > "$BASE/ADR-0001-tempo-vs-jaeger.md" <<'MD'
# ADR-0001 — Backend de traces: Tempo vs Jaeger

- **Status:** TODO (Proposed | Accepted | Rejected | Superseded by …)
- **Date:** TODO (YYYY-MM-DD)
- **Deciders:** TODO (nombres o roles)
- **Related:** otel-11, obs-13

## Context

TODO: describe el escenario de Mesa Logistics en 10–15 líneas. Resume los datos de
`MESA-LOGISTICS-FACTS.md` **con tus propias palabras** (no copiar). Explica por qué
hay que decidir **ahora**.

## Decision drivers (criteria)

TODO: lista al menos **5** criterios con peso (1–5) explícito, por ejemplo:

- **TCO a 400 M spans/día** — peso 5.
- **Operabilidad con equipo de 3** — peso 4.
- …

## Options considered

### Option A — Grafana Tempo

- Pros:
  - TODO
- Cons:
  - TODO

### Option B — Jaeger

- Pros:
  - TODO
- Cons:
  - TODO

## Decision

TODO: una **sola frase** inequívoca. Debe mencionar `Tempo` o `Jaeger` explícitamente.
Después, 1–2 párrafos justificando contra los criterios ponderados.

## Consequences

### Positive

- TODO
- TODO

### Negative

- TODO (sé honesto — si eliges Tempo, qué pierdes vs Jaeger; y viceversa)
- TODO

### Neutral

- TODO
- TODO

## Review trigger

TODO: condición objetiva que obliga a reevaluar este ADR. Ejemplos:

- spans/día > 1 500 M sostenido 30 días, OR
- Platform crece a > 6 personas (podemos operar algo más complejo), OR
- Grafana cae > 2 incidentes SEV1 en el trimestre (la dependencia de UI única nos duele).

## References

- `../theory/lesson.md` secciones 3, 4, 7, 10.
- Tempo docs: https://grafana.com/docs/tempo/latest/
- Jaeger docs: https://www.jaegertracing.io/docs/
MD

echo "Workspace ready at $BASE"
echo "Open ADR-0001-tempo-vs-jaeger.md and start filling the TODOs."
