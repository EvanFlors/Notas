# README-INTENT — Checkout Blob Reader (custom role)

> Documento de intención de los dos custom roles de este directorio. No duplica el JSON: lo justifica.

## role-storage-blob-reader

**Qué deniega / permite**

Permite exclusivamente la acción data-plane `Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read`. No incluye nada del management plane (`Actions` está vacío). No permite listar containers, no permite `listKeys`, no permite escribir ni borrar blobs.

**Por qué `Actions` está vacío**

El workload consumidor es una app detrás de una Managed Identity que solo necesita *leer bytes* de blobs. No necesita crear la storage account, ni modificar sus firewall rules, ni listar containers. Toda esa superficie se queda fuera por diseño — es la esencia del principio de mínimo privilegio.

**Por qué `DataActions` y no `Actions`**

Leer un blob es una operación del **data plane**. El servicio que atiende la petición es `*.blob.core.windows.net`, no `management.azure.com`. Azure RBAC distingue formalmente ambos planos: `Actions` sin `DataActions` te deja ver *metadatos* del contenedor pero no bajar el blob; `DataActions` sin `Actions` es exactamente lo que queremos aquí.

**Dónde asignar este role**

En Fase 4 se asignará con `azurerm_role_assignment` en el scope de la **storage account** `stcheckoutprod001` (no en el RG, para no cubrir storages futuras del mismo RG). El `principalId` será el `principal_id` de la user-assigned Managed Identity adjunta a la Container App (patrón del `az-06`).

```hcl
# ilustrativo — no commitees UUIDs reales
scope                = azurerm_storage_account.checkout.id
role_definition_id   = azurerm_role_definition.checkout_blob_reader.role_definition_resource_id
principal_id         = azurerm_user_assigned_identity.checkout_app.principal_id
```

**AssignableScopes**

Fijado a `/subscriptions/<SUB-UUID-PLACEHOLDER>/resourceGroups/rg-checkout-prod`. El role solo existe/puede asignarse dentro de ese RG. Si otro equipo quisiera reutilizarlo, debería crear su propia copia en su scope — hace explícita la "pertenencia" del custom role.

## role-storage-blob-reader-with-condition

**Qué añade**

Idéntico al anterior, más una `Condition` ABAC (version `2.0`) que restringe el `read` a blobs cuyo `path` empiece por `public/`. El resto de acciones del role (ninguna, en este caso) pasan sin la condition.

**Cuándo preferir esta variante**

Cuando quieres que *la misma MI* pueda leer sólo un **prefijo** del container, sin crear un container distinto y sin otro role. Es más mantenible que crear 10 custom roles distintos para 10 prefijos.

**Cuándo NO usarla**

Si el workload necesita leer todo el container, la variante base es más simple y auditable — menos superficie para errores.

## Decisión de scope

- `AssignableScopes`: RG `rg-checkout-prod`. El role no debería existir fuera del contexto del workload checkout.
- Scope del **role assignment** en Fase 4: la **storage account** concreta (`stcheckoutprod001`). Más estrecho que el RG; impide que el role aplique por accidente a storages futuras del mismo RG.
- `principalId`: la **Managed Identity** del workload (nunca un usuario humano para un workload de aplicación).

## Referencias cruzadas

- Lección §4 (role assignment), §6 (custom roles), §7 (scope jerárquico).
- Ejemplo `03-custom-role-json/` (anatomía) y `02-managed-identity-vm-to-keyvault/` (patrón MI + role assignment).
- Documentación oficial de **DataActions** vs **Actions**: ver `resources/links.md` del módulo.
