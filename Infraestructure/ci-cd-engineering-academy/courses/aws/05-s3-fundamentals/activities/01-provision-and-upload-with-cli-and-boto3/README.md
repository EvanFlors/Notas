# Actividad 01 — Provisionar bucket seguro y subir via CLI + boto3 (LocalStack)

## 1. Identificacion

- **ID:** `aws-05-01-provision-and-upload-with-cli-and-boto3`
- **Tecnologia:** `aws`
- **Modulo:** `aws-05-s3-fundamentals`
- **Dificultad:** beginner
- **Duracion estimada:** 50–70 min
- **Tipo:** guided-lab (independiente de la actividad 02)

## 2. Contexto

Vas a provisionar un bucket S3 "defendible" y a ejercitar las dos vias canonicas de interactuar con el: CLI (`aws s3` / `aws s3api`) y SDK (`boto3`). Todo contra **LocalStack** para evitar costos y riesgo de dejar algo abierto en una cuenta real.

Las APIs son identicas; la unica diferencia es `--endpoint-url=http://localhost:4566` para la CLI y `endpoint_url="http://localhost:4566"` para boto3. Lo que aprendes aqui se traslada **tal cual** a AWS real.

## 3. Objetivos

Al terminar deberias poder, **sin consultar la lección**:

- Explicar que settings minimos componen un bucket "serio" (BPA, ownership, versioning, SSE, lifecycle, policy).
- Escribir un **JSON de lifecycle** y un **JSON de bucket policy** desde cero.
- Subir un objeto con la CLI y con boto3, y leer su `VersionId` para comprobar que versioning funciona.
- Generar y usar una **presigned URL** de upload.

## 4. Prerrequisitos

- Haber leido `../../theory/lesson.md` completo (en especial §5 BPA, §6 bucket policies, §10 presigned, §11 LocalStack).
- Herramientas locales:
  - `docker` (para LocalStack).
  - `aws` CLI v2.
  - `python3` ≥ 3.9 con `boto3` (`pip install boto3`).
  - `jq` recomendado para inspeccionar JSON.
- Si **no** tienes `docker` o LocalStack no arranca, el validador omite los chequeos dinamicos (SKIP) y solo valida la estructura de los JSON entregados. **Puedes completar la actividad sin docker**, pero perderas el refuerzo practico.

**Costos**: 0. LocalStack es free para S3.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/aws-05-upload
cd /tmp/aws-05-upload
```

Si usas otra ruta, pasasela al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Levantar LocalStack

```bash
docker run --rm -d --name aws-05-localstack \
  -p 4566:4566 \
  -e SERVICES=s3 \
  localstack/localstack:latest

# Espera a que este listo
until curl -sf http://localhost:4566/_localstack/health | grep -q '"s3"'; do
  sleep 1
done
echo "LocalStack ready"
```

Exporta credenciales dummy:

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566
```

> `AWS_ENDPOINT_URL` es honrado por `aws` CLI v2 ≥ 2.13 y por boto3 ≥ 1.28. Si tu version es menor, pasa `--endpoint-url` explicito en cada comando.

### 5.3 Crear el bucket y endurecerlo

Elige un nombre bajo convencion (p. ej. `student-aws05-reports-$(date +%s)`). Guardalo:

```bash
export BUCKET="student-aws05-reports-$(date +%s)"
aws s3api create-bucket --bucket "$BUCKET"

# BPA 4/4 true
aws s3api put-public-access-block --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Ownership = BucketOwnerEnforced (ACLs off)
aws s3api put-bucket-ownership-controls --bucket "$BUCKET" \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'

# Versioning
aws s3api put-bucket-versioning --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
```

### 5.4 Escribir los JSON de configuracion

En `/tmp/aws-05-upload/` crea **tres** ficheros JSON:

**`lifecycle.json`** — debe contener al menos: `Rules[0].ID`, `Status=Enabled`, un `Filter`, al menos **una** `Transitions` o `Expiration`, `NoncurrentVersionExpiration` **y** `AbortIncompleteMultipartUpload`.

**`bucket-policy.json`** — debe contener `Version=2012-10-17`, al menos un `Statement` con `Effect=Deny` y la condicion `aws:SecureTransport = false` sobre `s3:*`.

**`event-notification.json`** — debe contener al menos una de `QueueConfigurations`, `TopicConfigurations`, `LambdaFunctionConfigurations` o `EventBridgeConfiguration`, con `Events` listando al menos un evento `s3:*`.

### 5.5 Aplicar los JSON

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket "$BUCKET" --lifecycle-configuration file://lifecycle.json

aws s3api put-bucket-policy \
  --bucket "$BUCKET" --policy file://bucket-policy.json

# Nota: para event notifications hacia SQS/SNS/Lambda haria falta crear primero
# el recurso destino. Aqui basta con validar el JSON estructuralmente.
```

### 5.6 Subir un objeto via CLI y via boto3

```bash
echo "hello from cli $(date -u +%FT%TZ)" > /tmp/aws-05-upload/cli.txt
aws s3 cp /tmp/aws-05-upload/cli.txt "s3://${BUCKET}/uploads/cli.txt"

