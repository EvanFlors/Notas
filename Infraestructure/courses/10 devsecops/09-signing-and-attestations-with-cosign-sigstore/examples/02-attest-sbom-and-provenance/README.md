# Ejemplo 02 — Attestations: SBOM + SLSA provenance firmadas (walkthrough)

> **Walkthrough.** Explica la **estructura** de una attestation y los comandos que la producen/verifican. La ejecución keyless requiere OIDC real; la ejecución key-based de firma/verificación de attestations se practica en `activities/01-sign-capstone-image/` (variante opcional).

## 1. Qué es exactamente una attestation

Una attestation es un **in-toto Statement** firmado:

```json
{
  "_type": "https://in-toto.io/Statement/v1",
  "predicateType": "https://cyclonedx.org/bom/v1.5",
  "subject": [
    {
      "name": "ghcr.io/acme/payments",
      "digest": { "sha256": "ABC…" }
    }
  ],
  "predicate": {
    "bomFormat": "CycloneDX",
    "specVersion": "1.5",
    "components": [ { "type": "library", "name": "fastapi", "version": "0.115.0" } ]
  }
}
```

Al firmarla con `cosign attest` se envuelve en un **DSSE envelope**:

```json
{
  "payloadType": "application/vnd.in-toto+json",
  "payload": "<base64 del Statement>",
  "signatures": [ { "sig": "<base64>", "cert": "<base64 PEM>" } ]
}
```

El envelope se adjunta a la imagen OCI con tag `sha256-<digest>.att`.

## 2. Dos predicados típicos

| `predicateType`                                 | Responde a            |
|-------------------------------------------------|-----------------------|
| `https://cyclonedx.org/bom/v1.5`                | **Qué** hay dentro (SBOM) |
| `https://slsa.dev/provenance/v1`                | **Cómo** se construyó |

Son complementarios: una imagen "bien instrumentada" lleva **ambos** adjuntos.

## 3. Producir la attestation SBOM (keyless, CI)

```bash
# Partimos de un SBOM ya generado con syft (ver sec-08).
syft ghcr.io/acme/payments@sha256:ABC... -o cyclonedx-json > sbom.cdx.json

cosign attest \
  --predicate sbom.cdx.json \
  --type cyclonedx \
  --yes \
  ghcr.io/acme/payments@sha256:ABC...
```

## 4. Producir SLSA provenance en GitHub Actions

Con `actions/attest-build-provenance` (hosted builder SLSA L3-capable):

```yaml
- uses: actions/attest-build-provenance@v2
  with:
    subject-name: ghcr.io/acme/payments
    subject-digest: ${{ steps.build.outputs.digest }}
    push-to-registry: true
```

Firma keyless con Fulcio, publica en Rekor, adjunta a la imagen. Nada que custodiar.

## 5. Verificar — con `--type` siempre

```bash
# SBOM
cosign verify-attestation \
  --type cyclonedx \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity-regexp='^https://github.com/acme/payments/\.github/workflows/release\.yml@refs/tags/v' \
  ghcr.io/acme/payments:v1.2.3 \
  | jq -r '.payload' | base64 -d | jq '.predicate.components | length'

# SLSA provenance
cosign verify-attestation \
  --type slsaprovenance1 \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity-regexp='^https://github.com/acme/payments/\.github/workflows/release\.yml@refs/tags/v' \
  ghcr.io/acme/payments:v1.2.3 \
  | jq -r '.payload' | base64 -d | jq '.predicate.buildDefinition.resolvedDependencies'
```

## 6. Checklist mental ante una attestation

- ¿Está firmada? (si no, es solo un JSON suelto).
- ¿La firma la hizo la identidad que esperaba (pin con `--certificate-identity[-regexp]`)?
- ¿El `predicateType` coincide con `--type`?
- ¿El `subject.digest` coincide con el digest de la imagen que voy a desplegar?
- ¿Está en Rekor (no-repudio)?
