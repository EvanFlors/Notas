# Ejemplo 02 — IMDSv2 enforced y por qué importa

> Lectura y análisis. Objetivo: ver cómo se **fuerza IMDSv2** y por qué dejar IMDSv1 habilitado es equivalente a dejar una llave bajo el felpudo.

## 1. Qué es el ataque que IMDSv2 cierra

Supón una app web vulnerable a **SSRF** (Server-Side Request Forgery). Un endpoint típico:

```
POST /api/fetch-url    { "url": "https://..." }
```

El backend hace `requests.get(url)` sin validar. Un atacante prueba:

```
POST /api/fetch-url    { "url": "http://169.254.169.254/latest/meta-data/iam/security-credentials/" }
```

### Con IMDSv1 (desgracia)

El backend obedece. La respuesta devuelve el **nombre** del rol. Segunda llamada:

```
POST /api/fetch-url    { "url": "http://169.254.169.254/latest/meta-data/iam/security-credentials/<ROL>" }
```

Devuelve `AccessKeyId`, `SecretAccessKey`, `Token`, `Expiration`. El atacante ya tiene **credenciales STS de tu rol**. Puede listar S3, leer DBs, lo que el rol permita. Esto es exactamente el patrón del **Capital One breach (2019)**.

### Con IMDSv2 (defensa)

La primera request falla:

```
GET http://169.254.169.254/latest/meta-data/iam/security-credentials/
→ 401 Unauthorized
```

Porque IMDSv2 requiere **primero** un `PUT` con `X-aws-ec2-metadata-token-ttl-seconds` para obtener un token, y el **token** debe adjuntarse en header `X-aws-ec2-metadata-token` en cada subsiguiente GET. La mayoría de SSRF **solo** permiten GETs simples; no pueden emitir el PUT ni los headers custom. El ataque queda bloqueado.

Adicionalmente, el **hop limit** (default 1) evita que el PUT viaje a través de un contenedor Docker intermedio con red bridge — otro vector histórico.

## 2. Cómo forzarlo (Terraform)

```hcl
resource "aws_instance" "app" {
  # ... ami, instance_type, subnet, SG, etc. ...

  metadata_options {
    http_endpoint               = "enabled"   # IMDS activo. "disabled" = sin IMDS en absoluto.
    http_tokens                 = "required"  # <--- IMDSv2 OBLIGATORIO. "optional" = permite v1.
    http_put_response_hop_limit = 1           # evita escapes via containers.
    instance_metadata_tags      = "enabled"   # expone tags via IMDS (practico).
  }
}
```

## 3. Verificaciones post-arranque

Dentro de la EC2 (vía SSM):

```bash
# Sin token: debe fallar.
curl -s -o /dev/null -w "HTTP %{http_code}\n" \
  http://169.254.169.254/latest/meta-data/
# Esperado: HTTP 401

# Con token: debe funcionar.
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
          -H "X-aws-ec2-metadata-token-ttl-seconds: 60")

curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
     http://169.254.169.254/latest/meta-data/instance-id
# Esperado: i-0123456789abcdef0
```

Y desde AWS CLI (fuera de la EC2):

```bash
aws ec2 describe-instances \
  --instance-ids i-0123456789abcdef0 \
  --query 'Reservations[0].Instances[0].MetadataOptions'
```

Debe mostrar:

```json
{
  "State": "applied",
  "HttpTokens": "required",
  "HttpPutResponseHopLimit": 1,
  "HttpEndpoint": "enabled",
  "InstanceMetadataTags": "enabled"
}
```

## 4. Account-level enforcement (más estricto)

Puedes configurar la cuenta/region para que **por default** las nuevas instancias usen IMDSv2:

```bash
aws ec2 modify-instance-metadata-defaults \
  --region eu-west-1 \
  --http-tokens required \
  --http-put-response-hop-limit 1 \
  --http-endpoint enabled
```

Esto es una **red de seguridad** por si alguien olvida el bloque `metadata_options` en su HCL.

## 5. Qué puede romperse al forzar IMDSv2

Casi nada en software moderno. Posibles fricciones:

- **SDKs AWS antiguos** (p. ej. boto3 <1.20, aws-sdk-java 1.x viejo) usan IMDSv1 por default. Actualizar.
- **Scripts caseros** que hacen `curl http://169.254.169.254/...` sin token. Hay que portarlos al patrón PUT→GET.
- **Herramientas de terceros** que leen metadata (datadog agent viejo, etc.). Las versiones recientes de todos los agentes serios ya hablan v2.

Ninguno de esos problemas justifica dejar v1 abierto. **La regla del programa es `http_tokens = "required"` siempre.**
