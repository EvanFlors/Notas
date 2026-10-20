# ADR-001: CI/CD Platform Contract

## Status

Proposed.

Fecha: 2026-10-14.
Autor(es): Platform Engineering (ACME-CO).

## Context

ACME-CO opera 42 repos privados + 8 públicos en GitHub Enterprise Cloud, con 60 ingenieros
distribuidos en 7 squads y stacks dominantes Python 3.12, Node 20 y Go 1.22. La producción
corre en EKS con despliegues desde GHA vía OIDC a AWS; imágenes se publican en GHCR.
Debemos sostener SOC 2 Type II, que exige SAST en cada PR a `main` y al menos un reviewer.

El dolor actual es triple:

- **Costo**: la factura de hosted runners pasó de $3,200 (enero) a $8,400 (septiembre) sin
  que ningún squad pueda explicar el delta. Dos equipos construyen wheels Python en
  `macos-latest` sin necesidad real (×10 multiplicador).
- **Seguridad**: en el incidente de febrero mergeó a `main` un PR que no corrió `bandit`
  porque el repo olvidó añadirlo a `ci.yml`. El control vive en cada repo y es olvidable.
- **Operación**: el deploy de *billing* a prod fue cancelado a la mitad por un merge
  concurrente porque el workflow usaba `cancel-in-progress: true` en deploy. Lead time
  medio de PR es 2.4 días; p95 CI = 24 min.

## Decision

**We will adopt a CI/CD platform contract composed of a required workflow enforced via an
org-level ruleset, plus a reusable workflow golden path versioned with the `vN` + SHA
pattern.**

Pilares:

- Un reusable workflow `ACME-CO/.github/.github/workflows/security-scan.yml@v1` (bandit
  para Python, semgrep para Node/Go) **obligatorio** en PRs a `main` de todos los repos
  privados vía ruleset con `enforcement: active`.
- Un segundo reusable `.../org-ci-golden-path.yml@v1` **recomendado** (no obligatorio)
  que estandariza setup, cache, matriz por stack y publicación de summary.
- Convención obligatoria de concurrency: `cancel-in-progress: true` solo en CI de PR;
  `false` en deploy (fuerza cola, nunca cancela despliegue en vuelo).
- Permissions por defecto a `contents: read`; escalada por job con comentario de por qué.
- Versionado: tags `v1` (mutable, mueve al último SHA de la major) + `v1.X.Y` (inmutable).
  Repos sensibles pinnean a SHA + Dependabot.
- `bypass_actors`: el team `platform` puede mergear al propio reusable sin esperar el
  check del reusable (evita deadlock cuando el reusable rompe).

## Alternatives Considered

- **Starter workflow únicamente**: menor fricción, nula obligatoriedad. Descartado: el
  incidente de febrero demostró que lo opcional no cubre el riesgo SOC 2.
- **Branch protection classic + required status check por nombre en cada repo**: requiere
  configurar 42 repos a mano; divergen con el tiempo. Descartado por costo operativo y
  por no cumplir con "una fuente de verdad".
- **Required workflows (modelo clásico, deprecated)**: GitHub lo está sustituyendo por
  rulesets. Descartado para no construir sobre API deprecada.
- **Reusable workflow pinneado solo a SHA inmutable**: máxima reproducibilidad; obliga a
  Dependabot y disciplina de merge en todos los repos. Descartado como *default*:
  friccionamos los 42 repos. Se mantiene como opción para los 5 repos "crown jewel".

## Consequences

- Cualquier PR a `main` en un repo privado no se puede mergear sin que `security-scan`
  pase. Elimina el patrón "olvidé añadir bandit".
- La divergencia entre repos cae: todos invocan el mismo YAML con los mismos defaults.
- Un bug en el reusable `v1` bloquea los PRs de toda la org hasta que `platform` mueve
  `v1` al SHA del fix. Riesgo gestionado vía bypass y vía *canary* del reusable en
  3 repos piloto antes de mover `v1`.
- Posible reducción del gasto estimada en 20–30% al eliminar builds macOS innecesarios y
  activar `cancel-in-progress: true` en CI de PR (reduce reruns por force-push).
- Fricción inicial con los squads que ya tenían su "golden path" propio; se mitiga con
  rollout en 4 semanas y oficina de horas de platform.

## Metrics and SLOs

- **p95 CI duration** < 10 min para el top-5 de repos por volumen de PRs. Medido
  semanalmente.
- **Required-workflow success-rate** >= 97% semanal. Caídas sostenidas disparan review.
- **Monthly runner-minutes cobrables** <= 150 000 agregado org. Larger runners
  <= 10% del total.
- **Lead time p50 de PR** <= 1 día (DORA). Actualmente 2.4 días.
- **Cache hit-rate** >= 70% en los 5 repos de mayor volumen.

## Risks and Mitigations

- **Risk 1 — reusable roto bloquea toda la org**: si `v1` apunta a un SHA que
  rompe, 42 repos no pueden mergear. **Mitigation**: `bypass_actors` para team
  `platform`; canary del reusable en 3 repos de sandbox 24 h antes de mover `v1`;
  rollback atómico moviendo `v1` al SHA anterior.
- **Risk 2 — equipo se siente "sin control"**: perciben la obligatoriedad como
  imposición. **Mitigation**: oficina de horas semanal; proceso ligero de propuesta
  de cambio al contrato (RFC → PR al repo platform); métricas públicas del contrato
  (success-rate, p95, bloqueos del ruleset).
- **Risk 3 — mover `v1` introduce regresión silenciosa**: la major cambia bajo los
  consumidores sin PR. **Mitigation**: changelog obligatorio en cada release;
  Dependabot activo en los 5 repos crown-jewel pinneados a SHA; smoke-tests del
  reusable en el propio repo platform.

## Review Triggers

- Si **p95 CI duration** del top-5 supera **15 min durante 2 semanas consecutivas**,
  revisamos el golden path.
- Si **gasto mensual** supera **$12 000**, revisamos política de larger runners.
- Si **success-rate** del required workflow cae por debajo de **95% durante 1 mes**,
  evaluamos relajar la obligatoriedad o invertir en flakiness.
- Nuevo stack dominante (p. ej. Rust >= 15% repos) obliga a extender el golden path.
- GitHub cambia el modelo de rulesets (como ya pasó dos veces desde 2019).

## References

- Lección gha-15 (`../../theory/lesson.md`).
- Docs oficiales: Repository rulesets, Reusing workflows, Billing for Actions.
- DORA metrics (dora.dev).
