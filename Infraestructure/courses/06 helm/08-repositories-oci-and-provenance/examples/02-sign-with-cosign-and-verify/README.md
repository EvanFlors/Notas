# Ejemplo 02 — Firmar un chart OCI con cosign y verificar

## Concepto que demuestra

Firmar un chart publicado como artefacto OCI con **cosign** (por digest, nunca por tag) y verificar la firma, en ambos modos:

- **`MODE=local`** (default) — `registry:2` en `localhost:5000`, cosign con key pair local y `--tlog-upload=false` + `--insecure-ignore-tlog`. No requiere internet.
- **`MODE=live`** — publica a GHCR y firma keyless (abre browser para OAuth2 contra Sigstore si no hay OIDC runner).

Incluye una **prueba negativa**: `cosign verify` con una clave distinta debe fallar.

## Contexto

Ver `theory/lesson.md` §7 (cosign + OCI) y §8 (comparación con `.prov` + GPG).

## Archivos

- `run.sh` — orquesta package + push + firma + verify + prueba negativa.

## Ejecución

### MODE=local (recomendado para aprender)

```bash
bash run.sh
# o workdir custom
bash run.sh /tmp/mi-ex02
```

### MODE=live

```bash
MODE=live REGISTRY=ghcr.io/yourorg bash run.sh
```

Para verificar en `MODE=live` necesitas conocer la identidad OIDC con la que firmaste. Si usas tu usuario personal desde terminal, será algo como:

```bash
cosign verify oci://ghcr.io/yourorg/charts/signed-demo@sha256:... \
  --certificate-identity 'you@example.com' \
  --certificate-oidc-issuer 'https://github.com/login/oauth'
```

Desde un workflow GHA la identity es la URL del workflow:

```bash
cosign verify ... \
  --certificate-identity-regexp 'https://github\.com/yourorg/yourrepo/\.github/workflows/.*' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com'
```

## Qué mirar

Después del `cosign sign` en `MODE=local`, el registry muestra el artefacto firma como tag derivado:

```bash
curl -s http://localhost:5000/v2/charts/signed-demo/tags/list | jq
# {
#   "name": "charts/signed-demo",
#   "tags": ["0.1.0", "sha256-<digest>.sig"]
# }
```

## Limpieza

```bash
docker stop helm-08-ex02-reg 2>/dev/null || true
rm -rf /tmp/helm-08-ex02
```

## Referencias

- `theory/lesson.md` §7.
- `courses/docker/14-supply-chain-sbom-signing-provenance/examples/03-cosign-keyless-and-verify/` — el mismo patrón sobre una imagen.
- `resources/links.md` → cosign, Sigstore.
