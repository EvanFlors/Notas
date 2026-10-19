# REFERENCE — aws-02-02-assume-role-cross-session

> Modelo razonado. No es la única respuesta correcta.

## `TRUST_OPERATOR.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "AllowSsoDeveloperWithMfa",
    "Effect": "Allow",
    "Principal": {
      "AWS": "arn:aws:iam::111111111111:root"
    },
    "Action": "sts:AssumeRole",
    "Condition": {
      "Bool": { "aws:MultiFactorAuthPresent": "true" },
      "StringEquals": { "aws:PrincipalTag/sso-role": "Developer" }
    }
  }]
}
```

Notas:

- `Principal: 111111111111:root` delega la autorización a las identity policies de la cuenta hub (típicamente el permission set SSO).
- MFA es **obligatorio** vía `Condition`. Sin MFA, STS devuelve `AccessDenied` incluso con los permisos correctos.
- La tag `sso-role=Developer` reduce el riesgo de que otros permission sets (ej. `ReadOnly`) puedan asumir el rol accidentalmente.

## `TRUST_PROD.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "AllowOperatorRoleWithExternalId",
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

Notas:

- Principal es **el rol concreto**, no la cuenta entera. Esto cierra el riesgo de que *otro* rol de la cuenta `111` también pudiera asumir prod.
- `sts:ExternalId` es el antídoto al *confused deputy*: aunque un tercero conociera el ARN de `OperatorRole`, sin el valor acordado no entra.

## `PERM_PROD.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListProdBuckets",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::acme-prod-*"
    },
    {
      "Sid": "ReadWriteProdObjects",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::acme-prod-*/*"
    }
  ]
}
```

Notas:

- Acotado a `acme-prod-*` por naming convention; no toca `acme-dev-*` ni ningún otro bucket.
- Sin `s3:*`, sin `Resource: *`.

## `SESSION.md` (modelo)

### Cadena

```
   Alice (humana)
       │  aws sso login --profile hub
       ▼
   permission set Developer           (cuenta 111111111111)
       │  aws sts assume-role --role-arn arn:aws:iam::111111111111:role/OperatorRole --token-code <MFA>
       ▼
   OperatorRole                       (cuenta 111111111111)
       │  aws sts assume-role --role-arn arn:aws:iam::222222222222:role/ProdS3Admin --external-id acme-prod-handshake-7f9c
       ▼
   ProdS3Admin                        (cuenta 222222222222)
       │
       ▼
   aws s3 ls s3://acme-prod-reports/
```

### Qué hace STS en cada salto

- **Salto 1 (SSO → OperatorRole)**: el *caller* es la sesión SSO de Alice, con tag `sso-role=Developer`. STS evalúa el trust policy de `OperatorRole`, verifica el claim MFA, y emite credenciales temporales con `Session Name=alice` y expiración 1 h.
- **Salto 2 (OperatorRole → ProdS3Admin)**: el *caller* ahora es `arn:aws:sts::111111111111:assumed-role/OperatorRole/alice`. STS en cuenta `222` evalúa el trust policy de `ProdS3Admin`, valida que el principal coincide **y** que el `ExternalId` presentado es el acordado. Emite credenciales en la cuenta `222` por 1 h.

### Trazas en CloudTrail

- Dos eventos `AssumeRole` separados (uno en cuenta `111`, otro en cuenta `222`).
- Tras el salto 1, `userIdentity.arn = arn:aws:sts::111111111111:assumed-role/OperatorRole/alice`.
- Tras el salto 2, `userIdentity.arn = arn:aws:sts::222222222222:assumed-role/ProdS3Admin/alice`.
- Las operaciones `s3:ListBucket` / `s3:GetObject` posteriores llevan ese ARN. Si siempre se usa el mismo *session name* (`alice`), es trivial correlacionar las operaciones destructivas con la humana original.

### Por qué este diseño y no "S3FullAccess a Alice"

- **Blast radius**: la laptop de Alice no almacena credenciales de prod cuando no está asumiendo. Si se compromete, no hay nada que exfiltrar hacia prod.
- **Audit explícito**: cada operación en prod viene precedida de un `AssumeRole` consciente. Es trivial alertar sobre `AssumeRole ProdS3Admin` fuera de horario.
- **Cero access keys**: el único login humano es SSO; nada que rotar.
- **Separación por entorno**: dar acceso a Bob a prod se traduce en meterlo en el permission set correcto; no se toca prod.
- **Reversibilidad**: revocar el acceso de Alice se hace en SSO, no en prod. Las credenciales activas duran a lo sumo 1 h.
- **Protección cross-account real**: el `ExternalId` evita que otro rol de la cuenta `111` (si lo hubiera) pueda saltar a prod por accidente.

### Rol del ExternalId

El *confused deputy* es un patrón en el que un servicio legítimo (el "diputado") es engañado para usar sus privilegios en favor de un atacante. En AWS cross-account aparece cuando: la cuenta B expone un rol asumible por un rol de la cuenta A, y la cuenta A corre código **que acepta ARNs externos como parámetro** (ej. una SaaS multi-tenant). Un cliente malicioso podría pedir "asume este rol que yo controlo", y si la SaaS obedece, se convierte en el diputado confuso.

`sts:ExternalId` cierra el hueco: la cuenta B solo acepta el `AssumeRole` si el *caller* presenta un valor acordado **fuera de banda** (típicamente generado por B y entregado al cliente real por canal seguro). Un atacante que solo conozca el ARN del rol de la cuenta A no puede recrear el `ExternalId` y, por tanto, no puede usar al diputado para entrar en una cuenta B ajena.
