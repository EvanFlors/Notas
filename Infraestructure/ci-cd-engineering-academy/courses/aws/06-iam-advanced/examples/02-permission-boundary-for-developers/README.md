# Ejemplo 02 — Permission boundary para developers

> Lectura y análisis. **No** se aplica en AWS.

## 1. Objetivo

Ver el patrón "developer-self-service con techo": el admin de cuenta delega al developer la capacidad de **crear roles de aplicación** sin convertirse en el cuello de botella. El techo (boundary) garantiza que ningún rol creado por el developer supere los permisos pactados.

## 2. Las dos piezas

### 2.1 El boundary (`boundary.json`)

Define el **techo máximo** de cualquier rol que lo tenga adjuntado. Un rol con este boundary puede, como mucho, escribir en `s3://app-*`, publicar en SNS `app-*` y escribir logs.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AppRuntime",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "sns:Publish",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:s3:::app-*/*",
        "arn:aws:sns:*:*:app-*",
        "arn:aws:logs:*:*:log-group:/aws/app-*:*"
      ]
    },
    {
      "Sid": "DenyPrivilegeEscalation",
      "Effect": "Deny",
      "Action": [
        "iam:CreateUser",
        "iam:AttachUserPolicy",
        "iam:PutUserPolicy",
        "iam:CreateAccessKey",
        "iam:DeleteRolePermissionsBoundary",
        "iam:DeleteUserPermissionsBoundary"
      ],
      "Resource": "*"
    }
  ]
}
```

### 2.2 La identity policy del developer (`developer-policy.json`)

Permite al developer crear roles cuyo path sea `/app-*/`, **siempre que** adjunten el boundary.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CreateAppRolesWithBoundary",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:PutRolePolicy",
        "iam:AttachRolePolicy",
        "iam:PassRole"
      ],
      "Resource": "arn:aws:iam::*:role/app-*",
      "Condition": {
        "StringEquals": {
          "iam:PermissionsBoundary":
            "arn:aws:iam::123456789012:policy/dev-app-boundary"
        }
      }
    },
    {
      "Sid": "ReadOnlyIAM",
      "Effect": "Allow",
      "Action": ["iam:Get*", "iam:List*"],
      "Resource": "*"
    }
  ]
}
```

## 3. Análisis

| Pregunta | Respuesta |
|----------|-----------|
| ¿Puede el developer crear un rol sin boundary? | **No.** La condition `iam:PermissionsBoundary` lo prohíbe. |
| ¿Puede un rol creado por el developer leer `arn:aws:s3:::finance-*`? | **No.** El boundary limita a `app-*`, y boundary es `AND` con la identity del rol. |
| ¿Puede el developer modificar el boundary para hacerlo más permisivo? | Depende: si no tiene `iam:CreatePolicyVersion` sobre `dev-app-boundary`, no. La policy del developer debe omitirla explícitamente. |
| ¿Puede un rol creado por el developer borrar su propio boundary? | **No**: el `DenyPrivilegeEscalation` lo niega. Y `Deny` siempre gana. |

## 4. Trampa clásica

Olvidar `iam:DeleteRolePermissionsBoundary` en el `Deny` del boundary. Si no lo niegas, un atacante que comprometa el rol podría remover el boundary y escalar.

## 5. Cómo se adjuntaría

- Al rol: `aws iam put-role-permissions-boundary --role-name <role> --permissions-boundary <boundary-arn>`.
- Al user: `aws iam put-user-permissions-boundary ...`.
- Terraform: `permissions_boundary = aws_iam_policy.boundary.arn` dentro del `aws_iam_role`.

Aquí no lo hacemos.

## 6. Validación local (opcional)

```bash
jq -e '[.Statement[] | select(.Effect=="Deny")] | length >= 1' boundary.json
```

Debe imprimir `true` (al menos un `Deny` anti-escalada presente).
