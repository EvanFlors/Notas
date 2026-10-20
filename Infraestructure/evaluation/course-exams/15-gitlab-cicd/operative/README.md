# Validación operativa — GitLab CI/CD exam

Scripts de validación **estructural** del entregable del candidato. **No requieren** servidor GitLab, runners ni red: solo parsean el YAML del `.gitlab-ci.yml` entregado y aplican checks `yq`/`grep` sobre su estructura.

## Requisitos

- `bash` 4+ (macOS: `brew install bash`)
- `python3` con `pyyaml` (`pip install pyyaml`) **o** `yq` v4+ (`brew install yq`)
- `grep`, `awk` (base del sistema)

El script detecta cuál de `yq` / `python3+pyyaml` está disponible y usa el que encuentre.

## Uso

Desde esta carpeta:

```bash
./validate.sh <ruta-al-directorio-entrega>
```

Ejemplo:

```bash
./validate.sh ../entrega
```

Salida esperada: una lista `PASS`/`FAIL` por check, red flags detectadas en bloque separado, y un score agregado `/100` que **no es** la nota final (el instructor pondera con la rúbrica de `EXAM.md`).

## Qué valida

Agrupado por requisito del enunciado (ver `EXAM.md` § B):

1. **Parseo YAML** válido de `.gitlab-ci.yml`, `.gitlab/ci/jobs.yml` y `.gitlab/components/scan/template.yml`.
2. **Stages** declarados en orden `build, test, scan, package, deploy`.
3. **`workflow:` rules** con `merge_request_event`, `main`, y bloqueo de `[skip ci]`.
4. **Variables globales** con `PYTHON_IMAGE` **pinneado por digest** (`@sha256:`).
5. **DAG `needs:`**: `test_unit`/`test_lint` tras `build`; `package` solo tras `test_unit`.
6. **`parallel: matrix:`** en `test_unit` con `PY_VERSION` y `SHARD`.
7. **`id_tokens:`** en `deploy_prod` con `aud` apuntando a STS AWS.
8. **Review App**: `environment:` con `on_stop:` y job `stop_review` con `action: stop`.
9. **Prod protegido**: `deploy_prod` con `when: manual`.
10. **Scanners**: ≥3 `include:template:` del catálogo `Jobs/*.gitlab-ci.yml`.
11. **Reutilización**: `include: local:` a `.gitlab/ci/jobs.yml`, uso de `extends:` y existencia del Component con `spec: inputs:`.

### Red flags detectadas (invalidan sección)

- `only:` / `except:` presente.
- `image:` sin tag o `:latest`.
- `curl ... | bash` en scripts.
- `privileged: true` sin TLS adyacente.
- AWS access key literal (`AKIA[0-9A-Z]{16}`) o secretos en `variables:` planas que parezcan tokens.
- Trust policy OIDC sin `sub` claim en comentarios (señal de pinning).

## Guía de corrección (`CORRECTION.md`)

Pasos del instructor para puntuar según la rúbrica cuando el entregable **parsea pero no cumple**. Ver `CORRECTION.md` adjunto.
