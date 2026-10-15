# Ejemplo 02 — Configuración de Dependabot multi-ecosistema

## Concepto que demuestra

Un `.github/dependabot.yml` **productivo** que cubre varios ecosistemas típicos (Python, GitHub Actions, Docker), agrupa updates para no inundar de PRs, y aplica labels.

## Contexto

Dependabot tiene tres patas:
- **Alerts** — activadas automáticamente en el repo si Dependency Graph está habilitado. No requieren este YAML.
- **Security updates** — PRs automáticos cuando una alerta tiene un fix disponible. Activables en Settings; no requieren este YAML.
- **Version updates** — PRs regulares para subir versiones **aunque no haya vulnerabilidad**. **Requieren** este YAML.

El `dependabot.yml` configura la tercera, y es donde se controla la frecuencia, los grupos, las labels, etc.

## Objetivo

- Habilitar version updates para `pip`, `github-actions` y `docker`.
- Agrupar menores y parches para reducir el ruido.
- Programar los PRs en horario laboral del equipo.

## Archivos

- `dependabot.yml` — a copiar en `.github/dependabot.yml` del repo real.

## Puntos finos a notar

- **`groups:`** convierte 20 PRs sueltos en 1 por categoría. Imprescindible en repos con muchas dependencias.
- **`open-pull-requests-limit`** = control de caudal. 5 es sano; subir si tu equipo revisa rápido.
- **`github-actions` ecosystem** detecta `uses: foo/bar@vX` en tus workflows y los actualiza. Si pinneas por SHA (`@abc123…` + comentario `# v4.2.2`), Dependabot sabe actualizar la SHA conservando el comentario.
- **`schedule.timezone`** usa la zona IANA (p. ej. `Europe/Madrid`). Útil para que los PRs lleguen cuando el equipo está.
- `allow:` / `ignore:` permiten listas blancas/negras muy finas.
- Para **registros privados** (JFrog, nexus, GHCR privado), añadir sección `registries:` + secrets `DEPENDABOT_*`.

## Verificación en GitHub

Tras commitear el archivo:

1. GitHub lo valida (Settings → Code security → Dependabot → version updates).
2. En **minutos** aparecen los primeros PRs si hay versiones nuevas.
3. En `Insights → Dependency graph → Dependabot` puedes ver todos los jobs y por qué un update no se abrió.

## Interpretación

- Dependabot NO decide por ti qué mergear. Mergearlo es parte del PR flow normal (con CODEOWNERS, CI, etc.).
- Buena práctica: **auto-merge** los PRs de parches (`patch`) con `gh pr merge --auto` + ruleset que exige CI verde. Minor y major, revisión manual.

## Errores frecuentes

- Olvidar `version: 2` → el archivo se ignora silenciosamente.
- Pedir `interval: daily` → al tercer día tendrás 50 PRs. Usar `weekly` por default.
- Agrupar `security-updates` dentro de un `group` grande que nadie revisa → ancla crítica detrás de PRs normales. No agrupar nada que sea `security-update`.

## Referencia

- <https://docs.github.com/code-security/dependabot/dependabot-version-updates/configuration-options-for-the-dependabot.yml-file>
