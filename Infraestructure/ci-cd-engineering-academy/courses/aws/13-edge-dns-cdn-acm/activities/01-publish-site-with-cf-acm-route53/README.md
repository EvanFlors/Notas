# Actividad 01 — Publicar un sitio con CloudFront + ACM + Route 53

## 1. Identificación

- **ID:** `aws-13-01-publish-site-with-cf-acm-route53`
- **Tecnología:** `aws`
- **Módulo:** `aws-13-edge-dns-cdn-acm`
- **Dificultad:** advanced
- **Duración estimada:** 100–130 min
- **Tipo:** mini-project (independiente de la actividad 02)

## 2. Contexto

Tu capstone necesita salir al mundo con `https://www.example.com`. En este ejercicio produces los artefactos de diseño — **sin levantar nada** en AWS — que demuestran que sabrías hacerlo correctamente: la plantilla Terraform, un JSON de distribución CloudFront, un *walkthrough* del flujo de validación DNS de ACM, y un ADR que decide y justifica el orden de cache behaviors.

**No se aplica contra AWS.** No se requieren credenciales AWS, ni cuenta real, ni dinero. Si clonas los artefactos y los aplicaras, la factura sería ~0.50 USD/mes por la hosted zone de Route 53 (ver §5 "Costos reales si lo levantaras").

## 3. Objetivos

Al terminar deberías poder:

- Escribir una plantilla Terraform coherente para CloudFront + ACM (us-east-1) + Route 53.
- Producir un JSON "exportado" de la distribución que un validador estructural lea y acepte.
- Explicar el flujo de validación DNS de ACM: qué registros se crean, cuánto tardan, qué pasa en la renovación.
- Decidir el **orden de cache behaviors** para una mezcla `/api/*` + `/static/*` + `/private/*` + default, y justificarlo en un ADR corto.
- Enumerar el costo real (hosted zone 0.50 USD/mes) y defender la decisión de **no aplicar** en el laboratorio.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en especial §3, §4, §7).
- Haber recorrido los 3 ejemplos.
- Herramientas locales: `bash`, `jq` (para validar JSON), un editor Markdown. Opcionalmente `terraform` CLI si quieres correr `terraform validate` / `terraform fmt` localmente — no es obligatorio para pasar el validador.

**NO necesitas** credenciales AWS, ni cuenta, ni una conexión especial.

## 5. Costos reales si lo levantaras (contexto)

| Recurso | Coste |
|---------|-------|
| Hosted zone pública Route 53 | **0.50 USD/mes por zona** (prorrateado al día) |
| Queries DNS (alias a CloudFront) | 0 USD (alias interno) |
| ACM certificate público | **0 USD** (gratis, renovación automática) |
| Distribución CloudFront | **0 USD** si no hay tráfico |
| Bucket S3 vacío | ~0 USD |
| **Total si aplicaras y lo dejaras ocioso** | **~0.50 USD/mes** por la zona |

En esta actividad **no se aplica**. Es `plan` + JSON + documentos.

## 6. Instrucciones

### 6.1 Preparar directorio de trabajo

```bash
mkdir -p /tmp/aws-13-publish
cd /tmp/aws-13-publish
```

Si prefieres otra ruta, pásala al validador: `bash tests/validate.sh /tu/ruta`.

### 6.2 Artefactos a producir

Dentro de `/tmp/aws-13-publish/` debes crear exactamente estos ficheros:

1. **`main.tf`** — plantilla Terraform con, al menos:
   - Dos `provider "aws"` con `alias` distintos (`use1` para us-east-1 y la otra región elegida — p. ej. `euw1`).
   - Un `aws_s3_bucket` + `aws_s3_bucket_public_access_block` (todo `true`).
   - Un `aws_cloudfront_origin_access_control`.
   - Un `aws_acm_certificate` **con `provider = aws.use1`** (ACM en us-east-1 para CloudFront).
   - Un `aws_cloudfront_distribution` con:
     - `aliases` ≥ 1.
     - `viewer_certificate.acm_certificate_arn` apuntando al cert anterior.
     - `viewer_certificate.minimum_protocol_version = "TLSv1.2_2021"`.
     - Un `origin` con `origin_access_control_id` referenciando el OAC.
     - `default_cache_behavior` con `viewer_protocol_policy = "redirect-to-https"`.
   - Un `aws_route53_zone` y un `aws_route53_record` **alias** apuntando a la distribución.

