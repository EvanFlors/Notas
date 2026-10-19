# Ejemplo 02 — Cadena de asumción de roles (humano → operador → cross-account)

> **Lectura y análisis.** Ejemplo documental. Si tienes dos cuentas y SSO configurado puedes replicarlo; no es necesario.

## Escenario

Una desarrolladora (Alice) tiene que operar sobre S3 en una cuenta **de producción** distinta de su cuenta de login. La organización ha decidido:

- Humanos entran por **IAM Identity Center (SSO)** en una cuenta "hub" (`111111111111`).
- Para operaciones no triviales en producción (`222222222222`), Alice asume un rol intermedio en el hub (`OperatorRole`) y, desde ahí, asume el rol de producción (`ProdS3Admin`).
- Esto genera una **traza clara** en CloudTrail: login SSO → `AssumeRole OperatorRole` → `AssumeRole ProdS3Admin` → operaciones S3.

## Diagrama

```
   Alice (humana, SSO)
        │
        │  aws sso login            (STS detrás, en el hub)
        ▼
   Permission set "Developer"       (en cuenta hub 111111111111)
   -> credenciales temporales       (1 h)
        │
        │  aws sts assume-role --role-arn arn:aws:iam::111111111111:role/OperatorRole
        ▼
   OperatorRole                     (en cuenta hub 111111111111)
   permisos: solo "puedo asumir ProdS3Admin en 222"
   -> credenciales temporales       (1 h)
        │
        │  aws sts assume-role --role-arn arn:aws:iam::222222222222:role/ProdS3Admin
        ▼
   ProdS3Admin                      (en cuenta prod 222222222222)
   permisos: S3 admin acotado a 'acme-prod-*'
   -> credenciales temporales       (1 h)
        │
        ▼
   aws s3 ls s3://acme-prod-reports/
```

## Las políticas que lo hacen posible

### A. Permission set "Developer" (SSO, cuenta hub)

Lo gestiona IAM Identity Center. Lo relevante aquí: concede a Alice `sts:AssumeRole` sobre `arn:aws:iam::111111111111:role/OperatorRole`. Sin esto no puede saltar al primer rol.

### B. `OperatorRole` (cuenta hub 111)

**Trust policy** (quién puede asumir OperatorRole):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "AWS": "arn:aws:iam::111111111111:root"
    },
    "Action": "sts:AssumeRole",
    "Condition": {
      "Bool": { "aws:MultiFactorAuthPresent": "true" },
      "StringEquals": {
        "aws:PrincipalTag/sso-role": "Developer"
      }
    }
  }]
}
```

Lectura: cualquier principal de la cuenta `111` (concretamente los que vengan de SSO con tag `sso-role=Developer`) puede asumir, **si** tiene MFA.

**Permission policy** (qué puede hacer una vez asumido):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "sts:AssumeRole",
    "Resource": "arn:aws:iam::222222222222:role/ProdS3Admin"
  }]
}
```

**Esto es todo**. `OperatorRole` no sabe hacer nada más que saltar a producción. No tiene `s3:*`, no tiene `ec2:*`. Es un *bastión de identidad*.

### C. `ProdS3Admin` (cuenta prod 222)

**Trust policy** (quién puede asumir desde fuera):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "AWS": "arn:aws:iam::111111111111:role/OperatorRole"
    },
    "Action": "sts:AssumeRole",
    "Condition": {
      "StringEquals": { "sts:ExternalId": "acme-prod-handshake-7f9c" }
    }
  }]
}
```

Dos cosas:

- El principal es **el rol** `OperatorRole`, no la cuenta entera. Más estricto.
- `sts:ExternalId` es un valor acordado entre las partes. Previene el ataque del *confused deputy*: aunque alguien robase el ARN de `OperatorRole`, sin el `ExternalId` no entra.

**Permission policy** (ya en producción, acotada):

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
    "Resource": [
      "arn:aws:s3:::acme-prod-*",
      "arn:aws:s3:::acme-prod-*/*"
    ]
  }]
}
```

## Qué hace STS en cada salto

- **Salto 1 (SSO → OperatorRole)**: STS valida que Alice (identificada como permission set Developer de la cuenta hub) está en la trust policy de OperatorRole, verifica MFA, y emite credenciales temporales con `Session Name = alice`.
- **Salto 2 (OperatorRole → ProdS3Admin)**: STS ve que ahora el *caller* es `arn:aws:sts::111111111111:assumed-role/OperatorRole/alice`. Comprueba la trust policy de ProdS3Admin, valida el `ExternalId`, y emite credenciales de 1 h en la cuenta `222`.

Cada salto deja una entrada **separada** en CloudTrail (`eventName=AssumeRole`), y las operaciones S3 posteriores llevan `userIdentity.arn=arn:aws:sts::222222222222:assumed-role/ProdS3Admin/alice`. La trazabilidad hasta el humano original se preserva si usas siempre el mismo *session name*.

## Por qué este diseño (y no "dale `S3FullAccess` a Alice y listo")

- **Blast radius**: si la laptop de Alice se compromete *mientras no está asumiendo* roles de prod, no hay credenciales de prod en ningún caché.
- **Audit**: cada operación destructiva en prod está precedida de un `AssumeRole` explícito. Fácil de alertar.
- **Separación**: añadir a Bob a prod solo pide ponerlo en el permission set Developer; no toca prod.
- **No access keys**: nadie almacena credenciales permanentes en ningún sitio.

## Qué llevarte

1. Una cadena `SSO → OperatorRole → ProdS3Admin` tiene **3 trust policies** que coordinar.
2. Cada rol intermedio debe tener permisos **mínimos** — típicamente, solo `sts:AssumeRole` del siguiente eslabón.
3. **`ExternalId`** es el antídoto al *confused deputy* en cross-account.
4. **MFA** se exige vía `Condition` en la trust policy, no en la permission policy.
