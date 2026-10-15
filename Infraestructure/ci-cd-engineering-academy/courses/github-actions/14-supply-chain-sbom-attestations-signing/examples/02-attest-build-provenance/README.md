# Ejemplo 02 — Attestation SLSA build provenance

## Concepto que demuestra

Un workflow que construye un artefacto (binario + imagen OCI) y emite dos attestations firmadas vía **Sigstore keyless**:

1. **Build provenance** (`actions/attest-build-provenance@v2`) con predicate `slsa-provenance/v1`.
2. **SBOM attestation** (`actions/attest-sbom@v2`) ligando el SBOM al mismo subject.

Las dos quedan ancladas en **Rekor** y disponibles en el repo (`Actions → Attestations`).

## Contexto

Ver `theory/lesson.md` secciones 2.1, 4.1 y 4.2 para el formato in-toto y el flujo keyless.

Qué garantiza:

- *Este artefacto (digest X) fue producido por `release.yml` del repo OWNER/REPO en el commit SHA Y, por un runner GitHub-hosted, en el momento Z.*
- *Este SBOM describe ese mismo artefacto.*

Qué **NO** garantiza (recordatorio): el código fue revisado, el build no hizo cosas raras, el binario no incluye telemetría.

## Archivos

- `workflow.yml` — a copiar en `.github/workflows/release.yml`.
- `Dockerfile.sample` — reutilizable del ejemplo 01.

## Permisos requeridos

```yaml
permissions:
  contents: read
  packages: write          # publish to GHCR
  id-token: write          # Sigstore keyless (OIDC token)
  attestations: write      # subir attestation al repo
```

Sin `id-token: write` → `Error: Unable to get OIDC token`.
Sin `attestations: write` → la attestation se firma pero no se guarda en el repo.

## Flujo

```
tag v*
  │
  ▼
checkout → build image → push to GHCR
                           │
                           ├─> actions/attest-build-provenance
                           │     subject: image digest
                           │     predicate: slsa-provenance/v1
                           │     push-to-registry: true  (OCI referrer)
                           │
                           ├─> syft → sbom.cdx.json
                           │
                           └─> actions/attest-sbom
                                 subject: image digest
                                 predicate: cyclonedx
                                 sbom-path: sbom.cdx.json
                                 push-to-registry: true
```

## Verificación (dos APIs)

### Con el CLI de GitHub

```bash
# Verifica la provenance del digest
gh attestation verify oci://ghcr.io/OWNER/REPO/app:v1.2.3 \
  --repo OWNER/REPO

# Verifica la attestation de SBOM específicamente
gh attestation verify oci://ghcr.io/OWNER/REPO/app:v1.2.3 \
  --repo OWNER/REPO \
  --predicate-type https://cyclonedx.org/bom
```

### Con cosign (sin gh)

```bash
# Descarga + verifica attestation vía referrers API
cosign verify-attestation ghcr.io/OWNER/REPO/app:v1.2.3 \
  --type slsaprovenance1 \
  --certificate-identity-regexp '^https://github\.com/OWNER/REPO/\.github/workflows/release\.yml@refs/tags/v.*$' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com'
```

Salida esperada: `Verification for ghcr.io/... Verified OK`.

## Dónde vive la attestation

- **En el repo**: `Repository → Actions → Attestations` (UI) y API `/repos/{owner}/{repo}/attestations/{digest}`.
- **En el registry**: como *referring artifact* al mismo digest (OCI 1.1).
- **En Rekor**: buscable por hash en `https://search.sigstore.dev/`.

## Interpretación

El predicate `slsa-provenance/v1` incluye:

- `buildType` — tipo de builder (workflow de GHA).
- `externalParameters` — inputs del build (ref, workflow, workflow_sha).
- `internalParameters.github` — contexto completo (`repository_id`, `event_name`, `runner_environment`, …).
- `runDetails.builder.id` — URI del builder (`https://github.com/actions/runner`).
- `runDetails.metadata.invocationID` — URL del run exacto.
- `materials[]` — repos y refs consumidos.

Este JSON es la "etiqueta del lote". Un atacante que cambie bytes del binario invalida la firma; uno que recree bytes idénticos no puede recrear la firma sin el OIDC original.

## Buenas prácticas

- Attestar **todos** los artefactos de un release (imagen, binarios por plataforma, SBOMs). Son baratas.
- Emitir provenance **y** attestation de SBOM juntas. Son complementarias.
- Documentar el `gh attestation verify` exacto en el `README.md` del repo.
- Para subject-path con glob (`subject-path: dist/*`), verificar que el glob matchea *antes* de attestar (evitar glob vacío → fallo silencioso).

## Errores frecuentes

- `permissions: id-token: write` olvidado.
- Attestar antes de pushear la imagen → el digest aún no existe en el registry y `push-to-registry: true` falla.
- `subject-digest` sin el prefijo `sha256:` → el action rechaza.
- Correr en runner self-hosted sin OIDC configurado → firma falla o produce claims inútiles.
- Pin de action a `@v2` (tag mutable) en workflows críticos; en producción, pin a SHA.

## Referencia

- <https://docs.github.com/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds>
- <https://github.com/actions/attest-build-provenance>
- <https://github.com/actions/attest-sbom>
- <https://slsa.dev/spec/v1.0/>
