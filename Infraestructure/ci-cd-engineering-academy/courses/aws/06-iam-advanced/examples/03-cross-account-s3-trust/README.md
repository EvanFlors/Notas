# Ejemplo 03 — Cross-account S3 con trust policy defendida

> Lectura y análisis. **No** se aplica en AWS.

## 1. Escenario

- **Cuenta A** `111111111111` — una pipeline de datos (Alice) necesita leer un bucket.
- **Cuenta B** `222222222222` — dueño del bucket `reports-b`.
- Ambas en la misma organización AWS `o-exampleorgid`.

Patrón: en cuenta B creamos `role/CrossAccountReadReports`. Alice en A asume el rol y lee.

## 2. Las tres piezas

### 2.1 Trust policy del rol en cuenta B (`trust-policy.json`)

Define **quién** puede asumir el rol:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowFromAccountAWithinOrgAndMFA",
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::111111111111:root"},
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "aws:PrincipalOrgID": "o-exampleorgid"
        },
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        }
      }
    }
  ]
}
```

### 2.2 Identity policy del rol (`role-policy.json`)

Define **qué** puede hacer el rol una vez asumido:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListReportsBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::reports-b"
    },
    {
      "Sid": "GetReportObjects",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::reports-b/*"
    }
  ]
}
```

### 2.3 Bucket policy en cuenta B (`bucket-policy.json`)

Permite al rol leer, cerrando lado-recurso:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCrossAccountRole",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::222222222222:role/CrossAccountReadReports"
      },
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::reports-b",
        "arn:aws:s3:::reports-b/*"
      ]
    }
  ]
}
```

## 3. Qué defiende cada condition

| Condition | Defiende contra |
|-----------|-----------------|
| `aws:PrincipalOrgID` | Que un principal de otra organización (p. ej. una cuenta A' con el mismo ARN pero bajo otro Organizations) asuma el rol. Sin esta, el principal `arn:aws:iam::111111111111:root` sería suficiente — pero el ARN **no** es prueba de membresía. |
| `aws:MultiFactorAuthPresent` | Que una sesión no-MFA (ej. una access key robada sin MFA) asuma el rol. |

Para vendors externos (Datadog, PagerDuty) **cambia** el patrón:

- Elimina `aws:PrincipalOrgID` (están fuera de tu org).
- Añade `sts:ExternalId: "<secreto-compartido>"`.
- El vendor almacena el ExternalId y lo pasa al asumir. Si un atacante no lo tiene, no pasa.

## 4. Alice asume el rol (ilustrativo)

```bash
aws sts assume-role \
  --role-arn arn:aws:iam::222222222222:role/CrossAccountReadReports \
  --role-session-name alice-data-pipeline \
  --serial-number arn:aws:iam::111111111111:mfa/alice \
  --token-code 123456
```

Si todo cuadra (trust acepta, identity de Alice permite `sts:AssumeRole`, SCP no niega), STS devuelve credenciales temporales de cuenta B.

## 5. Trampas

- **`"Principal": {"AWS": "*"}` con confianza por condition**: muy peligroso. Si olvidas una `Condition`, el rol queda abierto a todo AWS.
- **Confiar en el ARN sin `aws:PrincipalOrgID`**: no basta. ARNs son solo identificadores; dos orgs distintas pueden tener la misma cuenta `111...111`? No pueden en AWS real, pero el point es que el `root` principal en una trust es la cuenta "contenedora", no una validación de membresía.
- **No cerrar lado-recurso (bucket policy)**: si el rol tiene `s3:GetObject` en su identity pero el bucket deniega al rol en su resource policy, no lee. Hay que alinear ambos.

## 6. Validación local

```bash
jq -e '.Statement[0].Principal.AWS != "*"' trust-policy.json
```

Debe imprimir `true` (nunca `Principal: *` en una trust real).
