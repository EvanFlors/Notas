# Ejercicio operativo — Platform Engineering

> Entorno: take-home, Python 3.11+. **No requiere Backstage real** ni acceso a cloud. Todo opera sobre `catalog.json`.

## Contexto

Eres parte del platform team de ACME. Hoy no hay Backstage TechInsights desplegado y necesitas:

1. **Auditar** el catálogo de servicios para detectar entradas rotas antes de poblarlo en Backstage.
2. **Calcular un scorecard de madurez** por Component (bronze/silver/gold) con criterios defendibles.
3. **Computar métricas DORA agregadas** por sistema y detectar servicios "zombies" (entradas stale) que inflan la vista.
4. **Reportar freshness del catálogo** para que la plataforma pueda deprecar entradas con política.

El input es `catalog.json` (formato inspirado en Backstage pero autocontenido). El output son archivos y stdout verificables.

## Entregables

Debes entregar en esta carpeta `operative/`:

```
operative/
  catalog.json                 # provisto (no modificar)
  scorecard.py                 # tu código
  tests/test_scorecard.py      # tus tests (pytest)
  out/
    audit.json                 # OP-task-1 + OP-task-2
    scorecard.json             # OP-task-3 + OP-task-4
    dora.json                  # OP-task-5
    freshness.md               # OP-task-6
  REFLECTION.md                # máximo 300 palabras: decisiones de scoring y por qué
```

> No incluyas `ANALYSIS.md` — la reflexión va en `REFLECTION.md` y es intencionalmente corta.

## Tareas

### OP-task-1 — Validación referencial del catálogo (C5)

Escribe `scorecard.py audit --catalog catalog.json --out out/audit.json`.

Detecta y reporta por Component:

- **owner_missing_group**: `spec.owner = "group:X"` donde `X` no existe en `groups`.
- **consumes_unknown_api**: `consumesApis` referencia APIs no declaradas en `apis`.
- **provides_unknown_api**: `providesApis` referencia APIs no declaradas en `apis`.
- **depends_on_unknown_resource**: `dependsOn` apunta a Resources no declarados.
- **repo_archived_but_lifecycle_production**: inconsistencia lifecycle vs estado del repo.

### OP-task-2 — Vista de impacto (C5)

En `audit.json`, para cada API, lista los Components que la consumen (`consumers`). Para cada Resource, los Components que dependen de ella (`dependents`). Esto habilita la pregunta "¿quién se rompe si deprecamos X?".

### OP-task-3 — Scorecard de madurez (C9)

`scorecard.py score --catalog catalog.json --out out/scorecard.json`.

Checks mínimos (exactamente estos 8, no agregues "20 checks arbitrarios"):

| check_id | check | peso |
|----------|-------|------|
| has_owner | spec.owner apunta a Group existente | 2 |
| has_runbook | `signals.has_runbook == true` | 1 |
| has_slo | `signals.has_slo == true` | 1 |
| image_signed | `signals.image_signed == true` | 2 |
| no_critical_cves | `signals.critical_cves == 0` | 2 |
| coverage_ge_60 | `signals.test_coverage_pct >= 60` | 1 |
| on_call | `signals.on_call_configured == true` | 1 |
| deployed_last_90d | último build dentro de 90 días | 2 |

Nivel (sobre 12 puntos posibles):

- `gold`   si score ≥ 11
- `silver` si 8 ≤ score < 11
- `bronze` si 5 ≤ score < 8
- `unrated` si score < 5

### OP-task-4 — Adopción como KPI (C9)

Agrega al `scorecard.json` un bloque `adoption`:

```json
{"total": N, "gold_pct": X, "silver_pct": Y, "bronze_pct": Z, "unrated_pct": W}
```

Porcentajes redondeados a 1 decimal, suman 100.

### OP-task-5 — DORA agregada y detección de vanity (C10)

`scorecard.py dora --catalog catalog.json --out out/dora.json`.

Por `system`, agrega (ignorando Components con `lifecycle == deprecated` o `signals.*` en `null`):

- `deployment_frequency_30d`: suma de `deploys_last_30d`.
- `lead_time_minutes_p75`: mediana de los p75 por servicio.
- `change_failure_rate_pct`: promedio ponderado por `deploys_last_30d`.
- `mttr_minutes_p75`: mediana de los p75.

Además, incluye un campo `warnings[]` con **al menos uno** cuando un sistema reporta deploys altos (>30) y `change_failure_rate_pct > 10` o falta MTTR — explicando que celebrar deploys sin MTTR/CFR es Goodhart's Law.

### OP-task-6 — Freshness y política de deprecation (C12, C14)

`scorecard.py freshness --catalog catalog.json --out out/freshness.md`.

Markdown con:

- Lista de Components con `last_build_at > 90 días` o `repo_archived == true` o `owner` inexistente.
- Propuesta de política en 1 párrafo: ventana de **announce (30d) → warn (60d) → remove (90d)** con canal de aviso.
- Un bullet final: ¿qué cambia si uno de esos Components aparece en `OP-task-2` como dependencia de otro?

## Validación

El instructor debe poder correr:

```bash
cd operative/
python -m venv .venv && . .venv/bin/activate
pip install pytest
python scorecard.py audit     --catalog catalog.json --out out/audit.json
python scorecard.py score     --catalog catalog.json --out out/scorecard.json
python scorecard.py dora      --catalog catalog.json --out out/dora.json
python scorecard.py freshness --catalog catalog.json --out out/freshness.md
pytest -q
```

Esperado contra el `catalog.json` provisto (valores de referencia que el corrector verifica):

- `audit.json`:
  - `pricing-service.owner_missing_group == true` (grupo `ghost-team` no existe).
  - `legacy-reports.consumes_unknown_api` incluye `nonexistent-api`.
  - `legacy-reports.repo_archived_but_lifecycle_production == false` (lifecycle=deprecated, por lo tanto NO es inconsistencia).
  - `apis["pricing-v2"].consumers` incluye `checkout-api` y `legacy-reports`.
- `scorecard.json`:
  - `checkout-api` y `catalog-ui` → **gold**.
  - `notifications-worker` → **silver** (1 CVE crítico resta).
  - `pricing-service` → **unrated** o **bronze** según cálculo (debe ser consistente con los pesos).
  - `legacy-reports` → **unrated**.
  - `adoption.total == 5`.
- `dora.json`:
  - `growth.deployment_frequency_30d == 73` (18 + 55).
  - `payments` tiene warning por deploys altos (42) con CFR aceptable pero debe explicarse por qué el warning aplica/no.
- `freshness.md`:
  - lista `pricing-service` (último build 2026-07-02, > 90d desde 2026-10-20) y `legacy-reports` (archived + owner data OK pero lifecycle=deprecated → candidato a remove).

## Reglas

- Código Python idiomático (type hints, `argparse`, funciones puras separadas de IO).
- Mínimo 4 tests pytest (uno por subcomando o por regla de scoring).
- Prohibido: llamadas de red, `subprocess`, `curl | bash`, dependencias no estándar más allá de `pytest`.
- Prohibido: secretos hardcodeados en código, config o fixtures.
- Si cambias los pesos del scorecard, documenta en `REFLECTION.md` **por qué** y espera que te lo cuestionen en la pregunta de seguimiento.
