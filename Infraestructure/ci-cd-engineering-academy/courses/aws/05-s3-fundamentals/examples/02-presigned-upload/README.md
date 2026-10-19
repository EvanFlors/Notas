# Ejemplo 02 — Presigned URL para upload

> Lectura y analisis. Flujo end-to-end: backend firma, cliente sube sin credenciales AWS.

## 1. El escenario

Una SPA en `https://app.acme.com` deja que el usuario suba un avatar. **No queremos** que el navegador tenga credenciales AWS; **no queremos** que el backend reciba el fichero y lo reenvie (dobla trafico y memoria). La solucion es:

1. El navegador pide al backend una **URL firmada** para `PUT`.
2. El backend firma con sus credenciales y responde la URL + headers requeridos.
3. El navegador hace `PUT` directo a S3 con esa URL.
4. S3 valida la firma, verifica expiracion, acepta el upload.

Durante toda la operacion el **cliente nunca ve claves AWS**.

## 2. Backend (Python + boto3)

```python
# backend/signer.py
import boto3
from botocore.config import Config

s3 = boto3.client(
    "s3",
    config=Config(signature_version="s3v4", region_name="us-east-1"),
)

def sign_upload(user_id: str, filename: str, content_type: str) -> dict:
    key = f"incoming/user-{user_id}/{filename}"
    url = s3.generate_presigned_url(
        ClientMethod="put_object",
        Params={
            "Bucket": "acme-prod-uploads-us-east-1",
            "Key": key,
            "ContentType": content_type,
        },
        ExpiresIn=900,  # 15 min
    )
    return {
        "url": url,
        "method": "PUT",
        "headers": {"Content-Type": content_type},
        "key": key,
    }
```

Tres cosas que suelen fallar y como blindarlas:

- **`signature_version="s3v4"`** explicito. Algunas regiones (todas las nuevas) solo aceptan v4.
- **`ContentType` dentro de `Params`**: queda **firmado**; si el cliente pone otro `Content-Type` al hacer el PUT, S3 rechaza.
- **`ExpiresIn=900`**: 15 minutos. No pongas 7 dias "por si acaso"; es la ventana en la que un atacante que robe la URL podria usarla.

## 3. Cliente (navegador o curl)

```bash
curl -X PUT \
  -H "Content-Type: image/png" \
  --data-binary "@avatar.png" \
  "$PRESIGNED_URL"
```

En navegador:

```javascript
const res = await fetch(presignedUrl, {
  method: "PUT",
  headers: { "Content-Type": "image/png" },
  body: fileBlob,
});
```

## 4. Blindajes adicionales

- **Limite de tamaño**: usar `generate_presigned_post` (en vez de `generate_presigned_url`) permite firmar un `POST` con policy que impone `content-length-range`:

  ```python
  post = s3.generate_presigned_post(
      Bucket="acme-prod-uploads-us-east-1",
      Key="incoming/${filename}",
      Fields={"Content-Type": "image/png"},
      Conditions=[
          {"Content-Type": "image/png"},
          ["content-length-range", 0, 5_000_000],  # 5 MB max
      ],
      ExpiresIn=900,
  )
  ```

- **CORS en el bucket** (ver §9 de la leccion) para permitir el origen de la SPA.
- **Lifecycle** sobre `incoming/`: expiracion automatica tras N dias (muchos uploads nunca se "promueven" a `processed/`).
- **S3 Event Notification** `s3:ObjectCreated:*` sobre `incoming/*` que dispare validacion y mueva a `processed/` o borre.

## 5. Lo que la URL firmada **no** da

- **No bypassa la bucket policy**: si tienes `Deny` para `aws:SecureTransport = false`, el PUT sobre `http://` sigue fallando.
- **No bypassa BPA**: una URL firmada no publica un bucket.
- **No es revocable individualmente**: no hay "lista de URLs". Para "revocar" tendrias que rotar las credenciales del firmante o aplicar una policy que la bloquee (lo cual mata todas las URLs firmadas con esas credenciales).

## 6. Que practicamos en la actividad 01

En `activities/01-provision-and-upload-with-cli-and-boto3/` usas LocalStack para generar una presigned URL y hacer PUT con curl. La estructura es identica al patron de prod; cambia solo `endpoint_url`.
