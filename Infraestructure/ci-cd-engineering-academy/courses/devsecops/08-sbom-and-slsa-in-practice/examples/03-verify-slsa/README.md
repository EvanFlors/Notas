# Ejemplo 03 — Verificar SLSA / SBOM attestations (walkthrough + comandos)

> **Walkthrough + runnable parcial**. Los comandos reales se muestran y se ejecutan con un target público si tienes `cosign` y/o `gh`. Si no, es lectura.

## Objetivo

Aprender a **verificar** correctamente lo que emite el ejemplo 02 — y reconocer una verificación insegura (sin `--certificate-identity`) como el anti-patrón número uno.

## Comandos clave

### A. Verificación de alto nivel con `gh attestation verify`

```bash
gh attestation verify \
  oci://ghcr.io/<org>/<repo>@sha256:<digest> \
  --repo <org>/<repo>
```

Qué comprueba:

- Que existe una attestation en Rekor cuya subject coincide con el digest.
- Que la identidad del firmante (OIDC) coincide con un workflow del repo indicado.
- Que la cadena de certificados Sigstore es válida.

Es la forma más amigable; para la mayoría de casos **basta**.

### B. Verificación granular con `cosign verify-attestation`

```bash
cosign verify-attestation \
  --type slsaprovenance1 \
  --certificate-identity-regexp '^https://github\.com/<org>/<repo>/\.github/workflows/release\.yml@refs/heads/main$' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com' \
  ghcr.io/<org>/<repo>@sha256:<digest>
```

Qué añade frente a `gh attestation`:

- Pin **exacto** al workflow concreto (`release.yml`) y a la **ref** (`refs/heads/main`).
- Puedes también verificar un SBOM: `--type cyclonedx` o `--type spdxjson`.

### C. El anti-patrón que NUNCA debes copiar

```bash
# NO HAGAS ESTO EN PRODUCCIÓN
cosign verify-attestation --type slsaprovenance1 <image>
```

Falta `--certificate-identity` + `--certificate-oidc-issuer`. Esto acepta attestations firmadas **por cualquiera**: un atacante puede subir su propia imagen con su propia provenance firmada con su propia identidad y pasar esta verificación.

## Qué hace el script

`run.sh`:

1. Verifica `cosign` y `gh` en PATH; skip graceful si faltan.
2. Imprime los comandos de verificación con placeholders.
3. Si pasas `TARGET_IMAGE=...` y `TARGET_REPO=...` como env vars, ejecuta la verificación real contra ese target.
4. Muestra el anti-patrón **marcado explícitamente como inseguro**, sin ejecutarlo.

## Target de prueba público (opcional)

Puedes probar la mecánica contra una imagen pública con attestations ya emitidas, p. ej. imágenes de releases oficiales de GitHub (ver docs: `https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds`).

## Siguiente

→ `activities/01-publish-sbom-and-provenance-for-capstone/` para la práctica guiada.
