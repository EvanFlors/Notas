# REFERENCE — aws-13-02-add-waf-and-geo-restriction

> Una referencia razonada. Tu diseño puede diferir — compara criterios, no palabras.

## Sección 1 — Reglas

Diseño propuesto (web ACL con 4 reglas, prioridades de menor a mayor número evaluadas primero):

1. **AWSManagedRulesAmazonIpReputationList** (managed, prioridad 10, acción `Block`). Bloquea IPs con mala reputación conocida por AWS. Es casi gratis en falsos positivos y filtra ruido masivo antes de llegar a las reglas más caras.
2. **AWSManagedRulesCommonRuleSet** (managed, prioridad 20, acción `Block`). OWASP top 10 básico: XSS, SQLi genérico, path traversal. Es la línea de defensa estándar frente a scanners automáticos.
3. **Rate-based rule por IP** (rate-based, prioridad 30, acción `Block`, umbral 2000 req / 5 min). Mata ataques L7 básicos (scraping, brute force de login). Granularidad por IP — ver limitaciones.
4. **GeoMatch allowlist** (geo, prioridad 40, acción `Block` para países fuera de UE+LATAM+US+CA). Marketing solo opera en estos mercados; bloquear el resto reduce superficie de ataque.

Opcional 5ª: `SizeConstraintStatement` sobre `/login` para bloquear POSTs > 1 KB (defensa contra credential stuffing con payloads inflados).

## Sección 2 — Decisión Geo (CloudFront nativa vs WAF)

**Trade-offs**:

- **CloudFront `geo_restriction`** se evalúa **antes** que WAF, es **gratis**, y es trivial de operar (whitelist/blacklist de países). Pero es un bloqueo *all-or-nothing* por país; no se puede combinar con "salvo si viene header X".
- **WAF `GeoMatchStatement`** cuesta (1 USD/mes por regla + 0.60 USD/millón de requests inspeccionados), pero se puede combinar con `AndStatement`, `NotStatement`, etc. — por ejemplo, "bloquea X país **salvo si** `x-internal-token` == <esperado>".

**Decisión**: usar **CloudFront `geo_restriction` allowlist** como primera línea (gratis, rápido) y añadir **GeoMatch en WAF solo si** aparece el requisito de bypass condicional. Mientras tanto, duplicar la lógica en ambos sitios es desperdicio.

## Sección 3 — Costos (USD/mes)

| Concepto | USD/mes |
|----------|---------|
| Web ACL base | ~5 USD |
| 4 reglas × 1 USD | ~4 USD |
| Inspección (10M req × 0.60 / M) | ~6 USD |
| Shield Standard | 0 (incluido) |
| CloudFront `geo_restriction` | 0 |
| **Total aproximado (10M req/mes)** | **~15 USD/mes** |

Si el tráfico sube a 100M req/mes → ~69 USD/mes (dominan las inspecciones). WAF escala caro con tráfico; vale la pena asegurarse de que las reglas filtren rápido para que las caras no lleguen a evaluarse (prioridades correctas).

## Sección 4 — Limitaciones (cuándo WAF NO es la respuesta)

1. **Bugs de lógica de negocio**: una ruta `/transfer/{id}` sin check de ownership se explota con un request perfectamente válido. WAF no sabe nada de tu modelo de permisos.
2. **Rate limit por usuario autenticado**: WAF granula por IP; usuarios detrás de un NAT compartido comparten contador. Usa Cognito, API Gateway usage plans o un rate limit a nivel de app.
3. **DDoS volumétrico L3/L4** (SYN flood, UDP amplification): eso es Shield Standard (automático) o Shield Advanced si pasa cierto umbral — no WAF.
4. **SQL injection cuando la app usa ORM parametrizado**: la regla managed es defensa en profundidad, pero no es la primera línea; la primera es el código.
5. **Autenticación y autorización**: WAF no implementa OAuth2/OIDC; eso es Cognito, Auth0, IdC. Confundir "WAF bloquea requests no autenticados" es error típico; WAF puede ver si falta un header, no si el token es válido.
6. **Rate limit muy fino (ej. 5 req/seg por usuario autenticado)**: granularidad mínima de WAF rate-based es de 5 min (2000 req es el umbral mínimo). Para rate limit fino usa API Gateway o un sidecar.

## Observabilidad (extensión)

Métricas CloudWatch por regla: `AllowedRequests`, `BlockedRequests`, `CountedRequests`. Antes de poner una regla nueva en `Block`, pásala por `Count` 1-2 semanas para medir falsos positivos.
