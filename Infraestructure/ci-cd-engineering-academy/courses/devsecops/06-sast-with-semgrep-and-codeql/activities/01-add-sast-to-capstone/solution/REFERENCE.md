# REFERENCE — sec-06-01-add-sast-to-capstone

> Modelo de solución. No es la única correcta — es un punto de comparación.

## 1. `src/app.py` — las 3 vulnerabilidades plantadas

```python
# src/app.py
import hashlib
import subprocess
import requests


def fetch(url: str) -> str:
    # VULN 1: no timeout — peer lento cuelga el worker.
    resp = requests.get(url)
    return resp.text


def integrity_tag(data: bytes) -> str:
    # VULN 2: md5 no es resistente a colisiones. Para integridad usar sha256.
    return hashlib.md5(data).hexdigest()


def run_user_command(cmd: str) -> int:
    # VULN 3: shell=True con input externo. Comando injection.
    return subprocess.run(cmd, shell=True).returncode
```

```python
# src/safe.py — contraste
import hashlib
import requests


def fetch(url: str) -> str:
    return requests.get(url, timeout=5).text


def integrity_tag(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()
```

## 2. `.github/workflows/semgrep.yml`

Idéntico a `examples/01-semgrep-ci/README.md`, con `on.pull_request.branches: [main]`.

## 3. `.github/workflows/codeql.yml`

Idéntico a `examples/02-codeql-github-advanced-security/README.md`, matriz `languages: [python]`.

## 4. `TRIAGE.md` — modelo

Mínimo 10 findings. Ejemplo (los 3 reales + 7 inventados plausibles):

```
# TRIAGE — sec-06-01

| # | Rule ID                                  | File:Line        | Decision        | Justificación |
|---|------------------------------------------|------------------|-----------------|---------------|
| 1 | python.lang.security.audit.subprocess-shell-true | src/app.py:16    | fix             | shell=True con input externo → injection. Usar lista de args. |
| 2 | B303 (bandit)                            | src/app.py:11    | fix             | md5 para integridad. Migrar a sha256. |
| 3 | python.requests.best-practice.use-timeout | src/app.py:7     | fix             | Añadir timeout=5 o wrapper interno. |
| 4 | B101 assert_used                          | tests/test_x.py:3| false-positive  | Está en test. Bandit no distingue. |
| 5 | python.flask.security.audit.xss          | src/views.py:22  | suppress        | Output ya pasa por `markupsafe.escape`. Comentario `# nosemgrep: ... — razón: escape upstream`. |
| 6 | B404 subprocess_import                    | src/app.py:2     | false-positive  | Solo importar subprocess no es peligroso. |
| 7 | python.lang.security.audit.hardcoded-password | src/fixtures.py:4 | false-positive | Fixture de test. Mover a `tests/` para que la regla no triggerear. |
| 8 | B105 hardcoded_password_string           | src/config.py:9  | fix             | Mover a env var y secret manager (sec-02). |
| 9 | python.lang.security.audit.insecure-deserialization | src/jobs.py:14 | fix             | `pickle.loads` sobre bytes de cola. Migrar a JSON. |
| 10| python.lang.security.audit.insecure-random | src/token.py:8 | fix             | `random.randint` para token. Usar `secrets.token_hex`. |
```

## 5. Decisiones clave

- **CodeQL en nightly + PR** (no solo nightly): sin PR, el finding aparece ya mergeado.
- **Semgrep ERROR → bloqueante, WARNING → comment-only**: evitar fatiga.
- **Toda `nosemgrep` con razón**: sin razón, no se mergea.
- **El `codeql.yml` queda sin ejecutar en esta actividad**: lo verificas en el repo real cuando lo pushees.
