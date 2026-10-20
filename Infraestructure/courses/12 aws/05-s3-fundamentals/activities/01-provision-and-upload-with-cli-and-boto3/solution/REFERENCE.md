# REFERENCE — aws-05-01-provision-and-upload-with-cli-and-boto3

> Una referencia razonada. No es la unica respuesta correcta — es un modelo contra el que compararte.

## `lifecycle.json`

```json
{
  "Rules": [
    {
      "ID": "uploads-tiering-and-cleanup",
      "Status": "Enabled",
      "Filter": { "Prefix": "uploads/" },
      "Transitions": [
        { "Days": 30,  "StorageClass": "STANDARD_IA" },
        { "Days": 180, "StorageClass": "DEEP_ARCHIVE" }
      ],
      "NoncurrentVersionExpiration": { "NoncurrentDays": 30 },
      "AbortIncompleteMultipartUpload": { "DaysAfterInitiation": 7 }
    }
  ]
}
```

**Por que:** las transiciones a IA + Deep Archive capturan el escenario "warm/cold" tipico; la limpieza de versiones no actuales a 30 dias evita el goteo clasico de versioning; `AbortIncompleteMultipartUpload` cierra el agujero de multipart abandonadas.

## `bucket-policy.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::student-aws05-reports-REPLACE_ME",
        "arn:aws:s3:::student-aws05-reports-REPLACE_ME/*"
      ],
      "Condition": {
        "Bool": { "aws:SecureTransport": "false" }
      }
    }
  ]
}
```

**Por que:** una sola declaracion `Deny` global para peticiones no-TLS; en un bucket real añadirias los `Allow` minimos para los principals concretos. El `Deny` gana sobre cualquier `Allow`, lo que lo convierte en el bloqueo mas barato y robusto.

## `event-notification.json`

```json
{
  "QueueConfigurations": [
    {
      "Id": "notify-new-uploads",
      "QueueArn": "arn:aws:sqs:us-east-1:000000000000:aws-05-uploads",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            { "Name": "prefix", "Value": "uploads/" }
          ]
        }
      }
    }
  ]
}
```

**Por que:** patron canonico `ObjectCreated:*` sobre el prefijo de entrada; en LocalStack el ARN de SQS no es "real" pero el JSON es valido estructuralmente. En AWS real tendrias que crear la cola antes y conceder a S3 permiso para enviar.

## `NOTES.md` (esqueleto)

```markdown
# Notas de la actividad 01

## Bucket
- Nombre: `student-aws05-reports-<ts>` bajo convencion `<org>-<env>-<purpose>-<ts>`.
- Region: `us-east-1` (default en LocalStack).

## Settings aplicados
- BPA 4/4 true: `BlockPublicAcls`, `IgnorePublicAcls`, `BlockPublicPolicy`, `RestrictPublicBuckets`.
- Ownership: `BucketOwnerEnforced` -> ACLs deshabilitadas.
- Versioning: `Enabled`.
- Lifecycle: ver `lifecycle.json`.
- Bucket policy: `Deny` para `aws:SecureTransport = false`.

## Observaciones CLI vs boto3
- Mismo endpoint, misma semantica. La CLI usa `--endpoint-url` o `AWS_ENDPOINT_URL`; boto3 usa `endpoint_url=`.
- La CLI retorna texto; boto3 retorna dict con `VersionId`.

## Presigned URL
- Firmada por 60s; `curl` la consume. Expirada, S3 responde 403 `AccessDenied` (code `AccessDenied`, message `Request has expired`).
- No bypassa el `Deny` TLS: si pides HTTP, 403 igualmente.
```

## Lo que **no** se esperaba hacer

- Credenciales reales de AWS.
- ARNs de cuenta reales (`000000000000` o `111111111111` como placeholders son OK).
- CMK real de KMS (LocalStack free-tier da un mock; no se exige).

## Lo que corresponderia validar manualmente

- Que entiendes **por que** cada JSON tiene las claves que tiene y no solo que "pasa el validador".
- Que podrias explicar la diferencia entre lo que valida LocalStack y lo que no (p. ej. transiciones de lifecycle no se "ejecutan" en el tiempo).
