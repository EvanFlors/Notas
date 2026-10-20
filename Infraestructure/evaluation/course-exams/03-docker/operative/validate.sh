#!/usr/bin/env bash
# validate.sh — Validación automática del ejercicio operativo.
# Ejecutar desde evaluation/course-exams/03-docker/operative/
#
# Sale 0 si todos los checks pasan, != 0 en caso contrario.
# Esta no es la rúbrica completa — es un gate mínimo. La rúbrica cualitativa
# requiere revisión humana (ver VALIDATION.md).

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SOL="${HERE}/solution"
REGISTRY="localhost:5001"
IMAGE_NAME="${REGISTRY}/pricing-api"
TAG="1.0.0"
FAKE_TOKEN_FILE="/tmp/fake-build-token"

fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "OK:   $*"; }

# ---------- 0. Prerrequisitos ----------
for bin in docker syft trivy cosign jq curl; do
  command -v "$bin" >/dev/null || fail "falta binario: $bin"
done
docker info >/dev/null 2>&1 || fail "docker no responde"
curl -fsS "http://${REGISTRY}/v2/" >/dev/null || fail "registry local no disponible en ${REGISTRY}"

# ---------- 1. Estructura ----------
for f in Dockerfile compose.yaml sbom.cdx.json trivy-report.json cosign.pub notes.md; do
  [[ -f "${SOL}/${f}" ]] || fail "falta archivo: solution/${f}"
done
ok "estructura de entrega"

# ---------- 2. Red flags ----------
[[ ! -f "${SOL}/cosign.key" ]] || fail "RED FLAG: cosign.key presente en la entrega"
grep -q "docker.sock" "${SOL}/compose.yaml" && fail "RED FLAG: docker.sock montado en compose.yaml"
grep -Eq '^\s*ARG\s+.*(TOKEN|SECRET|KEY|PASSWORD)' "${SOL}/Dockerfile" \
  && fail "RED FLAG: ARG con nombre tipo secret en Dockerfile"
grep -Eq '(USER\s+root|^(?!.*USER))' "${SOL}/Dockerfile" >/dev/null 2>&1 || true
grep -Eq '^\s*USER\s+root\s*$' "${SOL}/Dockerfile" && fail "RED FLAG: USER root explícito"
grep -q "privileged: true" "${SOL}/compose.yaml" && fail "RED FLAG: privileged: true en compose"
ok "sin red flags detectables estáticamente"

# ---------- 3. Build + métricas ----------
[[ -f "${FAKE_TOKEN_FILE}" ]] || openssl rand -hex 32 > "${FAKE_TOKEN_FILE}"
cd "${SOL}"

echo "--> primer build (cold)"
DOCKER_BUILDKIT=1 docker build \
  --secret id=gh_token,src="${FAKE_TOKEN_FILE}" \
  -t "${IMAGE_NAME}:${TAG}" .

echo "--> rebuild caliente (sin tocar deps)"
touch "${HERE}/starter/app/main.py" 2>/dev/null || true
START=$(date +%s)
DOCKER_BUILDKIT=1 docker build \
  --secret id=gh_token,src="${FAKE_TOKEN_FILE}" \
  -t "${IMAGE_NAME}:${TAG}" . >/dev/null
END=$(date +%s)
ELAPSED=$((END - START))
[[ "${ELAPSED}" -lt 5 ]] || fail "rebuild caliente tardó ${ELAPSED}s (umbral 5s). Caché mal ordenada."
ok "rebuild caliente ${ELAPSED}s"

SIZE_MB=$(docker image inspect "${IMAGE_NAME}:${TAG}" --format '{{.Size}}' | awk '{printf "%d", $1/1024/1024}')
[[ "${SIZE_MB}" -lt 150 ]] || fail "imagen de ${SIZE_MB} MB (umbral 150 MB)"
ok "tamaño ${SIZE_MB} MB"

# ---------- 4. No filtra el token ----------
TOKEN=$(cat "${FAKE_TOKEN_FILE}")
docker history --no-trunc "${IMAGE_NAME}:${TAG}" | grep -q "${TOKEN}" \
  && fail "RED FLAG: token presente en docker history"
docker save "${IMAGE_NAME}:${TAG}" | tar -xO 2>/dev/null | grep -q "${TOKEN}" \
  && fail "RED FLAG: token presente en capas (docker save)"
ok "token no filtrado en imagen"

# ---------- 5. Push + digest ----------
docker push "${IMAGE_NAME}:${TAG}" >/dev/null
DIGEST=$(docker inspect --format '{{index .RepoDigests 0}}' "${IMAGE_NAME}:${TAG}")
ok "pushed ${DIGEST}"

# ---------- 6. SBOM + Trivy ----------
jq -e '.bomFormat == "CycloneDX"' "${SOL}/sbom.cdx.json" >/dev/null \
  || fail "sbom.cdx.json no es CycloneDX válido"
jq -e '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH" or .Severity=="CRITICAL")] | length == 0' \
  "${SOL}/trivy-report.json" >/dev/null \
  || fail "trivy-report.json contiene HIGH/CRITICAL sin remediar"
ok "SBOM válido y trivy limpio"

# ---------- 7. Firma + attestation ----------
cosign verify --key "${SOL}/cosign.pub" "${DIGEST}" >/dev/null \
  || fail "cosign verify falló"
cosign verify-attestation --key "${SOL}/cosign.pub" --type cyclonedx "${DIGEST}" >/dev/null \
  || fail "cosign verify-attestation (cyclonedx) falló"
ok "firma y attestation verificadas"

# ---------- 8. Compose up / health ----------
docker compose -f "${SOL}/compose.yaml" up -d
sleep 3
curl -fsS http://localhost:8000/health | jq -e '.status == "ok"' >/dev/null \
  || { docker compose -f "${SOL}/compose.yaml" logs; docker compose -f "${SOL}/compose.yaml" down -v; fail "healthcheck falló"; }
docker compose -f "${SOL}/compose.yaml" down -v
ok "stack arranca y /health responde"

echo
echo "========================================"
echo "  ALL CHECKS PASSED — gate aprobado"
echo "  (la rúbrica cualitativa es manual)"
echo "========================================"
