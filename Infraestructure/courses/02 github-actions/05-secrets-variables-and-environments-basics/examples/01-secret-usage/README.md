# Example 01 — Secret vs variable, enmascaramiento en logs

## Objetivo

Mostrar en un workflow mínimo:

1. Cómo se referencia un `secret` (`${{ secrets.X }}`) y una `var` (`${{ vars.Y }}`).
2. Cómo se **enmascara** automáticamente el secreto en los logs.
3. Dos formas en que el enmascaramiento NO protege: cuando el valor se **transforma** antes de imprimirse, y cuando se filtra como parte de un string distinto.

## Archivos

- `workflow.yml` — workflow listo para copiar a `.github/workflows/` en un repo.

## Setup esperado en el repo (NO en este directorio)

Configurar en el repo donde lo pruebes:

- **Secret** llamado `EXAMPLE_SECRET` con cualquier valor (p. ej. `hunter2`).
- **Variable** llamada `EXAMPLE_VAR` con un valor plano (p. ej. `https://api.example.com`).

Settings → Secrets and variables → Actions → New repository secret / New variable.

> No hay secretos reales en este repositorio. Los nombres anteriores son placeholders documentados que vos cargás con valores de prueba en tu propio repo al ejecutarlo.

## Cómo ejecutar

1. Copiá `workflow.yml` a `.github/workflows/demo-secret-usage.yml` en un repo tuyo.
2. Cargá los dos valores arriba.
3. Actions → "demo-secret-usage" → Run workflow (es `workflow_dispatch`).
4. Mirá los logs de cada step.

## Qué observar

| Step | Output esperado | Lección |
|---|---|---|
| `show-var` | `API_URL=https://api.example.com` | `vars` son texto plano, no enmascarado. |
| `show-secret-naive` | `API_TOKEN=***` | El filtro reemplaza el valor literal por `***`. |
| `transform-and-leak` | El valor en mayúsculas aparece **sin enmascarar** | El filtro trabaja por string exacto; transformarlo lo "libera". |
| `check-length-leak` | Longitud real impresa | Metadatos del secreto (longitud, hash, presencia) **no** se enmascaran. |

## Conclusión

- El enmascaramiento es una red de seguridad **para errores no maliciosos** (un `echo` accidental).
- No es un control contra alguien con permiso de editar el workflow — ese tipo de amenaza se mitiga con CODEOWNERS, protected branches y revisión obligatoria de workflows (`gha-13`).
- `vars` existe precisamente para no abusar de `secrets`: la URL no es sensible, usala como var y la vas a poder debuggear.