2. **`distribution.json`** — un JSON **sintético** representando la distribución (como si lo hubieras exportado con `aws cloudfront get-distribution`). No se verifica semántica; sí se verifica estructura:
   - Clave raíz `DistributionConfig`.
   - `DistributionConfig.Aliases.Items` lista con ≥ 1 elemento.
   - `DistributionConfig.Origins.Items[0].OriginAccessControlId` es string no vacío.
   - `DistributionConfig.DefaultCacheBehavior.ViewerProtocolPolicy == "redirect-to-https"`.
   - `DistributionConfig.ViewerCertificate.ACMCertificateArn` empieza por `arn:aws:acm:us-east-1:`.
   - `DistributionConfig.ViewerCertificate.MinimumProtocolVersion` contiene `TLSv1.2` (o superior).

3. **`ACM_DNS_WALKTHROUGH.md`** — explicación del flujo de validación DNS de ACM:
   - Al menos 5 pasos numerados.
   - Debe mencionar `CNAME`, `PENDING_VALIDATION`, `ISSUED`, "renovación automática" (o "renovacion automatica").
   - Debe explicar por qué **no** se borran los CNAME de validación tras emitirse el cert.

4. **`CACHE_ORDER_ADR.md`** — ADR corto (patrón "Context / Decision / Consequences") decidiendo el orden de cache behaviors para:
   - `/api/*` (dinámico, no cachear)
   - `/private/*` (firmado)
   - `/static/*` (estático long-TTL)
   - default `*` (SPA fallback)
   El ADR debe:
   - Tener las tres secciones (`Context`, `Decision`, `Consequences`), insensible a mayúsculas.
   - Listar los 4 patrones.
   - Justificar por qué el orden va de **más específico a menos específico** y qué pasaría si pones `*` arriba.

5. **`COSTS.md`** — nota breve que:
   - Mencione la cifra **0.50 USD/mes** por hosted zone.
   - Explique por qué ACM público es gratis.
   - Declare explícitamente "NO se aplica" / "no se aplica" (texto literal).

### 6.3 Validar

```bash
bash <ruta-repo>/courses/aws/13-edge-dns-cdn-acm/activities/01-publish-site-with-cf-acm-route53/tests/validate.sh /tmp/aws-13-publish
```

Pasa cuando ves `OK: estructura valida`.

### 6.4 Comparar con la referencia

Lee `solution/REFERENCE.md`. Compara tus decisiones. El validador no juzga semántica.

## 7. Resultado esperado

- Cinco ficheros creados en `/tmp/aws-13-publish/`.
- Validador en verde.
- Tu `main.tf` compila (si tienes Terraform instalado, `terraform fmt && terraform validate` ejecutándolo en ese directorio sin un `terraform init -backend=false` previo fallará; con el `init -backend=false` debería estar bien — opcional).

## 8. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: el ADR nombra el gotcha de ordering (`*` arriba se come todo).
- **Reproducibilidad**: cualquiera que lea tus artefactos puede diseñar el mismo stack.
- **Seguridad / costo**: la nota de costos es explícita; nada se aplicó.

## 9. Validación

```bash
bash tests/validate.sh /tmp/aws-13-publish
```

## 10. Preguntas de reflexión

1. Si olvidas el `provider = aws.use1` en `aws_acm_certificate`, ¿qué pasa cuando CloudFront intenta usar el cert?
2. ¿Por qué los alias records de Route 53 que apuntan a CloudFront no cobran por query?
3. Si pones `/api/*` **después** del `*` en el `ordered_cache_behavior`, ¿qué comportamiento real verá un `curl /api/users`?
4. ¿Qué pasa si borras los CNAME de validación de ACM una vez el cert está `ISSUED`?
5. Si quisieras servir también `example.com` (apex) con CloudFront, ¿qué dos cosas tendrías que ajustar (SAN del cert, alias record)?

## 11. Extensiones

- Añade un segundo origen (ALB) y un `ordered_cache_behavior` para `/api/*` con `CachingDisabled` y `AllViewer`.
- Añade un `aws_cloudfront_response_headers_policy` custom con un HSTS más estricto.
- Añade un `aws_cloudfront_function` para SPA fallback y referencia su asociación en el `default_cache_behavior`.

## 12. Limpieza

Como **nada** se aplicó contra AWS:

```bash
rm -rf /tmp/aws-13-publish
```

No hay recursos AWS que destruir, no hay facturas que vigilar.
