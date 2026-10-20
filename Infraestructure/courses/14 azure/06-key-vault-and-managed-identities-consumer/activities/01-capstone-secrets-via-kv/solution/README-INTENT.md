# README-INTENT — Key Vault + Managed Identity para el capstone

> Documento de intención: qué recursos se declaran, por qué, y qué decisiones se tomaron. El HCL vive en `main.tf` + `variables.tf`; el role assignment materializado vive en `role-assignment-kv-secrets-user.json`.

## Resumen

Diseño mínimo para que el capstone (`ca-capstone`, Container App) lea un secret desde Azure Key Vault **sin credenciales embebidas**, usando una **User-Assigned Managed Identity** y el modelo **RBAC data-plane** moderno.

| Recurso | Nombre lógico | Dónde |
|---------|---------------|-------|
| Resource Group | `rg-capstone-dev` | `westeurope` |
| User-Assigned MI | `id-capstone-api` | mismo RG |
| Key Vault | `kv-capstone-dev` | mismo RG, SKU `standard`, RBAC on |
| Role assignment | Key Vault Secrets User | scope: el vault, principal: la MI |
| Secret (dummy) | `db-connection-string` | valor placeholder `CHANGE-ME-DUMMY-NOT-A-REAL-SECRET` |

---

## key-vault

### Qué se crea

Un `azurerm_key_vault` llamado `kv-capstone-dev` en `westeurope`, SKU `standard`, con el **RBAC data-plane** habilitado y sin ninguna `access_policy` block.

### Por qué `enable_rbac_authorization = true`

El modelo **RBAC data-plane** es el camino moderno. Ganancias concretas frente a *access policies* legacy:

- **Un único mental model**: los permisos sobre secrets/keys/certs se asignan con `azurerm_role_assignment`, igual que el management plane. No hay listas internas del recurso.
- **Herencia por scope**: puedo dar el rol a nivel de RG o Subscription cuando convenga (aquí no conviene — scope al vault para mínimo privilegio).
- **Catálogo de roles granular**: `Key Vault Secrets User`, `Key Vault Secrets Officer`, `Key Vault Crypto User`, `Key Vault Certificate Officer`. Cada tipo de dato tiene su par read/write.
- **IaC más limpio**: nada de 1024 slots internos; cada permiso es un recurso Terraform aparte, diff-eable.

Las access policies legacy quedan para migraciones y vaults preexistentes.

### Por qué `soft_delete_retention_days = 7` y `purge_protection_enabled = false`

Este diseño es **dev**. En dev interesa poder `terraform destroy` sin que el vault se quede fantasma 90 días bloqueando el nombre. Por eso:

- `soft_delete_retention_days = 7` → mínimo permitido (soft delete no se puede desactivar, pero sí se puede acortar).
- `purge_protection_enabled = false` → en dev, para poder purgar y recrear.

**En prod** los dos valores deben ser `90` y `true` respectivamente, forzado por Azure Policy (ver `az-09`). `purge_protection_enabled = true` es **irreversible**: una vez habilitado, no se puede desactivar.

### Qué NO se declara aquí

- `network_acls` → se añadirá cuando se integre con la VNet (ver `az-03`).
- `azurerm_private_endpoint` → mismo motivo.
- Firma de certs → actividad `02-cert-auto-renewal`.

---

## managed-identity

### Qué se crea

Un `azurerm_user_assigned_identity` llamado `id-capstone-api` en el mismo RG. Es un recurso Azure de primera clase con `principal_id` (= `object_id` del SP subyacente) y `client_id` (= app ID).

### Por qué User-Assigned y no System-Assigned

Dos razones:

1. **Reutilización**. El capstone va a crecer: `ca-capstone-api`, `ca-capstone-worker`, `func-capstone-scheduled`. Todos leerán los mismos secrets. Con una **User-Assigned MI** compartida, hay **un** role assignment en el vault, no N. Con System-Assigned tendríamos una MI por recurso y N role assignments.
2. **Supervivencia al recreate**. Si el Container App se destruye y recrea (deploy fallido, cambio de nombre), la System-Assigned MI muere con él y los role assignments quedan huérfanos. La User-Assigned sobrevive.

