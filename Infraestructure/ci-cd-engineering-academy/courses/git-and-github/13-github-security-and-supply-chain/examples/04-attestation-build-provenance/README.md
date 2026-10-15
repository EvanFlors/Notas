# Ejemplo 04 — Build provenance attestation (SLSA)

## Concepto que demuestra

Un workflow que genera un artefacto y, con `actions/attest-build-provenance@v2`, publica una attestation **SLSA v1.0** firmada vía **Sigstore** (keyless, OIDC) y anclada en el log público **Rekor**.

Así cualquier consumidor del artefacto puede probar **de dónde salió** sin confiar en ti previamente.

## Contexto

Ver `theory/lesson.md` secciones 2.4 y 4.2 para el detalle del formato `in-toto` + predicate `slsa-provenance/v1` y el flujo Fulcio/Rekor.

Qué garantiza la attestation: *este artefacto fue producido por el workflow `release.yml` del repo `OWNER/REPO` en el commit `<sha>` por el runner de GitHub hospedado por GitHub.*

Qué NO garantiza: que el código sea seguro, que el workflow sea correcto, que la build no hiciera algo malicioso en su interior.

## Archivos

- `release.yml` — a copiar en `.github/workflows/release.yml`.

## Permisos requeridos

```yaml
permissions:
  contents: write        # para crear release
  id-token: write        # para firma Sigstore (via OIDC)
  attestations: write    # para subir attestation al repo
```

Sin `id-token: write` → la firma falla. Sin `attestations: write` → se genera pero no se asocia al repo.

## Verificación por un consumidor

```bash
# Descarga el artefacto del release
gh release download v1.0.0 --repo OWNER/REPO --pattern "myapp-*"

# Verifica la attestation (resuelve bundle, verifica Rekor, matchea claims)
gh attestation verify ./myapp-v1.0.0 --repo OWNER/REPO
```

Salida esperada:

```
Loaded digest sha256:abc... for file://./myapp-v1.0.0
Loaded 1 attestation from GitHub API
✓ Verification succeeded!
```

Si manipulas el binario y vuelves a verificar: `verification failed`.

## Dónde vive la attestation

- En GitHub: `Repository → Actions → Attestations` (UI nueva) y adjunta al release.
- En Rekor público: `https://rekor.sigstore.dev/` buscando por hash. **Prueba de que existe y cuándo**.
- Opcionalmente descargable con `gh attestation download`.

## Interpretación

El modelo es **keyless**: no gestionas claves de firma. La identidad proviene del OIDC token del workflow (claims con repo, ref, workflow, actor). Fulcio emite un certificado efímero (10 min) con esos claims como extensiones X.509. Rekor registra la firma de forma pública e inmutable.

Dos actores que firman con "la misma identidad" (mismo workflow en el mismo repo) producen attestations verificables como provenientes de ese contexto, aunque las claves usadas sean distintas en cada run.

## Buenas prácticas

- Attestar **todos los artefactos** de un release (binarios por plataforma, SBOMs, imágenes).
- Documentar la **invocación de verificación** en `README.md` del repo: así los consumidores saben qué comprobar.
- Combinar con **cosign sign** si publicas imágenes OCI (double-signing: build provenance + release approval).

## Errores frecuentes

- Olvido de `permissions: id-token: write` → `Error: Unable to get OIDC token`.
- `subject-path` apunta a un archivo que aún no existe en ese step → ejecutar la attestation **después** del build.
- Ejecutar en un **runner self-hosted** sin configurar OIDC correctamente → la firma falla o produce claims poco útiles para verificación.

## Referencia

- <https://docs.github.com/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds>
- <https://slsa.dev/spec/v1.0/>
- <https://docs.sigstore.dev/>
