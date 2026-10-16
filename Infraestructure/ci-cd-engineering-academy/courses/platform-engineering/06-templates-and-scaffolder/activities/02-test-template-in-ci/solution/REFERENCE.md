# REFERENCE — plat-06-02-test-template-in-ci

> Una **referencia** razonada: no es la única manera, pero sí una válida.

## Idea central

El patrón **fixture + diff** convierte el template en un **producto con tests**:

- La fixture es la "respuesta correcta" para una entrada canónica.
- CI es el guardián: cualquier cambio en el skeleton obliga a actualizar la fixture conscientemente, con el diff visible en el PR.

## `scripts/regenerate-fixture.sh`

Decisiones:

- **`set -eu`** sin `pipefail`: evita falsos positivos de SIGPIPE con `grep | head` u otros pipes early-exit (ver nota del script).
- **Dos modos**: regenerar (seed) y `--check` (CI). El mismo script sirve a developer y a pipeline.
- **SKIP graceful** si falta cookiecutter: pedagógicamente correcto en un curso donde no todos tendrán la herramienta instalada; en producción, `cookiecutter` es un deploy-time dependency del template repo.
- **`trap cleanup EXIT`** garantiza limpieza aunque falle.
- **`find ... -mindepth 1 -maxdepth 1 -type d | head -n1`** localiza el dir renderizado sin asumir su nombre exacto (depende del `project_slug`).

## `template-ci.yaml`

Decisiones:

- Trigger en `pull_request` **y** `push: main` para detectar drift tanto en PRs como tras un merge directo.
- Un solo job: la primera iteración no necesita más. Más tarde se añade yamllint, hadolint, SBOM check, etc.
- `actions/checkout@v4` + `setup-python@v5`: versiones mayores vigentes a 2026.

## Qué dejé fuera

- Comentario de PR con el diff: útil pero añade complejidad (necesita `pull_request_target` o un token con write permissions).
- `yamllint`/`shellcheck`/`hadolint`: ejercicio de extensión en §10.
- Matriz de múltiples fixtures: ejercicio de extensión.

## Autoevaluación

1. ¿Tu `--check` es puro (no modifica `fixture/`)?
2. ¿Tu script limpia los temp dirs si falla a mitad?
3. ¿El workflow se dispara en PRs (donde queremos el diff) o sólo en push?
4. ¿Cómo se comporta tu script si `cookiecutter.json` existe pero `cookiecutter-skeleton/` no?
