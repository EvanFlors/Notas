# Actividad 01 — Cablear el pipeline de CI (lint + test + SAST + SCA + secret scan)

## 1. Identificacion

- **ID:** `cap-03-01-wire-up-ci`
- **Tecnologia:** capstone
- **Modulo:** `03-ci-lint-test-sast-sca-secret-scan`
- **Dificultad:** intermediate
- **Duracion estimada:** 75 min
- **Tipo:** guided-lab

## 2. Contexto

Hasta ahora el repo del capstone tiene codigo (etapa 1) y tags/changelog (etapa 2). Ningun robot verifica calidad ni seguridad en cada commit. En esta actividad conectas un pipeline de GitHub Actions con seis trabajos independientes y validas que los hallazgos lleguen al tab Security del repo.

## 3. Objetivos

- Portar `ci.yml` y `pr.yml` al repo del capstone del estudiante.
- Correr los seis jobs (`lint`, `test`, `sast`, `sca`, `secret-scan`, `aggregate-sarif`) y entender el output de cada uno.
- Identificar y arreglar un hallazgo intencional de bandit (ejemplo: `subprocess.run(..., shell=True)`).
- Verificar que los SARIF agregados sean visibles en Code Scanning.

## 4. Prerrequisitos

- Git, Python 3.12.
- Repo propio con la app de etapa 1-2 ya pushada a GitHub.
- (Opcional) [`act`](https://github.com/nektos/act) para correr los jobs localmente.
- Permisos para habilitar Actions y Code Scanning en el repo.
- **Costo:** $0 (GHA free tier).

## 5. Instrucciones

### Paso 0 — Preparar workspace

```bash
export WORK="/tmp/cap-03-01"
rm -rf "$WORK" && mkdir -p "$WORK" && cd "$WORK"
```

### Paso 1 — Copiar los workflows y configs

Desde la raiz de esta etapa:

```bash
cp -r \
  ../../../projects/capstone/stages/03-ci-lint-test-sast-sca-secret-scan/.github \
  ../../../projects/capstone/stages/03-ci-lint-test-sast-sca-secret-scan/pyproject.toml \
  ../../../projects/capstone/stages/03-ci-lint-test-sast-sca-secret-scan/.gitleaks.toml \
  "$WORK/"
```

### Paso 2 — Crear fichero con hallazgo intencional

En `$WORK/app/insecure_demo.py`:

```python
"""Fichero intencional con un hallazgo bandit para la actividad."""
import subprocess


def run_cmd(cmd: str) -> int:
    # BAD: shell=True con input no sanitizado. Bandit lo marca como B602.
    return subprocess.run(cmd, shell=True, check=False).returncode
```

### Paso 3 — Correr validator

```bash
bash tests/validate.sh
```

El validator comprueba que los workflows existan, que sean YAML parseable, que el `pyproject.toml` tenga las secciones esperadas, y que el `.gitleaks.toml` tenga el `[allowlist]`.

### Paso 4 — Arreglar el hallazgo

Reescribe `run_cmd` sin `shell=True` (recibe una lista en lugar de string). Vuelve a correr bandit local:

```bash
pip install "bandit[sarif]"
bandit -r app
```

Debe salir limpio.

### Paso 5 — Push y revisar Code Scanning

```bash
git add . && git commit -m "ci: wire up stage 3 pipeline"
git push
```

Ver el run en Actions y los hallazgos en **Security → Code scanning alerts**.

## 6. Resultado esperado

- `tests/validate.sh` termina con `RESULT: PASS` (0 fails).
- Los seis jobs del workflow pasan en GitHub.
- SARIF visibles en Code Scanning.

## 7. Criterios de aceptacion

- Workflows existen y son YAML valido.
- `pyproject.toml` declara `[tool.ruff]`, `[tool.mypy]` y `[tool.pytest.ini_options]`.
- `.gitleaks.toml` existe y tiene `[allowlist]`.
- Ningun secreto real en el repo.

## 8. Validacion

```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexion

- ¿Por que los jobs corren en paralelo en vez de secuencial?
- ¿Que gana usar OIDC (`id-token: write`) en `aggregate-sarif` aunque hoy no suba a cloud?
- ¿Que hace `concurrency: cancel-in-progress`? ¿Cuando podria morderte?
- ¿Por que SAST y SCA no fallan el build pero igual suben SARIF?

## 10. Extensiones

- Agregar un job de `trivy fs` que escanee el filesystem del repo y suba SARIF tambien.
- Hacer que `pr.yml` publique como check status el `diff-cover` como required.
- Firmar el commit con `gitsign` (sigstore) y verificar en el pipeline.

## 11. Limpieza

```bash
rm -rf /tmp/cap-03-01
```

En GitHub, si quieres resetear: `git rm -r .github/workflows && git commit -m "chore: drop ci" && git push`.
