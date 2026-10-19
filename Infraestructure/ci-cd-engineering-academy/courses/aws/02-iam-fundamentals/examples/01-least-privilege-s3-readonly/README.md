# Ejemplo 01 — Anatomía de una política S3 read-only de mínimo privilegio

> **Lectura y análisis.** No se provisiona nada. Si tienes credenciales AWS, al final hay un comando `simulate-principal-policy` opcional para ver el motor en acción. Si no, el ejemplo se consume igual.

## Problema

Queremos que una aplicación (que corre en una Lambda, una EC2, lo que sea) pueda **leer** objetos del bucket `acme-reports`, bajo el prefijo `monthly/`, y nada más. Ni listar otros prefijos, ni tocar otros buckets, ni escribir.

## El antipatrón que vamos a evitar

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "s3:*",
    "Resource": "*"
  }]
}
```

Lo que concede en realidad: lectura, escritura, borrado y configuración de **todos** los buckets de la cuenta. Vida útil hasta que alguien se dé cuenta: 6 meses de media.

## La versión mínima

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListBucketScopedToPrefix",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::acme-reports",
      "Condition": {
        "StringLike": { "s3:prefix": ["monthly/*", "monthly/"] }
      }
    },
    {
      "Sid": "GetObjectsUnderPrefix",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:GetObjectVersion"],
      "Resource": "arn:aws:s3:::acme-reports/monthly/*"
    }
  ]
}
```

## Por qué cada decisión

| Decisión | Justificación |
|----------|---------------|
| **Dos statements separados** | `s3:ListBucket` opera sobre el ARN del **bucket** (`arn:...:acme-reports`), `s3:GetObject` sobre el ARN del **objeto** (`arn:...:acme-reports/*`). Son dos ARNs distintos y por eso dos statements. Mezclarlos en uno con `Resource: ["bucket", "bucket/*"]` *funciona* pero oculta la intención. |
| **`StringLike s3:prefix`** | Sin esta condición, `ListBucket` sobre `acme-reports` listaría **todos** los prefijos. Con la condición, un `aws s3 ls s3://acme-reports/other/` devuelve `AccessDenied`. |
| **`GetObjectVersion`** | Si el bucket tiene versioning, sin este permiso el app podría leer la última versión pero no una histórica — a veces se quiere, a veces no. Si decides *no* permitir históricas, bórralo. |
| **No incluir `s3:GetBucketLocation`** | Las SDKs modernas lo evitan si configuras región explícita. Si tu app lo necesita (código viejo), añádelo como statement aparte sobre `arn:aws:s3:::acme-reports`. **Añade lo que uses, no lo que podrías usar.** |
| **No `s3:GetObjectAcl`** | La política no da acceso a leer ACLs — en buckets modernos las ACLs están deshabilitadas, no hay nada que leer. Si tu bucket es legacy, considéralo. |
| **No `kms:Decrypt`** | Si los objetos están cifrados con SSE-KMS *customer-managed*, hace falta además permiso `kms:Decrypt` sobre esa key. Eso se documenta en la policy del rol **y** en la key policy. Lo verás en `aws-09`. |

## Cómo verificarlo sin salir del laptop

**Si tienes credenciales AWS activas** (SSO, access key, lo que sea):

```bash
# Suponiendo que la policy ya está adjunta a un role con ARN conocido:
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789012:role/ReportsReader \
  --action-names s3:GetObject s3:PutObject s3:DeleteObject s3:ListBucket \
  --resource-arns arn:aws:s3:::acme-reports/monthly/report-2026-10.pdf \
                  arn:aws:s3:::acme-reports
```

Esperas: `allowed` para `GetObject` + `ListBucket` (con la prefix condition), `implicitDeny` para `PutObject` y `DeleteObject`.

**Si no tienes credenciales**, usa el Policy Simulator en consola (https://policysim.aws.amazon.com/). O simplemente lee la política y practica predecir mentalmente qué pasaría — es el ejercicio real.

## Qué llevarte

1. **Dos statements** porque hay dos ARNs (bucket vs objeto).
2. **Condición `s3:prefix`** para que `ListBucket` no se vaya de madre.
3. **Mínimo privilegio no es minimalismo**: añade `GetObjectVersion` o `kms:Decrypt` si tu app los necesita. Lo que no quieres es *acciones no usadas*.
4. **Nunca `s3:*` + `*`** salvo que estés escribiendo una policy de administración consciente.
