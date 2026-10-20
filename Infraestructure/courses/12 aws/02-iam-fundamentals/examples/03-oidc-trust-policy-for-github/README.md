# Ejemplo 03 — Trust policy OIDC para GitHub Actions (sin access keys)

> **Lectura y análisis.** No se despliega nada. Si tienes una cuenta AWS y un repo, los pasos de despliegue están al final; son opcionales.

## El problema que resuelve

Hasta hace no tanto, dar a GitHub Actions acceso a AWS significaba:

1. Crear un IAM user.
2. Generar un access key.
3. Pegarlo como `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` en los secrets del repo.
4. Rezar para que nadie imprimiera `env` en un log.

Problema: las credenciales son **permanentes**, viven en **GitHub**, y la rotación es manual (y rara vez se hace). Resultado histórico: filtraciones por repos clonados, por forks mal protegidos, por logs mal configurados.

**OIDC federation** elimina el access key: GitHub firma un JWT por workflow, AWS lo verifica, STS devuelve credenciales de minutos.

## Arquitectura

```
   GitHub Actions workflow (ubuntu-latest runner)
          │
          │  Pide un ID token OIDC a GitHub:
          │     actions.getIDToken(audience=sts.amazonaws.com)
          ▼
   JWT firmado por token.actions.githubusercontent.com
   claims clave:
     iss: https://token.actions.githubusercontent.com
     sub: repo:acme/web:ref:refs/heads/main
     aud: sts.amazonaws.com
          │
          │  action aws-actions/configure-aws-credentials@v4
          │  sts:AssumeRoleWithWebIdentity
          ▼
   AWS STS verifica firma del JWT contra el OIDC provider
   (registrado una vez en IAM; thumbprint de la CA de GitHub)
          │
          │  Si el trust policy del rol acepta el claim 'sub' presentado,
          │  emite credenciales temporales (hasta 1 h).
          ▼
   Workflow usa credenciales temporales. Nada que rotar, nada que filtrar.
```

## El OIDC provider en IAM (una vez por cuenta)

Se registra `token.actions.githubusercontent.com` como *OpenID Connect provider*. Con Terraform:

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]  # placeholder; usa el real
}
```

(El thumbprint lo verifica AWS internamente para OIDC providers conocidos; muchos equipos lo ponen de referencia y se despreocupan.)

## El trust policy del rol

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:acme/web:ref:refs/heads/main"
      }
    }
  }]
}
```

Lectura línea a línea:

- **`Principal.Federated`**: solo acepta tokens emitidos por *este* OIDC provider en *esta* cuenta.
- **`Action`**: `sts:AssumeRoleWithWebIdentity`, variante OIDC de `AssumeRole`.
- **`aud: sts.amazonaws.com`**: previene reutilización de tokens que no estén destinados a AWS.
- **`sub: repo:acme/web:ref:refs/heads/main`**: **la cláusula crítica**. Solo workflows en el repo `acme/web`, corriendo contra la rama `main`, pueden asumir el rol. Pull requests y otras ramas → `AccessDenied`.

## Variantes útiles de `sub`

- `repo:acme/web:ref:refs/heads/main` — solo la rama `main`.
- `repo:acme/web:ref:refs/tags/*` — solo cuando se dispara por tag (típico de releases).
- `repo:acme/web:environment:production` — cuando el workflow usa un GitHub Environment llamado `production` (que puedes proteger con required reviewers). Esta es la joya: el acceso a AWS prod depende de aprobación humana en GitHub.
- `repo:acme/*:*` — cualquier repo de la org `acme`, cualquier branch/tag. **Casi siempre demasiado amplio**.

## El error histórico

Primeras guías de 2021–2022 ponían:

```json
"StringLike": { "token.actions.githubusercontent.com:sub": "repo:acme/*" }
```

**Sin** restringir `aud` ni fijar `repo:acme/web:...`. Resultado: cualquiera creando un repo público nuevo bajo el org `acme` (fork, misnamed repo) podía disparar workflows y asumir el rol. Si tu `Condition` no es estricto, estás regalando el acceso.

## Qué hace el workflow

```yaml
# .github/workflows/deploy.yml
permissions:
  id-token: write   # necesario para pedir el OIDC token
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubDeployWeb
          aws-region: us-east-1
      - run: aws sts get-caller-identity
      - run: aws s3 sync ./dist s3://acme-web-prod/
```

Zero secretos. La única pieza "sensible" en el repo es el ARN del rol, que no es un secreto (es público por diseño).

## Qué llevarte

1. OIDC federation **elimina los access keys** para CI/CD en AWS.
2. **La policy entera depende del `Condition`**: sin `sub` estricto, el rol es asumible por cualquier repo.
3. **GitHub Environments + `environment:production` en el `sub`** permiten gating por aprobación humana sin salir del flujo de GitHub.
4. **Un provider OIDC por cuenta** basta — luego cada rol apunta a él.
