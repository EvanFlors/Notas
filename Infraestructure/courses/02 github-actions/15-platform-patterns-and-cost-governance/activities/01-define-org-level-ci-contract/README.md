# Actividad 01 — Define el platform contract de CI/CD de una org

## 1. Identificación

- **ID:** `gha-15-01-define-org-level-ci-contract`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-15-platform-patterns-and-cost-governance`
- **Dificultad:** advanced
- **Duración estimada:** 90–150 min
- **Tipo:** independent (architecture — entregable triple)

## 2. Contexto

Eres platform engineer. El VP de ingeniería te pide "poner orden" en el CI/CD de la org: cada equipo hace algo distinto, la factura mensual crece sin control y hubo un *security incident* en febrero porque un repo olvidó correr el SAST en el PR que introdujo el bug.

Tu entregable es un **platform contract** compuesto de tres artefactos coherentes:

1. Un **ADR** que decide qué entra al contrato, por qué y con qué métricas se gobierna.
2. Un **reusable workflow** golden path (plantilla operacionalizable).
3. Un **ruleset JSON** que exige al menos un check obligatorio del contrato.

El validador comprueba **estructura + presencia**. La corrección semántica se evalúa en defensa oral contra `solution/ADR-reference.md`.

## 3. Objetivos

- Extraes restricciones del escenario y las traduces a decisiones.
- Decides qué es *obligatorio* (gate) vs *recomendado* (golden path) vs *blando* (convención).
- Redactas un ADR con contexto, decisión, consecuencias, métricas/SLOs.
- Operacionalizas el contrato en artefactos ejecutables (YAML + JSON), no solo prosa.
- Defines **review triggers** medibles.

## 4. Prerrequisitos

- Lección `gha-15` leída (especialmente §2, §4, §9, §10).
- Haber hecho `gha-08-02` (publicar un reusable), `gha-09-01` (environments), `gha-13-01` (hardening).
- Software: `bash`, `python3`, `yq` o `python -c "import yaml"` (opcional, solo si quieres validar YAML tú mismo). El validador requiere `bash` y `python3` con PyYAML (`pip install pyyaml`).

## 5. Instrucciones

### 5.1 Escenario asignado

> **Org:** `ACME-CO` (GitHub Enterprise Cloud).
> **Tamaño:** 42 repositorios privados activos, 8 públicos, ~60 desarrolladores en 7 squads.
> **Stacks dominantes:** Python 3.12 (65% repos), Node 20 (25%), Go 1.22 (10%).
> **Producción:** EKS en AWS; despliegues desde GHA vía OIDC (ya existe); imágenes en GHCR.
> **Cumplimiento:** SOC 2 Type II. Auditor exige evidencia de SAST en cada PR a `main` y approval de 1 reviewer.
> **Dolor:**
> - Factura hosted en septiembre: **$8,400** (vs $3,200 en enero). Nadie sabe en qué.
> - 2 equipos usan `macos-latest` para builds de wheels Python aunque no es necesario (hay ARM Linux).
> - El equipo *billing* tuvo un deploy a prod cancelado a mitad por otro merge (`cancel-in-progress: true`).
> - Un PR mergeó a `main` sin pasar `bandit` porque el repo olvidó incluirlo en `ci.yml`.
> - Lead time medio de PR: 2.4 días; p95 de duración de CI: 24 min.
> **Restricciones:**
> - No pueden sumar herramientas nuevas (nada de Datadog nuevo, nada de Jenkins).
> - Sí pueden usar: GHA, rulesets, repo `ACME-CO/.github`, Terraform ya existente para la org.

### 5.2 Entregables

Tu platform contract vive en:

```
starter/
├── ADR-001-ci-contract.md        ← ADR (ver §5.3 estructura mínima)
├── reusable/
│   └── org-ci-golden-path.yml    ← reusable workflow golden path
└── ruleset.json                  ← ruleset de org exigiendo ≥1 workflow
```

Edita cada uno reemplazando los `TODO`. **No borres los encabezados de sección** del ADR — el validador los requiere.

### 5.3 Estructura mínima del ADR

Headers obligatorios (literales):

- `# ADR-001: CI/CD Platform Contract`
- `## Status`
- `## Context`
- `## Decision`
- `## Alternatives Considered`
- `## Consequences`
- `## Metrics and SLOs`
- `## Risks and Mitigations`
- `## Review Triggers`

Contenido obligatorio:

