# Example 02 — Contexts dump

Workflow que imprime cada contexto accesible usando `toJSON()`. Útil cuando no sabes qué está disponible donde.

**Importante**: cada contexto se asigna a una **env var** y se imprime como `"$VAR"`, nunca interpolado directo en `run:`. Esto es exactamente el patrón seguro de la sección 10 de la lección, aplicado al depurar.

Archivo: `workflow.yml`.

## Qué vas a ver en los logs

- `github` — el payload completo del evento + metadatos del run (grande).
- `env` — las env vars definidas en el YAML (no las del sistema).
- `vars` — tus repository/organization variables (vacío si no configuraste).
- `secrets` — redactado como `***`; útil solo para confirmar que un secret existe.
- `inputs` — solo para `workflow_dispatch`/`workflow_call`.
- `runner` — `runner.os`, `runner.arch`, `runner.temp`, `runner.tool_cache`.
- `job` — status del job actual.
- `steps` — outputs y conclusion de steps anteriores con `id:`.
- `matrix` / `strategy` — presentes solo si el job usa `strategy.matrix`.

## Uso típico

Copia este workflow a tu repo con un trigger manual:

```bash
cp workflow.yml .github/workflows/dump.yml
git add -A && git commit -m "chore: dump contexts" && git push
gh workflow run dump.yml
gh run watch
```

**Borra el workflow después**. Es ruido en logs y en workflows de producción invita a bugs.
