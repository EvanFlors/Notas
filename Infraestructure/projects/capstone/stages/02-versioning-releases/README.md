# Capstone — Etapa 2: Versionamiento y Releases

> Stack: FastAPI + PostgreSQL (de Etapa 1) + **Conventional Commits**, **SemVer**,
> **release-please**, **commitlint**, **husky**, **GitHub Releases**.
> Entorno: `local-first` (release-please corre en GitHub Actions, pero se puede
> emular con `release-please-cli` localmente).

## 1. Resumen de la etapa

Introducimos un flujo **automatizado y auditable** de versionamiento sobre la
aplicación FastAPI de la Etapa 1. Cada commit a `main` dispara `release-please`,
que agrega los cambios por tipo (`feat`, `fix`, `perf`...), calcula el próximo
**SemVer**, mantiene un `CHANGELOG.md` humano, abre un **Release PR** y, al
mergearlo, crea el **tag anotado** y un **GitHub Release** con notas y assets.

**Delta vs Etapa 1:**

- Nuevos archivos: `release-please-config.json`, `.release-please-manifest.json`,
  `commitlint.config.js`, `.gitmessage`, `.husky/commit-msg`,
  `.github/workflows/release-please.yml`, `CHANGELOG.md`.
- Nueva política: `main` sólo recibe commits que cumplen Conventional Commits
  (bloqueado client-side por husky, server-side por el job `commitlint`).
- Nuevo output: tags `vX.Y.Z` + GitHub Releases + `CHANGELOG.md` siempre al día.

**Fuera de scope (ya se tocará después):**

- Build/push de imagen Docker al tag (Etapa 4–5).
- Firma de release (cosign) y SBOM (Etapa 5).
- Promoción multi-ambiente (Etapa 10).

## 2. Arquitectura al cierre de esta etapa

```text
      ┌──────────────────┐    push feat:/fix:    ┌──────────────────────┐
dev → │ local hooks      │ ────────────────────▶ │ GitHub main branch   │
      │ - .gitmessage    │                       │                      │
      │ - husky commit-  │                       └──────────┬───────────┘
      │   msg → commit-  │                                  │ on: push
      │   lint           │                                  ▼
      └──────────────────┘                       ┌──────────────────────┐
                                                 │ release-please.yml   │
                                                 │  (googleapis action) │
                                                 └──────────┬───────────┘
                                                            │ opens / updates
                                                            ▼
                                                 ┌──────────────────────┐
                                                 │  Release PR          │
                                                 │  - bump SemVer       │
                                                 │  - update CHANGELOG  │
                                                 │  - update manifest   │
                                                 └──────────┬───────────┘
                                                            │ merge
                                                            ▼
                                           ┌─────────────────────────────────┐
                                           │ git tag vX.Y.Z (anotado)        │
                                           │ GitHub Release + notas + assets │
                                           └─────────────────────────────────┘
```

**Entradas**: commits en `main` siguiendo Conventional Commits.
**Salidas**: tags, releases, `CHANGELOG.md`, `.release-please-manifest.json`
sincronizado y (opcional) version bumping en `pyproject.toml`.
**Resource list**: nada en cloud; sólo repo + GitHub Actions minutes.

## 3. Prerrequisitos verificados

- [ ] Etapa 1 cerrada: `app/` FastAPI, `pyproject.toml` con `version = "0.0.0"`,
      `pytest` en verde, pre-commit instalado.
- [ ] Repo publicado en GitHub con rama default `main`.
- [ ] `node >= 20` y `npm` instalados para husky + commitlint.
- [ ] Permiso de `GITHUB_TOKEN` con `contents: write` y `pull-requests: write`
      (default del workflow).

Si falta la app base, cerrar primero la Etapa 1.

## 4. Implementación guiada

> Resumen operativo. El detalle paso a paso vive en
> `activities/01-conventional-commits-and-releaseplease/README.md`.

1. **Semilla de manifest y config** — `.release-please-manifest.json` arranca
   en `"0.0.0"` para que el primer release calcule desde el commit más antiguo.
2. **Config declarativa** — `release-please-config.json` define
   `release-type: python`, cambia `extra-files` para versionar también
   `app/__init__.py` y agrupa secciones del changelog.
3. **Workflow** — `.github/workflows/release-please.yml` dispara en `push` a
   `main` usando `googleapis/release-please-action@v4`.
4. **Guardarraíl local** — `.gitmessage` configurado como template global del
   repo (`git config commit.template .gitmessage`) + `.husky/commit-msg`
   invocando `npx --no-install commitlint --edit $1`.
