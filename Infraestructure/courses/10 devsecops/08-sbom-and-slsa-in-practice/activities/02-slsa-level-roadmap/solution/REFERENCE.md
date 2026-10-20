# REFERENCE — sec-08-02-slsa-level-roadmap

> **Modelo** razonado. No es la única respuesta correcta — es un patrón contra el que compararte.

## Sección A — Diagnóstico (modelo)

**Nivel actual: L0 (bordeando L1)**.

Hay un `Dockerfile` y un `Makefile release:` versionado — eso satisface L1 **si** aceptamos "build script existe". Pero no hay provenance (ni manual ni autogenerada), así que el requisito de L1 (produce provenance, aunque sea self-reported) **no** se cumple. Por tanto: **L0**.

**Clases de atacante no defendidas:**

- **Tampering del build**: la laptop del lead puede ser comprometida → imagen con malware firmada "oficialmente" por él. Nada lo detecta.
- **Falsificación de origen**: cualquiera con push access a GHCR puede subir una imagen `:v1.2.3` que no proviene del código del repo.
- **Repudio**: no hay registro público/auditable de qué commit generó qué imagen. Un commit malicioso puede desaparecer de la historia sin dejar rastro verificable.
- **Supply chain upstream**: una base image comprometida pasa inadvertida (no hay SBOM que lo documente).

## Sección B — Camino a L2 (modelo)

Al menos 4 cambios:

1. **Mover el build a GitHub Actions hosted.**
   - **Cómo**: `.github/workflows/release.yml` con `runs-on: ubuntu-latest` en lugar de `make release` local.
   - **Gana**: builder confiable + aislado por job + logs auditables.
2. **Añadir `actions/attest-build-provenance@v2`.**
   - **Cómo**: step tras `docker/build-push-action@v6`, pasando `subject-digest: ${{ steps.push.outputs.digest }}`.
   - **Gana**: provenance autogenerada **firmada** por el runner vía OIDC.
3. **Habilitar los permisos mínimos**: `id-token: write`, `attestations: write`.
   - **Cómo**: bloque `permissions:` en el workflow.
   - **Gana**: autorización explícita para pedir OIDC token y publicar attestation.
4. **Pin por digest aguas abajo**: Argo CD referencia `ghcr.io/acme/svc@sha256:...` en vez de `:latest`.
   - **Cómo**: image updater o cambio manual del values.yaml.
   - **Gana**: no hay ventana de tiempo donde el tag apunta a otra imagen; el deploy es reproducible bit-a-bit.

Opcional pero recomendado: añadir `anchore/sbom-action` + `actions/attest-sbom@v2` para publicar SBOM como attestation.

## Sección C — De L2 a L3 (modelo)

Al menos 3 cambios adicionales:

1. **Enforcement de verificación en el consumidor.**
   - **Cómo**: Kyverno `ClusterPolicy` con `verifyImages` que exige `attest-build-provenance` del workflow concreto (`sec-11`).
   - **Gana**: cierra el *loop* productor→consumidor. Sin consumidor que verifique, L3 es decorativo.
2. **Pin por identidad del workflow + ref en la verificación.**
   - **Cómo**: `cosign verify-attestation --certificate-identity-regexp '^https://github.com/acme/repo/.github/workflows/release.yml@refs/heads/main$'`.
   - **Gana**: impide que un workflow en otra branch o repo genere attestations "válidas".
3. **Prohibir self-hosted runners para release workflows** (o aislarlos con ephemeral VMs).
   - **Cómo**: policy organizacional + branch protection que requiere el workflow con `runs-on: ubuntu-latest`.
   - **Gana**: builder isolation garantizada; self-hosted mal aislado rompe L3.

Opcional: branch protection "require signed commits" + `required_pull_request_reviews` prepara el terreno para L4.

## Sección D — Métricas (modelo)

Al menos 5 señales medibles:

- **% imágenes con `slsaprovenance1` adjunta** (meta: 100 % de las que llegan a prod).
- **% deploys bloqueados por `verify-attestation`** (señal de que el enforcement vive — meta: > 0 en no-prod).
- **Tiempo medio desde que un commit sale de `main` hasta que la imagen tiene attestation** (meta: < 10 min).
- **% workflows con `permissions.id-token: write` que **sí** lo necesitan** (meta: 100 % — ningún workflow con más permisos de los que usa).
- **Nº de entradas en Rekor por release / nº releases esperados** (sanity check: deben coincidir).
- Bonus: **% imágenes base con su propia attestation upstream** (hoy raro; metric a nacer).

## Sección E — Las 5 afirmaciones (modelo)

1. *"Si firmamos todas las imágenes, estamos en SLSA L3."* → **En desacuerdo.** Firmar ≠ provenance. SLSA pide provenance con contenido específico (buildType, resolvedDependencies, builder.id). La firma es necesaria pero no suficiente.
2. *"Un `Makefile release:` versionado ya es L1."* → **Depende.** L1 exige que el build **produzca provenance** (aunque sea manual). Un Makefile sin provenance = L0.
3. *"Subir de L2 a L3 no requiere cambios en el consumidor."* → **En desacuerdo.** L3 produce provenance non-forgeable, pero si el consumidor no la verifica con identity-pin, el salto L2→L3 **no se materializa** en garantía real.
4. *"Self-hosted runners pueden mantener L3 si están aislados."* → **De acuerdo (con asteriscos).** Es posible, pero requiere ephemeral VMs, políticas estrictas y una capa de aislamiento que la mayoría de equipos no implementa bien. En práctica: usa hosted runners para release workflows.
5. *"SBOM y SLSA provenance son independientes."* → **De acuerdo.** Responden preguntas distintas (*qué hay dentro* vs *cómo se construyó*). Pueden emitirse por separado, aunque se recomienda emitir **las dos** adjuntas al mismo digest.

## Punto a repetir

> SLSA L3 **sin** verificación en el consumidor es decoración. L2+verificación vale más que L3 sin verificar.
