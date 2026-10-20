#!/usr/bin/env bash
# Reference solution for cap-05-01-write-signed-release-workflow.
set -euo pipefail

BASE="${1:-/tmp/cap-05}"
PROJECT="$BASE/project"
if [ ! -d "$PROJECT" ]; then
  echo "FAIL: $PROJECT not initialized. Run starter/bootstrap.sh first."
  exit 1
fi

mkdir -p "$PROJECT/.github/workflows"

# 1) trivy.yaml
cat > "$PROJECT/trivy.yaml" <<'YAML'
format: sarif
output: trivy-results.sarif
exit-code: 1
severity:
  - HIGH
  - CRITICAL
scan:
  scanners:
    - vuln
    - secret
    - misconfig
vulnerability:
  ignore-unfixed: true
  type:
    - os
    - library
timeout: 10m
YAML

# 2) release.yml
cat > "$PROJECT/.github/workflows/release.yml" <<'YAML'
name: release

on:
  push:
    tags: ["v*.*.*"]
  workflow_dispatch: {}

permissions: {}

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-scan-sign:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write
      attestations: write
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2

      - uses: docker/setup-qemu-action@49b3bc8e6bdd4a60e6116a5414239cba5943d3cf  # v3.2.0
      - uses: docker/setup-buildx-action@c47758b77c9736f4b2ef4073d4d51994fabfe349  # v3.7.1

      - uses: docker/login-action@9780b0c442fbb1117ed29e0efdff1e18412f7567  # v3.3.0
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - id: meta
        uses: docker/metadata-action@369eb591f429131d6889c46b94e711f089e6ca96  # v5.6.1
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=tag
            type=sha,format=long

      - id: build
        uses: docker/build-push-action@48aba3b46d1b1fec4febb7c5d0c644b249a11355  # v6.10.0
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

      - uses: aquasecurity/trivy-action@18f2510ee396bbf400402947b394f2dd8c87dbb0  # 0.29.0
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}
          trivy-config: trivy.yaml
          exit-code: "1"
          severity: HIGH,CRITICAL
          ignore-unfixed: true

      - uses: anchore/sbom-action@f325610c9f50a054015b6da1d1e7e4a4f8c1e57f  # v0.17.8
        with:
          image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.build.outputs.digest }}
          format: spdx-json
          output-file: sbom.spdx.json

      - uses: sigstore/cosign-installer@dc72c7d5c4d10cd6bcb8cf6e3fd625a9e5e537da  # v3.7.0
        with:
          cosign-release: v2.4.1

      - name: cosign sign (keyless)
        env:
          COSIGN_EXPERIMENTAL: "1"
        run: |
          cosign sign --yes \
            "${REGISTRY}/${IMAGE_NAME}@${{ steps.build.outputs.digest }}"

      - name: cosign attest SBOM
        env:
          COSIGN_EXPERIMENTAL: "1"
        run: |
          cosign attest --yes \
            --predicate sbom.spdx.json \
            --type spdxjson \
            "${REGISTRY}/${IMAGE_NAME}@${{ steps.build.outputs.digest }}"

      - uses: actions/attest-build-provenance@c074443f1aee8d4aeeae555aebba3282517141b2  # v2.1.0
        with:
          subject-name: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          subject-digest: ${{ steps.build.outputs.digest }}
          push-to-registry: true
YAML

# 3) verify.yml
cat > "$PROJECT/.github/workflows/verify.yml" <<'YAML'
name: verify

on:
  workflow_call:
    inputs:
      image:
        required: true
        type: string
      digest:
        required: true
        type: string
      certificate-identity-regexp:
        required: false
        type: string
        default: "^https://github\\.com/[^/]+/[^/]+/\\.github/workflows/release\\.yml@refs/tags/v.*$"
      certificate-oidc-issuer:
        required: false
        type: string
        default: "https://token.actions.githubusercontent.com"

permissions: {}

jobs:
  verify:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write
      packages: read
    steps:
      - uses: sigstore/cosign-installer@dc72c7d5c4d10cd6bcb8cf6e3fd625a9e5e537da  # v3.7.0
        with:
          cosign-release: v2.4.1

      - name: cosign verify
        env:
          COSIGN_EXPERIMENTAL: "1"
        run: |
          cosign verify \
            --certificate-identity-regexp "${{ inputs.certificate-identity-regexp }}" \
            --certificate-oidc-issuer "${{ inputs.certificate-oidc-issuer }}" \
            "${{ inputs.image }}@${{ inputs.digest }}"

      - name: cosign verify-attestation (SBOM)
        env:
          COSIGN_EXPERIMENTAL: "1"
        run: |
          cosign verify-attestation --type spdxjson \
            --certificate-identity-regexp "${{ inputs.certificate-identity-regexp }}" \
            --certificate-oidc-issuer "${{ inputs.certificate-oidc-issuer }}" \
            "${{ inputs.image }}@${{ inputs.digest }}"

      - name: gh attestation verify (SLSA)
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh attestation verify "oci://${{ inputs.image }}@${{ inputs.digest }}" \
            --repo "${GITHUB_REPOSITORY}"
YAML

echo "Solution applied under $PROJECT/"
ls -R "$PROJECT"
