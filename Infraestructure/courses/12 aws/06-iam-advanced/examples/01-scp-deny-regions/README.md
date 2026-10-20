# Ejemplo 01 — SCP deny regions

> Lectura y análisis. **No** se aplica en AWS.

## 1. Objetivo

Entender cómo se escribe una SCP que **restrinja regiones**, y por qué `NotAction` excluye deliberadamente los **servicios globales**.

## 2. La policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyAllOutsideAllowedRegions",
      "Effect": "Deny",
      "NotAction": [
        "iam:*",
        "organizations:*",
        "cloudfront:*",
        "route53:*",
        "support:*",
        "sts:*",
        "waf:*",
        "aws-portal:*"
      ],
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:RequestedRegion": ["us-east-1", "eu-west-1"]
        }
      }
    }
  ]
}
```

Guardado en `policy.json` al lado.

## 3. Análisis

| Pieza | Qué dice | Por qué así |
|-------|----------|-------------|
| `Effect: Deny` | niega | SCPs **no otorgan**. Solo niegan. |
| `NotAction` | aplica a todo **salvo** los servicios listados | IAM, Route53, STS, soporte y afines son **globales**: no viven en una región. Si los metieras, bloquearías operaciones legítimas (listar usuarios, cambiar DNS, asumir roles). |
| `Resource: "*"` | sobre cualquier recurso | SCPs normalmente usan `*`: la restricción real está en la condition. |
| `StringNotEquals aws:RequestedRegion` | se cumple si la región del request **no es** `us-east-1` ni `eu-west-1` | Cuando se cumple la condition, el `Deny` se dispara. Resultado: cualquier `ec2:RunInstances` en `ap-south-1` → denegado. |

## 4. Qué pasa en la práctica

- Alice en una cuenta bajo esta OU corre `aws ec2 describe-instances --region ap-south-1` → `AccessDenied` (SCP la para antes de llegar al servicio).
- Alice corre `aws iam list-users` → OK (IAM está en `NotAction`).
- Alice corre `aws s3 ls --region us-east-1` → OK (región permitida).
- Alice corre `aws s3 ls --region eu-central-1` → `AccessDenied` por SCP.

## 5. Trampa que la gente mete

Si quitas `sts:*` del `NotAction`, cualquier `AssumeRole` que resuelva internamente contra `sts.<region>.amazonaws.com` fuera de las regiones permitidas se cae — y STS puede llamarse desde cualquier región. Resultado: el administrador no entiende por qué los roles dejan de funcionar.

## 6. Cómo se adjunta (fuera del scope de ejecución)

- Vía consola Organizations → OU → Policies → Service Control Policies → Attach.
- Vía CLI: `aws organizations attach-policy --policy-id p-xxxx --target-id ou-xxxx`.
- Vía Terraform: `aws_organizations_policy` + `aws_organizations_policy_attachment`.

Aquí no lo hacemos. El objetivo es leerla y entenderla.

## 7. Validación estructural (opcional, local)

```bash
jq -e '.Version == "2012-10-17" and (.Statement | type == "array")' policy.json
```

Debe imprimir `true`.
