# Lección — Edge en AWS: Route 53, ACM y CloudFront

> Objetivo de la lección: entender la cadena **DNS → TLS → CDN → origen** desde fundamentos, no desde la UI. Al terminar deberías poder diseñar y defender una publicación global con TLS, caché y DNS correctos, y poder dibujar quién hace qué en cada salto.

Esta lección es densa a propósito. No se levanta infraestructura — se diseña y se razona.

---

## 1. El problema: publicar al mundo con TLS, latencia aceptable y DNS correcto

Imagina que tu capstone (una app detrás de un ALB en `eu-west-1` y un bucket S3 con los assets estáticos) ya funciona. Entonces aparecen cinco preguntas que ya no se pueden evadir:

1. ¿Cómo lo encuentra la gente? → **DNS** (Route 53).
2. ¿Cómo evitamos que el navegador grite "Not Secure"? → **TLS** (ACM).
3. ¿Cómo evitamos pagar egreso desde eu-west-1 para cada petición de Tokio? → **CDN** (CloudFront).
4. ¿Cómo protegemos el bucket S3 para que **nadie** pueda saltarse el CDN? → **OAC** (Origin Access Control).
5. ¿Cómo filtramos bots obvios y limitamos por geografía si marketing lo pide? → **WAF** y/o **geo restriction**.

Las tres primeras — Route 53, ACM, CloudFront — son el bloque de este módulo. Las otras dos son extensiones naturales.

---

## 2. Route 53 — DNS como servicio operado

Route 53 es un **DNS autoritativo** gestionado. No es un recursivo de usuario (eso es Route 53 **Resolver**, servicio distinto). Lo que compras es: "AWS mantiene mis zonas, responde queries con SLA 100 %, y acepta registros con tipos avanzados".

### 2.1 Hosted zone pública vs privada

- **Pública**: la zona autoritativa de `example.com` en Internet. Para que funcione, los nameservers (NS) delegados por el registrar (o por la zona padre) deben apuntar a los 4 nameservers que Route 53 te asigna. **Esto es lo que cobra 0.50 USD/mes por zona** más consultas (ver §9).
- **Privada**: la zona solo responde dentro de las VPCs asociadas. Útil para `svc.internal` corporativo. Mismo costo base.

**Gotcha de delegación**: si borras una hosted zone pero no quitas los NS en la zona padre, apuntarán al vacío → **NXDOMAIN** o, peor, otra cuenta puede reclamar esos nameservers si hay rotación (dangling delegation). Siempre: primero quita delegación, después borra zona.

### 2.2 Routing policies

| Policy       | Para qué                                                 | Ejemplo |
|--------------|----------------------------------------------------------|---------|
| Simple       | Un valor por nombre                                      | `www → 203.0.113.10` |
| Weighted     | Reparto por peso (canary, A/B)                           | 90/10 entre dos ALBs |
| Latency      | Enruta al endpoint con menor latencia desde el resolver  | multi-region active-active |
| Failover     | Primary/secondary con health check                       | DR activo-pasivo |
| Geolocation  | Según país/continente del resolver                       | sitios por región |
| Geoproximity | Según distancia geográfica + bias                        | solo con Route 53 Traffic Flow |
| Multivalue   | Hasta 8 valores sanos con health check (DNS round-robin+)| cheap LB |

**Clave**: Route 53 enruta **al resolver** (quien hizo la query), no al cliente final. Por eso latency routing puede fallar si el usuario usa un DNS público (8.8.8.8 vs un ISP local).

### 2.3 Resolver (hybrid DNS)

- **Inbound endpoint**: on-prem puede resolver nombres privados dentro de AWS.
- **Outbound endpoint + rules**: EC2 pueden resolver nombres del on-prem reenviando queries.

Se usa cuando una red corporativa necesita ver `svc.internal` de AWS y viceversa. Tiene costo horario por ENI.

---

## 3. ACM — Certificados TLS como servicio

ACM (**AWS Certificate Manager**) emite certificados **TLS/SSL públicos gratis** con rotación automática. Dos reglas duras:

1. **Validación DNS** es la vía recomendada. ACM te da un `CNAME` tipo `_x1y2.example.com → _z3w4.acm-validations.aws`. Lo creas en Route 53 (o en el DNS que tengas), y ACM comprueba cada tanto que sigue existiendo. Mientras exista, **ACM renueva solo**. Si lo borras, la próxima renovación falla silenciosamente (vigila CloudWatch/EventBridge).
2. **Región del certificado = región del servicio que lo usa**:
   - **CloudFront** solo acepta certificados ACM en **us-east-1** (porque CloudFront es un servicio global cuyo plano de control vive en us-east-1).
   - **ALB/NLB** necesitan el certificado en la **misma región** del load balancer.
   - **API Gateway edge-optimized**: us-east-1. Regional: su región.

