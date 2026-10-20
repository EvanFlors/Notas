# Ejemplo 01 — Role assignment en scope de Resource Group

> Lectura y análisis. **No ejecutes** nada contra un tenant real; los IDs son placeholders.

## 1. La fórmula

```
role assignment = role definition + principal + scope
```

Las tres piezas se eligen por separado:

- **Role definition**: *qué* se puede hacer. Built-in (`Reader`, `Storage Blob Data Reader`...) o custom.
- **Principal**: *quién* lo hace. `principalId` (objectId en Entra ID) de un user, group, SPN o MI.
- **Scope**: *dónde* aplica. Ruta jerárquica (MG → Sub → RG → resource).

Un assignment es un recurso independiente en Azure; se identifica por el triple `(role, principal, scope)`. Dos assignments con el mismo role pero distinto scope son *dos* assignments.

## 2. El escenario

- Workload: `checkout` (una API).
- Equipo backend (Entra ID group `grp-checkout-backend`) necesita **leer** cualquier recurso del RG `rg-checkout-prod` para debug/soporte, pero **no** modificarlo.
- Elección: role **built-in `Reader`** al **grupo** en el **scope del RG**. Más estrecho que subscription, pero cubre todos los recursos actuales y futuros del RG.

## 3. CLI (`az`)

```bash
# IDs ilustrativos — reemplaza por tus valores reales en producción.
SUB_ID="<SUB-UUID-PLACEHOLDER>"
RG="rg-checkout-prod"
GROUP_OBJECT_ID="<GROUP-OBJECT-ID-PLACEHOLDER>"

az role assignment create \
  --role "Reader" \
  --assignee-object-id "$GROUP_OBJECT_ID" \
  --assignee-principal-type Group \
  --scope "/subscriptions/$SUB_ID/resourceGroups/$RG"
```

Notas:

- `--assignee-object-id` + `--assignee-principal-type` es la forma recomendada; evita colisiones de nombre y es idempotente.
- Si el principal fuera un service principal, `--assignee-principal-type ServicePrincipal`. Para una managed identity también `ServicePrincipal` (el `principalId` es el objectId del SPN subyacente).

## 4. Terraform (`azurerm`)

```hcl
# IDs ilustrativos — reemplaza por tus valores reales en producción.
# Nunca commits de UUIDs reales de tenant/subscription.
data "azurerm_subscription" "current" {}

resource "azurerm_role_assignment" "checkout_backend_reader" {
  scope                = "${data.azurerm_subscription.current.id}/resourceGroups/rg-checkout-prod"
  role_definition_name = "Reader"
  principal_id         = var.checkout_backend_group_object_id
  # Opcional pero recomendado para auditoría:
  description          = "Backend team read access for debug in checkout prod RG."
}
```

Puntos a observar:

- El `scope` se construye a partir del subscription id — no se hardcodea.
- `role_definition_name = "Reader"` referencia un built-in por nombre. Para custom roles usarías `role_definition_id`.
- `principal_id` es el **objectId** del group en Entra ID, no el `displayName` ni el `appId`.

## 5. Verificación mental

Con este assignment aplicado:

- Un miembro del group **puede** hacer `GET` sobre cualquier recurso dentro de `rg-checkout-prod` (incluidos los que se creen mañana).
- **No puede** crear, modificar ni borrar — `Reader` solo tiene `Microsoft.*/*/read`.
- **No puede** leer blobs del data-plane de una storage account del RG — `Reader` no incluye `Microsoft.Storage/.../blobs/read` como `DataAction`. Para eso haría falta `Storage Blob Data Reader` adicional, con su propio assignment (idealmente al scope de la storage account, no del RG).

## 6. Antipatrón a reconocer

```
Scope: /subscriptions/<SUB>              ← demasiado amplio
Role:  Owner                             ← demasiado permisivo
Principal: usuario individual            ← debería ser un group
```

Cada uno de los tres ejes rotos multiplica el blast-radius. En producción se audita que ningún `Owner` cuelgue de scope subscription hacia principales no humanos permanentemente.

## 7. Lecturas sugeridas

- Lección §4 (anatomía) y §7 (scope jerárquico).
- Ejemplo `03-custom-role-json/` para la variante `Actions` / `DataActions`.
