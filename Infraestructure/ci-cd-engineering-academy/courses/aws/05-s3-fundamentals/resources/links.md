# Recursos — aws-05

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso para asegurar vigencia (precios y defaults cambian).

## Oficiales (AWS S3)

- **User Guide**: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/Welcome.html`
- **API Reference**: `https://docs.aws.amazon.com/AmazonS3/latest/API/Welcome.html`
- **Storage classes**: `https://aws.amazon.com/s3/storage-classes/`
- **Pricing**: `https://aws.amazon.com/s3/pricing/`
- **Security best practices**: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html`

## Seguridad

- **Block Public Access**: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html`
- **Default encryption (SSE-S3 por default desde 2023)**: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/default-encryption-faq.html`
- **S3 Bucket Keys (reduce costo SSE-KMS)**: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucket-key.html`
- **Object Ownership `BucketOwnerEnforced` (ACLs off)**: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/about-object-ownership.html`
- **Bucket policies ejemplos**: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-bucket-policies.html`

## Lifecycle y versioning

- **Lifecycle configuration**: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html`
- **Versioning**: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html`
- **Object Lock (WORM)**: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock.html`

## Eventos y logging

- **S3 Event Notifications**: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/NotificationHowTo.html`
- **EventBridge integration**: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/EventBridge.html`
- **Server access logging**: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/ServerLogs.html`

## Presigned URLs y CORS

- **Presigned URLs**: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/ShareObjectPreSignedURL.html`
- **CORS**: `https://docs.aws.amazon.com/AmazonS3/latest/userguide/cors.html`

## Herramientas locales

- **LocalStack (gratis para S3)**: `https://docs.localstack.cloud/user-guide/aws/s3/`
- **AWS CLI v2**: `https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html`
- **boto3 S3**: `https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3.html`

## Lecturas y charlas

- AWS re:Invent "Deep dive on Amazon S3" (hay versión por año; buscar la más reciente en YouTube AWS Events).
- "S3 Strongly Consistent Reads" post (anuncio 2020) en AWS News Blog.
- Casos públicos de leaks por BPA ausente: buscar "S3 bucket leak" + año en krebsonsecurity.com y upguard.com.

## Checklist de verificación requerida en Fase 4

- Default actual de **Block Public Access** a nivel cuenta en nuevas cuentas AWS.
- Default actual de **Object Ownership** en buckets nuevos (debe seguir siendo `BucketOwnerEnforced`).
- Lista actualizada de **storage classes** y sus precios en la región usada por el curso.
- Compatibilidad y features actuales de **LocalStack** para S3 (lifecycle, event notifications, presigned URLs).
- Formato vigente del JSON de **lifecycle** y de **event notifications** (ambos han sido estables, pero conviene revisar).
