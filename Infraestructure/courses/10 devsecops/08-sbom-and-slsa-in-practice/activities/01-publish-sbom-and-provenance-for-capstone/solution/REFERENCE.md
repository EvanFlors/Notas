# REFERENCE — sec-08-01-publish-sbom-and-provenance-for-capstone

> **Modelo** razonado. No es la única respuesta correcta — es un patrón contra el que compararte.

## 1. SBOMs

### 1.1 `sbom.cdx.json` (CycloneDX)

Debe tener en el top-level:

```json
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.5",
  "components": [ ... ],
  "metadata": { "timestamp": "...", "tools": { "components": [...] } }
}
```

Puntos clave:

- Cada `component` tiene `purl` (`pkg:pypi/requests@2.25.1`).
- `type` suele ser `library` para deps y `operating-system` para el OS base.
- Si vino de una imagen con `python:3.11-alpine`, verás componentes `apk` además de `pypi`.

### 1.2 `sbom.spdx.json` (SPDX)

Debe tener en el top-level:

```json
{
  "spdxVersion": "SPDX-2.3",
  "SPDXID": "SPDXRef-DOCUMENT",
  "packages": [ ... ],
  "relationships": [ ... ]
}
```

Puntos clave:

- Cada `package` tiene `SPDXID`, `name`, `versionInfo`, `licenseConcluded`.
- Los PURLs van en `externalRefs[].referenceLocator`.
- `relationships` modela "DOCUMENT DESCRIBES X", "X DEPENDS_ON Y".

## 2. `vulns.json` (grype)

Estructura mínima:

```json
{
  "matches": [
    {
      "vulnerability": {"id": "CVE-...", "severity": "High", ...},
      "artifact":      {"name": "requests", "version": "2.25.1", "purl": "pkg:pypi/..."}
    }
  ],
  "source": {"type": "sbom", "target": "..."}
}
```

Con los pins antiguos (`requests==2.25.1`, `urllib3==1.26.5`) deberías ver varias entries. Si **no** hay matches, revisa que la DB de Grype se haya descargado (`grype db update`).

## 3. `provenance.json`

Modelo mínimo L1 (self-reported):

```json
{
  "_type": "https://in-toto.io/Statement/v1",
  "subject": [{
    "name": "sec-08-capstone",
    "digest": {"sha256": "deadbeef..."}
  }],
  "predicateType": "https://slsa.dev/provenance/v1",
  "predicate": {
    "buildDefinition": {
      "buildType": "https://example.com/manual-build/v1",
      "externalParameters": {
        "note": "L1 self-reported — subir a L2 con hosted builder"
      },
      "resolvedDependencies": [{
        "uri": "git+file:///tmp/sec-08-capstone",
        "digest": {"gitCommit": "N/A"}
      }]
    },
    "runDetails": {
      "builder":  {"id": "local-workstation"},
      "metadata": {
        "invocationId": "manual-run",
        "startedOn":  "2026-01-01T00:00:00Z",
        "finishedOn": "2026-01-01T00:00:05Z"
      }
    }
  }
}
```

Por qué esto es **solo L1**:

- No hay firma Sigstore → cualquiera puede reescribirlo.
- `builder.id` es `local-workstation` → no hay hosted builder confiable.
- No está en Rekor → no es auditable públicamente.

Para subir a **L2**: el build pasa a GitHub Actions hosted; `builder.id` apunta al runner GitHub; la provenance la emite `actions/attest-build-provenance` (firmada).

Para **L3**: idem L2, pero garantizando que **el propio workflow** no puede alterar la provenance después de emitida. GHA + Sigstore + Rekor lo garantizan **si** usas hosted runners.

## 4. `release.yml`

Lo que **debe** aparecer:

- `permissions: id-token: write` **y** `permissions: attestations: write`.
- Un step con `uses: actions/attest-build-provenance@v2` (o compatible).
- Un step con `uses: anchore/sbom-action@v0` + `uses: actions/attest-sbom@v2` (o equivalente).
- Las attestations usan `subject-digest: ${{ steps.push.outputs.digest }}` — **nunca** el tag.

Lo que **no** debe aparecer:

- No almacenar `COSIGN_PRIVATE_KEY` como secret (es keyless — no hay clave que custodiar).
- No `push-to-registry: false` si quieres que el consumidor verifique con `cosign verify-attestation` sobre la imagen.

## 5. Respuestas a las preguntas de reflexión

1. **¿Por qué L1 y no L2?** Porque el builder no es un servicio confiable e independiente; la provenance es auto-reportada; nada impide reescribirla.
2. **`--certificate-identity-regexp '.*workflow.*'`**: pierde el *identity binding* fuerte. Un atacante puede crear un workflow en **otro** repo cuyo nombre contenga "workflow" y pasar la verificación.
3. **CycloneDX vs SPDX**: para el equipo legal → **SPDX** (`licenseConcluded`, `licenseInfoFromFiles`, SPDX License List). Para Dependency-Track → **CycloneDX** (es el formato nativo del proyecto).
4. **`syft dir:.` vs `syft <image>`**: `dir:.` es **source SBOM** (lee manifests declarados — `requirements.txt`, `go.sum`); `syft <image>` es **build SBOM** (ve el OS base + lo que acabó realmente instalado tras `pip install`). Build SBOM es el valioso para scanning; source SBOM es el valioso para auditoría de deps declaradas.

## 6. Resumen a llevar

> Local: Syft + Grype te dan el 80 % del valor sin pipeline. GHA te sube de L1 a L3 con dos actions oficiales. La verificación en el consumidor es la mitad olvidada — sin ella, firmar no sirve.
