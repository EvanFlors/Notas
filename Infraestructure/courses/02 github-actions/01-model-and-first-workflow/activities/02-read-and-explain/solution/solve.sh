#!/usr/bin/env bash
# Reference solution for gha-01-02-read-and-explain.
# Rebuilds $BASE via bootstrap, then writes a canonical ANSWERS.md that passes
# the validator. For instructor use / smoke testing.

set -euo pipefail

BASE="${1:-/tmp/gha-01-read-and-explain}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

bash "$SCRIPT_DIR/starter/bootstrap.sh" "$BASE" >/dev/null

cat > "$BASE/ANSWERS.md" <<'EOF'
# ANSWERS — gha-01-02-read-and-explain

## Q1
El workflow se dispara en `push` a la rama `main` y en `pull_request`
contra `main`. Un `push` directo a `main` crea 1 workflow run. Un PR abierto
contra `main` también crea 1 workflow run (del evento `pull_request`); si
luego se mergea con push a main, se creará otro run por ese push.

## Q2
Hay dos jobs: `build` y `publish`. `publish` tiene `needs: build`, así que
NO corren en paralelo: primero corre `build`; cuando termina OK, corre
`publish`. Si `build` falla, `publish` no se ejecuta (se queda en estado
`skipped`). Si no hubiera `needs:`, correrían en paralelo en runners
distintos. El orden en este caso es secuencial por dependencia explícita.

## Q3
El job `publish` NO tiene `actions/checkout`. Como cada job corre en una VM
nueva y distinta (otro runner, workspace vacío), `publish` no tiene el
código del repo ni los archivos que generó `build` (los jobs no comparten
disco). El `ls -la dist` fallará con "no dist/ here!" porque esa carpeta
solo existió en el workspace del job `build`. Esto es un bug / antipattern
para este caso: para pasar el `dist/app.whl` entre jobs hay que usar
`actions/upload-artifact` en `build` y `actions/download-artifact` en
`publish` (o bien hacer todo en el mismo job).

## Q4
Los tres steps del job `build`:
1. `uses: actions/checkout@v4` — invoca la action oficial de checkout para
   clonar el repo en el workspace.
2. `uses: actions/setup-python@v5` — invoca la action que instala Python
   3.12 y lo deja en el PATH.
3. `run: ...` — comando shell que crea `dist/` y escribe un archivo falso
   para simular un artifact (`echo pretend-this-is-a-wheel > dist/app.whl`).

## Q5
Las variables `$GITHUB_REPOSITORY`, `$GITHUB_SHA`, `$GITHUB_EVENT_NAME`,
`$GITHUB_ACTOR`, `$GITHUB_RUN_ID` las define el runner agent antes de
ejecutar los steps. Su contenido viene del contexto `github`, que a su vez
se rellena desde el payload del evento (push / pull_request) que GitHub
publicó en el bus de eventos. Se asignan al momento en que el runner
prepara el job, y permanecen constantes durante toda la ejecución.

## Q6
Al hacer "Re-run failed jobs" (o "Re-run all jobs") desde la UI, GitHub
re-ejecuta con el **mismo YAML del commit disparador** del run original
—no con el YAML actual de `main`. Es decir, si cambiaste el workflow en
`main` después de que el run original ocurrió, el re-run seguirá usando
el YAML viejo. Para probar el YAML nuevo hay que hacer un commit nuevo que
dispare un nuevo run.
EOF

echo "Solution ANSWERS.md written at: $BASE/ANSWERS.md"
