#!/usr/bin/env bash
# Reference solution for dkr-09-01-publish-and-consume-your-image (MODE=local).
# Builds, tags x4, pushes to localhost:5000, resolves DIGEST, pulls by digest,
# and writes publish/tag-policy.md.
set -euo pipefail

BASE="${1:-/tmp/dkr-09-publish}"
REGISTRY_PORT="${REGISTRY_PORT:-5000}"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

bash "$SCRIPT_DIR/starter/bootstrap.sh" "$BASE" >/dev/null

REPO="$BASE/repo"
PUBLISH_DIR="$BASE/publish"
cd "$REPO"

REG="localhost:${REGISTRY_PORT}/evan/publish-demo"
GIT_SHA="$(git rev-parse --short=7 HEAD)"

docker build -q -t publish-demo:dev . >/dev/null

for t in "v1.0.0" "v1.0" "v1" "sha-${GIT_SHA}"; do
  docker tag publish-demo:dev "${REG}:${t}"
done
for t in "v1.0.0" "v1.0" "v1" "sha-${GIT_SHA}"; do
  docker push "${REG}:${t}" >/dev/null
done

# Resolve digest (pull first to be sure RepoDigests is populated)
docker pull "${REG}:v1.0.0" >/dev/null
docker inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "${REG}:v1.0.0" \
  | grep "^${REG}@" | head -n1 > "$PUBLISH_DIR/DIGEST"

DIGEST_REF="$(cat "$PUBLISH_DIR/DIGEST")"
docker pull "$DIGEST_REF" >/dev/null

cat > "$PUBLISH_DIR/tag-policy.md" <<EOF
# Politica de tags — publish-demo

## Tags publicados

- \`v1.0.0\` — version semver completa; inmutable por politica.
- \`v1.0\`   — minor; mutable, se re-apunta con cada \`v1.0.z\`.
- \`v1\`     — major; mutable, se re-apunta con cada \`v1.y.z\`.
- \`sha-${GIT_SHA}\` — commit del build; inmutable 1:1 con el commit.

## Cual usa produccion

Produccion referencia la imagen por **digest** (\`publish-demo@sha256:...\`),
resuelto tras el push y pegado directamente en el manifiesto de deploy. Esto
garantiza reproducibilidad binaria y aisla al deploy de cualquier re-push al
mismo tag.

Digest canonico de este release:
\`\`\`
${DIGEST_REF}
\`\`\`

## Cual usan los humanos

En logs, dashboards y demos usamos \`v1.0.0\` (y el \`sha-${GIT_SHA}\` cuando
necesitamos trazar al commit). Aceptamos que \`v1\`, \`v1.0\` y \`latest\` son
alias mutables que se re-apuntan con cada release y por tanto no sirven para
clavar un bit especifico.
EOF

echo "Solution built. Validator should pass:"
echo "  bash courses/docker/09-registries-tags-and-digests/activities/01-publish-and-consume-your-image/tests/validate.sh $BASE"
