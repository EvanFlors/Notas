# Ejemplo 03 — Signed URLs: contenido privado en S3 servido por CloudFront

> Demostrativo. No se ejecuta contra AWS; sí puedes correr el snippet Python localmente para generar una URL firmada contra una clave privada de ejemplo (RSA generada *on the fly*).

## 1. Caso de uso

Un bucket S3 con PDFs premium que **no** deben ser accesibles sin autorización. No queremos buckets públicos, ni URLs presignadas de S3 directas (expiran por request + fugan la región del bucket). Queremos:

- CDN delante (latencia, caché opcional).
- Firma controlada por nosotros con una clave privada que **nunca sale** de nuestro backend.
- URLs con expiración y, opcionalmente, política por IP/path.

## 2. Piezas

```
   Backend (nuestro)         CloudFront                S3 (privado, OAC)
   ─────────────────         ──────────                ─────────────────
   firma URL con            comprueba firma           sirve objeto
   clave privada            con key group             solo con SigV4 OAC
                            (clave pública)
```

- Un **key pair** RSA 2048 (o ECDSA). La **privada** vive en Secrets Manager / Parameter Store de tu backend. La **pública** se sube a CloudFront como un `public_key`.
- Un **key group** agrupa 1+ public keys y se asocia al behavior.
- El behavior tiene `trusted_key_groups` → señal de "este path requiere firma".

## 3. Fragmento Terraform

```hcl
resource "aws_cloudfront_public_key" "signer" {
  name        = "pk-premium-signer"
  comment     = "Public key para firmar URLs premium"
  encoded_key = file("${path.module}/signer_public.pem")  # NOTE: solo la PÚBLICA
}

resource "aws_cloudfront_key_group" "premium" {
  name  = "kg-premium"
  items = [aws_cloudfront_public_key.signer.id]
}

# ...dentro de la distribución
ordered_cache_behavior {
  path_pattern         = "/premium/*"
  target_origin_id     = "s3-site"
  trusted_key_groups   = [aws_cloudfront_key_group.premium.id]  # ← aquí
  viewer_protocol_policy = "https-only"
  allowed_methods      = ["GET", "HEAD"]
  cached_methods       = ["GET", "HEAD"]
  cache_policy_id      = "658327ea-f89d-4fab-a63d-7e88639e58f6"  # CachingOptimized
}
```

Cualquier request a `/premium/*` sin firma válida → **403**.

## 4. Firma en Python (snippet ejecutable localmente)

> Este snippet **no** llama a AWS; genera un keypair RSA al vuelo y produce una URL firmada que *tendría* validez contra una distribución real si usaras la pública del keypair. Util para ver la mecánica.

```python
import base64
import datetime as dt
import json
import textwrap

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa

# 1) Keypair ilustrativo (NUNCA uses esta clave contra AWS real).
key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
pub_pem = key.public_key().public_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PublicFormat.SubjectPublicKeyInfo,
).decode()
print("PUBLIC KEY (subir a CloudFront):\n", pub_pem)

# 2) Política canned (expira en 1h, un recurso):
resource = "https://cdn.example.com/premium/report.pdf"
expires = int((dt.datetime.utcnow() + dt.timedelta(hours=1)).timestamp())
policy = {
    "Statement": [{
        "Resource": resource,
        "Condition": {"DateLessThan": {"AWS:EpochTime": expires}},
    }]
}
policy_json = json.dumps(policy, separators=(",", ":")).encode()

# 3) Firma SHA-1 RSA (requisito CloudFront classic).
signature = key.sign(policy_json, padding.PKCS1v15(), hashes.SHA1())

def cf_b64(data: bytes) -> str:
    """Base64 variant que usa CloudFront: + / = → - _ ~"""
    return base64.b64encode(data).decode().translate(str.maketrans("+/=", "-_~"))

signed_url = (
    f"{resource}"
    f"?Policy={cf_b64(policy_json)}"
    f"&Signature={cf_b64(signature)}"
    f"&Key-Pair-Id=K2EXAMPLEKEYID"  # ← id del public key en CloudFront
)
print("\nSIGNED URL:\n", textwrap.fill(signed_url, 80))
```

## 5. Signed URL vs Signed Cookie — cuándo cada una

| Signed URL                                      | Signed Cookie                                                |
|-------------------------------------------------|--------------------------------------------------------------|
| Firma **un** recurso                            | Firma **un patrón** (`/premium/*`)                           |
| URL va en link / email / descarga directa       | Cookies van en el navegador del usuario autenticado          |
| Fácil para "descarga protegida"                 | Natural para "sesión premium con muchos recursos"            |
| URL larga, visible en logs                      | Cookies no se ven en URL                                     |
| Sin estado adicional                            | Requiere HTTPS + path/domain correctos para las cookies      |

Regla: **URL** para enlace puntual; **cookie** para dashboard/galería donde el usuario navega.

## 6. Alternativa: URL presignada de S3 directa (sin CloudFront)

Es válida para casos simples. Diferencias:

- La URL **expone el bucket** y la región.
- No pasa por el edge (sin cache, sin TLS en POP cercano, egreso desde la región del bucket).
- Es más barata si hay poco tráfico y el usuario está cerca de la región.

Para distribución global y volumen alto: **CloudFront + signed URL/cookie**.

## 7. Costos

- CloudFront **no cobra extra** por signed URL/cookie — es la misma distribución.
- Key groups / public keys son gratis.
- Guardar la privada en Secrets Manager: ~0.40 USD/mes por secret + accesos.

**Para esta academia: NO se levanta nada en AWS.** Puedes ejecutar el snippet Python localmente si quieres ver la mecánica.
