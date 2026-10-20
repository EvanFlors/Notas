# Actividad 02 — Tratar el template como producto: fixture y CI

## 1. Identificación

- **ID:** `plat-06-02-test-template-in-ci`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-06-templates-and-scaffolder`
- **Dificultad:** intermediate
- **Duración estimada:** 50–70 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Un template sin CI se pudre a los 3 meses: alguien actualiza una acción, otro cambia un comentario y nadie se entera hasta que un developer abre un ticket "el template genera basura". La prevención es el patrón **fixture regenerable**:

1. En el repo del template vive una `fixture/` con el output canónico (lo que sale si rellenas el form con los valores por defecto).
2. En CI, un job: ejecuta el template con los mismos valores → compara con la fixture → `git diff` → si hay diff, el PR del template debe actualizarlo adrede.

Esta actividad implementa el patrón **en local**, usando cookiecutter como análogo del scaffolder (ver `theory/lesson.md` §7). Si no tienes cookiecutter, el validador salta la ejecución pero verifica estructura.

## 3. Objetivos

- Diseñar el flujo "regenerar fixture + diff" como primera línea de defensa.
- Escribir `scripts/regenerate-fixture.sh` reproducible, idempotente, con `--check` para CI.
- Escribir el workflow GHA que invoca el script.
- Comunicar en el README del repo del template cómo mantener la fixture.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` §6 y §7.
- Herramientas: `bash`, `python3`, `diff`. Opcional: `cookiecutter` (si no está, SKIP ejecutable).

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/plat-06-ci
cp -r <ruta-repo>/courses/platform-engineering/06-templates-and-scaffolder/activities/02-test-template-in-ci/starter/* /tmp/plat-06-ci/
cd /tmp/plat-06-ci
```

El starter trae:

```
/tmp/plat-06-ci/
├── cookiecutter.json                 # valores por defecto para la fixture
├── cookiecutter-skeleton/
│   └── {{cookiecutter.project_slug}}/
│       └── ...                       # skeleton Jinja2 (análogo nunjucks)
├── fixture/                          # output esperado (congelado)
│   └── ...
├── scripts/
│   └── regenerate-fixture.sh         # TODO: completar
└── .github/
    └── workflows/
        └── template-ci.yaml          # TODO: completar
```

### 5.2 Completa `scripts/regenerate-fixture.sh`

Requisitos:

- Flag `--check` que **no reescribe** la fixture: la genera en `/tmp/<temp>/`, hace `diff -r fixture/ <temp>/<project>` y sale con `1` si hay diferencias.
- Sin flag, **regenera** la fixture: la borra, re-renderiza y copia al dir `fixture/`.
- Si `cookiecutter` no está instalado, el script imprime `SKIP: cookiecutter not installed` y sale `0` (no es un fallo).
- Debe empezar con `#!/usr/bin/env bash` y `set -eu` (NO `pipefail`).
- Debe limpiar sus temp dirs al terminar.

### 5.3 Completa `.github/workflows/template-ci.yaml`

Requisitos:

- Trigger en `pull_request` y `push` a `main`.
- Un job con pasos: checkout, setup python, pip install cookiecutter, `bash scripts/regenerate-fixture.sh --check`.
- `name:` del workflow descriptivo.

### 5.4 Verifica

```bash
bash <ruta-repo>/courses/platform-engineering/06-templates-and-scaffolder/activities/02-test-template-in-ci/tests/validate.sh /tmp/plat-06-ci
```

El validador:

- Comprueba presencia y permisos de `regenerate-fixture.sh`.
- Comprueba que el script responde a `--check` (ejecuta y verifica exit code 0 cuando la fixture está sincronizada).
- Comprueba la estructura del workflow (triggers, jobs, step que invoca al script).
- Si `cookiecutter` no está, el chequeo ejecutable se marca SKIP.

## 6. Resultado esperado

- `scripts/regenerate-fixture.sh` ejecutable y conforme al contrato.
- Workflow GHA bien formado.
- `bash tests/validate.sh /tmp/plat-06-ci` en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador en verde.
- **Calidad**: `set -eu`, limpieza de temp, SKIP graceful si falta cookiecutter.
- **Reproducibilidad**: tras `./scripts/regenerate-fixture.sh --check`, exit 0 si no hay drift.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-06-ci
```

## 9. Preguntas de reflexión

1. ¿Por qué `--check` **no debe** reescribir la fixture?
2. ¿Qué pasa si un desarrollador toca el skeleton y olvida regenerar la fixture? ¿Dónde se nota el problema?
3. ¿Qué otro lint pondrías en CI además de `diff` (p. ej. `yamllint`, `shellcheck`, `hadolint`)?
4. ¿Cómo escalarías a múltiples fixtures (p. ej. valores canónicos para "dev" y para "prod")?
5. Si Backstage cambia su versión y una built-in action rompe, ¿quién lo detecta primero: tu CI del template o un developer?

## 10. Extensiones

- Añade un segundo fixture `fixture-prod/` con otros `cookiecutter.json` y amplía el `--check` para ambos.
- Añade un step al workflow que publique el diff como comentario en el PR si hay drift.
- Añade `yamllint` sobre el output renderizado.

## 11. Limpieza

```bash
rm -rf /tmp/plat-06-ci
```
