# Capstone — Etapa 3: CI con lint, test, SAST, SCA y secret scan

> Prerrequisitos cerrados: etapa 1 (app FastAPI + tests + pre-commit) y etapa 2 (versionamiento + releases).
>
> Esta etapa agrega un pipeline de GitHub Actions que corre, en cada push y PR, un abanico de controles de calidad y seguridad, y publica los hallazgos en el panel de **Code Scanning** de GitHub via SARIF.

---

## 1. Resumen de la etapa

- **Objetivo.** Construir un pipeline CI reproducible que falle rápido ante problemas de estilo, tipos, pruebas, vulnerabilidades conocidas, patrones inseguros o secretos filtrados; y centralizar los hallazgos en Code Scanning.
- **Delta vs etapa 2.** Antes el repo solo tenía tags y changelog manual. Ahora, cada commit atraviesa una tubería CI con seis trabajos independientes (`lint`, `test`, `sast`, `sca`, `secret-scan`, `aggregate-sarif`) y un workflow secundario orientado a PR (`pr.yml`) con comentarios y gates.
- **Fuera de scope.** Build de imagen OCI, firma, SBOM, container scan, despliegues — todo eso llega en etapa 5. Tampoco se publica aun a PyPI ni se corre carga.

## 2. Arquitectura al cierre de esta etapa

```
+-----------------------+      push / PR      +-----------------------------+
|  Dev workstation      |  ---------------->  |  GitHub repo (main + PRs)   |
|  (ruff / pytest OK)   |                     +--------------+--------------+
+-----------------------+                                    |
                                                             | triggers
                                                             v
                              +------------------------------+------------------------------+
                              |                       GitHub Actions                        |
                              |                                                             |
                              |  ci.yml                              pr.yml                 |
                              |  +--------+ +--------+ +--------+    +----------------+     |
                              |  | lint   | | test   | | sast   |    | pr-title-lint  |     |
                              |  | ruff   | | pytest | | bandit |    | changed-files  |     |
                              |  | mypy   | | cov    | |  sarif |    | diff-cov       |     |
                              |  +---+----+ +---+----+ +---+----+    +--------+-------+     |
                              |      |          |          |                   |            |
                              |      v          v          v                   v            |
                              |  +--------+ +------------+ +------------------------+       |
                              |  | sca    | | secret-scn | | aggregate-sarif        |       |
                              |  | pip    | | gitleaks   | | upload to Code         |       |
                              |  | audit  | |  sarif     | | Scanning (OIDC-aware)  |       |
                              |  +---+----+ +------+-----+ +-----------+------------+       |
                              |      |             |                   |                    |
                              |      +------+------+----------+--------+                    |
                              |             |                 |                             |
                              |             v                 v                             |
                              |      SARIF artifacts    GitHub Code Scanning alerts         |
                              +-------------------------------------------------------------+
```

**Resource list.** Nada en cloud. Solo:

- Un repositorio GitHub con Actions habilitado.
- Permisos `security-events: write`, `id-token: write` (OIDC), `contents: read`, `pull-requests: write`.
- Branch protection en `main` que exige los jobs `lint`, `test`, `sast`, `sca`, `secret-scan` como required checks.

## 3. Prerrequisitos verificados

- [ ] Etapa 1: existe `app/` con FastAPI, `tests/` con pytest, `pre-commit` configurado.
- [ ] Etapa 2: tags SemVer y `CHANGELOG.md`.
- [ ] `pyproject.toml` del repo acepta nuevas secciones `[tool.ruff]`, `[tool.mypy]`, `[tool.pytest.ini_options]` o se puede fusionar con el existente.
- [ ] Repo GitHub con permisos para habilitar Code Scanning (requiere Actions + Security tab).

Si algo falta, cerrar la etapa correspondiente antes de continuar.

## 4. Implementación guiada

### Paso 1 — Configurar herramientas en `pyproject.toml`

Agrega al `pyproject.toml` las secciones `[tool.ruff]` (lint + format), `[tool.mypy]` (estricto en modulos de app), y `[tool.pytest.ini_options]` (cobertura mínima 80%). Ver archivo materializado en esta etapa.

**Por qué.** Centralizar la configuración en `pyproject.toml` evita que CI y local diverjan: el mismo comando corre en ambos lados.

### Paso 2 — Añadir `ci.yml`

Crear `.github/workflows/ci.yml` con seis jobs. Decisiones:

