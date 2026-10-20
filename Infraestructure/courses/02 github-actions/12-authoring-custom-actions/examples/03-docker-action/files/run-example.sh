#!/usr/bin/env bash
# Scaffolds a Docker container action and reproduces the runner's
# docker build + docker run cycle.
set -euo pipefail

DEMO="${1:-/tmp/docker-action-demo}"
rm -rf "$DEMO"
mkdir -p "$DEMO/greet-docker"
cd "$DEMO/greet-docker"

cat > action.yml <<'EOF'
name: "Greet (Docker)"
description: "Prints a greeting from an Alpine container"
inputs:
  who:
    description: "Target name"
    required: false
    default: "world"
runs:
  using: docker
  image: Dockerfile
  args:
    - ${{ inputs.who }}
EOF

cat > Dockerfile <<'EOF'
FROM alpine:3.20
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
EOF

cat > entrypoint.sh <<'EOF'
#!/bin/sh
set -eu

# Inputs come in TWO ways:
#   (1) positional args:   $1 = inputs.who (from action.yml args)
#   (2) env vars INPUT_*:  $INPUT_WHO (always available for every input)
WHO="${1:-${INPUT_WHO:-world}}"

GREETING="Hello, ${WHO}, from a container"
echo "$GREETING"

# Emit output
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "greeting=${GREETING}" >> "$GITHUB_OUTPUT"
fi
EOF
chmod +x entrypoint.sh

echo "== Scaffolded Docker action at: $DEMO/greet-docker =="
echo

if ! command -v docker >/dev/null 2>&1; then
  echo "docker not installed. Install Docker Desktop or engine:"
  echo "  macOS:  https://docs.docker.com/desktop/install/mac-install/"
  echo "  Linux:  https://docs.docker.com/engine/install/"
  echo "Skipping build; files are in place."
  exit 0
fi
if ! docker ps >/dev/null 2>&1; then
  echo "docker daemon not reachable. Start Docker Desktop or 'systemctl start docker'."
  echo "Skipping build; files are in place."
  exit 0
fi

echo "== docker build =="
docker build -t greet-docker:local . >/dev/null
echo "image built: greet-docker:local"

echo
echo "== docker run (simulating runner) =="
touch "$DEMO/github_output"
docker run --rm \
  -e INPUT_WHO="mundo" \
  -e GITHUB_OUTPUT=/github/file_commands/output \
  -v "$DEMO/github_output":/github/file_commands/output \
  greet-docker:local mundo

echo
echo "== Contents of \$GITHUB_OUTPUT =="
cat "$DEMO/github_output"
echo
echo "Done."
