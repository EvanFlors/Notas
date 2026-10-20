# Ejemplo 01 — Portar un workflow GHA a `.gitlab-ci.yml`

> Lectura y análisis. Sin ejecución. Objetivo: ver un porting real paso a paso y memorizar los *gotchas*.

## 1. El workflow GHA de partida

Un workflow típico de una API Node que corre lint, tests, build de imagen y despliegue vía OIDC a AWS. Resumido:

```yaml
# .github/workflows/ci.yml
name: ci
on:
  push: { branches: [main] }
  pull_request: {}

permissions:
  id-token: write
  contents: read

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci
      - run: npm run lint

  test:
    runs-on: ubuntu-latest
    needs: lint
    strategy:
      matrix:
        node: [18, 20]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: ${{ matrix.node }}, cache: npm }
      - run: npm ci
      - run: npm test -- --coverage

  build-and-push:
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/gha-build
          aws-region: eu-west-1
      - run: |
          docker build -t $ECR/api:${{ github.sha }} .
          docker push $ECR/api:${{ github.sha }}
```

## 2. El `.gitlab-ci.yml` equivalente

```yaml
# .gitlab-ci.yml
stages: [lint, test, build]

default:
  image: node:20
  cache:
    key:
      files: [package-lock.json]
    paths: [node_modules/]

workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == "main"

lint:
  stage: lint
  script:
    - npm ci
    - npm run lint

test:
  stage: test
  needs: [lint]
  parallel:
    matrix:
      - NODE_VERSION: ["18", "20"]
  image: node:$NODE_VERSION
  script:
    - npm ci
    - npm test -- --coverage

build-and-push:
  stage: build
  needs: [test]
  image: docker:27
  services: [docker:27-dind]
  variables:
    DOCKER_TLS_CERTDIR: /certs
  id_tokens:
    AWS_ID_TOKEN:
      aud: https://gitlab.com
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  script:
    - aws sts assume-role-with-web-identity
        --role-arn $AWS_DEPLOY_ROLE_ARN
        --role-session-name gl-$CI_JOB_ID
        --web-identity-token $AWS_ID_TOKEN
        --duration-seconds 900 > creds.json
    - export AWS_ACCESS_KEY_ID=$(jq -r .Credentials.AccessKeyId creds.json)
    - export AWS_SECRET_ACCESS_KEY=$(jq -r .Credentials.SecretAccessKey creds.json)
    - export AWS_SESSION_TOKEN=$(jq -r .Credentials.SessionToken creds.json)
    - aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin $ECR
    - docker build -t $ECR/api:$CI_COMMIT_SHA .
    - docker push $ECR/api:$CI_COMMIT_SHA
```

## 3. Mapping línea a línea

| GHA | GitLab | Nota |
|-----|--------|------|
| `on: push: branches: [main]` + `pull_request:` | `workflow:` con `$CI_PIPELINE_SOURCE == "merge_request_event"` y `$CI_COMMIT_BRANCH == "main"` | Un único entry-point; `workflow:` filtra el pipeline entero. |
| `jobs.<x>.steps:` | `script:` (lista de shell) | GitLab no tiene *steps*; agrupas con `script:` y `before_script:`/`after_script:`. |
| `actions/checkout@v4` | **implícito** | GitLab hace checkout automático al inicio del job. |
| `actions/setup-node@v4` | `image: node:20` | Elige la base del contenedor directamente. |
| `strategy.matrix: node: [18, 20]` | `parallel: matrix: - NODE_VERSION: ["18","20"]` | Semántica equivalente. |
| `needs: lint` + `if: github.ref == 'refs/heads/main'` | `needs:` + `rules: if: $CI_COMMIT_BRANCH == "main"` | DAG igual; `rules:` filtra. |
| `aws-actions/configure-aws-credentials@v4` + OIDC | `id_tokens:` + `aws sts assume-role-with-web-identity` | Sin "action": haces la llamada STS a mano. |
| `${{ github.sha }}` | `$CI_COMMIT_SHA` | Variable predefinida equivalente. |
| cache `actions/setup-node@v4 with: cache: npm` | `cache:` de GitLab con `key:files:[package-lock.json]` | GitLab tiene cache nativo por job. |

## 4. Lo que cambia en la trust policy AWS

### Antes (GHA)

```json
{
  "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
  "StringLike":   { "token.actions.githubusercontent.com:sub": "repo:my-org/my-api:*" }
}
```

### Después (GitLab)

```json
{
  "StringEquals": {
    "gitlab.com:aud": "https://gitlab.com",
    "gitlab.com:project_path": "my-group/my-api",
    "gitlab.com:ref_type": "branch",
    "gitlab.com:ref": "main"
  }
}
```

Durante el **dual-run**, la trust policy acepta ambos issuers (dos statements con `Federated:` distintos). Al corte, se elimina el de GHA.

## 5. Decisiones no obvias de este porte

- **`image: node:20` en `default:`**: en lugar de `setup-node` por job, se fija globalmente. Un job de matrix lo sobreescribe (`image: node:$NODE_VERSION`).
- **`workflow:` en lugar de `rules:` por job para MR**: filtrar el pipeline entero en el entry-point es más barato y legible que repetir `rules:` en cada job.
- **DinD con TLS**: `DOCKER_TLS_CERTDIR: /certs` evita el modo inseguro. En runners propios, muchas orgs prefieren `kaniko` o `buildkit` sin daemon.
- **`$AWS_DEPLOY_ROLE_ARN` como variable protegida**: expuesta solo a jobs que corren en `main` (branch protegida). Sin esto, un MR podría leerla.
- **Checkout implícito**: la línea `uses: actions/checkout@v4` desaparece. Olvidarlo en un porting es inocuo (ya ocurre); el error inverso (en GHA olvidarlo) sí rompe.

## 6. Preguntas de autocomprobación

1. ¿Qué pasa si olvidas `rules:` en `build-and-push` y haces un MR? ¿El job corre?
2. ¿Por qué el `aud:` del `id_tokens:` tiene que ser `https://gitlab.com` **exacto**?
3. En la trust policy, ¿por qué pinnear `ref_type` además de `ref`?
4. Si el equipo cambia `main` por `trunk`, ¿qué 3 sitios tocas para no romper nada?
5. ¿Cómo convertirías el bloque `aws sts assume-role-with-web-identity` repetido en 5 jobs en un **CI/CD Component** del catálogo?

Las respuestas se trabajan en la actividad `01-migrate-capstone-pipeline`.
