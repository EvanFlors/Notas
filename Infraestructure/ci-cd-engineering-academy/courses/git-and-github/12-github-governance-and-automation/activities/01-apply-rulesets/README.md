# Actividad 01 — Aplicar un Ruleset sobre `main`

## 1. Identificación

- **ID:** `gh-12-01-apply-rulesets`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-12-github-governance-and-automation`
- **Dificultad:** intermediate
- **Duración estimada:** 50 min
- **Tipo:** guided-lab

## 2. Contexto

Diseñar y materializar — **como código** — un Ruleset que proteja la rama `main` de un repositorio hipotético, de forma coherente con un workflow trunk-based. Valida en modo `local` (sin GitHub, siempre funciona) o `live` (contra un repo propio).

## 3. Objetivos

Al terminar:
- Escribir un JSON de ruleset válido (campos mínimos de la API).
- Diferenciar `active` vs `evaluate` enforcement.
- Justificar `bypass_actors: []` (o lo contrario) por escrito.
- Validar sintácticamente offline.
- Opcional: aplicar realmente vía `gh api` y re-leer el estado.

## 4. Prerrequisitos

- `python3` (para parsear JSON).
- Opcional `yq`.
- Para modo `live`: `gh` autenticado + un repo propio donde seas admin.

**Costos**: ninguno. GitHub Free alcanza (los Rulesets están disponibles en free tier para repos públicos; en orgs necesitas Team o Enterprise para algunas reglas).

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/build-scratch.sh /tmp/apply-rulesets
cd /tmp/apply-rulesets
ls
# Verás: ruleset-main.json (vacío) y README.md con las reglas a cumplir.
```

### 5.2 Escribir el ruleset

Edita `/tmp/apply-rulesets/ruleset-main.json` para que cumpla:

- `name`: `"protect-main"`.
- `target`: `"branch"`.
- `enforcement`: `"active"`.
- `conditions.ref_name.include`: `["refs/heads/main"]`.
- `rules` incluye al menos: `deletion`, `non_fast_forward`, `pull_request` con `required_approving_review_count >= 1`, y `required_status_checks` con al menos un check.
- `bypass_actors`: `[]`.

Puedes partir de `examples/01-ruleset-main-branch/files/ruleset-main.json` como referencia, pero **debes escribirlo tú** y entenderlo.

### 5.3 Documentar la decisión

Crea `/tmp/apply-rulesets/DECISION.md` con 5–10 líneas que respondan:

- Por qué `bypass_actors: []`.
- Por qué `require_last_push_approval: true` (o por qué no).
- Por qué los status checks elegidos.

### 5.4 Validar en modo local (default)

```bash
bash tests/validate.sh /tmp/apply-rulesets
# o explícito:
MODE=local bash tests/validate.sh /tmp/apply-rulesets
```

### 5.5 Validar en modo live (opcional)

```bash
export GH_OWNER=your-user
export GH_REPO=your-sandbox-repo
MODE=live bash tests/validate.sh /tmp/apply-rulesets
# El validador:
#   1. Confirma que el ruleset local es válido.
#   2. Aplica (POST) o actualiza (PUT) el ruleset en el repo real.
#   3. Lo re-lee vía gh api y compara.
#   4. Al final te deja el ruleset aplicado. Borra con:
#        gh api -X DELETE repos/$GH_OWNER/$GH_REPO/rulesets/<id>
```

## 6. Resultado esperado

- `/tmp/apply-rulesets/ruleset-main.json` existe, es parseable, cumple el shape mínimo.
- `/tmp/apply-rulesets/DECISION.md` existe con contenido no-trivial.
- `tests/validate.sh` termina en `OK`.

## 7. Criterios de aceptación

- [ ] JSON válido y aplica el shape exacto de la API de Rulesets.
- [ ] Documentación de la decisión está presente y es sustancial (≥ 5 líneas, no "porque sí").
- [ ] En modo `live`, el ruleset leído desde GitHub matchea el local.

## 8. Validación

```bash
bash tests/validate.sh /tmp/apply-rulesets         # modo local
MODE=live bash tests/validate.sh /tmp/apply-rulesets   # requiere gh + GH_OWNER/GH_REPO
```

## 9. Preguntas de reflexión

1. ¿Qué pasa si otro ruleset sobre `main` exige `required_signatures`? ¿Cómo interactúan?
2. ¿Qué daño causaría poner `bypass_actors` con el role Admin en modo `always`?
3. ¿Cuándo usarías `enforcement: evaluate`?

## 10. Extensiones

- **E1** — Añade un segundo ruleset sobre `refs/heads/release/*` con `required_signatures`.
- **E2** — Marca `require_code_owner_review: true` y crea un CODEOWNERS mínimo (sinergia con actividad 02).
- **E3** — Consulta `GET /repos/.../rulesets/rule-suites` tras un PR en tu repo sandbox y lee el audit.

## 11. Limpieza

```bash
rm -rf /tmp/apply-rulesets
# Si aplicaste en live:
#   gh api -X DELETE repos/$GH_OWNER/$GH_REPO/rulesets/<id>
```
