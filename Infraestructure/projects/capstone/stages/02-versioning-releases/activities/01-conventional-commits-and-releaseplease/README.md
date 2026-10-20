# Actividad `cap-02-01` — Montar release-please + Conventional Commits

**Tipo:** independent · **Nivel:** intermediate · **Duración:** ~90 min

## Objetivo

Convertir la app FastAPI de la Etapa 1 en un proyecto con **releases
automatizados**: cada `feat:`/`fix:` empujado a `main` abre un **Release PR**
mantenido por `release-please`, y al mergearlo nace un tag `vX.Y.Z` + GitHub
Release, con `CHANGELOG.md` actualizado.

No hay guión paso a paso: te damos el estado inicial (`starter/`) y los
criterios automatizados (`tests/validate.sh`). Decides el orden.

## Estado inicial (`starter/`)

- `app/__init__.py` con `__version__ = "0.0.0"`.
- `pyproject.toml` mínimo con `version = "0.0.0"`.
- `package.json` sin dependencias instaladas.

Copia la carpeta a tu workspace:

```bash
cp -R starter/ /tmp/cap-02-01
cd /tmp/cap-02-01
```

## Entregables mínimos

Al final, dentro de `/tmp/cap-02-01` deben existir:

- `release-please-config.json` — JSON válido, con `release-type: "python"`.
- `.release-please-manifest.json` — JSON válido con una sola entrada `"."`.
- `commitlint.config.js` — extiende `@commitlint/config-conventional`.
- `.husky/commit-msg` — ejecutable, invoca `commitlint --edit`.
- `.gitmessage` — plantilla con la lista de tipos y la nota de `BREAKING CHANGE`.
- `.github/workflows/release-please.yml` — usa
  `googleapis/release-please-action@v4`.
- `CHANGELOG.md` — nace con cabecera `# Changelog`.
- `notas-releases.md` — tus respuestas a: ¿por qué el primer `feat:` da
  `0.1.0`?, ¿cuándo salta a `1.0.0`?, ¿qué footer dispara `major`?

## Verificación

```bash
bash tests/validate.sh /tmp/cap-02-01
```

El script corre `tests/smoke.sh` **dos veces** para confirmar que el setup es
idempotente (no se rompe al re-aplicarlo).

## Pistas progresivas

1. Mira los archivos de referencia en el nivel de la etapa
   (`projects/capstone/stages/02-versioning-releases/`): puedes copiarlos.
2. Para habilitar husky local: `npm pkg set scripts.prepare="husky"` + `npm i -D
   husky @commitlint/{cli,config-conventional}` y luego `npx husky init`.
3. El manifest arranca en `"0.0.0"` para que el primer `feat:` suba a `0.1.0`
   (porque `bump-minor-pre-major: true`).
