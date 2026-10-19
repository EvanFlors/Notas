# Starter — az-06-02-cert-auto-renewal

Esta actividad es **independiente**: produces 1 JSON + 1 HCL + 1 Markdown.

## Pasos

1. Lee `../README.md` completo y `../../theory/lesson.md` §8.
2. Prepara el directorio:

   ```bash
   mkdir -p /tmp/az-06-02
   cd /tmp/az-06-02
   ```

3. Escribe los 3 archivos (nombres exactos):
   - `certificate-policy.json`
   - `main.tf`
   - `README-INTENT.md`

4. Verifica el JSON:

   ```bash
   jq . certificate-policy.json >/dev/null && echo OK
   ```

5. Valida:

   ```bash
   bash <ruta-repo>/courses/azure/06-key-vault-and-managed-identities-consumer/activities/02-cert-auto-renewal/tests/validate.sh /tmp/az-06-02
   ```

6. Compara con `../solution/REFERENCE.md`.

## Esqueleto útil para la policy

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

## Esqueleto útil para HCL

```hcl
resource "azurerm_key_vault_certificate" "tls" {
  name         = "cert-capstone-tls"
  key_vault_id = azurerm_key_vault.main.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = false
    }

    lifetime_action {
      action { action_type = "AutoRenew" }
      trigger { days_before_expiry = 30 }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      key_usage = ["digitalSignature", "keyEncipherment"]
      subject   = "CN=capstone.example.com"

      subject_alternative_names {
        dns_names = ["capstone.example.com"]
      }

      validity_in_months = 12
    }
  }
}
```
