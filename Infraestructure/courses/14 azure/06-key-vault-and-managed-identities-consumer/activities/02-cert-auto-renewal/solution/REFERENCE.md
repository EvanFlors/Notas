# REFERENCE — Solución de referencia (cert auto-renewal)

## Entregables

| Archivo | Qué debe contener |
|---------|-------------------|
| `certificate-policy.json` | Policy JSON con `issuerParameters`, `keyProperties`, `lifetimeActions` (AutoRenew/30), `secretProperties`, `x509CertificateProperties` |
| `main.tf` | RG + Key Vault + `azurerm_key_vault_certificate` con `certificate_policy` block equivalente |
| `README-INTENT.md` | 3 secciones (`certificate-policy`, `auto-renewal`, `issuer-strategy`) justificando las decisiones |

## Checklist

- [ ] `certificate-policy.json` parsea con `jq .`.
- [ ] `lifetimeActions[0].action.actionType == "AutoRenew"`.
- [ ] `lifetimeActions[0].trigger.daysBeforeExpiry` entre 1 y 365.
- [ ] `keyProperties.keyType == "RSA"` y `keyProperties.keySize >= 2048`.
- [ ] `x509CertificateProperties.subject` empieza por `CN=`.
- [ ] `x509CertificateProperties.subjectAlternativeNames.dnsNames` tiene ≥ 1 entrada.
- [ ] `main.tf` tiene `resource "azurerm_key_vault_certificate"` con `certificate_policy` block.
- [ ] `main.tf` tiene `lifetime_action` + `action_type = "AutoRenew"` + `days_before_expiry` numérico.
- [ ] `README-INTENT.md` menciona `AutoRenew`/`auto-renewal`, un issuer integrado (DigiCert o GlobalSign), y `Managed Identity`.

## Errores comunes

1. **`daysBeforeExpiry` como string** (`"30"` en vez de `30`): el schema espera entero.
2. **`keySize = 1024`**: inseguro, el validador rechaza.
3. **Olvidar SAN**: browsers modernos requieren SAN, `CN` solo ya no basta.
4. **Issuer `"self"` en minúscula**: Key Vault espera `"Self"` capitalizado.
5. **No reproducir la policy en HCL**: el JSON va al vault pero el `azurerm_key_vault_certificate` debe tener el `certificate_policy` block equivalente para que Terraform pueda crearlo.
