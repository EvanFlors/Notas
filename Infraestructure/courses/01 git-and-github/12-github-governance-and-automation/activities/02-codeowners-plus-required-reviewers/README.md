# Actividad 02 — CODEOWNERS + required reviewers

## 1. Identificación

- **ID:** `gh-12-02-codeowners-plus-required-reviewers`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-12-github-governance-and-automation`
- **Dificultad:** intermediate
- **Duración estimada:** 45 min
- **Tipo:** guided-lab

## 2. Contexto

Un CODEOWNERS mal escrito es peor que no tener uno: GitHub ignora silenciosamente entries con usuarios/teams inválidos, y la ruleset no bloquea. En esta actividad produces un CODEOWNERS **cubriendo paths críticos**, un **PR template**, y un **ruleset parcial** que exige `require_code_owner_review`. Validas offline (modo `local`) o contra GitHub (modo `live`).

## 3. Objetivos

Al terminar:
- Escribir un CODEOWNERS no trivial con reglas por path y "última-regla-gana".
- Añadir un `.github/pull_request_template.md`.
- Preparar un fragmento de ruleset JSON con `require_code_owner_review: true`.
- Validar sintaxis offline y, opcionalmente, los *CODEOWNERS errors* vía API.

## 4. Prerrequisitos

- `python3`.
- Opcional: `gh` autenticado + repo propio.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-repo.sh /tmp/codeowners-lab
cd /tmp/codeowners-lab
tree -a -L 3 .
```

El starter crea un repo esqueleto con paths: `infra/`, `services/api/`, `apps/web/`, `docs/`, y `.github/`.

### 5.2 Crear CODEOWNERS

Edita `/tmp/codeowners-lab/.github/CODEOWNERS` para cumplir:

- Default fallback: `@example-org/platform`.
- `infra/` y `*.tf` → `@example-org/sre`.
- `services/api/` → `@example-org/backend` **y** `@alice`.
- `apps/web/` → `@example-org/frontend`.
- `docs/` → `@example-org/docs`.
- El propio `.github/CODEOWNERS` → `@example-org/platform-admins`.

Recuerda: **el último match gana**. Pon las reglas en orden del más general al más específico.

### 5.3 PR template

Crea `/tmp/codeowners-lab/.github/pull_request_template.md` con, al menos:

- Sección **Context** (por qué).
- Sección **Change** (qué).
- Sección **Testing** (cómo se probó).
- Sección **Risk & rollback**.

### 5.4 Ruleset parcial

Crea `/tmp/codeowners-lab/.github/ruleset-codeowners.json` con un ruleset que — además de PR y approvals — exija `require_code_owner_review: true`.

### 5.5 Validar

```bash
bash tests/validate.sh /tmp/codeowners-lab
# modo live:
# export GH_OWNER=... GH_REPO=...
# MODE=live bash tests/validate.sh /tmp/codeowners-lab
```

En modo `live` el validador llama `gh api repos/$GH_OWNER/$GH_REPO/codeowners/errors` y falla si hay errores.

## 6. Resultado esperado

- `.github/CODEOWNERS` sintácticamente correcto, cubre todos los paths requeridos.
- `.github/pull_request_template.md` con las 4 secciones.
- `.github/ruleset-codeowners.json` JSON válido con `require_code_owner_review: true`.
- Validador en modo `local` → `OK`.

## 7. Criterios de aceptación

- [ ] CODEOWNERS cumple el mapping del punto 5.2.
- [ ] PR template tiene las 4 secciones.
- [ ] Ruleset JSON es parseable y contiene la flag `require_code_owner_review: true`.
- [ ] Si corres `live`, `codeowners/errors` devuelve vacío.

## 8. Validación

```bash
bash tests/validate.sh /tmp/codeowners-lab
```

## 9. Preguntas de reflexión

1. ¿Qué pasa si en CODEOWNERS pones `@does-not-exist`? ¿Cómo lo detectarías?
2. ¿Por qué `require_code_owner_review` es inútil sin un ruleset activo?
3. ¿Cuándo tiene sentido que un path tenga **dos** owners (uno team, otro user)?

## 10. Extensiones

- **E1** — Añade un workflow que corra `gh api codeowners/errors` como check de CI.
- **E2** — Combina este ruleset con el de la actividad 01 (dos rulesets simultáneos sobre `main`) y observa la unión.
- **E3** — Añade un path `security/` cuyo owner único sea un team mínimo.

## 11. Limpieza

```bash
rm -rf /tmp/codeowners-lab
```