cat > /tmp/aws-05-upload/upload.py <<'PY'
import os, boto3
s3 = boto3.client("s3", endpoint_url=os.environ.get("AWS_ENDPOINT_URL"))
bucket = os.environ["BUCKET"]
s3.put_object(Bucket=bucket, Key="uploads/boto3.txt",
              Body=b"hello from boto3", ContentType="text/plain")
# Firma una presigned URL de GET sobre el objeto CLI, 60s.
url = s3.generate_presigned_url(
    "get_object",
    Params={"Bucket": bucket, "Key": "uploads/cli.txt"},
    ExpiresIn=60,
)
print(url)
PY
python3 /tmp/aws-05-upload/upload.py > /tmp/aws-05-upload/presigned.url
```

Verifica que la URL firmada funciona:

```bash
curl -sf "$(cat /tmp/aws-05-upload/presigned.url)" | head
```

### 5.7 Capturar evidencia

Para que el validador pueda verificar lo dinamico sin reejecutarlo, guarda:

- **`bucket-name.txt`**: una sola linea con `$BUCKET`.
- **`listing.txt`**: salida de `aws s3api list-object-versions --bucket "$BUCKET" --prefix uploads/`.

```bash
echo "$BUCKET" > /tmp/aws-05-upload/bucket-name.txt
aws s3api list-object-versions --bucket "$BUCKET" --prefix uploads/ \
  > /tmp/aws-05-upload/listing.txt
```

### 5.8 Documentar

Escribe `/tmp/aws-05-upload/NOTES.md` (en español) explicando:

- Que settings aplicaste y por que.
- Que diferencia observaste entre CLI y boto3 (deberia ser ninguna semantica).
- Que paso cuando intentaste usar la presigned URL vencida (opcional: espera 60s y prueba).

## 6. Resultado esperado

- `lifecycle.json`, `bucket-policy.json`, `event-notification.json` validos estructuralmente.
- `bucket-name.txt`, `listing.txt`, `NOTES.md` presentes.
- Si LocalStack estaba levantado: `listing.txt` muestra al menos un objeto con `VersionId` no vacio para `uploads/cli.txt` o `uploads/boto3.txt`.
- `bash tests/validate.sh /tmp/aws-05-upload` sale en verde.

## 7. Criterios de aceptacion

- **Funcional**: validador en verde.
- **Calidad**: JSONs mínimos pero coherentes; `NOTES.md` justifica cada decision.
- **Reproducibilidad**: alguien con tu `NOTES.md` puede reproducir el bucket exacto.
- **Mantenibilidad**: nombres de bucket bajo convencion; no credenciales reales ni IDs de cuenta reales.

## 8. Validacion

```bash
bash tests/validate.sh /tmp/aws-05-upload
```

El validador:

1. Confirma que los 3 JSON existen y son parseables.
2. Comprueba su **estructura minima** con Python (claves obligatorias, enums de StorageClass validos, Effect=Deny en policy, al menos un evento s3:*).
3. Si detecta LocalStack vivo y `bucket-name.txt`, comprueba contra la API que BPA = 4/4 true, versioning Enabled, lifecycle y policy aplicadas, y que existe al menos un objeto con version.
4. Si LocalStack no esta disponible, imprime `SKIP` para los chequeos dinamicos y evalua solo lo estructural.

## 9. Preguntas de reflexion

1. ¿Por que la bucket policy incluye un `Deny` global con `aws:SecureTransport = false` y no simplemente un `Allow` para TLS?
2. ¿Que diferencia hay entre `BlockPublicAcls` y `IgnorePublicAcls`? ¿Por que necesitas los dos?
3. Si subieras el mismo `uploads/cli.txt` dos veces, ¿cuantas versiones aparecerian? ¿Y si versioning estuviera `Suspended`?
4. ¿Por que `AbortIncompleteMultipartUpload` es gratis y aun asi se olvida siempre?
5. ¿Que ocurriria si la presigned URL de GET se firmase con credenciales que **no** tienen `s3:GetObject` sobre ese prefijo?

## 10. Extensiones

- Añade una regla de lifecycle extra que caduque `uploads/` a los 7 dias.
- Genera una presigned URL de **PUT** y sube un objeto con `curl -X PUT`.
- Habilita SSE-KMS con una CMK mock de LocalStack (`aws kms create-key`) y comprueba `GetObject`.

## 11. Limpieza

```bash
# Borrar objetos (incluidas versiones)
aws s3api delete-objects --bucket "$BUCKET" \
  --delete "$(aws s3api list-object-versions --bucket "$BUCKET" \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' --output json)" \
  2>/dev/null || true

aws s3api delete-bucket --bucket "$BUCKET" || true

docker rm -f aws-05-localstack 2>/dev/null || true
rm -rf /tmp/aws-05-upload
```
