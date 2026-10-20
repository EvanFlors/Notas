# REFERENCE — gl-08-02-sign-and-publish

> Una referencia razonada. No es la única respuesta correcta.

---

## `.gitlab-ci.yml`

```yaml
stages: [build, sign, verify]

variables:
  IMAGE: "$CI_REGISTRY_IMAGE"

build:
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:v1.21.0-debug
    entrypoint: [""]
  script:
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"$CI_REGISTRY\":{\"username\":\"$CI_REGISTRY_USER\",\"password\":\"$CI_REGISTRY_PASSWORD\"}}}" > /kaniko/.docker/config.json
    - /kaniko/executor
        --context "$CI_PROJECT_DIR"
        --dockerfile "$CI_PROJECT_DIR/Dockerfile"
        --destination "$IMAGE:$CI_COMMIT_SHA"
        --digest-file "$CI_PROJECT_DIR/image.digest"
  artifacts:
    paths: [image.digest]
    expire_in: 7 days

sign:
  stage: sign
  image: gcr.io/projectsigstore/cosign:v2.2.3
  needs: ["build"]
  id_tokens:
    SIGSTORE_ID_TOKEN:
      aud: sigstore
  script:
    - DIGEST="$(cat image.digest)"
    - cosign sign --yes --identity-token "$SIGSTORE_ID_TOKEN" "$IMAGE@$DIGEST"

verify:
  stage: verify
  image: gcr.io/projectsigstore/cosign:v2.2.3
  needs: ["sign", "build"]
  script:
    - DIGEST="$(cat image.digest)"
    - cosign verify
        --certificate-identity "https://gitlab.com/$CI_PROJECT_PATH//.gitlab-ci.yml@refs/heads/$CI_DEFAULT_BRANCH"
        --certificate-oidc-issuer "https://gitlab.com"
        "$IMAGE@$DIGEST"
```

## `cleanup-policy.json`

```json
{
  "enabled": true,
  "cadence": "7d",
  "keep_n": 10,
  "older_than": "30d",
  "name_regex_delete": "^(pr-\\d+|sha-[0-9a-f]{7,40})$",
  "name_regex_keep": "^(v\\d+\\.\\d+\\.\\d+|main-.*|latest)$"
}
```

## `README-INTENT.md` (resumen)

```markdown
## Build (Kaniko)
Rootless, sin DinD, sin --privileged. Captura el digest con --digest-file.

## Firma keyless con cosign
id_tokens: SIGSTORE_ID_TOKEN con aud: sigstore. Se firma el digest
(IMAGE@sha256:...), nunca el tag :latest (los tags son mutables).

## Verificacion
--certificate-identity pineado a project_path + ref; --certificate-oidc-issuer
a https://gitlab.com. Un fork no pasa porque su sub claim difiere.

## SBOM y SLSA
Los scanners nativos emiten CycloneDX gl-sbom-*.cdx.json. SLSA provenance
nativa esta parcialmente disponible; cubrimos el gap con cosign attest.

## Cleanup policy
Preserva v\d+\.\d+\.\d+, main-* y latest. Borra pr-* y sha-* mas viejos
que 30d, conservando los 10 mas recientes.
```
