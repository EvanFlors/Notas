#!/usr/bin/env bash
# Bootstrap de la actividad 01: layout simulado de un runner self-hosted.
# NOTE: no usamos `set -o pipefail` globalmente para evitar SIGPIPE con
# productores largos + `grep -q` (ver nota en gh-02).
set -eu

DEST="${1:-/tmp/sh-runner}"
MODE="${MODE:-local}"

echo "[info] bootstrap MODE=$MODE DEST=$DEST"

if [ "$MODE" != "local" ] && [ "$MODE" != "live" ]; then
  echo "[fail] MODE debe ser 'local' o 'live' (got: $MODE)" >&2
  exit 2
fi

rm -rf "$DEST"
mkdir -p "$DEST/actions-runner/bin" \
         "$DEST/actions-runner/externals" \
         "$DEST/actions-runner/_diag" \
         "$DEST/workflows"

# Placeholders de binarios para simular que "existen".
cat > "$DEST/actions-runner/bin/Runner.Listener" <<'EOF'
#!/usr/bin/env bash
echo "simulated Runner.Listener — would long-poll GitHub for jobs"
EOF
cat > "$DEST/actions-runner/bin/Runner.Worker" <<'EOF'
#!/usr/bin/env bash
echo "simulated Runner.Worker — would execute a single job"
EOF
chmod +x "$DEST/actions-runner/bin/Runner.Listener" "$DEST/actions-runner/bin/Runner.Worker"

# config.sh y run.sh simulados: imprimen qué harían, no hacen daño.
cat > "$DEST/actions-runner/config.sh" <<'EOF'
#!/usr/bin/env bash
echo "simulated config.sh — would register against \$RUNNER_URL as \$RUNNER_NAME"
echo "with labels=\$RUNNER_LABELS, ephemeral=\$RUNNER_EPHEMERAL"
echo "would produce: .runner, .credentials, .credentials_rsaparams"
EOF
cat > "$DEST/actions-runner/run.sh" <<'EOF'
#!/usr/bin/env bash
echo "simulated run.sh — would start Runner.Listener (long-polling)"
echo "logs would go to _diag/Runner_*.log"
EOF
chmod +x "$DEST/actions-runner/config.sh" "$DEST/actions-runner/run.sh"

# Templates que el alumno debe COPIAR y RELLENAR.
cat > "$DEST/actions-runner/runner-config.env.template" <<'EOF'
# Copia este archivo a runner-config.env y completa los valores.
# RUNNER_URL=https://github.com/<tu-user>/<repo-prueba>
# RUNNER_NAME=demo-runner
# RUNNER_LABELS=demo,linux-local
# RUNNER_EPHEMERAL=true
# RUNNER_WORK_FOLDER=_work
EOF

cat > "$DEST/actions-runner/.runner.template" <<'EOF'
{
  "agentId": 42,
  "agentName": "<RUNNER_NAME>",
  "poolId": 1,
  "serverUrl": "https://pipelines.actions.githubusercontent.com/example",
  "gitHubUrl": "<RUNNER_URL>",
  "workFolder": "_work",
  "labels": [
    {"name": "self-hosted", "type": "system"},
    {"name": "linux",       "type": "system"},
    {"name": "x64",         "type": "system"},
    {"name": "<CUSTOM-1>",  "type": "user"},
    {"name": "<CUSTOM-2>",  "type": "user"}
  ],
  "ephemeral": true
}
EOF

cat > "$DEST/workflows/hello-self-hosted.yml.template" <<'EOF'
# Copia a hello-self-hosted.yml y ajusta las labels custom.
name: hello-self-hosted
on:
  workflow_dispatch:
jobs:
  hello:
    runs-on: [self-hosted, <CUSTOM-1>, <CUSTOM-2>]
    steps:
      - name: Who am I
        run: |
          echo "runner_name=$RUNNER_NAME"
          echo "hostname=$(hostname)"
      - name: Checkout
        uses: actions/checkout@v4
EOF

echo "[ok] directorio $DEST creado"
echo "[ok] layout actions-runner simulado creado"
echo "siguiente paso: copia los *.template, quita el .template, y rellena los placeholders."
echo "luego: bash tests/validate.sh $DEST"
