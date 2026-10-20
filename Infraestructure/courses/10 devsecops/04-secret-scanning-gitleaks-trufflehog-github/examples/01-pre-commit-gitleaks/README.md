# Ejemplo 01 — Pre-commit con gitleaks

Mínimo hook pre-commit que corta un commit si introduce patrones de secretos.

## Archivos del ejemplo (ilústralos — no se ejecutan en el repo del curso)

`.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks
        name: gitleaks (staged changes)
        entry: gitleaks protect --staged --redact --verbose
```

`.gitleaks.toml`:

```toml
title = "proyecto X — gitleaks"

[extend]
useDefault = true

[allowlist]
description = "Fixtures de test con claves evidentemente falsas"
paths = [
  '''tests/fixtures/.*''',
  '''docs/examples/.*''',
]
# Permitir strings que empiecen por 'sk_fake_' o 'ghp_FAKE'
regexes = [
  '''sk_fake_[A-Za-z0-9_]+''',
  '''ghp_FAKE[A-Za-z0-9]+''',
]
stopwords = [
  "example",
  "fake",
  "dummy",
  "placeholder",
]
```

## Flujo

```bash
# 1. instalar el framework una vez
pip install pre-commit
# o: brew install pre-commit

# 2. en el repo
pre-commit install   # engancha .git/hooks/pre-commit

# 3. probarlo
echo "AWS_KEY = 'AKIAFAKEEXAMPLE1234'" >> app.py   # <-- fake obvio
git add app.py
git commit -m "test leak"
# gitleaks debería imprimir el hallazgo y abortar el commit
```

## Puntos a observar

- **`gitleaks protect --staged`** escanea solo lo que vas a commitear, no la historia. Es rápido (ms).
- `--redact` evita que el valor del secreto quede en el log del hook (importante: el output del hook puede ir a CI logs).
- Si el desarrollador fuerza con `--no-verify`, el pre-commit se salta. Por eso **también** hace falta CI (ejemplo 02).
- El `.pre-commit-config.yaml` se commitea; el estado "instalado" (`.git/hooks/pre-commit`) no — cada clon necesita correr `pre-commit install`. Añadirlo al `make bootstrap` del proyecto es la mitigación.

## Falsos positivos esperados y cómo tratarlos

| FP típico | Tratamiento |
|-----------|-------------|
| Fixtures `tests/fixtures/stripe_webhook.json` | `allowlist.paths` por carpeta |
| Documentación con `AKIA` ejemplo | `allowlist.paths` por `docs/` |
| Clave generada por `make dev` localmente | **No commitearla.** `.gitignore` + regen por desarrollador |
| String aleatorio con alta entropía (hash, UUID) | Añadir `stopwords` o, si es puntual, `# gitleaks:allow <razón>` |
