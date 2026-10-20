# REFERENCE — sec-04-01

Solución de referencia. Cópiala **después** de haber intentado la actividad por tu cuenta.

## Layout final esperado

```
/tmp/sec-04-full-pipeline/
├── .git/
├── .pre-commit-config.yaml
├── .gitleaks.toml
├── .github/workflows/secret-scan.yml
├── tests/fixtures/sample.env
└── RUNBOOK.md
```

## `.pre-commit-config.yaml`

```yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
        name: gitleaks (staged changes)
        entry: gitleaks protect --staged --redact --verbose
```

## `.gitleaks.toml`

```toml
title = "sec-04 full pipeline — gitleaks config"

[extend]
useDefault = true

# Allowlist: fixtures de test con claves evidentemente falsas.
# Cada entrada debe tener comentario explicando por que es segura.
[allowlist]
description = "Fakes evidentes bajo tests/fixtures/"
paths = [
  '''tests/fixtures/.*''',
]
regexes = [
  # Fakes obvios usados por la suite de tests.
  '''sk_fake_[A-Za-z0-9_]+''',
  '''ghp_FAKE[A-Za-z0-9]+''',
]
stopwords = [
  "example",
  "fake",
  "dummy",
  "placeholder",
  "demo",
]
```

## `.github/workflows/secret-scan.yml`

```yaml
name: secret-scan

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout (full history, needed to scan all commits)
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## `tests/fixtures/sample.env`

```
# This file is a TEST FIXTURE. Values are intentionally fake.
GITHUB_TOKEN=ghp_FAKEabc0000demo000000000000000000000
STRIPE_SECRET=sk_fake_live_FAKEstripe00000000000000demo
```

## `RUNBOOK.md`

Debe seguir el orden canónico. Ejemplo mínimo:

```markdown
# Runbook — respuesta a secreto filtrado

## 0. Confirmar hallazgo
Verifica que no es FP: ¿formato real del proveedor? ¿fuera de tests/fixtures?

## 1. Rotar el secreto (prioridad absoluta)
En el dashboard del proveedor: revocar, emitir nuevo, publicar en el gestor de
secretos. Esta accion reduce el blast radius a cero hacia adelante.

## 2. Notificar
Seguridad + stakeholders + (si procede) comms/legal.

## 3. Investigar abuso
Logs del proveedor entre commit_date y rotation_date; cambios de permisos.

## 4. Reescribir historia
`git filter-repo --replace-text replacements.txt` sobre un clone fresh.
Alternativa: BFG Repo-Cleaner para repos grandes.

## 5. Force-push coordinado
Anunciar al equipo que re-clone; sin esto, los clones viejos reintroducen el secreto.

## 6. Invalidar cachés
Soporte GitHub para forks/PR snapshots si procede.

## 7. Post-mortem
Por que entro, que control fallo, que anadir (push protection, trufflehog --only-verified, etc.).
```

## Decisiones clave

| Decisión | Por qué |
|----------|---------|
| Allowlist por **path** antes que por regex global | Más auditable; "todo bajo tests/fixtures/" es inspectable |
| `fetch-depth: 0` explícito | Sin esto el workflow degenera a pre-commit (solo último commit) |
| `rotar` antes que `filter-repo` | Rotar es irreversible y hace el valor filtrado inútil; reescribir es cosmético |
| Fakes con `fake`/`FAKE`/`demo` literales | Humanamente obvios + stopwords de gitleaks los filtran por diseño |
