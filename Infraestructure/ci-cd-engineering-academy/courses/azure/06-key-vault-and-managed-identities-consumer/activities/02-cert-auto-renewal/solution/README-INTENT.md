# README-INTENT — Certificate con auto-renewal en Key Vault

> Documento de intención: qué define la certificate policy, por qué los valores elegidos y qué cambia entre dev y prod.

## Resumen

Un **certificate** TLS gestionado por Azure Key Vault para el endpoint HTTPS del capstone. Issuer `Self` (self-signed) en dev, renovación automática 30 días antes del expiry, clave RSA 2048, SAN para `capstone.example.com` y su subdominio `www`.

| Elemento | Valor | Nota |
|----------|-------|------|
| Nombre lógico | `cert-capstone-tls` | estable; versiones nuevas al renovar |
| Issuer | `Self` | en prod → `DigiCert` o `GlobalSign` |
| Algoritmo | RSA 2048 | mínimo recomendado hoy |
| Validez | 12 meses | típico para certs públicos |
| Auto-renewal | sí, 30 días antes | con 1 año de validez da margen holgado |
| Content type | `application/x-pkcs12` | PFX, lo que consumen App Gateway / Front Door |

---

## certificate-policy

### Qué define cada bloque

- **`issuerParameters`**: quién firma. `Self` = Key Vault firma a sí mismo (válido solo para dev / internal mTLS). `DigiCert`/`GlobalSign` requieren un `azurerm_key_vault_certificate_issuer` previo con credenciales. `Unknown` para issuers externos manuales (haces el CSR fuera, importas la cadena).
- **`keyProperties`**: material criptográfico. `keyType = "RSA"` + `keySize = 2048` es el mínimo moderno; `3072`/`4096` para prod regulado. `exportable = true` deja descargar la clave privada — útil en dev; en prod `false` para que el cert viva solo dentro de App Gateway/Front Door/Container Apps (que lo consumen por referencia, no por export).
- **`lifetimeActions`**: array de pares `(trigger, action)`. Aquí usamos `AutoRenew` + `daysBeforeExpiry`. Alternativa: `EmailContacts` (solo notifica, no renueva).
- **`secretProperties.contentType`**: el *secret counterpart* del certificate. `application/x-pkcs12` para PFX (más universal), `application/x-pem-file` para PEM. App Gateway consume PFX nativamente.
- **`x509CertificateProperties`**: metadata X.509 estándar. `subject` con `CN=`, `subjectAlternativeNames.dnsNames` con los FQDN que el cert cubre (browsers modernos ignoran `CN`, usan SAN), `keyUsage` con `digitalSignature` + `keyEncipherment` (lo que necesita un TLS server), `validityInMonths` 12.

### Por qué `exportable = true` en dev

En dev queremos poder descargar el PFX, inspeccionarlo con `openssl pkcs12`, importarlo en nuestro navegador, montarlo en un sidecar nginx local. En prod `exportable = false` cierra ese vector: el cert nunca puede salir del vault, los consumers (App Gateway, Front Door) lo leen por referencia API.

---

## auto-renewal

### Por qué `AutoRenew` con `daysBeforeExpiry = 30`

- **30 días** es el estándar para certs anuales. Da margen para que:
  - el issuer responda (algunos CAs tardan horas en dev, minutos en prod);
  - cualquier fallo (credenciales caducadas, dominio reclamado) sea notado y resuelto antes del expiry real;
  - los consumers recojan la versión nueva al próximo deploy (si no leen por referencia dinámica).
- **1 día** sería irresponsable: un fin de semana largo con la CA caída → outage.
- **90 días** sería desperdicio: el cert habría tenido potencial de uso 60 días más.

### Qué pasa si el issuer no responde a tiempo

Para `Self` nunca pasa — Key Vault firma localmente. Para issuers integrados, Key Vault reintenta durante los 30 días. Si falla al llegar al expiry, el cert vence y hay outage TLS. Mitigación: alertas en `Microsoft.KeyVault.CertificateNearExpiry` via Event Grid (fuera del scope de esta actividad).

### Qué consume el cert renovado

El cert se identifica por **nombre**, no por versión. Consumers típicos:

- `azurerm_application_gateway.ssl_certificate { key_vault_secret_id = azurerm_key_vault_certificate.tls.secret_id }`.
- `azurerm_cdn_frontdoor_secret` (Front Door Standard/Premium) referenciando el mismo cert.
- `azurerm_container_app` con `ingress.custom_domain.certificate_id = ...`.

Al renovar, el nombre no cambia → los consumers recogen la versión nueva automáticamente (en el próximo poll del AppGw, ~4 h).

---

## issuer-strategy

### Por qué `Self` en dev

- Sin CA externa que configurar, sin facturación, sin verificación de dominio.
- Suficiente para probar el *plumbing* completo (vault → consumer → navegador con warning aceptable).
- Permite iterar en el HCL sin esperar propagación DNS ni validaciones ACME.

### Cuándo migrar a `DigiCert` / `GlobalSign`

Cuando el workload tenga un dominio público real y usuarios externos. El flujo en prod:

1. Crear cuenta con la CA (fuera de Azure).
2. Crear `azurerm_key_vault_certificate_issuer` con las credenciales de la cuenta (`org_id`, `account_id`, API key).
3. **Las credenciales viven en otro `azurerm_key_vault_secret`**, leído por la Managed Identity del tooling, nunca commiteadas al HCL.
4. Cambiar `issuerParameters.name` de `"Self"` a `"DigiCert"` (o el nombre del issuer).
5. Validar el dominio una vez (DNS o HTTP challenge, dependiendo del CA); las renovaciones posteriores son automáticas mientras la validación siga vigente.

### Managed Identity para el consumer

El workload que **consume** el cert (App Gateway, Front Door, Container App) lee la versión actual del cert con su **Managed Identity**, de la misma forma que leería un secret: con el rol built-in **Key Vault Certificate User** (data-plane) sobre el scope del vault. Para App Gateway concretamente, basta con **Key Vault Secrets User** porque el cert se expone por su `secret_id` (es el PFX bajo el capó).

El código de la app **nunca** manipula el PFX: lo hace el servicio Azure que termina TLS.

---

## Rollout

1. Fase 4 aplica `main.tf` → se crea `kv-capstone-dev` y `cert-capstone-tls` con una versión inicial self-signed de 12 meses.
2. 335 días después, Key Vault emite la renovación local y crea la versión 2.
3. 11 meses después se repite. Sin acción humana en dev.
4. Al migrar a prod: cambiar `issuer_parameters.name` y añadir el `azurerm_key_vault_certificate_issuer`; la primera renovación tras el cambio irá al CA real.
