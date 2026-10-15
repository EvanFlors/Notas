# Ejemplo 03 — Pinnear todas las actions a SHA + Dependabot

## Concepto que demuestra

El patrón recomendado de **supply chain de actions**:
1. **Todas** las actions (oficiales, de vendors de confianza, de terceros) pinneadas a **SHA de 40 caracteres**.
2. Comentario con la versión legible al lado (`# v4.2.2`).
3. `.github/dependabot.yml` con `package-ecosystem: github-actions` para que los PRs de actualización lleguen semanalmente y mantengan ambos (SHA y comentario) al día.

## Contexto

Un `git tag` es **mutable**. Un atacante con write access al repo de la action puede reescribir `v4` apuntando a un commit malicioso; cualquier workflow que use `uses: owner/repo@v4` empezará a ejecutar código nuevo sin cambiar ninguna línea. Esto no es hipotético: ocurrió a escala masiva en **`tj-actions/changed-files` en marzo 2025**, afectando ~23 000 repos. Los repos que pinneaban por SHA **no fueron afectados**.

Pinnear a SHA elimina el vector por completo (el commit es inmutable). El coste es legibilidad y actualizaciones manuales — ambos resueltos por el comentario y Dependabot respectivamente.

## Objetivo

- Workflow donde **toda** `uses:` tiene formato `owner/repo@<40-hex>  # <version>`.
- `.github/dependabot.yml` que programe actualizaciones semanales del `github-actions` ecosystem con grouping para minor/patch.

## Archivos

- `workflow.yml` — ejemplo con 4 actions distintas (oficial, vendor, tercero, propia).
- `dependabot.yml` — a copiar a `.github/dependabot.yml`.

## Puntos finos

- Para resolver un tag a SHA desde la CLI:
  ```bash
  gh api /repos/actions/checkout/git/refs/tags/v4.2.2 --jq .object.sha
  # 11bd71901bbe5b1630ceea73d27597364c9af683
  ```
- Para tags **anotados** (con mensaje), hay que seguir una indirección:
  ```bash
  TAG_OBJ=$(gh api /repos/OWNER/REPO/git/refs/tags/vX.Y.Z --jq .object.sha)
  gh api /repos/OWNER/REPO/git/tags/$TAG_OBJ --jq .object.sha
  ```
- Dependabot reconoce el patrón `uses: owner/repo@<SHA>  # vX.Y.Z` y actualiza **ambos** campos al abrir un PR. Si rompes el formato del comentario, dejará de actualizar el comentario (pero sí la SHA).
- **Composite / reusable workflows internos del mismo repo** (`uses: ./.github/actions/foo`) no necesitan pin: viven en el mismo commit del workflow.
- **Actions internas de otro repo de la misma org** (`uses: myorg/action@v1`) **sí** necesitan pin: tu org también puede ser comprometida.

## Verificación

```bash
# ¿Alguna action sin pin a SHA?
grep -rnE 'uses: .+@(v[0-9]+(\.[0-9]+)*|main|master|HEAD)$' .github/workflows/
# → vacío = todas pinneadas
```

Y en el log de un run: GHA imprime el SHA resuelto para cada `uses:`. Con pin a SHA, log y YAML coinciden siempre.

## Interpretación

- Pin a SHA es **el único mecanismo** que da inmutabilidad real a nivel action.
- Dependabot cierra la deuda operativa: en vez de rebuscar SHAs cada N semanas, el equipo revisa PRs como cualquier otro cambio.
- Costo total: 1 línea de comentario extra por action + 1 archivo YAML de Dependabot.

## Errores frecuentes

- "Pinneé la SHA pero copié del release notes del maintainer y era otra" → verifica siempre con `gh api`.
- `uses: owner/repo@<SHA>` sin comentario → funcional, pero ilegible para humanos y Dependabot pierde el contexto de versión.
- Olvidar pinnear la propia composite action del equipo → es tu repo, pero sigue siendo un target.
- `package-ecosystem: github-actions` **sin** `directory: "/"` → Dependabot busca workflows en `/` por default; para monorepos con subdirectorios de actions, añadir una entrada por path.

## Referencia

- <https://docs.github.com/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions>
- <https://docs.github.com/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot-yml-file#package-ecosystem>
- Advisory del incidente `tj-actions/changed-files` (2025).