- **Decision**: frase explícita del tipo `We will adopt <golden-path pattern>` donde el patrón mencione alguno de: `required workflows`, `reusable workflows`, `golden path`, `platform contract`.
- **Alternatives Considered**: ≥ 2 bullets.
- **Consequences**: ≥ 3 bullets.
- **Metrics and SLOs**: ≥ 2 métricas con umbral numérico (p. ej. `p95 CI < 10 min`, `success-rate >= 97%`, `monthly runner-minutes <= 150 000`).
- **Risks and Mitigations**: ≥ 2 riesgos con la palabra `Mitigation` en cada uno.
- **Review Triggers**: ≥ 1 bullet con condición medible.
- Longitud ≥ 500 palabras.

### 5.4 Estructura mínima del reusable (`org-ci-golden-path.yml`)

- Clave `on.workflow_call` presente.
- Declara `permissions:` explícito (no comodines) a nivel workflow o job.
- Declara `concurrency:` con `group:`.
- Al menos un job con `timeout-minutes:` explícito.
- Al menos un step con una action pinneada a SHA de 40 caracteres (patrón `uses: owner/action@<sha40>`).

### 5.5 Estructura mínima del ruleset (`ruleset.json`)

JSON válido con:

- `name` (string no vacío).
- `enforcement` ∈ {`"active"`, `"evaluate"`, `"disabled"`}.
- `target` == `"branch"`.
- `conditions.ref_name.include` incluye `"refs/heads/main"` (o `"~DEFAULT_BRANCH"`).
- `rules` es array con al menos una regla de tipo `"workflows"` que referencia tu golden path con `path` que termine en `.yml` y un `ref` no vacío.

### 5.6 Validar

```bash
bash tests/validate.sh
```

Debe terminar en `OK`. Si falla, el output dice qué sección o artefacto falla.

### 5.7 (Opcional) comparar con la referencia

Tras intentarlo, revisa `solution/ADR-reference.md` + `solution/reusable/` + `solution/ruleset.json`. Es *una* respuesta razonada; la tuya puede ser distinta y seguir siendo válida.

## 6. Resultado esperado

- Los tres artefactos presentes y pasando el validador estructural.
- Puedes defender oralmente: por qué estos checks son obligatorios y no otros; por qué este golden path y no un starter; qué SLO dispararía revisión del contrato.

## 7. Criterios de aceptación

- [ ] ADR con las 9 secciones obligatorias.
- [ ] Decisión explícita con uno de los patrones permitidos.
- [ ] 2+ alternativas descartadas con razón.
- [ ] 3+ consecuencias.
- [ ] 2+ métricas con umbral numérico.
- [ ] 2+ riesgos con mitigación.
- [ ] 1+ review trigger medible.
- [ ] Longitud ≥ 500 palabras.
- [ ] Reusable con `workflow_call`, `permissions`, `concurrency`, `timeout-minutes` y ≥ 1 action pinneada a SHA.
- [ ] Ruleset JSON válido con `workflows` rule apuntando al golden path.
- [ ] `tests/validate.sh` pasa.

## 8. Validación

```bash
bash tests/validate.sh
```

El validador comprueba **estructura y presencia**, no corrección semántica (que es subjetiva). La corrección semántica se evalúa en defensa oral o en revisión por pares.

## 9. Preguntas de reflexión

1. ¿Qué parte del contrato impondrías con *required workflow* (gate duro) y qué parte con *starter workflow* (sugerencia)? ¿Por qué?
2. ¿Qué SLO dispararía revisión del contrato *en menos de un trimestre*?
3. Si el reusable `v1` rompe tras un cambio, ¿cómo evitas bloquear a toda la org? ¿Qué papel juega `bypass_actors` del ruleset?
4. ¿Cómo convencerías al equipo *billing* de aceptar un cambio obligatorio en su CI sin generar fricción?
5. Si GitHub Actions se cae 4 h durante un *release train* nocturno, ¿qué partes del contrato dejan de proteger y qué pondrías en el runbook?

## 10. Extensiones

- **E1** — Añade un segundo ADR (`ADR-002-cost-governance.md`) con política de larger runners y presupuesto mensual por repo.
- **E2** — Operacionaliza el ruleset en Terraform usando `integrations/github` provider (`github_organization_ruleset`).
- **E3** — Añade dashboards: lista las queries BigQuery/Datadog que materializan las métricas del ADR.

## 11. Limpieza

Esta actividad no crea recursos remotos (todo son archivos en el repo). Para empezar de cero:

```bash
git checkout -- starter/
```
