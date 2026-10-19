# Actividad 02 — Certificate policy con auto-renewal en Key Vault

## 1. Identificación

- **ID:** `az-06-02-cert-auto-renewal`
- **Tecnología:** `azure`
- **Módulo:** `az-06-key-vault-and-managed-identities-consumer`
- **Dificultad:** intermediate
- **Duración estimada:** 55–65 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

El capstone necesita un **certificado TLS** para su endpoint HTTPS. Decides emitirlo y gestionarlo desde **Azure Key Vault** con **auto-renewal**. En dev usas issuer `Self` (self-signed) para no depender de una CA externa; en prod se migraría a un issuer integrado (`DigiCert`, `GlobalSign`).

El entregable son:

- Un **`certificate-policy.json`** válido que describe algoritmo, uso, subject, SANs y la **lifetime action** de auto-renewal.
- Un **`main.tf`** `plan-ready` con `azurerm_key_vault_certificate` que referencia esa policy en línea.
- Un **`README-INTENT.md`** justificando las decisiones.

**Importante**:

- **No hay suscripción Azure** y no la hace falta.
- **No uses CA real** ni dominios de propiedad de terceros. El SAN `capstone.example.com` es placeholder; `example.com` está reservado por IANA para documentación.
- **No llames al documento `ANALYSIS.md`** — otros validadores del repo tratan ese nombre con convenciones especiales. Usa **`README-INTENT.md`**.

## 3. Objetivos

Al terminar deberías poder:

- Escribir una `certificate_policy` JSON de Key Vault con los 5 bloques: `issuerParameters`, `keyProperties`, `lifetimeActions`, `secretProperties`, `x509CertificateProperties`.
- Configurar `AutoRenew` con `daysBeforeExpiry = 30`.
- Mapear la misma policy a HCL dentro de `azurerm_key_vault_certificate`.
- Justificar por escrito por qué `Self` en dev y por qué `30` días.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§8).
- Herramientas: `bash`, `jq`, editor de texto.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/az-06-02
cd /tmp/az-06-02
```

### 5.2 Escribe `certificate-policy.json`

JSON válido con esta estructura (ajusta valores a tu criterio dentro de los requisitos):

```json
{
  "issuerParameters": { "name": "Self" },
  "keyProperties": {
    "exportable": true,
    "keySize": 2048,
    "keyType": "RSA",
    "reuseKey": false
  },
  "lifetimeActions": [
    {
      "action": { "actionType": "AutoRenew" },
      "trigger": { "daysBeforeExpiry": 30 }
    }
  ],
  "secretProperties": { "contentType": "application/x-pkcs12" },
  "x509CertificateProperties": {
    "keyUsage": ["digitalSignature", "keyEncipherment"],
    "subject": "CN=capstone.example.com",
    "subjectAlternativeNames": {
      "dnsNames": ["capstone.example.com"]
    },
    "validityInMonths": 12
  }
}
```

Requisitos **mínimos** que el validador comprueba:

- JSON válido.
- `issuerParameters.name` existe (`"Self"` o un issuer integrado).
- `keyProperties.keyType == "RSA"` y `keyProperties.keySize >= 2048`.
- `lifetimeActions` array con al menos un elemento donde `action.actionType == "AutoRenew"` y `trigger.daysBeforeExpiry` sea un entero entre 1 y 365.
- `x509CertificateProperties.subject` empieza por `"CN="`.
- `x509CertificateProperties.subjectAlternativeNames.dnsNames` tiene al menos 1 entrada.
- `x509CertificateProperties.validityInMonths` presente (12 recomendado).

### 5.3 Escribe `main.tf`

Terraform `plan-ready` con `azurerm_key_vault_certificate`. Debe:

- Declarar `provider "azurerm" { features {} }`.
- Declarar `azurerm_resource_group`.
- Declarar `azurerm_key_vault` (puedes copiar el patrón de la actividad 01: `enable_rbac_authorization = true`, `soft_delete_retention_days = 7`, `purge_protection_enabled = false`).
- Declarar `azurerm_key_vault_certificate` con `certificate_policy` block que replique la policy JSON (`issuer_parameters`, `key_properties`, `lifetime_action`, `secret_properties`, `x509_certificate_properties`).

### 5.4 Escribe `README-INTENT.md`

Secciones obligatorias (el validador las busca):

- `## certificate-policy` — qué define cada bloque; por qué `RSA 2048`; por qué `exportable = true` (dev) o `false` (prod).
- `## auto-renewal` — por qué `AutoRenew` con `daysBeforeExpiry = 30`; qué pasa si el issuer no responde a tiempo; qué consume el cert renovado (App Gateway, Front Door, Container Apps).
- `## issuer-strategy` — por qué `Self` en dev; cuándo migrar a `DigiCert`/`GlobalSign`; cómo se configuran credenciales del issuer en prod sin commitearlas.

Debes mencionar explícitamente:

- La palabra **certificate**.
- La palabra **AutoRenew** o **auto-renewal**.
- Un issuer integrado por nombre (**DigiCert** o **GlobalSign**).
- La palabra **Managed Identity** (describiendo que el workload consumirá el cert con MI, igual que un secret).

### 5.5 Entregables

```
/tmp/az-06-02/
├── certificate-policy.json
├── main.tf
└── README-INTENT.md
```

## 6. Resultado esperado

- `jq . certificate-policy.json` imprime JSON válido.
- `bash tests/validate.sh /tmp/az-06-02` termina con `0 issue(s)`.

## 7. Criterios de aceptación

- **Funcionalidad**: validador pasa en verde.
- **Correctitud sintáctica**: JSON válido, HCL parseable.
- **Correctitud conceptual** (autoevaluación): comparar con `solution/REFERENCE.md`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/az-06-02
```

El validador comprueba estructura JSON + presencia de bloques HCL + secciones del README. **No** comprueba que una renovación real ocurra contra una CA real.

## 9. Preguntas de reflexión

1. ¿Qué pasa si pones `daysBeforeExpiry = 1` en lugar de `30`?
2. En prod con `DigiCert`, ¿dónde viven las credenciales del issuer y cómo las lees? (pista: otro Key Vault secret + MI).
3. ¿Por qué el cert tiene también un *secret counterpart*? ¿Qué contiene?
4. Si el consumer es un `azurerm_application_gateway`, ¿cómo se le pasa el cert sin descargarlo? (pista: `ssl_certificate { key_vault_secret_id = ... }` + MI del AppGw con `Key Vault Certificate User`).
5. ¿Por qué `example.com` como SAN de documentación en lugar de tu dominio real?

## 10. Extensiones

- Añade un `azurerm_key_vault_certificate_issuer` con credenciales ficticias (`org_id = "DUMMY"`, `account_id = "DUMMY"`) para practicar la estructura.
- Añade un segundo cert con `validityInMonths = 3` y `daysBeforeExpiry = 7` — típico para certs de uso corto.
- Documenta la rotación manual: `az keyvault certificate update --name <> --vault-name <>`.

## 11. Limpieza

```bash
rm -rf /tmp/az-06-02
```

No hay infraestructura que detener.
