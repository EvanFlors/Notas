# Ejemplo 03 — Firma y verificación de imágenes con cosign

## Concepto que demuestra

Firma de una imagen OCI con **cosign** en dos modos:

1. **Keyless (OIDC)** — recomendado en CI. En GHA la identidad proviene del OIDC token del runner; local, abre un browser para autenticar con GitHub/Google/Microsoft.
2. **Key pair local** — útil para demos sin red, aire acomplado, o CI que no puede alcanzar Sigstore pública.

Y verificación de ambos.

## Contexto

Ver `theory/lesson.md` secciones 2.2, 4.1 y 4.5.

Diferencia operativa importante: la **firma** valida *bytes* (digest). La **attestation** adjunta *afirmaciones estructuradas* firmadas (predicados). En GHCR ambas quedan como *referrers* del digest de la imagen.

## Archivos

- `workflow-keyless.yml` — workflow que firma con keyless + verifica. Para `.github/workflows/sign.yml`.
- `local-demo.sh` — script 100% local con `registry:2` + key pair + cosign (lo que corren los tests de la actividad 01 en MODE=local).

## Modo keyless en GHA

```yaml
permissions:
  contents: read
  packages: write
  id-token: write        # imprescindible para keyless
steps:
  - uses: sigstore/cosign-installer@d7d6e113b16d7d6f54e9c0ff52a95f31f3cce3b7  # v3.9.1
  - name: Sign
    env:
      IMAGE: ghcr.io/${{ github.repository }}/app@${{ steps.push.outputs.digest }}
    run: cosign sign --yes "$IMAGE"
```

`cosign sign` sin `--key` entra en modo keyless: lee `ACTIONS_ID_TOKEN_REQUEST_URL` + `ACTIONS_ID_TOKEN_REQUEST_TOKEN` del runner, pide un OIDC JWT a GitHub con audience `sigstore`, lo canjea en Fulcio por un cert efímero, firma, y publica en Rekor.

## Verificación keyless

```bash
cosign verify ghcr.io/OWNER/REPO/app:v1.2.3 \
  --certificate-identity-regexp '^https://github\.com/OWNER/REPO/\.github/workflows/sign\.yml@refs/tags/v.*$' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com'
```

**Las dos flags no son opcionales** en producción. Sin ellas:

- Sin `--certificate-oidc-issuer` → aceptas *cualquier* issuer OIDC que Fulcio soporte. Un atacante con cuenta en otro IdP puede engañar.
- Sin `--certificate-identity-regexp` (o `--certificate-identity`) → aceptas firmas de *cualquiera*. Carece de sentido.

Regex útil:

```
^https://github\.com/OWNER/REPO/\.github/workflows/release\.yml@refs/tags/v[0-9]+(\.[0-9]+){2}$
```

Esto solo acepta tags SemVer en el workflow `release.yml` del repo exacto.

## Modo key pair (local, sin red externa)

```bash
# Generar par (una vez)
export COSIGN_PASSWORD=''
cosign generate-key-pair
# → cosign.key (privada) + cosign.pub (pública)

# Firmar
cosign sign --key cosign.key localhost:5000/app@sha256:abc...

# Verificar
cosign verify --key cosign.pub localhost:5000/app@sha256:abc...
```

Para que `cosign sign` key-based **no** intente contactar Rekor público, exporta:

```bash
export COSIGN_EXPERIMENTAL=0   # evita push a Rekor público desde modo keyless accidental
# Y pasa --tlog-upload=false si quieres evitar Rekor en keyless también.
cosign sign --key cosign.key --tlog-upload=false localhost:5000/app@sha256:abc...
cosign verify --key cosign.pub --insecure-ignore-tlog localhost:5000/app@sha256:abc...
```

Esta modalidad es la que usa el script `local-demo.sh` y los tests MODE=local.

## Flujo del demo local

```
┌───────────────────┐  push   ┌──────────────────────┐
│ docker build      │ ──────> │ registry:2 en :5000  │
└───────────────────┘         └──────────────────────┘
         │                              │
         │                              ▼
         │                   ┌──────────────────────┐
         └─────> cosign ────>│ firma como referrer  │
                             │ al digest de la img  │
                             └──────────────────────┘
                                        │
                                        ▼
                             cosign verify --key cosign.pub
                                        │
                                        ▼
                                       OK
```

## Buenas prácticas

- **Firma el digest**, no el tag. `cosign sign repo:tag` lo convierte internamente pero es mejor que lo veas explícito: `cosign sign repo@sha256:...`.
- **Pin `sigstore/cosign-installer` a SHA**.
- **En producción crítica**, firma en un workflow aparte con `environment: release` + required reviewers.
- **Verifica también la attestation**, no solo la firma — ver ejemplo 02.

## Errores frecuentes

- `cosign sign` sin `--yes` → espera confirmación interactiva y timeouts en CI.
- Olvido de `id-token: write` en keyless.
- Verificar con el regex de identidad apuntando al workflow equivocado → `no matching signatures`.
- Pushear a GHCR como `ghcr.io/USER/image` (con el `USER` como path) vs `ghcr.io/USER/REPO/image` — formato correcto es `ghcr.io/OWNER/REPO/<name>` (OWNER puede ser user u org); comprueba con `docker inspect`.
- Firmar imagen local no pusheada → `cosign sign` necesita el digest en el registry.

## Referencia

- <https://docs.sigstore.dev/cosign/signing/overview/>
- <https://github.com/sigstore/cosign-installer>
- <https://docs.sigstore.dev/cosign/verifying/verify/>
