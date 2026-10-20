# aws-05 — Lección: S3 con seguridad por default

> 12 secciones. Objetivo: entender S3 lo suficientemente bien como para no filtrar datos ni gastar de más. Prerrequisito: `aws-02` (IAM).

---

## 1. El modelo mental: object store, no filesystem

S3 **no** es un filesystem. Es un **key-value store** masivo donde:

- La **clave** (`key`) es una cadena arbitraria (`fotos/2024/01/avatar.png`). Las "carpetas" son una **ilusión visual** del listado por prefijo.
- El **valor** es el objeto: un blob opaco de bytes + metadata (content-type, custom metadata, versionId, storage class).
- El **bucket** es el contenedor. Su nombre es **globalmente único** en toda AWS. Si `data` existe, no puedes usarlo (y no, no existe ninguno "libre" útil desde hace una década).

Consecuencia práctica: convenciones de naming como `mycompany-env-purpose-region` (`acme-prod-userdata-us-east-1`) son el estándar razonable. Nombres cortos están tomados.

**Consistencia:** desde diciembre de 2020, S3 ofrece **strong read-after-write consistency** para PUT/DELETE sobre cualquier objeto en todas las regiones. El viejo folclore de "espera unos segundos tras un PUT" ya no aplica.

---

## 2. Storage classes: la pregunta no es "¿cuál?", es "¿cómo migra?"

| Clase | Latencia primer byte | Min storage | Costo relativo storage | Casos |
|-------|---------------------|-------------|------------------------|-------|
| **Standard** | ms | — | 1.0× | hot: tráfico frecuente, assets web |
| **Intelligent-Tiering** | ms | 30 d | ~1.0× + fee monitoreo | acceso impredecible; AWS mueve por ti |
| **Standard-IA** | ms | 30 d | ~0.55× | warm: acceso infrecuente (backups mensuales) |
| **One Zone-IA** | ms | 30 d | ~0.44× | warm, re-creable (una AZ, menor durabilidad) |
| **Glacier Instant Retrieval** | ms | 90 d | ~0.25× | archive con lectura ocasional pero inmediata |
| **Glacier Flexible Retrieval** | min–h | 90 d | ~0.12× | archive, lectura programada |
| **Glacier Deep Archive** | h | 180 d | ~0.04× | compliance, logs antiguos, nunca-se-lee-salvo-auditoría |

**Dos trampas:**

1. Las clases "frías" tienen **mínimo de almacenamiento** y **costo por retrieval**. Mover 10 MB a Deep Archive y leerlo dos veces al mes sale **más caro** que Standard.
2. **Intelligent-Tiering** cobra un pequeño fee por objeto monitoreado; para objetos muy pequeños (< 128 KB) no vale la pena, porque esos no transicionan.

**Idea clave:** no eliges storage class "a mano por objeto". Eliges **lifecycle rules** que los van transicionando según edad / último acceso. Más en §4.

---

## 3. Versioning: red de seguridad barata (hasta que no la limpies)

Habilitar **versioning** convierte cada PUT sobre una key existente en una **nueva versión** y cada DELETE en un **delete marker** (no borra bytes, solo marca el objeto como ausente para `GetObject` sin `versionId`).

Beneficios:

- **Recuperación ante borrado accidental** y ante overwrite incorrecto.
- Base para **MFA Delete** (requiere MFA para borrar permanentemente una versión).
- Base para **Object Lock** (WORM / compliance).

Riesgo: **el costo crece sin cota** si no limpias versiones no actuales. Siempre que habilites versioning, añade en la misma lifecycle rule algo como:

```json
{
  "NoncurrentVersionExpiration": { "NoncurrentDays": 30 }
}
```

Nunca "activo versioning y veo mañana". Mañana se olvida.

**Dato operativo:** una vez habilitado, el bucket no puede volver a "disabled"; solo puede ir a `Suspended` (nuevas versiones ya no se crean; las existentes no se tocan).

---

## 4. Lifecycle rules: la economía real de S3

Las **lifecycle rules** son JSON declarativo que vive en el bucket. Dos acciones principales:

- **Transition**: mueve objetos a otra storage class tras N días.
- **Expiration**: borra objetos tras N días (o `NoncurrentDays` para versiones viejas).

Ejemplo canónico (versiones actuales → IA → Glacier Deep Archive; versiones viejas → expiran; multipart abortadas → se limpian):

