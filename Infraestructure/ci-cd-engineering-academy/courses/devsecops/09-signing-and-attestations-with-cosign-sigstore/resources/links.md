# Recursos — sec-09

Referencias oficiales. **Verificar en Fase 4** del curso para asegurar vigencia.

## Sigstore (proyecto)

- Sitio oficial: `https://www.sigstore.dev/`
- Documentación: `https://docs.sigstore.dev/`
- CNCF (proyecto): `https://www.cncf.io/projects/sigstore/`

## cosign

- Repo: `https://github.com/sigstore/cosign`
- Instalación: `https://docs.sigstore.dev/cosign/system_config/installation/`
- `cosign sign`: `https://docs.sigstore.dev/cosign/signing/signing_with_blobs/`
- `cosign attest`: `https://docs.sigstore.dev/cosign/signing/other_types/#attestations`
- `cosign verify` (identity flags): `https://docs.sigstore.dev/cosign/verifying/verify/`

## Fulcio (CA)

- Repo: `https://github.com/sigstore/fulcio`
- Fulcio OIDs (extensiones X.509): `https://github.com/sigstore/fulcio/blob/main/docs/oid-info.md`

## Rekor (transparency log)

- Repo: `https://github.com/sigstore/rekor`
- Buscador público: `https://search.sigstore.dev/`

## Formatos y specs

- in-toto Statement v1: `https://github.com/in-toto/attestation/blob/main/spec/v1/statement.md`
- DSSE envelope: `https://github.com/secure-systems-lab/dsse`
- SLSA Provenance v1: `https://slsa.dev/spec/v1.0/provenance`
- CycloneDX: `https://cyclonedx.org/specification/overview/`
- SPDX: `https://spdx.dev/`

## OIDC en GitHub Actions

- About security hardening with OIDC: `https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect`
- `actions/attest-build-provenance`: `https://github.com/actions/attest-build-provenance`

## gitsign

- Repo: `https://github.com/sigstore/gitsign`

## Admission en K8s (preview de sec-11)

- Kyverno `verifyImages`: `https://kyverno.io/docs/writing-policies/verify-images/sigstore/`
- sigstore/policy-controller: `https://docs.sigstore.dev/policy-controller/overview/`

## Casos reales

- SolarWinds (2020) — por qué provenance importa.
- `tj-actions/changed-files` (2025) — por qué fijar `--certificate-identity` por tag firmado y no por nombre de workflow.

## Checklist de verificación en Fase 4

- Versión actual de cosign (binario estable).
- Vigencia de la raíz de confianza de Sigstore (TUF root).
- Lista oficial de OIDC issuers aceptados por Fulcio.
- Estado del soporte `verifyImages` + SLSA provenance en Kyverno y policy-controller.
