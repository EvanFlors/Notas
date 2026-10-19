# Actividad 02 — Diseño de WAF + decisión geo restriction para CloudFront

## 1. Identificación

- **ID:** `aws-13-02-add-waf-and-geo-restriction`
- **Tecnología:** `aws`
- **Módulo:** `aws-13-edge-dns-cdn-acm`
- **Dificultad:** advanced
- **Duración estimada:** 50–70 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Marketing avisa que el *landing* del capstone va a lanzarse en Europa y LATAM, pero el *dashboard* interno solo debe ser accesible desde la red corporativa (geo + CIDR). Simultáneamente, Security quiere al menos las reglas managed de AWS activas frente a OWASP top 10. Debes **diseñar** la **web ACL** y decidir si la restricción geográfica va en WAF o en CloudFront nativo.

Esta actividad es **100 % escrita**. No se levanta nada. No hay credenciales AWS, no hay coste real. El entregable es un documento Markdown.

## 3. Objetivos

Al terminar deberías poder:

- Elegir un conjunto de reglas WAF razonadas (al menos 3) y defender cada una.
- Decidir entre **geo restriction** de CloudFront y **GeoMatchStatement** en WAF, con trade-offs claros.
- Dimensionar el **costo mensual** aproximado de la solución (WAF ACL + reglas + inspecciones).
- Enumerar **cuándo WAF NO es la respuesta** (bugs de app-layer, lógica de negocio, rate limit muy fino, etc.).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (especialmente §4 y §7).
- Herramientas: `bash` + un editor Markdown.

**No** necesitas: credenciales AWS, cuenta AWS, Terraform.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/aws-13-waf
cd /tmp/aws-13-waf
```

### 5.2 Escribe `WAF_DESIGN.md` con cuatro secciones

#### Sección 1 — Reglas

Diseña una web ACL con **al menos 3 reglas numeradas**. Para cada regla:

- Nombre.
- Tipo (managed group, rate-based, geo match, size constraint, byte match, scope-down statement, etc.).
- Acción (`Allow`, `Block`, `Count`).
- Prioridad.
- Justificación en 1-3 líneas.

Ejemplos de reglas que **vale la pena** considerar: `AWS-AWSManagedRulesCommonRuleSet`, `AWS-AWSManagedRulesAmazonIpReputationList`, `AWS-AWSManagedRulesKnownBadInputsRuleSet`, rate-based (ej. 2000 req/5min por IP), geo match (whitelist UE+LATAM), size constraint para evitar POSTs enormes al login.

Reglas: menciona explícitamente al menos uno de los siguientes términos: `managed`, `rate`, `geo`.

#### Sección 2 — Decisión Geo (CloudFront nativa vs WAF)

Decide dónde pones la restricción geográfica y defiende:

- **CloudFront `restrictions.geo_restriction`**: whitelist o blacklist de países a nivel de distribución. Gratis. Ataca antes que WAF.
- **WAF `GeoMatchStatement`**: regla dentro de la web ACL. Cuesta por regla y por request inspeccionado, pero permite combinar con otras condiciones (ej. "bloquea X país salvo si viene con header interno Y").

Debes mencionar la palabra `CloudFront` y la palabra `WAF`, enumerar al menos **2 trade-offs** y tomar una decisión con "Decision" o "Decisión".

#### Sección 3 — Costos (orden de magnitud, en USD/mes)

Lista aproximada:

- Web ACL: ~5 USD/mes.
- Por regla: ~1 USD/mes.
- Por millón de requests inspeccionados: ~0.60 USD.
- Shield Standard: incluido (gratis).
- Geo restriction CloudFront: gratis.

Añade un **total estimado** para tu diseño (ej. "~15 USD/mes para 3 reglas + 10M requests").

Debe aparecer explícitamente `USD` y las cifras `5` y `0.60` (o equivalentes `~5`, `0,60`).

#### Sección 4 — Limitaciones (cuándo WAF NO es la respuesta)

Enumera al menos **5 escenarios numerados** donde WAF **no** resuelve el problema. Ejemplos:

- Bug de lógica de negocio (p. ej. una ruta `/transfer` sin check de ownership).
- Rate limit muy fino por usuario (WAF solo granula por IP; usa Cognito/API quotas).
- DDoS volumétrico L3/L4 (es Shield, no WAF).
- SQL injection si tu app usa un ORM parametrizado — redundante.
- Autenticación / autorización (eso es Cognito/IAM, no WAF).

### 5.3 Entregable

Un fichero:

```
/tmp/aws-13-waf/WAF_DESIGN.md
```

con las 4 secciones.

### 5.4 Validar

```bash
bash <ruta-repo>/courses/aws/13-edge-dns-cdn-acm/activities/02-add-waf-and-geo-restriction/tests/validate.sh /tmp/aws-13-waf
```

## 6. Resultado esperado

- `WAF_DESIGN.md` existe y pasa la validación estructural.
- Tus decisiones son defendibles contra `solution/REFERENCE.md`.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: la decisión geo cita trade-offs concretos (coste, flexibilidad, orden de evaluación).
- **Realismo**: el costo total está en el orden correcto (decenas de USD/mes).

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-13-waf
```

## 9. Preguntas de reflexión

1. Si tienes una regla WAF "block country X" y además `geo_restriction` en CloudFront que whitelistea países, ¿cuál se evalúa antes? ¿Qué pasa si entran en conflicto?
2. ¿En qué caso tiene sentido pagar Shield Advanced (3000 USD/mes compromiso 1 año)?
3. Rate-based rule de WAF agrupa por IP. ¿Qué pasa con usuarios detrás de un NAT corporativo compartido?
4. ¿Qué visibilidad te da `Action = Count` en una regla WAF y cuándo lo prefieres antes de `Block`?
5. Si tu app está detrás de API Gateway + Lambda, ¿tiene sentido WAF en API Gateway en lugar de en CloudFront? ¿O ambos?

## 10. Extensiones

- Añade una **5ª regla**: scope-down statement que exima a tu propio ASN de la regla de rate limit (para que CI no te bloquee).
- Añade un apartado "Observabilidad" con qué métricas CloudWatch mirar (`AllowedRequests`, `BlockedRequests`, `CountedRequests` por regla).

## 11. Limpieza

Como es puramente conceptual:

```bash
rm -rf /tmp/aws-13-waf
```

No hay nada que destruir en AWS.
