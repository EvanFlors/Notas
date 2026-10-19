# REFERENCE — Solución de referencia

> Autoevaluación. Compara tu entrega con los archivos adyacentes.

## Entregables

| Archivo | Qué debe contener |
|---------|-------------------|
| `main.tf` | RG + MI User-Assigned + Key Vault con RBAC + role assignment + secret dummy |
| `variables.tf` | `location`, `resource_group_name`, `key_vault_name`, `identity_name` |
| `role-assignment-kv-secrets-user.json` | JSON con `principalId`, `principalType=ServicePrincipal`, `roleDefinitionId` terminando en el GUID de **Key Vault Secrets User**, `scope` apuntando al vault |
| `README-INTENT.md` | 3 secciones (`key-vault`, `managed-identity`, `role-assignment`) con decisiones justificadas |

## Checklist de autoevaluación

- [ ] `main.tf` usa `enable_rbac_authorization = true` y no tiene ningún `access_policy` block.
- [ ] El `azurerm_role_assignment` referencia `principal_id` (NO `client_id`) de la MI.
- [ ] El `scope` del role assignment es `azurerm_key_vault.<name>.id` y no `azurerm_resource_group.<name>.id`.
- [ ] El `azurerm_key_vault_secret.value` es un dummy, no una contraseña plausible.
- [ ] El JSON incluye el GUID `4633458b-17de-408a-b874-0445c86b69e6` al final del `roleDefinitionId`.
- [ ] El JSON tiene `principalType = "ServicePrincipal"`.
- [ ] El `README-INTENT.md` menciona explícitamente **RBAC data-plane**, **Managed Identity** y **Key Vault Secrets User**.

## Errores comunes

1. **Dejar `access_policy` block coexistiendo con `enable_rbac_authorization = true`**: el block se ignora silenciosamente. Confuso en code review.
2. **Scope al RG**: concede el rol a vaults futuros sin revisión.
3. **`principal_id = ...client_id`**: Terraform acepta, runtime rechaza con `Forbidden`.
4. **Valor del secret parece real**: cualquier cosa que no sea el placeholder genera alarma.
5. **`purge_protection_enabled = true` en dev**: `terraform destroy` falla.
6. **README-INTENT con un único bloque de texto y ninguna sección**: validador falla por no encontrar `## key-vault`, etc.