**Private CA** es otro servicio (ACM PCA) para emitir certs internos de una PKI corporativa; **esto sí cuesta** (CA + por certificado emitido). No se usa para serving público típico.

**Validación DNS, paso a paso** (importante para la actividad 01):

1. Pides el cert para `www.example.com` + `example.com` (y `*.example.com` si quieres wildcard). Añade todos los SANs al mismo cert — no uses certs separados por SAN.
2. ACM te devuelve, para cada FQDN, un `name` y un `value` tipo CNAME.
3. Creas esos CNAME en Route 53 (si Route 53 ha emitido el certificado, puedes marcar la opción "crear registros automáticamente" en la consola; en Terraform usas `aws_route53_record`).
4. ACM pasa de **PENDING_VALIDATION** → **ISSUED** en segundos/minutos.
5. **Deja los CNAME vivos para siempre.** ACM los re-usa en renovaciones (cada 395 días por defecto).

---

## 4. CloudFront — CDN con cerebro

CloudFront es la red de edge locations de AWS (400+ POPs). Hace tres cosas:

1. **Terminación TLS en el edge** (usando tu cert ACM de us-east-1).
2. **Caché por `cache behavior`** según `path pattern` y configuración.
3. **Fetch al origin** (S3, ALB, EC2, HTTP arbitrario) cuando hay miss.

### 4.1 Distribución, orígenes y behaviors

Una **distribución** tiene:

- 1..N **orígenes** (S3 bucket, ALB, custom HTTP).
- 1..N **cache behaviors**. **Hay siempre un "default (*)"** y 0+ específicos por `path pattern`.
- 1 **viewer certificate** (ACM en us-east-1 + alias CNAMEs).
- Opcional: **WAF web ACL**, **geo restriction**, **logging**, **real-time logs**.

### 4.2 Cache behavior ordering — el gotcha central

El orden importa. CloudFront evalúa los behaviors **de arriba a abajo**, el primero que matchea gana. Así que si pones `*` arriba, todo se come. Si tienes:

```
/api/*       → origin ALB,  no cache,      forward all headers/cookies/qs
/static/*    → origin S3,   long cache,    minimize forwards
*            → origin S3,   long cache,    default
```

El orden correcto es de **más específico a menos específico**. En Terraform/API, "default_cache_behavior" es siempre el último lógico y los `ordered_cache_behavior` se evalúan **en el orden que los declaras**.

Un error típico es poner `*` como behavior específico "por si acaso" — eso rompe todos los demás.

### 4.3 Cache policy, Origin request policy, Response headers policy

Antes (pre-2020): toda la configuración de qué se cachea, qué se forwardea y qué headers de respuesta se añaden iba inline en el behavior. Hoy, AWS las separó en 3 **objetos reutilizables**:

- **Cache policy**: *qué forma parte de la cache key*. TTL mínimo/máximo/por defecto. Headers / query strings / cookies incluidos en la key. AWS ofrece managed: `CachingOptimized`, `CachingDisabled`, etc.
- **Origin request policy**: *qué se envía al origen* (aunque no forme parte de la key). Managed: `AllViewer`, `AllViewerExceptHostHeader`, `CORS-S3Origin`, etc.
- **Response headers policy**: *qué headers añade/modifica CloudFront* en la respuesta. Managed: `SecurityHeadersPolicy`, `CORS-With-Preflight`, etc.

**Clave operativa**: para un bucket S3 estático normal, usa `CachingOptimized` + `CORS-S3Origin` + `SecurityHeadersPolicy`. Para un `/api/*` dinámico sobre ALB, usa `CachingDisabled` + `AllViewer`. Y nada de inventar policies custom antes de haber agotado las managed.

### 4.4 OAC vs OAI (legacy)

Para que un bucket S3 **privado** sea servido por CloudFront sin ser público:

- **OAI** (legacy, Origin Access Identity): identidad IAM asociada a la distribución; añades un bucket policy que permite `s3:GetObject` solo a ese OAI. Funciona, pero **no soporta SigV4** para buckets en regiones nuevas (post-ap-east-1), no soporta cifrado KMS SSE-KMS bien, y AWS lo marca como legacy.
- **OAC** (Origin Access Control, 2022+): la distribución firma la petición con SigV4; el bucket tiene un policy que permite acceso **solo si el request viene con firma de esa distribución** (vía `aws:SourceArn`). Soporta todas las regiones, SSE-KMS, y es la vía recomendada.