- **Jobs independientes en paralelo** (fail-fast desactivado): un lint roto no bloquea ver los otros hallazgos.
- **OIDC (`id-token: write`)** se habilita en `aggregate-sarif` para poder subir reportes firmados y, mas adelante en etapa 5, usar el mismo mecanismo para registry.
- **SARIF uniforme.** Bandit y Gitleaks emiten SARIF nativamente; `pip-audit` se convierte via `pip-audit -f sarif`. Todos se suben con `github/codeql-action/upload-sarif@v3`.

### Paso 3 — Añadir `pr.yml`

Workflow adicional que solo corre en `pull_request`:

- Lint del titulo del PR (Conventional Commits) para alinear con etapa 2.
- Diff coverage (solo lineas tocadas por el PR) — mas util que coverage global.
- Comentario con tabla resumen de hallazgos.

### Paso 4 — Añadir `.gitleaks.toml`

Reglas custom + allowlist de fixtures de test. Nunca se usan secretos reales; los dummies llevan prefijo `dummy_`.

### Paso 5 — Actividad del estudiante

Correr `activities/01-wire-up-ci/` (ver seccion 5).

## 5. Actividades del estudiante

| ID | Tipo | Duracion | Descripcion |
|----|------|----------|-------------|
| `cap-03-01-wire-up-ci` | guided-lab | 75 min | Clonar los workflows a su propio repo, ejecutar los seis jobs localmente con `act`, corregir el fallo intencional de bandit, y verificar que el SARIF aparezca en Code Scanning. |

## 6. Entregables

- `.github/workflows/ci.yml` y `.github/workflows/pr.yml` versionados.
- `pyproject.toml` con configs de ruff/mypy/pytest.
- `.gitleaks.toml` en la raiz.
- Primer run verde en GitHub Actions (badge en el README del repo del estudiante).
- Captura de pantalla del panel **Security → Code scanning alerts** mostrando los hallazgos agregados.
- ADR corto (opcional) justificando la eleccion de pip-audit vs safety.

## 7. Pruebas y criterios de aceptacion

Automaticos:

- `bash activities/01-wire-up-ci/tests/validate.sh` termina con `RESULT: PASS`.
- Los seis jobs del workflow pasan en el repo del estudiante (badge verde).
- SARIF visible en el tab Security del repo.
- `ruff check .` y `mypy app/` corren sin errores locales.
- `pytest --cov=app --cov-fail-under=80` pasa.

Calidad:

- Ningun secreto real en el repo (verificado por gitleaks).
- Workflow usa versiones fijas por SHA o por tag mayor (`@v3`, no `@main`).
- `permissions:` declarado al nivel del workflow con el minimo necesario.

## 8. Costos y limpieza

- **Costo.** $0. GitHub Actions es gratis hasta 2000 minutos/mes en repos publicos.
- **Limpieza.** No hay recursos externos. Para dejar el repo limpio:

```bash
# Revertir workflows en el repo del estudiante (opcional):
git rm -r .github/workflows
git commit -m "chore: remove ci workflows"
```

**Guard-rails.** Habilitar notificaciones de Actions para no agotar minutos; limitar `on:` a `push: branches: [main]` + `pull_request:` para evitar runs por tag.

## 9. Riesgos y mitigaciones

| Riesgo | Mitigacion |
|--------|------------|
| Falsos positivos de bandit bloquean merges | Marcar hallazgos conocidos con `# nosec BXXX` justificado y revisar en PR, no silenciar global. |
| `pip-audit` lento por resolver dependencias en cada run | Cachear `~/.cache/pip` y usar `actions/setup-python` con `cache: pip`. |
| Gitleaks ruidoso con dummies de test | Usar `[allowlist]` en `.gitleaks.toml` con rutas y regex explicitos. |

Hints progresivos para estudiantes atascados: primero reproducir el fallo local con `act -j <job>`; segundo leer el SARIF crudo (`jq` sobre el artifact); tercero comparar con el solution.

## 10. Puente con la siguiente etapa

Habilitada por esta etapa: contrato de calidad verificable. La etapa 4 (**Dockerizacion + Compose dev**) va a asumir que `pytest` pasa y que `pip-audit` esta corriendo sobre `requirements.txt` o `pyproject.toml`.

Dejar corriendo: nada; los workflows se disparan por evento. Apagar: nada.

**Cliffhanger.** El pipeline hoy prueba el codigo, pero no la imagen que va a produccion. ¿Como garantizamos que la imagen OCI construida tiene las mismas dependencias auditadas que el repo? La etapa 4 abre el frente de containerizacion y la 5 cierra el loop con SBOM y firma.
