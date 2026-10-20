# REFERENCE — sec-09-02-verify-in-clean-env

> Modelo razonado. No es la única respuesta correcta — es un modelo contra el que compararte.

## Sección A — Supuestos y alcance

- El consumidor dispone de `cosign >= 2.x` y acceso a Internet (Rekor público, raíz TUF de Sigstore).
- El productor firma **keyless** la imagen `ghcr.io/acme/capstone-api@sha256:<digest>` desde `.github/workflows/release.yml` al taggear `v<MAJOR>.<MINOR>.<PATCH>` en el repo `acme/capstone-api`.
- La imagen lleva adjunta una attestation SLSA provenance (`actions/attest-build-provenance`).
- No hay distribución previa de pub keys al consumidor: la raíz de confianza es Fulcio + Rekor.
- Alcance: verificación pre-despliegue (puede automatizarse en CI del consumidor, en admission controller en K8s, o manualmente por un auditor).

## Sección B — Comando canónico

Verificación de la firma de la imagen:

```bash
cosign verify \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity-regexp='^https://github.com/acme/capstone-api/\.github/workflows/release\.yml@refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$' \
  ghcr.io/acme/capstone-api@sha256:<digest>
```

Verificación de la attestation SLSA provenance:

```bash
cosign verify-attestation \
  --type=slsaprovenance1 \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  --certificate-identity-regexp='^https://github.com/acme/capstone-api/\.github/workflows/release\.yml@refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$' \
  ghcr.io/acme/capstone-api@sha256:<digest>
```

Notas:

- Siempre por **digest**, nunca por tag mutable.
- El regex está **anclado** (`^...$`) y restringido a tags release.
- `cosign` consulta Rekor internamente para confirmar la inclusión; opcionalmente, `--offline` si se pre-cachea el bundle.

## Sección C — Fallos esperados y cómo leerlos

| Síntoma                                                       | Interpretación                             | Acción                                   |
|---------------------------------------------------------------|--------------------------------------------|------------------------------------------|
| `no matching signatures`                                      | Imagen sin firma adjunta                   | Rechazar: no cumple política.            |
| `no matching certificate identity`                            | Firmada por otra identidad (otro repo/workflow/branch) | Rechazar: potencial suplantación.        |
| `certificate issued by unrecognized issuer`                   | Otro OIDC issuer                           | Rechazar.                                |
| `error getting rekor entry`                                    | Rekor inaccesible / entry ausente          | Investigar antes de aceptar — no mergear a enforcement si solo es un outage transitorio. |
| `verify-attestation`: `no attestations found with type=…`     | Sin provenance adjunta                     | Rechazar en política estricta.           |

## Sección D — Checklist pre-despliegue (5 ítems)

1. ¿Estoy verificando por **digest** (sha256:...) y no por tag mutable?
2. ¿El comando incluye `--certificate-oidc-issuer` **y** `--certificate-identity-regexp` anclado?
3. ¿El regex permite **solo** tags release (`refs/tags/v...`), no branches ni PRs?
4. ¿Verifico además la attestation `--type=slsaprovenance1` del mismo digest, con los mismos pins de identidad?
5. ¿La verificación consulta Rekor (transparency log) y la inclusión es válida?

## Anti-patrones a cazar en revisión

- `cosign verify` sin `--certificate-identity[-regexp]` → acepta cualquier firma.
- Pin por branch (`refs/heads/main`) → vulnerable a push/replace de workflow en main.
- `--certificate-identity-regexp 'acme/capstone-api'` sin anclas → matchea `evil/acme/capstone-api-mirror/...`.
- Verificar firma pero **no** attestation → autenticas quién publicó, no cómo se construyó.