**Siempre OAC** para nuevos diseños. OAI solo si mantienes un sitio viejo.

### 4.5 CloudFront Functions vs Lambda@Edge

Dos formas de ejecutar código en el edge:

| Dimensión          | CloudFront Functions                 | Lambda@Edge                              |
|--------------------|--------------------------------------|------------------------------------------|
| Runtime            | JavaScript limitado (sin red, sin fs)| Node.js / Python completo                |
| Latencia           | ~sub-ms (en POP, mismo proceso)      | ms (en región, no en POP)                |
| Uso típico         | redirects, header manipulation, A/B  | lógica compleja, auth, fetch a backends  |
| Triggers           | viewer-request, viewer-response      | viewer-req/resp **y** origin-req/resp    |
| Costo              | ~10x más barato por invocación       | precio Lambda normal                     |

Regla: **primero CF Functions**. Si no te alcanza, Lambda@Edge. Si Lambda@Edge no alcanza, replantea arquitectura (quizá el edge no es el lugar).

### 4.6 Signed URLs vs Signed Cookies

Para servir contenido privado (vídeos, PDFs, builds) por CloudFront:

- **Signed URL**: la URL incluye `?Policy=...&Signature=...&Key-Pair-Id=...`. Firma **un recurso específico**. Útil para descarga única, email, link temporal.
- **Signed Cookie**: pones 3 cookies en el navegador (`CloudFront-Policy`, `CloudFront-Signature`, `CloudFront-Key-Pair-Id`). Firma **un patrón** (`https://cdn.example.com/premium/*`). Útil para sesión de usuario autenticado con muchos recursos.

Ambos usan un **key group** asociado a la distribución (una o más claves públicas RSA/ECDSA; la privada la guardas y firmas tú con ella — nunca en AWS). Si usas Lambda, idealmente guardas la clave en **Secrets Manager** o **Parameter Store** cifrado.

### 4.7 HTTP/2 y HTTP/3 (QUIC)

CloudFront soporta HTTP/2 por defecto y permite habilitar HTTP/3 (QUIC/UDP) en la distribución. Beneficio real para móviles y redes con packet loss (handshake en 1-RTT, sin head-of-line blocking de TCP). Siempre activable, sin coste adicional.

---

## 5. Flujo end-to-end: usuario → CloudFront → origen

