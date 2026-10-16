# Ejemplo 03 — SLSA v1.0: recorrido por los niveles

> Lectura y análisis. Sin ejecución. Objetivo: ver, con pipelines concretos, qué nivel SLSA representa cada uno y qué cambio exacto hace falta para subir un escalón.

## 1. Recordatorio: qué es SLSA

**SLSA** = *Supply-chain Levels for Software Artifacts*. Framework de la OpenSSF que define niveles progresivos de garantía sobre **cómo se construye** un artefacto. v1.0 tiene 3 niveles operativos (L1, L2, L3) + L4 reservado.

**Objeto central:** la **provenance** = documento firmado que dice *qué código fuente, qué builder, qué workflow, qué timestamp* produjeron el artefacto. SLSA no es "¿qué hay en el binario?" (eso es SBOM); es "¿cómo llegó a existir ese binario?".

## 2. L0 — Sin garantía (anti-patrón)

Workflow típico (lo que *no* queremos):

```yaml
# .github/workflows/release.yml  (L0 — anti-patrón)
on: workflow_dispatch
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - run: docker build -t myapp:latest .
      - run: docker push myapp:latest   # mutable tag, no digest, no attestation
```

Problemas:

- **Tag mutable** (`:latest`). Mañana puede ser otra imagen.
- **No publica digest**. Los consumidores no pueden pinnear.
- **No hay provenance**. Nadie sabe de qué commit salió.
- **Builder = quien ejecute el workflow** (puede ser cualquiera con permisos).

## 3. L1 — Build script documentado + provenance mínima

Cambios respecto a L0:

```yaml
# .github/workflows/release.yml  (L1)
on: workflow_dispatch
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build and push with digest
        id: build
        run: |
          # Dockerfile está versionado en el repo (build script documentado)
          docker build -t ghcr.io/org/myapp:${{ github.sha }} .
          docker push ghcr.io/org/myapp:${{ github.sha }}
          digest=$(docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/org/myapp:${{ github.sha }})
          echo "digest=$digest" >> "$GITHUB_OUTPUT"
      - name: Write minimal provenance
        run: |
          cat > provenance.json <<EOF
          {
            "subject": [{ "digest": { "sha256": "${{ steps.build.outputs.digest }}" } }],
            "builder": "github-actions-manual",
            "source": "github.com/org/repo@${{ github.sha }}"
          }
          EOF
          # publicar provenance.json como asset del release
```

Garantías L1:

- Build script (`Dockerfile`) versionado y reproducible.
- Provenance mínima publicada (dice "este digest salió de este commit").
- Tag inmutable por SHA.

**No** protege de un autor malicioso que escriba provenance mentirosa — porque la escribe él mismo.

## 4. L2 — Hosted builder + provenance firmada por el builder

Cambio clave: la provenance la emite el **builder hospedado**, no el autor. GitHub Actions con `attest-build-provenance` lo hace nativo:

```yaml
# .github/workflows/release.yml  (L2)
on:
  push:
    tags: ['v*']
permissions:
  contents: read
  packages: write
  id-token: write        # necesario para keyless signing (OIDC)
  attestations: write    # necesario para attest-build-provenance
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - id: push
        uses: docker/build-push-action@v6
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
      - uses: actions/attest-build-provenance@v2
        with:
          subject-name: ghcr.io/${{ github.repository }}
          subject-digest: ${{ steps.push.outputs.digest }}
          push-to-registry: true
```

Garantías adicionales respecto a L1:

- La provenance la genera **el builder** (GitHub Actions), no el autor.
- Está **firmada** (keyless con Fulcio/Rekor).
- Incluye materiales: commit SHA, workflow path, trigger, timestamp — todo auditable.

**Dónde se queda corto L2**: el builder podría, en teoría, ser manipulado por un workflow adversarial. L3 cierra esa puerta.

## 5. L3 — Non-forgeable + builder isolation

