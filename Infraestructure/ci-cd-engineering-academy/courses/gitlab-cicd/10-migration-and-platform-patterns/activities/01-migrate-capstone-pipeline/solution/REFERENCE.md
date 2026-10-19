# REFERENCE — gl-10-01-migrate-capstone-pipeline

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

---

## Archivo 1 — `.gitlab-ci.yml`

```yaml
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

# Durante el dual-run se incluye el Componente del catálogo para OIDC a AWS.
include:
  - component: $CI_SERVER_FQDN/platform/ci-catalog/aws-oidc@1.0.0

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

---

## Archivo 2 — `MIGRATION-ADR.md`

# ADR 010 — Migración `my-org/api-checkout` de GitHub Actions a GitLab CI/CD

## Estado

Propuesto (Fase 3). Pendiente de aprobación por Platform + Security tras completar el dual-run de 3 semanas.

## Contexto

- La org decidió consolidarse en GitLab (Premium) para unificar código, pipelines y Compliance Frameworks bajo una sola plataforma.
- `my-org/api-checkout` es el **repo piloto** por ser el crítico (procesa pagos) y por tener un workflow representativo del resto de la org: lint, tests con matrix, build de imagen y OIDC a AWS.
- Constraints:
  - **No perder gates**: todo lo que bloquea un merge hoy debe seguir bloqueándolo.
  - **No romper deploys**: la trust policy de AWS debe aceptar GitLab antes de cortar GHA.
  - **Dual-run** de al menos 2 semanas con criterios de corte explícitos.
  - **Reutilización**: el bloque OIDC lo heredan 20+ repos de la org, debe terminar como Componente del catálogo interno `platform/ci-catalog`.

## Decisión

### 1. Mapping GHA → GitLab

| GHA | GitLab | Nota |
|-----|--------|------|
| `on: push: [main]` + `pull_request:` | `workflow: rules:` con `$CI_PIPELINE_SOURCE` y `$CI_COMMIT_BRANCH` | Filtro del pipeline entero en el entry-point. |
| `strategy.matrix: node: [18, 20]` | `parallel: matrix: - NODE_VERSION: ["18","20"]` + `image: node:$NODE_VERSION` | Semántica equivalente. |
| `needs: lint` | `needs: [lint]` | DAG casi idéntico. |
| `aws-actions/configure-aws-credentials@v4` | `id_tokens: AWS_ID_TOKEN: { aud: https://gitlab.com }` + `aws sts assume-role-with-web-identity` | Sin "action"; llamada STS directa, encapsulada en Componente. |
| `${{ github.sha }}` | `$CI_COMMIT_SHA` | Variable predefinida. |
| `actions/checkout@v4` | implícito | GitLab hace checkout automático. |
| `actions/setup-node@v4` | `image: node:20` | Elegimos la base del contenedor. |

### 2. Trust policy AWS (post-migración / durante dual-run acepta ambos)

```json
{
  "StringEquals": {
    "gitlab.com:aud": "https://gitlab.com",
    "gitlab.com:project_path": "my-org/api-checkout",
    "gitlab.com:ref_type": "branch",
    "gitlab.com:ref": "main"
  }
}
```

Durante el dual-run (2–4 semanas) la role trust mantiene **dos** statements: uno con `Federated: token.actions.githubusercontent.com` (GHA, por retirar) y otro con `Federated: gitlab.com` (nuevo, el de arriba). Al corte se elimina el de GHA.

### 3. CI/CD Component del catálogo

Promovemos el bloque OIDC a `platform/ci-catalog/aws-oidc@1.0.0` con contrato:

```yaml
spec:
  inputs:
    role_arn: { type: string }
    region:   { type: string, default: eu-west-1 }
    duration: { type: number, default: 900 }
```

20+ repos lo consumen con `include: - component: $CI_SERVER_FQDN/platform/ci-catalog/aws-oidc@1.0.0`.

### 4. Plan de dual-run

- **Semana 0**: pipeline GitLab en verde. GHA sigue siendo el *required status check* de la branch protection.
- **Semanas 1–2**: ambos pipelines corren en cada MR. Comparamos: mismos tests pasan, misma imagen (hash digest), misma tag en ECR.
- **Semana 3**: GitLab pasa a ser *required*. GHA se marca *optional*.
- **Semana 4**: GHA se desactiva y se elimina el statement GHA de la trust policy.

**Criterios de corte**:

- 10 MRs consecutivos sin discrepancias funcionales.
- `p95(pipeline_duration_gitlab) ≤ 1.2 × p95(pipeline_duration_gha)`.
- 0 incidencias de deploy fallido por OIDC en semana 2.
- Secretos migrados a GitLab (project/group variables protegidas) y rotados.

### 5. DAG del pipeline portado

```
lint ──► test (matrix 18, 20) ──► build-and-push (solo main)
                                      │
                                      ▼
                                   ECR eu-west-1
```

## Consecuencias

### Positivas

- Un único entry-point (`.gitlab-ci.yml`) frente a N workflows GHA. Menos duplicación.
- Componente `aws-oidc` reutilizable por 20+ repos; cambios OIDC se propagan por bump de versión.
- Trust policy pinneada por `project_path` + `ref_type` + `ref` (más estricta que la actual de GHA, que usaba `StringLike` sobre `sub`).
- `workflow:` filtra el pipeline completo; evita evaluar `rules:` por job sin necesidad.
- Preparados para el ADR final (`02`): catálogo + observabilidad + cost control sobre esta base.

### Negativas

- Durante el dual-run, los minutos de runner se duplican (GHA + GitLab). Mitigación: cap de 3 semanas máximo.
- La ausencia de "action marketplace" obliga a reescribir el OIDC a mano la primera vez. Mitigación: lo encapsulamos en el Componente.
- Dependencia nueva de `jq` y `aws` cli en la imagen del job de deploy. Mitigación: usar una imagen pre-hecha (`platform/aws-tools:1`).
- Developers tienen que aprender la UI nueva (MRs, Pipelines, Environments). Mitigación: sesión de 1h grabada.

## Alternativas descartadas

### Alt A — Big-bang sin dual-run

- Portar y cortar en el mismo día. Rechazada: la primera incidencia OIDC (típica: `aud:` incorrecto, trust policy con `sub` mal pinneado) nos deja sin deploy durante horas y no hay fallback. El dual-run cuesta minutos de runner, el big-bang cuesta un domingo.

### Alt B — Inline del `aws sts` en cada job sin promover a Componente

- Rechazada: 20+ repos duplicarían 15 líneas de shell. Un bugfix OIDC (por ejemplo, pasar a `--duration-seconds 1800` por un script que tarda más) obligaría a 20 MRs. Con Componente, es un bump de version y Renovate actualiza.

### Alt C — Mantener GHA y usar GitLab solo como mirror

- Rechazada: no da ganancia (seguimos pagando GHA) y pierde Compliance Frameworks y catálogo interno, que son dos de las razones de la migración corporativa.

### Alt D — Portar con `include: remote:` en vez de Componente

- Rechazada: `include: remote:` no tiene contrato tipado; cualquier error en el bloque remoto rompe silenciosamente. Componente valida `inputs:` en tiempo de pipeline.

---

## Notas sobre IDs / nombres

- `AWS_DEPLOY_ROLE_ARN`, `ECR`, `AWS_ID_TOKEN` son placeholders. El ARN real se registra en Group Variables protegidas, no en el ADR.
- `platform/ci-catalog/aws-oidc@1.0.0` es el path esperado tras publicar al catálogo del grupo `platform`.