```
   Usuario escribe https://www.example.com/dashboard
        │
        ▼
   1. DNS: resolver pregunta a Route 53 (NS autoritativos de example.com)
        └─► Alias record `www.example.com → d123xyz.cloudfront.net`
                 (los Alias records son A/AAAA especiales que apuntan a servicios
                  AWS; sin TTL cobrado, resuelven al POP más cercano del usuario)
        │
        ▼
   2. TLS handshake con el POP CloudFront más cercano
        └─► CloudFront presenta el cert ACM de us-east-1 (SAN: www.example.com)
        │
        ▼
   3. CloudFront busca el request en caché:
        - path `/dashboard` → ¿qué cache behavior matchea?
            `/api/*` no       `/static/*` no       default `*` sí
        - default behavior: origin = ALB, cache policy = CachingDisabled
        - MISS siempre
        │
        ▼
   4. CloudFront hace el request al origen ALB:
        - headers reenviados según origin request policy
        - cert del ALB validado (ACM de la región del ALB)
        │
        ▼
   5. Origen responde; CloudFront aplica response headers policy
      (Strict-Transport-Security, X-Content-Type-Options, etc.)
      y devuelve al usuario.
```

Nota la **triple validación TLS**: usuario↔POP (cert ACM us-east-1), POP↔origen ALB (cert ACM región ALB), y si el ALB va a instancias HTTPS, un tercer salto más. Cada hop termina y re-origina TLS.

---

## 6. ¿Por qué us-east-1 para CloudFront?

Pregunta de pizarra que cae en entrevistas. Respuesta corta: **CloudFront es un servicio global**, y el plano de control (donde se almacena la asociación distribución → cert) vive en us-east-1. Cuando pides un cert para asociarlo a una distribución, CloudFront consulta ACM en us-east-1, no en la región donde tú estás trabajando. Si el cert está en eu-west-1, no lo encuentra, y la UI/API te lo niega.

Para **ALB en eu-west-1**, el cert debe estar en **eu-west-1** porque el plano de control del ALB es regional. Son dos planos distintos. Esto confunde a casi todo el mundo la primera vez.

---

## 7. Modelo de costos del edge (lo que importa)

- **Route 53 hosted zone pública**: **0.50 USD/mes por zona**, prorrateado. Es la trampa clásica: creas 20 zonas de prueba, las olvidas, al mes son 10 USD mensuales.
- **Route 53 queries**: ~0.40 USD por millón de queries (estándar). Alias records a servicios AWS **no cobran** la query interna.
- **Health checks**: 0.50 USD/mes por check básico; endpoints HTTPS/custom más caros.
- **ACM público**: **gratis**. ACM PCA: **sí cuesta** (CA mensual + por certificado emitido).
- **CloudFront**:
  - Transferencia saliente: tiered por región (más barato en América del Norte y Europa, más caro en India y Sudáfrica). Mucho menor que S3-to-Internet si hay volumen.
  - Requests HTTPS: ~0.012 USD por 10k requests (varía por región).
  - Invalidaciones: primeras 1000 paths/mes gratis, luego 0.005 USD cada una.
  - CloudFront Functions: ~0.10 USD por millón de invocaciones.
  - Lambda@Edge: precio Lambda normal + 0.60 USD por millón.
- **WAF**: ~5 USD/mes por web ACL + 1 USD/mes por regla + 0.60 USD por millón de requests inspeccionados.
- **AWS Shield Standard**: gratis para todos; **Shield Advanced**: 3000 USD/mes compromiso 1 año (negociable). Solo si realmente necesitas DDoS avanzado.

**Trampa típica para un lab**: dejar una hosted zone y 3 health checks activos. **Siempre destruye hosted zone + health checks al terminar.** CloudFront y ACM público no acumulan costo si no hay tráfico.

---

## 8. Diseño: cache behaviors para un sitio híbrido

Supón el capstone: HTML/CSS/JS estático en S3, API JSON en ALB, descargas privadas de PDFs en S3 con firma.

| Behavior order | Path pattern    | Origin             | Cache policy        | Origin request policy        | Comentario |
|----------------|-----------------|--------------------|---------------------|------------------------------|------------|
| 1              | `/api/*`        | ALB                | CachingDisabled     | AllViewer                    | API dinámica, no cachear |
| 2              | `/private/*`    | S3 (OAC)           | CachingOptimized    | CORS-S3Origin                | **Trust signer** activado → signed URLs/cookies |
| 3              | `/static/*`     | S3 (OAC)           | CachingOptimized    | CORS-S3Origin                | assets long-TTL con cache busting por hash |
| default `*`    | `*`             | S3 (OAC)           | CachingOptimized    | CORS-S3Origin                | SPA fallback (`index.html`) |

Si tu SPA necesita que `/foo/bar` devuelva `index.html` (client-side routing), añade un **CloudFront Function** que reescriba el URI en `viewer-request` cuando no termina en archivo con extensión. No necesitas Lambda@Edge.

---

## 9. Operaciones de borrado seguro

Para destruir todo al final de un ejercicio:

1. **Deshabilitar** la distribución CloudFront (toma 15-45 min en pasar a `Disabled`).
2. **Delete** distribución.
3. Delete key groups (si tenías signed URLs).
4. Delete records en Route 53 (alias a la distribución, CNAME de validación ACM si no quieres renovar nunca más).
5. Delete hosted zone (**si no la vas a reutilizar** — ojo con la delegación en la zona padre).
6. Delete ACM certificate (solo cuando ya no hay recursos asociados; la UI te lo bloquea si hay).
7. Delete bucket S3 (vaciarlo primero).

Para este módulo **no se destruye nada** porque no se levantó nada. Pero el *runbook* es parte del aprendizaje.

---

## 10. Resumen ejecutivo

- **Route 53** es DNS autoritativo gestionado. Modelo de costo pequeño pero **persistente** por zona (0.50 USD/mes).
- **ACM** público es gratis con validación DNS automática. **Región del cert = plano de control del servicio consumidor**. Para CloudFront, **us-east-1 siempre**.
- **CloudFront** tiene distribuciones con **múltiples orígenes** y **cache behaviors ordenados**. El orden es de más específico a menos. Usa cache/origin-request/response-headers policies **managed** salvo que haya razón para custom.
- **OAC** reemplaza OAI para S3 privados. Siempre OAC en nuevos diseños.
- **Signed URLs** para un recurso puntual; **signed cookies** para una sesión con muchos recursos.
- **CloudFront Functions** antes que Lambda@Edge. Lambda@Edge solo si hace falta origin-request o lógica compleja.
- **Costo**: zona Route 53 es el gasto predecible; CloudFront se paga por tráfico. Destruir recursos no usados es higiene.
- **Para esta academia no se levantan recursos reales** — todo se demuestra con `terraform plan`, JSON validado estructuralmente y walkthroughs escritos.
