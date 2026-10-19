# REFERENCE — aws-05-02-detect-and-fix-public-bucket

> Una referencia razonada. No es la unica respuesta correcta — es un modelo contra el que compararte.

## Seccion A — Hallazgos (modelo)

1. **BPA 4/4 en false.**
   - Donde: `bucket-config.json → PublicAccessBlockConfiguration`.
   - Riesgo: nada frena nuevas policies o ACLs publicas; cualquier error en una futura modificacion vuelve a exponer el bucket.
   - Severidad: **alta**.

2. **Policy con `Principal: "*"` y `Action: "s3:*"` sobre el bucket entero.**
   - Donde: `bucket-policy-current.json → Statement[0]`.
   - Riesgo: no solo lectura publica; **cualquier** usuario anonimo podria (si BPA lo permitiera) escribir, borrar o cambiar la propia policy via `s3:PutBucketPolicy`. Es un allow catastrofico.
   - Severidad: **alta**.

3. **ObjectOwnership = `ObjectWriter`.** ACLs activas.
   - Donde: `bucket-config.json → OwnershipControls.Rules[0]`.
   - Riesgo: los objetos pueden tener dueños distintos del bucket owner, y una ACL de objeto `public-read` concede acceso aunque la policy sea mas restrictiva.
   - Severidad: **media** (habilita el hallazgo 4).

4. **Objeto con ACL `public-read` (grant a `AllUsers`).**
   - Donde: `object-acl-sample.json → Grants[1]`.
   - Riesgo: lectura publica directa aun si la bucket policy cambia; ACLs se evaluan en paralelo.
   - Severidad: **media**.

5. **Versioning `Suspended`.**
   - Donde: `bucket-config.json → Versioning.Status`.
   - Riesgo: cualquier borrado accidental es irreversible; red de seguridad desactivada.
   - Severidad: **media** (no es publico, pero no deberia estar off en un bucket que recibe cambios).

6. **SSE AES256 sin Bucket Key, sin KMS.**
   - Donde: `bucket-config.json → ServerSideEncryptionConfiguration`.
   - Riesgo: para datos no sensibles es aceptable; si marketing custodia PII (listas de leads, etc.), SSE-KMS con CMK propia seria lo adecuado para auditabilidad y rotacion.
   - Severidad: **baja** salvo que haya PII; entonces media.

## Seccion B — Correcciones propuestas

1. **Activar BPA 4/4 = true** (ver `bpa-fixed.json`).
2. **Reescribir la bucket policy** (ver `policy-fixed.json`):
   - Un `Deny` global para `aws:SecureTransport = false`.
   - Un `Allow` acotado a `s3:GetObject` sobre `arn:aws:s3:::legacy-marketing-assets-us-east-1/public/campaigns/*`, con `Principal: "*"` **restringido** por una condicion de red o idealmente migrado a CloudFront + OAC. (En AWS real, el patron correcto es CloudFront sirviendo este prefijo con el bucket privado; aqui se preserva el `Allow` publico para no romper al cliente heredado, documentandolo como deuda.)
3. **Migrar ownership a `BucketOwnerEnforced`**: desactiva ACLs; la unica autoridad queda en la bucket policy.
4. **Habilitar versioning** (`Enabled`) y añadir lifecycle con `NoncurrentVersionExpiration` para no acumular versiones.
5. **(Opcional, segun sensibilidad)**: SSE-KMS con CMK propia + Bucket Key.

## `policy-fixed.json`

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
        "arn:aws:s3:::legacy-marketing-assets-us-east-1",
        "arn:aws:s3:::legacy-marketing-assets-us-east-1/*"
      ],
      "Condition": {
        "Bool": { "aws:SecureTransport": "false" }
      }
    },
    {
      "Sid": "AllowPublicReadOnPublicCampaignsPrefix",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::legacy-marketing-assets-us-east-1/public/campaigns/*",
      "Condition": {
        "Bool": { "aws:SecureTransport": "true" }
      }
    }
  ]
}
```

Clave: `Action` minima (`s3:GetObject`), `Resource` acotado al prefijo, y el `Deny` TLS gana sobre cualquier intento HTTP.

## `bpa-fixed.json`

```json
{
  "PublicAccessBlockConfiguration": {
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }
}
```

**Nota importante:** con los 4 en `true`, S3 **rechazara** aplicar `policy-fixed.json` por tener `Principal: "*"`. El plan de migracion correcto es:

1. Aplicar `policy-fixed.json` **antes** de activar BPA (deja el acceso publico controlado).
2. Levantar CloudFront + OAC apuntando al prefijo publico.
3. Cambiar la policy a una que **solo** permita entrar al service principal `cloudfront.amazonaws.com` con `aws:SourceArn` de la distribucion.
4. Activar BPA 4/4 `true`.
5. Repoint DNS/CDN a CloudFront.

## Seccion C — Riesgos residuales

1. **Lo que ya se filtro, filtrado esta.** Los objetos publicos probablemente estan indexados por Google / archive.org. Cambiar la policy no "des-indexa"; hay que pedir removal explicito a cada motor.
2. **Logs historicos de acceso.** Si hubo acceso logging activo (no en este caso), los logs listan quien accedio; si no, no hay forma de saber que se descargo.
3. **Cache de CDN con contenido antiguo.** Si habia una CDN delante, su cache puede seguir sirviendo contenido retirado hasta que expire o se invalide.
4. **Prefijos no auditados.** Hemos mirado `/public/campaigns/`. ¿Que hay bajo `/internal/`? La policy anterior exponia **todo**; cualquier cosa pudo salir.
5. **ACLs huerfanas.** Aunque movamos a `BucketOwnerEnforced`, el proceso de migracion debe limpiar ACLs existentes; de lo contrario quedan como configuracion muerta confusa.

## Preguntas

1. **¿Por que `BlockPublicPolicy = true` no "rompe" una policy publica ya existente?**
   `BlockPublicPolicy` evalua al **aplicar** una policy (PutBucketPolicy). Si la policy publica se aplico antes, ya esta persistida; BPA no la borra automaticamente, solo rechaza nuevos cambios que la hagan publica. Para "limpiar" hay que **reaplicar** una policy sin principal publico, o borrarla.

2. **¿Que ganas con `BucketOwnerEnforced`?**
   Eliminas ACLs como vector de acceso. Toda la autorizacion vive en IAM + bucket policy, auditable con Access Analyzer y versionable con Terraform. Las ACLs son difíciles de leer, poco expresivas y la causa frecuente de "pero si la policy esta bien..."

3. **Nuevo bucket hoy, publico `/public/campaigns/*`.**
   Bucket privado (BPA 4/4) + **CloudFront** con **Origin Access Control** apuntando a ese prefijo + bucket policy que **solo** acepta al service principal `cloudfront.amazonaws.com` con `aws:SourceArn` igual al ARN de la distribucion. Ventajas: TLS en el edge, cache, logs CloudFront, WAF, geo-restriction, firma de URLs opcional, y S3 nunca expuesto directamente.
