# Ejemplo 04 — OIDC GitHub Actions ↔ AWS, walkthrough + `terraform plan`

> Walkthrough. Se ejecuta **solo** `terraform plan` localmente (sin credenciales AWS reales). **Nunca** `terraform apply`.

## 1. Objetivo

Leer el Terraform que materializa el patrón "GitHub Actions despliega en AWS sin IAM User". Reproducir el `plan` localmente y entender cada recurso que se *crearía* si se aplicara.

## 2. Las piezas

- **IdP OIDC** en IAM — AWS confía en el emisor `token.actions.githubusercontent.com`.
- **Rol IAM** con trust policy que exige `aud` y `sub` concretos.
- **Policy** adjunta al rol con los permisos de deploy (en este ejemplo, mínima: `s3:PutObject` en un bucket).

Archivos:

- `main.tf` — recursos Terraform.
- `README.md` — este documento.

## 3. El Terraform (lectura)

Está en `main.tf` al lado. Resumen:

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

resource "aws_iam_role" "gha_deploy" {
  name = "gha-deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" =
            "repo:example-org/example-repo:ref:refs/heads/main"
        }
      }
    }]
  })
}
```

Puntos:

- `thumbprint_list` — el huella SHA-1 del cert del IdP de GitHub. AWS lo necesita para validar la firma del JWT. GitHub la publica; aquí ponemos un valor ilustrativo. **En uso real, obtén el actual de la doc oficial.**
- `aud = sts.amazonaws.com` — AWS lo exige para este IdP.
- `sub = repo:example-org/example-repo:ref:refs/heads/main` — ata el rol al repo `example-org/example-repo` y la branch `main`. Un workflow en `example-org/other-repo` **no** puede asumir este rol.

## 4. Workflow de GitHub Actions (lectura, no se ejecuta)

```yaml
name: deploy
on:
  push:
    branches: [main]
permissions:
  id-token: write
  contents: read
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::111111111111:role/gha-deploy
          aws-region: us-east-1
      - run: aws s3 cp dist/ s3://my-site/ --recursive
```

`permissions.id-token: write` es lo que habilita el OIDC token. Sin eso, `configure-aws-credentials` no puede pedirlo.

## 5. Reproducir `terraform plan` localmente

Esto **no** requiere credenciales AWS; solo que Terraform resuelva el provider y planifique.

```bash
# scratch
mkdir -p /tmp/aws-06-oidc-plan
cp main.tf /tmp/aws-06-oidc-plan/
cd /tmp/aws-06-oidc-plan

# fake creds para que el provider no proteste al inicializar
export AWS_ACCESS_KEY_ID=AKIAFAKEFAKEFAKEFAKE
export AWS_SECRET_ACCESS_KEY=fakefakefakefakefakefakefakefakefakefake
export AWS_DEFAULT_REGION=us-east-1

terraform init -backend=false
terraform plan -out=plan.bin || true

# limpieza
cd /
rm -rf /tmp/aws-06-oidc-plan
```

El `plan` debe listar **3 recursos a crear**: `aws_iam_openid_connect_provider.github`, `aws_iam_role.gha_deploy`, `aws_iam_role_policy.gha_deploy`. Si no tienes Terraform instalado localmente, lee el `main.tf` y reproduce mentalmente qué pasaría.

> **Nunca** ejecutes `terraform apply` aquí. El `plan` es el entregable pedagógico.

## 6. Por qué OIDC gana sobre IAM User

| Dimensión | IAM User + access keys | OIDC federado |
|-----------|------------------------|---------------|
| Credenciales de larga vida | sí (hasta que rotes) | **no** — JWT caduca en minutos |
| Secrets en GitHub | sí (keys) | **no** — solo config |
| Rotación | manual | **no aplica** |
| Scoping por repo/branch | no (una key sirve en cualquier workflow) | **sí** (vía `sub`) |
| Auditoría | sabe que fue "esa key" | sabe que fue "ese repo:branch:workflow" |
| Blast radius si se filtra | **enorme** | efímero |

## 7. Trampas

- Poner `sub = "repo:example-org/*"` → cualquier repo de la org puede asumir. Casi nunca es lo que quieres.
- Olvidar `permissions.id-token: write` en el workflow → `AssumeRoleWithWebIdentity` falla con `InvalidIdentityToken`.
- Confundir `aud` — para este caso siempre `sts.amazonaws.com`. Otros valores vienen de usar la custom audience de GitHub, caso avanzado.
- No fijar `thumbprint_list` o fijarlo con un valor obsoleto — la validación de firma falla y nunca entiendes por qué.
