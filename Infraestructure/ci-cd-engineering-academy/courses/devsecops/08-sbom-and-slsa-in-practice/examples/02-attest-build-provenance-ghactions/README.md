# Ejemplo 02 — `actions/attest-build-provenance` en GitHub Actions (walkthrough)

> **Walkthrough**. No se ejecuta. No requiere push a GHCR ni credenciales reales. El objetivo es leer un workflow completo y entender *qué* garantiza cada bloque.

## Objetivo

Entender, línea a línea, un workflow GHA que:

1. Hace build de una imagen de contenedor.
2. La pushea a **GHCR** (`ghcr.io/<org>/<repo>`).
3. Emite SBOM (CycloneDX) y lo adjunta como attestation (`actions/attest-sbom`).
4. Emite **provenance SLSA v1.0** y la adjunta como attestation (`actions/attest-build-provenance`).

Todo esto sin manejar claves privadas: el OIDC token del runner + Fulcio + Rekor hacen el trabajo.

## El workflow — `release.yml`

Ver `release.yml` en este directorio. Comentarios inline explican cada pieza.

## Lectura dirigida

### A. Permisos

```yaml
permissions:
  contents: read
  packages: write          # push a GHCR
  id-token: write          # OIDC token para Sigstore
  attestations: write      # emitir attestation
```

- `id-token: write` es la llave: sin él, la action no puede pedir el OIDC token y por tanto no puede firmar.
- `attestations: write` autoriza publicar la attestation (en GitHub + en el registry si `push-to-registry: true`).

### B. Build y push

El step `docker/build-push-action@v6` produce un **digest** (`sha256:...`) de la imagen pusheada. Ese digest es el input de las attestations: siempre atestamos **el digest**, nunca el tag (los tags son mutables).

```yaml
- name: Build and push
  id: push
  uses: docker/build-push-action@v6
  with:
    push: true
    tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
```

### C. SBOM attestation

```yaml
- name: Generate SBOM
  uses: anchore/sbom-action@v0
  with:
    image: ghcr.io/${{ github.repository }}@${{ steps.push.outputs.digest }}
    format: cyclonedx-json
    output-file: sbom.cdx.json

- name: Attest SBOM
  uses: actions/attest-sbom@v2
  with:
    subject-name: ghcr.io/${{ github.repository }}
    subject-digest: ${{ steps.push.outputs.digest }}
    sbom-path: sbom.cdx.json
    push-to-registry: true
```

- Resultado: la imagen OCI tiene una attestation con predicate `https://cyclonedx.org/bom` adjunta.
- Un consumidor hace `cosign verify-attestation --type cyclonedx <image>` y obtiene el SBOM verificado.

### D. Provenance SLSA v1.0

```yaml
- name: Attest build provenance
  uses: actions/attest-build-provenance@v2
  with:
    subject-name: ghcr.io/${{ github.repository }}
    subject-digest: ${{ steps.push.outputs.digest }}
    push-to-registry: true
```

- Resultado: la imagen OCI tiene una attestation con predicate `https://slsa.dev/provenance/v1` adjunta.
- La provenance contiene: `builder.id`, `buildType`, `externalParameters` (workflow ref, repo), `resolvedDependencies` (commit SHA del source), `invocationId`.

## Qué garantiza este workflow (y qué NO)

**Garantiza**:

- Que *este* digest de imagen fue construido *por este workflow* en *este repo* en *este commit*.
- Que la provenance no puede ser falsificada por un tercero (la firma Sigstore + Rekor son el ancla).
- Que el SBOM que se publicó no fue modificado después (la firma lo protege).

**NO garantiza**:

- Que el código fuente sea seguro (eso es SAST/SCA).
- Que el `Dockerfile` no instale cosas raras (eso es revisión + policy).
- Que el consumidor verifique antes de desplegar (eso es `sec-11` admission).
- Que si usas **self-hosted runners** sin aislamiento, siga siendo L3 (deja de serlo).

## Para probarlo de verdad (opcional, fuera del scope del ejemplo)

Si quieres ejecutarlo:

1. Hacer fork de un repo real y copiar `release.yml` a `.github/workflows/`.
2. Push a `main`. GitHub ejecuta el workflow.
3. Verificar con `gh attestation verify oci://ghcr.io/<org>/<repo>@sha256:... --repo <org>/<repo>`.

Este módulo **no** pide hacerlo: la actividad 01 cubre la parte local (syft + grype) y la 02 cubre el gap analysis conceptual.

## Siguiente ejemplo

`examples/03-verify-slsa/` — cómo verificar correctamente lo que este workflow produce.
