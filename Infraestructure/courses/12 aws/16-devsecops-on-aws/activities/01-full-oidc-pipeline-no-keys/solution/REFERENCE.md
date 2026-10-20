# REFERENCE — aws-16-01-full-oidc-pipeline-no-keys

> Una **referencia** razonada. No es la única respuesta correcta; es un modelo contra el que compararte.

## 1. `terraform/main.tf` (modelo)

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# OIDC provider for GitHub Actions. AWS recomputes the thumbprint
# automatically; the value below is a well-known reference.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "gha_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:${var.github_ref}"]
    }
  }
}

resource "aws_iam_role" "gha" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.gha_trust.json

  description = "Role assumed by GitHub Actions via OIDC. Pinned to repo:${var.github_repo}:ref:${var.github_ref}"
}
```

## 2. `terraform/variables.tf` (modelo)

```hcl
variable "github_repo" {
  description = "Owner/repo pinned in the sub claim, e.g. miorg/mirepo."
  type        = string
  default     = "miorg/mirepo"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repo))
    error_message = "github_repo must be in the form owner/repo."
  }
}

variable "github_ref" {
  description = "Git ref pinned in the sub claim (e.g. refs/heads/main)."
  type        = string
  default     = "refs/heads/main"
}

variable "role_name" {
  description = "Name of the IAM role assumed by GitHub Actions."
  type        = string
  default     = "gha-mirepo-prod"
}
```

## 3. `terraform/outputs.tf` (modelo)

```hcl
output "role_arn" {
  description = "ARN of the IAM role to pass as role-to-assume in GitHub Actions."
  value       = aws_iam_role.gha.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider."
  value       = aws_iam_openid_connect_provider.github.arn
}
```

## 4. `.github/workflows/deploy.yml` (modelo)

```yaml
name: deploy

on:
  push:
    branches: [main]

# Note: no top-level permissions. We grant id-token: write ONLY to the job
# that needs it, following least-privilege for GITHUB_TOKEN scopes.
permissions: {}

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write    # required for OIDC JWT emission
      contents: read     # required for actions/checkout
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::111122223333:role/gha-mirepo-prod
          aws-region: us-east-1
          # role-session-name is useful in CloudTrail
          role-session-name: gha-${{ github.run_id }}

      - name: Verify identity (no mutation)
        run: aws sts get-caller-identity
```

## 5. `ADR-oidc-sub-pinning.md` (modelo)

```markdown
# ADR — Pinning del claim `sub` en el OIDC trust policy de GitHub Actions

## Context

GitHub Actions emite para cada job un JWT firmado por `token.actions.githubusercontent.com`. AWS acepta ese JWT vía `sts:AssumeRoleWithWebIdentity` si existe un OIDC provider en la cuenta y un IAM Role cuya trust policy acepte al emisor y evalúe condiciones sobre los claims del JWT. La condición de seguridad **determinante** es el claim `sub`, que identifica el repo + ref origen del JWT. Si la trust policy no pinnea `sub` adecuadamente, cualquier repo de GitHub puede asumir el rol.

## Decision

- Usar `StringEquals` (no `StringLike`) sobre `token.actions.githubusercontent.com:sub`.
- Pinnear a un valor exacto, por ejemplo `repo:miorg/mirepo:ref:refs/heads/main`.
- Añadir también `StringEquals` sobre `token.actions.githubusercontent.com:aud = sts.amazonaws.com` como defensa en profundidad.
- Un rol **por environment × repo**: `gha-mirepo-dev`, `gha-mirepo-stg`, `gha-mirepo-prod`, cada uno con el `sub` pinneado al environment correspondiente (`:environment:prod`).
- Los 3 patrones aceptados en nuestra organización:
  1. `repo:miorg/mirepo:ref:refs/heads/main` — deploy continuo desde main.
  2. `repo:miorg/mirepo:environment:prod` — deploy desde un GitHub Environment protegido.
  3. `repo:miorg/mirepo:ref:refs/tags/v*` — release por tag (usa `StringLike` **solo** para el sufijo del tag; nunca para el repo ni el prefijo de ref).

## Consequences

**Positivas**:

- Un fork público, un repo de un atacante o un workflow modificado por un PR hostil **no** pueden asumir el rol. El blast radius de una fuga de JWT se reduce al conjunto exacto de workflows en el ref pinneado.
- La trust policy es auditable: `grep "sub"` da una línea con el ref exacto.
- CloudTrail registra `sts:AssumeRoleWithWebIdentity` con `userIdentity` que incluye el `sub` — las auditorías pueden reconstruir qué commit disparó qué deploy.

**Negativas**:

- Cambiar el branch default (p. ej. de `main` a `develop`) requiere `terraform apply` para actualizar la condition. Mitigación: hacerlo en un PR con doble approver.
- Añadir un nuevo flujo (p. ej. releases por tag) requiere añadir un segundo rol o complicar la condition. Es intencional: cada flujo es una decisión consciente.
- Un developer que experimente desde un branch personal no puede probar el deploy sin que operaciones añada el ref. Mitigación: rol separado `gha-mirepo-dev` abierto a `refs/heads/*` **solo** con permisos de sandbox.

## Alternatives

1. **`StringLike` con `repo:miorg/mirepo:*`** — permite cualquier ref dentro del repo. Rechazada: PRs y branches de feature matchean. Un PR hostil que modifique el workflow puede obtener credenciales de prod.
2. **`StringLike` con `repo:*`** — permite cualquier repo. Rechazada: es equivalente a publicar las credenciales.
3. **Access keys humanas en GitHub Secrets** — status quo histórico. Rechazada: no hay rotación automática, el secret vive en N backups, y la auditoría cross-ref CloudTrail es ciega al origen.
4. **Un único rol compartido con permisos muy restringidos** — descartada porque "muy restringidos" se diluye en el tiempo; el blast radius siempre crece.

## Status

Accepted.
```

## 6. Lo que NO debe aparecer en ninguno de los entregables

- `StringLike` combinado con wildcard en `sub`.
- `aws_access_key_id` / `aws_secret_access_key` en ningún archivo.
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` en secrets del workflow.
- `permissions: write-all` o `permissions.id-token: write` a nivel top-level (debe ir por job).
- Account IDs reales. Usamos `111122223333` como placeholder.
- Nombres de repo reales. Usamos `miorg/mirepo`.

## 7. Punto a repetir hasta que suene aburrido

> El `sub` claim pinneado con `StringEquals` a un ref exacto es **la frontera de seguridad** del OIDC. Todo lo demás (el workflow, el ADR, incluso el OIDC provider) es decorado alrededor de esa condición. Si esa línea está mal, el resto no importa.
