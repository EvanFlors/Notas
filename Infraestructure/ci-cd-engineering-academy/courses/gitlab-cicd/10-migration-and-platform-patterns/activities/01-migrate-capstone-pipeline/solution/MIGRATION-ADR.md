# ADR 010 — Migración my-org/api-checkout de GitHub Actions a GitLab CI/CD

## Estado

Propuesto (Fase 3). Pendiente de aprobación por Platform + Security tras completar el dual-run de 3 semanas.

## Contexto

- La org decidió consolidarse en GitLab (Premium) para unificar código, pipelines y Compliance Frameworks.
- `my-org/api-checkout` es el repo piloto por ser el crítico (procesa pagos) y por tener un workflow representativo: lint, tests con matrix, build de imagen y OIDC a AWS.
- Constraints:
  - No perder gates (todo lo que bloquea un merge hoy debe seguir bloqueándolo).
  - No romper deploys: la trust policy de AWS debe aceptar GitLab antes de cortar GHA.
  - Dual-run de al menos 2 semanas con criterios de corte explícitos.
  - El bloque OIDC lo heredan 20+ repos; debe terminar como CI/CD Component del catálogo interno.

## Decisión

### 1. Mapping GHA -> GitLab

| GHA | GitLab | Nota |
|-----|--------|------|
| `on: push: [main]` + `pull_request:` | `workflow: rules:` con `$CI_PIPELINE_SOURCE` y `$CI_COMMIT_BRANCH` | Filtro del pipeline entero en el entry-point. |
| `strategy.matrix: node: [18, 20]` | `parallel: matrix: - NODE_VERSION: ["18","20"]` + `image: node:$NODE_VERSION` | Semántica equivalente. |
| `needs: lint` | `needs: [lint]` | DAG casi idéntico. |
| `aws-actions/configure-aws-credentials@v4` | `id_tokens: AWS_ID_TOKEN: { aud: https://gitlab.com }` + `aws sts assume-role-with-web-identity` | Encapsulado en CI/CD Component. |
| `${{ github.sha }}` | `$CI_COMMIT_SHA` | Variable predefinida. |
| `actions/checkout@v4` | implícito | GitLab hace checkout automático. |
| `actions/setup-node@v4` | `image: node:20` | Elegimos la base del contenedor. |

### 2. Trust policy AWS (nueva)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Federated": "arn:aws:iam::123456789012:oidc-provider/gitlab.com" },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "gitlab.com:aud": "https://gitlab.com",
          "gitlab.com:project_path": "my-org/api-checkout",
          "gitlab.com:ref_type": "branch",
          "gitlab.com:ref": "main"
        }
      }
    }
  ]
}
```

Durante el dual-run la role trust mantiene **dos** statements: uno con `Federated: token.actions.githubusercontent.com` (GHA, por retirar) y otro con `Federated: gitlab.com`. Al corte se elimina el de GHA.

### 3. CI/CD Component del catálogo interno

Promovemos el bloque OIDC a `platform/ci-catalog/aws-oidc@1.0.0`:

```yaml
spec:
  inputs:
    role_arn: { type: string }
    region:   { type: string, default: eu-west-1 }
    duration: { type: number, default: 900 }
```

20+ repos lo consumen vía `include: - component: $CI_SERVER_FQDN/platform/ci-catalog/aws-oidc@1.0.0`.

### 4. Plan de dual-run

- Semana 0: pipeline GitLab en verde; GHA sigue siendo *required status check*.
- Semanas 1–2: ambos pipelines corren en cada MR; comparamos resultados (tests, digest de imagen, tag en ECR).
- Semana 3: GitLab pasa a *required*; GHA se marca *optional*.
- Semana 4: GHA se desactiva y se elimina el statement GHA de la trust policy.

Criterios de corte:

- 10 MRs consecutivos sin discrepancias funcionales.
- `p95(duration_gitlab) <= 1.2 x p95(duration_gha)`.
- 0 incidencias de deploy fallido por OIDC en semana 2.
- Secretos migrados a GitLab (variables de group/project protegidas) y rotados.

### 5. DAG del pipeline portado

```
lint -> test (matrix 18, 20) -> build-and-push (solo main) -> ECR eu-west-1
```

## Consecuencias

### Positivas

- Un único entry-point frente a N workflows GHA; menos duplicación.
- Componente `aws-oidc` reutilizable por 20+ repos; cambios OIDC se propagan por bump de versión.
- Trust policy pinneada por `project_path` + `ref_type` + `ref` (más estricta que la actual GHA con `StringLike` sobre `sub`).
- `workflow:` filtra el pipeline completo; evita evaluar `rules:` por job sin necesidad.

### Negativas

- Durante el dual-run los minutos de runner se duplican (GHA + GitLab). Mitigación: cap de 3 semanas máximo.
- Reescritura del OIDC a mano la primera vez (sin marketplace). Mitigación: encapsulado en Componente.
- Dependencia de `jq` y `aws` cli en la imagen del job de deploy. Mitigación: imagen pre-hecha `platform/aws-tools:1`.

## Alternativas descartadas

### Alt A — Big-bang sin dual-run

1. Portar y cortar el mismo día.
2. Rechazada: la primera incidencia OIDC (típica: `aud:` incorrecto, `sub` mal pinneado) nos deja sin deploy durante horas sin fallback. El dual-run cuesta minutos; el big-bang cuesta un domingo.

### Alt B — Inline del `aws sts` en cada job sin Componente

1. Duplicar 15 líneas de shell en 20+ repos.
2. Rechazada: un bugfix OIDC obligaría a 20 MRs; con Componente, es un bump de version y Renovate actualiza.

### Alt C — Mantener GHA y usar GitLab solo como mirror

- Rechazada: pierde Compliance Frameworks y catálogo interno, que son dos de las razones de la migración corporativa.

### Alt D — Portar con `include: remote:` en vez de Componente

- Rechazada: `include: remote:` no tiene contrato tipado; Componente valida `inputs:` en tiempo de pipeline.