En GitHub, L3 se consigue con `slsa-github-generator` (reusable workflow oficial de OpenSSF) o con la cadena `attest-build-provenance` + verificación estricta:

```yaml
# .github/workflows/release.yml  (L3 vía slsa-github-generator)
on:
  push:
    tags: ['v*']
permissions:
  id-token: write
  contents: read
  packages: write
jobs:
  build:
    outputs:
      image: ${{ steps.push.outputs.image }}
      digest: ${{ steps.push.outputs.digest }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - id: push
        uses: docker/build-push-action@v6
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}

  provenance:
    needs: [build]
    permissions:
      id-token: write
      actions: read
      packages: write
    uses: slsa-framework/slsa-github-generator/.github/workflows/generator_container_slsa3.yml@v2
    with:
      image: ${{ needs.build.outputs.image }}
      digest: ${{ needs.build.outputs.digest }}
      registry-username: ${{ github.actor }}
    secrets:
      registry-password: ${{ secrets.GITHUB_TOKEN }}
```

Garantías adicionales respecto a L2:

- La generación de provenance corre en un **job separado** y aislado, **no en el mismo runner** que el build.
- El autor del workflow **no puede** interferir con la generación (el reusable workflow corre bajo identidad separada).
- El OIDC claim del builder está vinculado al workflow concreto; un atacante que modifique el repo cambiaría el claim y la verificación fallaría.

Verificación (lado consumidor):

```bash
# fake values; NO son credenciales
cosign verify-attestation \
  --type slsaprovenance \
  --certificate-identity-regexp "^https://github.com/slsa-framework/slsa-github-generator" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/org/myapp@sha256:FAKE_DIGEST_ONLY_FOR_EXAMPLE
```

## 6. L4 — Reservado

v1.0 lo deja sin especificar. Discusión abierta sobre:

- **Two-party review** de todo cambio al código fuente *y* al build config.
- Builds **hermetic** (sin red, dependencias pinnadas por digest, output bit-por-bit reproducible).
- Verificación cross-replica (varios builders independientes producen el mismo digest).

En práctica, L3 es el techo operativo hoy.

## 7. Tabla resumen

| Nivel | Qué garantiza | Trabajo para llegar | Qué evita |
|-------|---------------|---------------------|-----------|
| L0 | Nada | n/a | Nada. |
| L1 | Build script versionado + provenance mínima autodeclarada | Documentar Dockerfile, publicar digest y attestation JSON | Errores humanos triviales ("¿qué commit?"). |
| L2 | Provenance generada **por builder hospedado**, firmada | Mover build a GHA/GCB, usar `attest-build-provenance` | Provenance forjada por el autor en su laptop. |
| L3 | Non-forgeable: autor no puede escribir en el proceso de provenance; builder isolation | Reusable workflow `slsa-github-generator` o equivalente | Manipulación del runner/entorno de build por el autor. |
| L4 | Two-party review + hermetic builds | Bastante alto; aún no estandarizado | Insider con un solo set de credenciales. |

## 8. Lecciones a extraer

- Subir de L0 a L1 es **documentación + disciplina de tags**. Cero infra nueva.
- Subir de L1 a L2 es **cambiar el flag correcto** (`attest-build-provenance` + `permissions:` correctos). Horas.
- Subir de L2 a L3 es **cambiar la estructura del workflow** para que la provenance la genere un job aislado. Días, no semanas.
- Lo caro **no** es llegar a L3; lo caro es **mantener** la verificación en el consumidor (política + runbook + rotación de identidades esperadas).

## 9. Para discutir

- Si tu pipeline hoy es L0 y tienes 1 día: ¿subes a L1 o invierte el día en algo distinto?
- ¿Qué parte de L3 **no funciona** si tu organización no está en GitHub (p. ej. GitLab self-hosted)? ¿Hay equivalente?
- ¿Qué pasa si el **consumidor** nunca verifica la provenance que publicas? ¿Para qué sirvió entonces?