5. **Guardarraíl server** — job `commitlint` adicional en CI para bloquear PRs
   con títulos no convencionales (apoyado por `wagoid/commitlint-github-action`).
6. **Seed del CHANGELOG** — `CHANGELOG.md` nace vacío pero con cabecera
   `# Changelog` y nota apuntando a release-please como fuente de verdad.

## 5. Actividades del estudiante

| ID | Tipo | Nivel | Descripción |
|----|------|-------|-------------|
| `cap-02-01-conventional-commits-and-releaseplease` | `independent` | intermediate | Materializa toda la pipeline de releases, dispara el primer `feat:` y `fix:`, mergea el Release PR y verifica tag + release en GitHub. |

## 6. Entregables

- Repo con la pipeline configurada (archivos listados en §1).
- Al menos **un** Release PR mergeado produciendo tag `v0.1.0` o `v0.0.1`.
- Captura o enlace del GitHub Release generado.
- Nota (`notas-releases.md`, 1 página) explicando: ¿por qué el primer `feat:`
  produce `0.1.0` y no `0.0.1`?, ¿cuándo salta a `1.0.0`?, ¿qué commit genera
  un bump `major`?

## 7. Pruebas y criterios de aceptación

Automáticos (los corre `tests/validate.sh`):

- [ ] `release-please-config.json` parsea como JSON y tiene `release-type`.
- [ ] `.release-please-manifest.json` parsea y tiene exactamente una entrada.
- [ ] `commitlint.config.js` extiende `@commitlint/config-conventional`.
- [ ] `.husky/commit-msg` existe y es ejecutable.
- [ ] `.github/workflows/release-please.yml` referencia
      `googleapis/release-please-action`.
- [ ] `CHANGELOG.md` existe y contiene cabecera `# Changelog`.
- [ ] `.gitmessage` existe con las secciones mínimas.
- [ ] `smoke.sh` corre dos veces consecutivas con exit 0 (idempotente).

Manual:

- [ ] Un commit `feat(api): ...` sobre `main` abre un Release PR.
- [ ] Al mergearlo se crea tag anotado + GitHub Release.
- [ ] `BREAKING CHANGE:` en el footer dispara un `major`.

## 8. Costos y limpieza

Costos: **$0**. Sólo GitHub Actions minutes del plan free (<2 min por push).

Limpieza:

```bash
# Revertir configuración local sin tocar los artefactos de release:
rm -rf node_modules .husky
git config --local --unset commit.template || true
# Para abandonar la etapa por completo (destruye tags y releases):
gh release list --limit 50 | awk '{print $1}' | xargs -I {} gh release delete {} -y
git tag -l 'v*' | xargs -I {} git push origin :refs/tags/{}
git tag -l 'v*' | xargs -I {} git tag -d {}
```

## 9. Riesgos y mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| El primer Release PR nunca aparece porque los commits previos no son convencionales. | Reescribir el historial de la Etapa 1 (`git rebase -i --root`) o hacer un commit semilla `feat: initial release` después de instalar el workflow. |
| husky bloquea `merge` o `revert` auto-generados. | commitlint ya ignora `Merge`/`Revert` por default (`defaultIgnores: true`). |
| `release-please` abre PR vacío al no detectar commits bumpeables. | Confirmar que los commits llevan tipos listados en `changelog-sections`; usar `chore(release): ...` es inert. |

Si el estudiante se atasca, pistas progresivas en orden:

1. "Mira los logs del workflow en la pestaña Actions."
2. "¿Existe `.release-please-manifest.json` en `main` con `\"0.0.0\"`?"
3. "¿El commit que empujaste empieza por `feat:`, `fix:` o `perf:`?"

## 10. Puente con la siguiente etapa

- **Qué habilita**: tener tags inmutables `vX.Y.Z` permite a la Etapa 3 (CI)
  disparar jobs que correlacionen artefactos con una versión concreta, y a la
  Etapa 4 (Docker) etiquetar la imagen `fastapi-notes:v0.1.0` sin inventar
  convenciones.
- **Qué queda corriendo**: nada; todo vive como configuración en el repo.
- **Cliffhanger**: "Mergeaste el Release PR, pero la imagen Docker todavía se
  etiqueta `latest`. ¿Cómo garantizamos que el pipeline publique
  `fastapi-notes:v0.1.0` **sólo** cuando release-please corte el tag?"
