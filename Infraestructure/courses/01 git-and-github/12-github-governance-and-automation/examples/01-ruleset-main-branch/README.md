# Ejemplo 01 — Ruleset sobre `main`

Un **Ruleset JSON** aplicable a cualquier repo vía `gh api`. Es el "golden template" del módulo.

## Qué contiene

`files/ruleset-main.json`:

- Scope: `refs/heads/main` únicamente.
- Enforcement: `active`.
- Reglas: no delete, no non-fast-forward, linear history, pull_request (1 approval, dismiss stale, require last push approval), required status checks (`ci/build`, `ci/test`).
- `bypass_actors: []` — nadie puede saltarse.

## Validar offline

```bash
cd /tmp && cp -r "$(dirname "$0")/files" /tmp/ruleset-demo && cd /tmp/ruleset-demo
python3 -c "import json; d=json.load(open('ruleset-main.json')); \
  assert d['target']=='branch'; assert d['enforcement']=='active'; \
  print('OK: JSON parseable y campos mínimos presentes.')"
```

## Aplicar a un repo real (opcional)

Prerrequisitos:
- `gh auth login` con un token con permisos `administration:write` sobre `OWNER/REPO`.
- Repo propio donde puedas probar sin romper nada.

```bash
export OWNER=your-user
export REPO=your-sandbox-repo

# Crear
gh api -X POST repos/$OWNER/$REPO/rulesets --input ruleset-main.json

# Listar
gh api repos/$OWNER/$REPO/rulesets

# Borrar (al terminar la prueba)
RID=$(gh api repos/$OWNER/$REPO/rulesets --jq '.[] | select(.name=="protect-main") | .id')
gh api -X DELETE repos/$OWNER/$REPO/rulesets/$RID
```

## Variantes útiles

- Para `release/*`: cambia `ref_name.include` a `["refs/heads/release/*"]` y añade `{ "type": "required_signatures" }`.
- Para tags inmutables: `"target": "tag"`, `ref_name.include: ["refs/tags/v*"]`, reglas `{ "type": "update" }` y `{ "type": "deletion" }` denegadas.
- Para probar sin bloquear: `"enforcement": "evaluate"` y revisar `rule-suites`.

## Limpieza

```bash
rm -rf /tmp/ruleset-demo
```
