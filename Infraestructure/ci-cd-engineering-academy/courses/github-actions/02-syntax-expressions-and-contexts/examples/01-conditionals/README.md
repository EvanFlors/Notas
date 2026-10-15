# Example 01 — Conditionals (`if:` en jobs y steps)

Workflow que ejercita las combinaciones más comunes de `if:`:

- Un job que solo corre en push a `main`.
- Un job que solo corre en pull_request.
- Un step condicionado por el **resultado** del step anterior.
- Un step que corre **siempre** con `if: always()` (cleanup).
- Un step con `continue-on-error: true` que no rompe el job si falla.

Archivo: `workflow.yml`. Para probarlo, cópialo a `.github/workflows/example-conditionals.yml` en un repo y haz un push y un PR; compara los logs.

## Lectura dirigida

1. Mira `on:`. Dispara en `push` a cualquier rama y en `pull_request` a `main`.
2. Fíjate en el `env:` a nivel workflow: `LOG_LEVEL`.
3. En el job `on-main-push`, `if:` combina `github.ref` y `github.event_name`.
4. En el job `on-pr`, `if:` chequea `github.event_name == 'pull_request'`.
5. Dentro de `on-pr`, el step `advisory-lint` tiene `continue-on-error: true`: aunque falle, el job sigue y acaba verde.
6. El step `report-after-failure` usa `if: failure()`: solo corre si *algo* falló antes en este job.
7. El step `cleanup` usa `if: always()`: corre siempre, incluso si cancelas el run.

## Comando de validación local

```bash
# Si tienes actionlint instalado:
actionlint workflow.yml
```

Es un linter estático; no ejecuta el workflow. Para ejecución local puedes usar [`nektos/act`](https://github.com/nektos/act), pero no es obligatorio para el curso.
