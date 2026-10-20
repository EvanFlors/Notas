# Example 02 — `GITHUB_TOKEN` con mínimo privilegio

## Objetivo

Mostrar el patrón de referencia para los `permissions:` del `GITHUB_TOKEN`:

- **Top-level**: `contents: read` (lectura al propio repo, nada más).
- **Por job**: escalada *explícita* y *comentada* solo donde haga falta.

## Archivos

- `workflow.yml` — workflow con tres jobs:
  - `test` — hereda `contents: read` (no escala nada).
  - `comment-pr` — escala a `pull-requests: write` (justificado en comentario).
  - `publish-release-notes` — escala a `contents: write` (justificado) para crear un release draft.

## Cómo leerlo

Fijate en tres cosas:

1. El bloque `permissions:` **top-level** aparece una vez y es la base.
2. Cada `permissions:` por job **reemplaza completamente** al top-level dentro de ese job (no se mergean). Por eso cada job que escala tiene que repetir también los permisos base que necesita (`contents: read`).
3. Cada escalada va acompañada de un **comentario** que explica para qué. Ese comentario es el audit trail más barato posible.

## Qué NO hacer

Patrones equivalentes a tener la casa abierta:

```yaml
# MAL — da todo
permissions: write-all

# MAL — ambiguo; depende del default de la org (puede ser write-all en repos viejos)
# (no declarar permissions en absoluto)
```

## Verificación mental

Preguntá por cada job: "¿este job necesita escribir en el repo?" Si la respuesta es "no", `contents: read` basta. Si la respuesta es "solo para X", escalá *la mínima* key que habilita X (`pull-requests: write`, `issues: write`, `packages: write`, `id-token: write` para OIDC — ver `gha-11`).

Referencia completa de keys y qué permite cada una: GitHub Docs → "Permissions for the `GITHUB_TOKEN`".
