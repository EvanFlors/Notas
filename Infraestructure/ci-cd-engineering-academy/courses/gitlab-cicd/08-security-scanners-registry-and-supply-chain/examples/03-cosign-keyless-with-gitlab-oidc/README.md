# Ejemplo 03 — Firma keyless con cosign + ID Token de GitLab

> Objetivo: ver el pipeline *build → sign → verify* **sin claves de larga vida**, usando el ID Token que GitLab emite por job como credencial OIDC para Sigstore.

## 1. El `.gitlab-ci.yml`

Ver `.gitlab-ci.yml`. Flujo:

1. `build` — Kaniko construye y publica la imagen, dejando el digest en `image.digest`.
2. `sign` — `cosign sign --yes` con `id_tokens: SIGSTORE_ID_TOKEN: { aud: sigstore }`. Firma el digest **immutable** (no el tag).
3. `verify` — `cosign verify` con `--certificate-identity` pinneado a `project_path` + `ref`.

## 2. Lectura clave

- **El digest, no el tag**. Firmar `:latest` es inseguro: el tag puede ser repunteado. Siempre `@sha256:…`.
- **`aud: sigstore`** es el audience que Sigstore espera para issuer `https://gitlab.com`.
- **`--certificate-identity`** acepta un string exacto. El `//.gitlab-ci.yml@refs/heads/main` es el subject del JWT emitido por GitLab para jobs del pipeline del propio `.gitlab-ci.yml` en la ref `main`. Para tags, se usaría `@refs/tags/vX.Y.Z`.
- **`--certificate-oidc-issuer`** fija el issuer (`https://gitlab.com` o la URL de tu Self-Managed).

## 3. ¿Qué pasa si un atacante forkea?

Un fork hereda el repo pero no el `$CI_PROJECT_PATH`. El ID Token emitido en el fork lleva otro `sub` claim. La verificación falla:

```
Error: no matching certificate identity found
```

Mismo resultado si se intenta firmar desde una branch distinta a `main`: la verificación de `verify` ancla la ref.

## 4. Attestations (opcional)

Se puede añadir un job `attest:` con `cosign attest --predicate provenance.json --type slsaprovenance`. Consumidores que apliquen `policy-controller` en Kubernetes rechazarán imágenes sin attestation válida.

## 5. Verificación local

```bash
python3 -c 'import yaml,sys; yaml.safe_load(open(".gitlab-ci.yml"))'
grep -c 'id_tokens:' .gitlab-ci.yml   # debe ser >=1
```