```json
{
  "Rules": [
    {
      "ID": "tiering-and-cleanup",
      "Status": "Enabled",
      "Filter": { "Prefix": "logs/" },
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

Observa `AbortIncompleteMultipartUpload`: subidas multipart que se cortaron a medias **cobran storage** por los chunks subidos aunque nunca se "completen". Esta regla es gratis y evita goteo de costos invisibles. **Ponla siempre.**

---

## 5. Block Public Access (BPA): la red de seguridad que debería haber existido en 2006

Casi todos los "leaks de S3" históricos (Verizon, Accenture, Dow Jones, etc.) tuvieron la misma causa: alguien dejó una **bucket policy** o una **ACL** pública *por accidente*, nadie lo auditó, y el bucket apareció en una herramienta tipo *grayhatwarfare*.

AWS introdujo **Block Public Access** en 2018 y lo movió a **default `true`** a nivel de bucket en 2023. Son 4 settings independientes:

| Setting | Qué bloquea |
|---------|-------------|
| `BlockPublicAcls` | Rechaza **nuevas** ACLs públicas (PUT bucket/object ACL con `public-read`, etc.) |
| `IgnorePublicAcls` | **Ignora** ACLs públicas existentes al evaluar acceso |
| `BlockPublicPolicy` | Rechaza **nuevas** bucket policies que permitan acceso público |
| `RestrictPublicBuckets` | Si la policy permite público, solo principals AWS autenticados pueden usarla |

**Regla de oro:** los 4 en `true` a nivel bucket **y** a nivel cuenta, salvo caso justificadísimo (sitio estático servido directo desde S3 sin CloudFront — hoy preferible OAC con CloudFront, módulo `aws-13`).

Para publicar contenido "público", el patrón moderno es **CloudFront + OAC** con el bucket privado. Nunca abras el bucket.

---

## 6. Bucket policies vs ACLs: por qué ACLs están "muertas por default"

S3 tiene **dos** mecanismos resource-based históricos:

- **ACLs** (Access Control Lists): modelo antiguo, grano por objeto, poco expresivo, difícil de auditar.
- **Bucket policies**: JSON IAM moderno, expresivo (conditions, principals, etc.), auditado por Access Analyzer.

Desde abril de 2023, los buckets nuevos vienen con **Object Ownership = `BucketOwnerEnforced`**, lo que **deshabilita ACLs** completamente. Toda operación cross-account se gobierna por bucket policy + IAM. Es el default correcto.

**Patrón mínimo** para dar lectura a un rol específico sobre un prefijo, exigiendo TLS:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowRoleReadReports",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::111111111111:role/report-reader" },
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::acme-prod-reports/public/*",
      "Condition": {
        "Bool": { "aws:SecureTransport": "true" }
      }
    },
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::acme-prod-reports",
        "arn:aws:s3:::acme-prod-reports/*"
      ],
      "Condition": {
        "Bool": { "aws:SecureTransport": "false" }
      }
    }
  ]
}
```

Dos cosas a notar:

1. **Allow explícito** solo para el principal + prefijo + acción mínima.
2. **Deny global** para cualquier petición no-TLS. El `Deny` gana sobre cualquier `Allow` (regla de evaluación IAM).

---

## 7. Encryption at-rest: SSE-S3, SSE-KMS, DSSE-KMS

Desde enero de 2023, **todo objeto nuevo en S3 se cifra at-rest por default** con **SSE-S3** (claves gestionadas por S3, AES-256). Ya no hay que pedirlo. Opciones:

| Modo | Clave | Costo extra | Cuándo |
|------|-------|-------------|--------|
| **SSE-S3** (default) | S3 la gestiona | 0 | datos no sensibles / cumplimiento básico |
| **SSE-KMS** | KMS CMK (AWS-managed o customer-managed) | KMS requests + storage de la key | compliance que exige **tu** control de la key, rotación, key policy auditable |
| **DSSE-KMS** | KMS doble capa | 2× cost de KMS | compliance con requisito de "double encryption" (FedRAMP High, etc.) |
| **SSE-C** | **tú** provees la key en cada request | — | caso raro, implicas que tú custodias la key; AWS no la almacena |

**Trampa clásica de SSE-KMS:** cada `GetObject` genera una llamada a KMS (`Decrypt`) que **cobra**. Para buckets con millones de reads, activar **S3 Bucket Keys** reduce ~99 % de esas llamadas usando una key intermedia cacheada. Siempre que uses SSE-KMS, activa Bucket Keys.

---

## 8. Access logging y S3 Event Notifications

Dos capacidades distintas para "saber qué pasa en el bucket":

- **Server access logging**: S3 escribe un log por request a **otro bucket** (nunca al mismo — loops). Formato de texto, latencia de minutos a horas. Útil para análisis forense barato.
- **S3 Event Notifications**: eventos (`s3:ObjectCreated:*`, `s3:ObjectRemoved:*`, etc.) empujados a **SQS**, **SNS**, **Lambda** o **EventBridge**. Latencia de segundos. Útil para pipelines reactivos (procesar un upload en cuanto llega).

Para auditoría de **control-plane** (quién creó/modificó el bucket) la respuesta es **CloudTrail** (módulo `aws-12`), no access logging.

**Event Notifications** se configuran por JSON. Estructura mínima:

```json
{
  "QueueConfigurations": [
    {
      "Id": "notify-new-uploads",
      "QueueArn": "arn:aws:sqs:us-east-1:111111111111:uploads-queue",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            { "Name": "prefix", "Value": "incoming/" },
            { "Name": "suffix", "Value": ".jpg" }
          ]
        }
      }
    }
  ]
}
```

---

## 9. CORS: cuándo sí, cuándo no

