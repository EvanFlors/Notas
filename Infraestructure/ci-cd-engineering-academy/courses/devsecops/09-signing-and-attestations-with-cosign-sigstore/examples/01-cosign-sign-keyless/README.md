# Ejemplo 01 — Firma keyless con cosign desde GitHub Actions (walkthrough)

> **Walkthrough.** No se ejecuta localmente. Reproducirlo requiere un token OIDC real emitido por GitHub Actions (sólo disponible dentro de un workflow con `permissions: id-token: write`). Para la práctica ejecutable con `registry:2` ver `activities/01-sign-capstone-image/`.

## 1. El flujo end-to-end (una ejecución típica)

```
┌──────────────────────── GitHub Actions runner ────────────────────────┐
│                                                                       │
│  on: push: tags: ['v*']                                               │
│  permissions:                                                         │
│    id-token: write     ◄── imprescindible para pedir el OIDC token   │
│    contents: read                                                     │
│    packages: write                                                    │
│                                                                       │
│  1) docker build + push → ghcr.io/acme/payments@sha256:ABC…           │
│  2) cosign sign ghcr.io/acme/payments@sha256:ABC…                     │
│     ├─ pide OIDC id-token al runner                                   │
│     ├─ POST a Fulcio con CSR + id-token                               │
│     ├─ recibe cert efímero (10 min) con SAN=workflow URI              │
│     ├─ firma el digest, descarta la priv key (RAM)                    │
│     └─ sube firma + cert + proof a Rekor y attach al OCI              │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

## 2. Workflow mínimo (anotado, lectura)

```yaml
name: release
on:
  push:
    tags: ['v*']

permissions:
  id-token: write        # necesario para que el runner pida el OIDC token
  contents: read
  packages: write        # para push a GHCR

jobs:
  build-and-sign:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: sigstore/cosign-installer@v3   # instala el binario

      - name: Login a GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build & push
        id: build
        uses: docker/build-push-action@v6
        with:
          push: true
          tags: ghcr.io/acme/payments:${{ github.ref_name }}

      - name: Sign (keyless)
        env:
          IMAGE: ghcr.io/acme/payments@${{ steps.build.outputs.digest }}
        run: |
          cosign sign --yes "$IMAGE"
```

## 3. ¿Qué hay en Rekor después?

Buscable en `https://search.sigstore.dev/` por el digest de la imagen. Cada entrada contiene:

- `hashedrekord` o `dsse` (según sea firma simple o attestation).
- Certificado emitido por Fulcio, con el SAN apuntando a `https://github.com/acme/payments/.github/workflows/release.yml@refs/tags/vX.Y.Z`.
- Timestamp firmado por Rekor.

## 4. Qué verá el consumidor

Para verificar sin tener nada local (fuera del binario cosign):

```bash
cosign verify \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity-regexp='^https://github.com/acme/payments/\.github/workflows/release\.yml@refs/tags/v[0-9]+' \
  ghcr.io/acme/payments:v1.2.3
```

Falla **con exit 1** si:

- La imagen no está firmada.
- La identidad no matchea el regex (ej.: alguien firmó desde un fork).
- El issuer no coincide.
- La inclusión en Rekor no se puede verificar.

## 5. Qué no hacer

- No omitir `--certificate-identity[-regexp]`. "Acepto cualquier cosa que Fulcio haya firmado" no es una política.
- No fijar identidad por nombre de workflow sin ref/tag — ver anti-patrón en `theory/lesson.md §5`.
- No reutilizar el patrón para builds locales de desarrolladores: para eso está `cosign sign --key`, o mejor **no firmar** y marcar la imagen como `-dev`.
