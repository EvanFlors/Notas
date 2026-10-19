# Ejemplo 02 — API dinámica en ALB fronteada por CloudFront (dos orígenes, cache behaviors ordenados)

> Demostrativo. No se aplica. Objetivo: ver un diseño de distribución con **dos orígenes** y **cache behaviors ordenados** correctamente, y entender el *ordering gotcha* en la práctica.

## 1. Topología

```
   Usuario
     │  HTTPS
     ▼
   CloudFront distribution
     │  ├── behavior /api/*     ──► origin  ALB (eu-west-1)
     │  └── behavior default *  ──► origin  S3 bucket privado (OAC)
     │                                    (SPA: HTML/CSS/JS)
     ▼
   TLS re-encrypt al origen
```

Un solo nombre público (`app.example.com`), una sola distribución, dos backends.

## 2. Orden de behaviors — el gotcha central

CloudFront evalúa behaviors de **arriba a abajo**; gana el primero que matchee el path pattern. **El `default (*)` es siempre el último lógico.**

Si declaras en Terraform:

```hcl
ordered_cache_behavior {
  path_pattern     = "*"           # ← ERROR: se come todo
  target_origin_id = "s3-site"
  ...
}
ordered_cache_behavior {
  path_pattern     = "/api/*"      # nunca se evalúa
  target_origin_id = "alb-api"
  ...
}
```

...tu API nunca llegará al ALB. Siempre caerá en el behavior "*" primero.

**Regla**: ordena de **más específico a menos específico**. El `default_cache_behavior` sirve como catch-all; no uses `*` como `ordered_cache_behavior`.

## 3. Plantilla Terraform (fragmentos relevantes)

```hcl
# Dos orígenes
origin {
  domain_name = aws_lb.api.dns_name
  origin_id   = "alb-api"
  custom_origin_config {
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "https-only"
    origin_ssl_protocols   = ["TLSv1.2"]
  }
}

origin {
  domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
  origin_id                = "s3-site"
  origin_access_control_id = aws_cloudfront_origin_access_control.site.id
}

# Behavior MÁS ESPECÍFICO primero
ordered_cache_behavior {
  path_pattern     = "/api/*"
  target_origin_id = "alb-api"

  viewer_protocol_policy = "redirect-to-https"
  allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
  cached_methods         = ["GET", "HEAD"]
  compress               = true

  # Managed "CachingDisabled" — nada en cache para la API
  cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  # Managed "AllViewer" — forwardea todos los headers/cookies/querystring al ALB
  origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
}

# default = catch-all (SPA)
default_cache_behavior {
  target_origin_id = "s3-site"

  viewer_protocol_policy = "redirect-to-https"
  allowed_methods        = ["GET", "HEAD"]
  cached_methods         = ["GET", "HEAD"]
  compress               = true

  cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6"  # CachingOptimized
  origin_request_policy_id   = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"  # CORS-S3Origin
  response_headers_policy_id = "67f7725c-6f97-4210-82d7-5512b31e9d03"  # SecurityHeadersPolicy
}
```

## 4. ¿Qué pasa en cada tipo de petición?

| Request               | Behavior matched | Origin  | Cache? | Qué forwardea |
|-----------------------|------------------|---------|--------|---------------|
| `GET /`               | default `*`      | s3-site | sí     | mínimo (CORS-S3Origin) |
| `GET /app.js`         | default `*`      | s3-site | sí     | mínimo |
| `GET /api/users`      | `/api/*`         | alb-api | **no** | **todo** (headers, cookies, qs) |
| `POST /api/login`     | `/api/*`         | alb-api | no     | todo |
| `GET /no/such/path`   | default `*`      | s3-site | sí (404 cached brevemente, o SPA fallback via CF Function) |

## 5. SPA fallback con CloudFront Function

Para que `/app/dashboard` sirva `index.html` (client-side routing), añade una CloudFront Function en `viewer-request`:

```javascript
function handler(event) {
  var req = event.request;
  var uri = req.uri;
  // Si no termina en algo con extensión, servir index.html del SPA
  if (!uri.includes('.') && !uri.startsWith('/api/')) {
    req.uri = '/index.html';
  }
  return req;
}
```

Esto es ~sub-ms en el POP, sin salir del edge. Lambda@Edge sería caro y lento para esta tarea.

## 6. JSON de distribución (campos clave)

```json
{
  "DistributionConfig": {
    "Origins": {
      "Quantity": 2,
      "Items": [
        { "Id": "alb-api",  "DomainName": "api-alb-12345.eu-west-1.elb.amazonaws.com" },
        { "Id": "s3-site",  "DomainName": "example-site.s3.eu-west-1.amazonaws.com",
          "OriginAccessControlId": "E1ABCDEF2GHIJ3" }
      ]
    },
    "CacheBehaviors": {
      "Quantity": 1,
      "Items": [
        {
          "PathPattern": "/api/*",
          "TargetOriginId": "alb-api",
          "CachePolicyId": "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
        }
      ]
    },
    "DefaultCacheBehavior": {
      "TargetOriginId": "s3-site",
      "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6"
    }
  }
}
```

Validaciones estructurales recomendadas (y usadas en la actividad 01):

- `Origins.Quantity >= 2`.
- Existe un `CacheBehaviors.Items[*]` con `PathPattern == "/api/*"` apuntando al `alb-api`.
- El default behavior apunta al `s3-site`.
- No existe ningún `CacheBehaviors.Items[*]` con `PathPattern == "*"` (eso rompería el default).

## 7. Costos

- CloudFront + ALB es el patrón más común en producción. CloudFront reduce latencia (TLS en edge) y absorbe picos (cache de GETs si el API tiene algún endpoint cacheable con `Cache-Control: public, max-age=60`).
- El ALB sí tiene coste horario (~0.0225 USD/h + por LCU). **Esto solo lo levantas en el módulo de ALB real; aquí es ilustrativo.**
- Para esta academia: **NO se aplica**. Solo `plan` y lectura del JSON.