**CORS** solo importa si un **navegador** (JavaScript en una página de otro origen) habla directo con S3. Entre backends (Python, Go, Java hablando con S3 vía SDK) no hay CORS: no hay navegador imponiendo same-origin.

Patrón típico CORS: SPA en `https://app.acme.com` sube directo a `https://acme-uploads.s3.amazonaws.com` vía presigned URL. Necesitas:

```json
[
  {
    "AllowedOrigins": ["https://app.acme.com"],
    "AllowedMethods": ["PUT", "GET"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3000
  }
]
```

**No** uses `AllowedOrigins: ["*"]` en producción salvo que el bucket aloje assets realmente públicos (y entonces probablemente debería estar detrás de CloudFront).

---

## 10. Presigned URLs: la joya menos entendida

Una **presigned URL** es una URL firmada con **tus credenciales temporales** que permite a **otro agente** (navegador, cliente móvil, script sin credenciales AWS) ejecutar **una** operación concreta (típicamente `GetObject` o `PutObject`) sobre **un** objeto durante **un tiempo limitado**.

Ventajas:

- El cliente **no necesita credenciales AWS**. El backend firma, el cliente ejecuta.
- Granularidad **por operación + objeto + tiempo**. No es "token amplio".
- Soporta **content-type**, **content-length-range** y otros headers forzados en la firma (para evitar que suban cualquier cosa).

Trampas:

- La URL hereda los **permisos del firmante** en el momento de firmar. Si firmas con credenciales que pueden hacer `s3:*` sobre todo el bucket, la URL podría ser abusada **para el objeto específico** firmado (no para otros — la firma incluye el recurso), pero **durante su validez** no se puede revocar sin rotar las credenciales del firmante o aplicar una bucket policy que la invalide.
- **Expiración máxima**: 7 días cuando se firma con SigV4 usando credenciales de usuario IAM; con credenciales temporales (STS), el límite es la vigencia del token (puede ser mucho menor).
- La URL **no bypassa** la bucket policy ni BPA. Si una `Deny` aplica (p. ej. `aws:SecureTransport = false`), la presigned URL también falla.

Patrón backend (boto3):

```python
import boto3
s3 = boto3.client("s3")
url = s3.generate_presigned_url(
    "put_object",
    Params={
        "Bucket": "acme-uploads",
        "Key": "incoming/user-42/avatar.png",
        "ContentType": "image/png",
    },
    ExpiresIn=900,  # 15 min
)
```

El cliente luego:

```bash
curl -X PUT -H "Content-Type: image/png" --data-binary @avatar.png "$URL"
```

---

## 11. LocalStack: cómo practicamos sin cuenta AWS

LocalStack emula los APIs AWS localmente. Para S3 el soporte está entre los mejores: cubre bucket CRUD, versioning, lifecycle (declarativo; las transiciones de tiempo no "ocurren" realmente), policies, event notifications hacia SQS/Lambda emulados, presigned URLs.

Lanzarlo:

```bash
docker run --rm -d --name localstack -p 4566:4566 localstack/localstack:latest
```

Hablar con él vía CLI:

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
aws --endpoint-url=http://localhost:4566 s3 mb s3://my-bucket
```

Hablar con él vía boto3:

```python
import boto3
s3 = boto3.client("s3", endpoint_url="http://localhost:4566",
                  aws_access_key_id="test", aws_secret_access_key="test",
                  region_name="us-east-1")
```

**Lo que LocalStack NO replica fielmente:**

- Lifecycle **transitions en el tiempo** (puedes declarar la regla, pero los objetos no cambian de storage class esperando).
- Billing / costos.
- Comportamiento exacto de BPA cross-account (no hay "cuenta" real).
- KMS envelope-encryption real (hay mock).

Es excelente para **validar estructura y lógica**; para validar **comportamiento de producción con dinero**, usa una cuenta real sandbox.

---

## 12. Checklist operativo (y qué se lleva uno a producción)

Antes de considerar un bucket "listo para producción":

- [ ] Nombre bajo convención (`<org>-<env>-<purpose>-<region>`).
- [ ] **Block Public Access** = 4/4 `true` a nivel bucket y a nivel cuenta.
- [ ] **Object Ownership = `BucketOwnerEnforced`** (ACLs off).
- [ ] **Versioning** = `Enabled`.
- [ ] **Lifecycle rule** con al menos: `AbortIncompleteMultipartUpload` (7 d) y `NoncurrentVersionExpiration` (30 d razonables).
- [ ] **Encryption at-rest** = SSE-KMS con CMK propia + **Bucket Key** activado (si volumen alto).
- [ ] **Bucket policy** mínima + `Deny` global para `aws:SecureTransport = false`.
- [ ] **Access logging** a un bucket aparte (si compliance lo pide).
- [ ] **Tags** (`env`, `owner`, `cost-center`) para cost allocation.
- [ ] **CloudTrail data events** evaluado (cuesta — ver `aws-12`).

Síntesis en una línea:

> **Bucket privado, cifrado, versionado, con lifecycle de limpieza, bajo BPA y detrás de policies mínimas con TLS obligatorio. Todo lo demás es extensión.**
