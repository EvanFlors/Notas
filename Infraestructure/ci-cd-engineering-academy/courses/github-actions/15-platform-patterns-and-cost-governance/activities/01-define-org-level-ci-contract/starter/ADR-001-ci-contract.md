# ADR-001: CI/CD Platform Contract

## Status

TODO: Proposed | Accepted | Deprecated | Superseded. (Para este ejercicio típicamente Proposed.)

Fecha: TODO (YYYY-MM-DD).
Autor(es): TODO.

## Context

TODO: Resume con tus palabras el escenario de ACME-CO (tamaño, stacks, cumplimiento, dolor
actual). Incluye los datos del dolor: factura $8,400 en septiembre, lead time 2.4 días,
p95 CI 24 min, incidente de SAST olvidado, deploy cancelado por `cancel-in-progress`.
6–12 líneas.

## Decision

TODO: Toma la decisión en una frase clara del tipo:
"We will adopt a platform contract composed of <required workflows + reusable workflows
golden path + ruleset>." (debe mencionar al menos uno de: required workflows,
reusable workflows, golden path, platform contract).

TODO: Explica los pilares de la decisión en 3–6 bullets:
- qué workflow(s) se exige(n) obligatoriamente;
- qué reusable(s) son golden path (opcional);
- qué convenciones de concurrency y permissions;
- cómo se versiona el reusable;
- cómo opera el bypass del contrato.

## Alternatives Considered

TODO: Al menos 2 alternativas descartadas con una razón explícita cada una.

- **Alternative A — <nombre>**: TODO por qué se descartó para este escenario.
- **Alternative B — <nombre>**: TODO por qué se descartó para este escenario.

## Consequences

TODO: Al menos 3 consecuencias esperadas (positivas y/o negativas).

- TODO consequence 1.
- TODO consequence 2.
- TODO consequence 3.

## Metrics and SLOs

TODO: Al menos 2 métricas con **umbral numérico** medible.

- TODO ej.: `p95 CI duration < 10 min` para los top-5 repos.
- TODO ej.: `monthly runner-minutes <= 150000`.
- TODO ej.: `required-workflow success-rate >= 97% semanal`.

## Risks and Mitigations

TODO: Al menos 2 riesgos con la palabra **Mitigation** en cada uno.

- **Risk 1 — <nombre>**: TODO descripción. **Mitigation:** TODO.
- **Risk 2 — <nombre>**: TODO descripción. **Mitigation:** TODO.

## Review Triggers

TODO: Al menos 1 criterio medible que, si se cumple, obliga a revisar este contrato.

- TODO ej.: "si p95 CI supera 15 min durante 2 semanas consecutivas, revisamos el golden path".
- TODO ej.: "si gasto mensual > $12 000, revisamos política de larger runners".

## References

- Lección gha-15 (`../../theory/lesson.md`).
- Docs: Repository rulesets, Reusing workflows, Billing for Actions.