### Cómo la consume el capstone

El `azurerm_container_app` del capstone (fuera del scope de esta actividad) declarará:

```hcl
identity {
  type         = "UserAssigned"
  identity_ids = [azurerm_user_assigned_identity.app.id]
}

secret {
  name                = "db-connection-string"
  identity            = azurerm_user_assigned_identity.app.id
  key_vault_secret_id = azurerm_key_vault_secret.db_conn.versionless_id
}
```

El runtime de Container Apps usa la MI para obtener un token de Entra ID (`vault.azure.net`), lee el secret vía REST, lo inyecta como env var. **El valor nunca aparece en el HCL ni en app settings**.

---

## role-assignment

### Qué se crea

Un `azurerm_role_assignment` que concede el rol **built-in Key Vault Secrets User** (GUID `4633458b-17de-408a-b874-0445c86b69e6`) al **principal** `id-capstone-api.principal_id` sobre el **scope** `azurerm_key_vault.main.id` (el vault, no el RG).

### Por qué `principal_id` y no `client_id`

RBAC razona sobre el **principal** del directorio (= `object_id` del service principal subyacente a la MI). El `client_id` es el **application ID** y se usa en el flujo de autenticación del SDK, pero **no** identifica al principal para RBAC. Si por costumbre pones `client_id` en el `principal_id`, Terraform acepta el GUID (es sintácticamente válido) pero la asignación efectiva no "pega" y en runtime verás `Forbidden`.

### Por qué scope al vault y no al RG

**Mínimo privilegio**. Si pongo el scope al RG, cualquier Key Vault futuro en el mismo RG hereda ese rol automáticamente. Scope al vault concreto limita la autoridad al único recurso que la necesita. Si mañana añado un `kv-capstone-sensitive-dev` para datos regulados, su role assignment será otro recurso distinto, revisado explícitamente.

### Por qué `Key Vault Secrets User` (y no `Secrets Officer`)

El capstone **lee** secrets; no los crea, actualiza ni borra. `Key Vault Secrets User` da únicamente `Microsoft.KeyVault/vaults/secrets/getSecret/action` (y list). Si en el futuro el capstone necesitase rotar su propio secret, se añadiría una MI aparte con `Key Vault Secrets Officer` **solo** sobre los secrets que debe rotar (vía scope más específico).

### Equivalente materializado

El `role-assignment-kv-secrets-user.json` adjunto es lo que generaría `az role assignment create --output json` sobre un tenant real. Los GUIDs de `principalId` y de la subscription están como placeholder (`00000000-...`); Fase 4 los substituye.

El GUID del `roleDefinitionId` (`4633458b-17de-408a-b874-0445c86b69e6`) **sí** es real y estable — es el ID built-in global del rol **Key Vault Secrets User**. No cambia entre tenants.

---

## Rollout y pruebas

1. Fase 4 ejecuta `terraform plan` y revisa que **no** haya diff en los secrets reales (el valor del secret está en placeholder; la rotación real se hace por fuera con `az keyvault secret set` y `lifecycle { ignore_changes = [value] }`).
2. `terraform apply` crea el RG, la MI, el vault y el role assignment.
3. Un pipeline aparte (fuera de este Terraform) escribe el valor real del secret.
4. El Container App del capstone (otro módulo Terraform) lee el secret al arrancar.

Si algo falla con `Caller is not authorized`:

- Esperar 5 min por propagación RBAC.
- Verificar que `principal_id` es el de la MI y no `client_id`.
- Verificar que el `scope` es el vault y no el RG.
- Verificar que `enable_rbac_authorization = true` y que **no** quedan `access_policy` blocks que sobrescriban.
