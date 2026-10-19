# Starter — gl-08-02-sign-and-publish

Esta actividad es **independiente**. Produces 3 archivos.

## Pasos

1. Lee `../README.md` y recorre `../../examples/03-cosign-keyless-with-gitlab-oidc/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gl-08-sign
   cd /tmp/gl-08-sign
   ```
3. Escribe `.gitlab-ci.yml` con stages `build`, `sign`, `verify`.
4. Escribe `cleanup-policy.json` con `enabled`, `cadence`, `keep_n`, `older_than`, `name_regex_delete`, `name_regex_keep`.
5. Escribe `README-INTENT.md` con las 5 secciones listadas en `../README.md` §5.4.
6. Valida:
   ```bash
   python3 -c 'import yaml; yaml.safe_load(open(".gitlab-ci.yml"))'
   jq . cleanup-policy.json
   bash <ruta-repo>/courses/gitlab-cicd/08-security-scanners-registry-and-supply-chain/activities/02-sign-and-publish/tests/validate.sh /tmp/gl-08-sign
   ```

## Esqueleto `.gitlab-ci.yml`

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
