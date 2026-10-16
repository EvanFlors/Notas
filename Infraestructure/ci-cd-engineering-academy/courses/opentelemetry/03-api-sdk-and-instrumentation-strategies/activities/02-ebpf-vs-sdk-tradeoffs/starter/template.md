# ANALYSIS — eBPF vs SDK (plantilla)

> Copia este archivo a `/tmp/otel-03-02/ANALYSIS.md` y completa cada sección.
> No borres los títulos: `tests/validate.sh` los busca literalmente para validar
> la estructura.

## Escenario 1 — checkout-api (Python/FastAPI greenfield)

Descripción:
- (describe en 2 líneas)

Decisión: <manual|library|auto|ebpf|ninguna o combinación>

Justificación:
- (3–6 líneas; menciona madurez SDK, acceso al código, dominio de negocio)

## Escenario 2 — legacy-pricing (binario Go cerrado)

Descripción:
- (2 líneas)

Decisión: ...

Justificación:
- ...

## Escenario 3 — payments-worker (Celery, requisito de auditoría)

Descripción:
- ...

Decisión: ...

Justificación:
- ...

## Escenario 4 — cron-sync-bash (script bash corto)

Descripción:
- ...

Decisión: ...

Justificación:
- ...

## Síntesis

Lista cinco criterios reutilizables (numerados `1.`–`5.`). Al menos uno debe
mencionar eBPF (Pixie, Beyla o Hubble).

1.
2.
3.
4.
5.
