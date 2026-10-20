# Actividad 01 — Pipeline completo de secret scanning

## 1. Identificación

- **ID:** `sec-04-01-full-pipeline-secret-scan`
- **Tecnología:** `devsecops`
- **Módulo:** `04-secret-scanning-gitleaks-trufflehog-github`
- **Dificultad:** intermediate
- **Duración estimada:** 60–80 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a dejar un repositorio nuevo con las **tres capas** del secret scanning funcionando: pre-commit local, CI que escanea historia completa, y un runbook de respuesta a incidente. Es la base que se asume en todos los módulos posteriores del curso DevSecOps.

Para hacerlo seguro y reproducible: todos los "secretos" que uses son **evidentemente falsos** (`sk_fake_...`, `ghp_FAKEabc...`). Nunca pruebes esto con claves reales — Git conserva todo en la reflog.

## 3. Objetivos

Al terminar deberías tener en `/tmp/sec-04-full-pipeline/`:

1. Un repo git inicializado con `main`.
2. `.pre-commit-config.yaml` que invoque `gitleaks protect` sobre staged.
3. `.gitleaks.toml` con `[extend] useDefault = true`, un `[allowlist]` por path (`tests/fixtures/`), y stopwords (`fake`, `example`, `dummy`).
4. `.github/workflows/secret-scan.yml` que use `actions/checkout@v4` con `fetch-depth: 0` y corra `gitleaks-action@v2`.
5. `tests/fixtures/sample.env` con un token **fake obvio** (`ghp_FAKEabc0000demo`) que la allowlist deja pasar.
6. `RUNBOOK.md` con el proceso de respuesta ordenado (rotar → notificar → investigar → reescribir historia → re-clone → post-mortem).

## 4. Prerrequisitos

- `git` y `bash`.
- Opcional: `gitleaks` instalado localmente (brew/arch/apt o binario de releases). Si no está, la validación lo detecta y hace **skip** del smoke test de detección — el resto se evalúa igual.
- Opcional: Python + `pre-commit` para probar el hook end-to-end.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/sec-04-full-pipeline/{tests/fixtures,.github/workflows}
cd /tmp/sec-04-full-pipeline
git init -q -b main
```

### 5.2 Escribir `.pre-commit-config.yaml`

Debe referenciar el repo oficial `https://github.com/gitleaks/gitleaks` y un `rev:` (ej. `v8.21.2`) con un hook `id: gitleaks`. Mira `examples/01-pre-commit-gitleaks/README.md` del módulo.

### 5.3 Escribir `.gitleaks.toml`

Secciones requeridas:
- `title`
- `[extend] useDefault = true`
- `[allowlist]` con `paths` (al menos `tests/fixtures/.*`) y `regexes` para los fakes (`sk_fake_...`, `ghp_FAKE...`).
- `stopwords = ["example", "fake", "dummy", "placeholder"]`.

Cada entrada debe tener comentario de justificación.

### 5.4 Escribir el workflow CI

`.github/workflows/secret-scan.yml` con:
- `on: [push, pull_request]`.
- `actions/checkout@v4` + `fetch-depth: 0`.
- `gitleaks/gitleaks-action@v2` (o equivalente que corra `gitleaks detect` sobre la historia).

### 5.5 Fixture con fake obvio

```bash
cat > tests/fixtures/sample.env <<'EOF'
# This file is a TEST FIXTURE. Values are intentionally fake.
GITHUB_TOKEN=ghp_FAKEabc0000demo000000000000000000000
STRIPE_SECRET=sk_fake_live_FAKEstripe00000000000000demo
EOF
```

Debe estar bajo `tests/fixtures/` para que la allowlist por path lo cubra.

### 5.6 Redactar `RUNBOOK.md`

Debe cubrir, con headings numerados:

1. Confirmar que no es falso positivo.
2. **Rotar** el secreto (prioridad absoluta).
3. Notificar a seguridad / stakeholders.
4. Investigar logs del proveedor por posible abuso.
5. Reescribir historia con `git filter-repo` (o BFG).
6. Coordinar `re-clone` del equipo (force-push rompe clones).
7. Post-mortem con causas y controles añadidos.

Keywords que debe mencionar: `rotar`, `filter-repo` o `bfg`, `force-push` o `force push`, `post-mortem`, `blast radius`.

### 5.7 Commit inicial

```bash
git add .
git commit -m "chore: bootstrap secret scanning pipeline" -q
```

(Si no tienes `user.name`/`user.email` configurados, defínelos en `/tmp/sec-04-full-pipeline/.git/config` para no polucionar la config global.)

## 6. Resultado esperado

- Validador en verde: `bash tests/validate.sh /tmp/sec-04-full-pipeline`.
- Si tienes `gitleaks` instalado, el smoke test adicional corre `gitleaks detect --no-git --source tests/fixtures/` esperando que la allowlist lo deje pasar.

## 7. Criterios de aceptación

- **Funcionalidad**: validador pasa todas las comprobaciones estructurales.
- **Seguridad**: no hay **ningún** valor que parezca real; todos los fakes incluyen `fake`/`FAKE`/`demo`.
- **Calidad**: cada allowlist tiene comentario; el runbook ordena rotar **antes** de reescribir historia.

## 8. Validación

```bash
bash tests/validate.sh /tmp/sec-04-full-pipeline
```

El script valida estructura, keywords y, si `gitleaks` está disponible, ejecuta un smoke test.

## 9. Preguntas de reflexión

1. Si un desarrollador corre `git commit --no-verify`, ¿qué capa del pipeline lo atrapa?
2. ¿Por qué `fetch-depth: 0` es necesario en el workflow CI? ¿Qué dejarías de ver sin él?
3. Un compañero propone "borrar `tests/fixtures/sample.env` del repo porque gitleaks lo marca a veces". Explica por qué su solución es peor que la allowlist disciplinada.
4. En el runbook, invertir los pasos 2 (rotar) y 5 (reescribir historia) ¿qué consecuencia tiene?

## 10. Limpieza

```bash
rm -rf /tmp/sec-04-full-pipeline
```

El validador también acepta `BASE_DIR` como variable de entorno si prefieres otro path.
