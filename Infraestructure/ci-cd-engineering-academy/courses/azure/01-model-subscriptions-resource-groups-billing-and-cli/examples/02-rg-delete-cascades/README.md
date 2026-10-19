# Ejemplo 02 — `az group delete`: eliminación en cascada

> Lectura y análisis. **No ejecutes** `az group delete` contra un RG real en este módulo. Objetivo: entender por qué el Resource Group es el pivote operativo de limpieza en Azure, y por qué AWS no tiene equivalente directo.

## 1. El patrón

Un RG `rg-checkout-dev` puede contener, por ejemplo:

```
rg-checkout-dev   (location: westeurope)
├── vnet-checkout-dev           (Microsoft.Network/virtualNetworks)
├── nsg-checkout-dev            (Microsoft.Network/networkSecurityGroups)
├── stcheckoutdev123            (Microsoft.Storage/storageAccounts)
├── kv-checkout-dev             (Microsoft.KeyVault/vaults)
├── pg-checkout-dev             (Microsoft.DBforPostgreSQL/flexibleServers)
├── ca-checkout-dev             (Microsoft.App/containerApps)
└── log-checkout-dev            (Microsoft.OperationalInsights/workspaces)
```

Para desmontarlo **todo** en una sola operación:

```bash
# DRY-RUN / preview (no destruye):
az group show --name rg-checkout-dev --query "properties.provisioningState"
az resource list --resource-group rg-checkout-dev -o table

# REAL (NO EJECUTAR en este módulo):
# az group delete --name rg-checkout-dev --yes --no-wait
```

Flags clave:

- `--yes` — no pregunta confirmación interactiva. Útil en scripts; peligroso en terminal humana.
- `--no-wait` — vuelve el prompt inmediatamente; el borrado continúa en background.
- `--force-deletion-types` — para familias que requieren orden específico (p. ej. `Microsoft.Compute/virtualMachines`).

## 2. Por qué este patrón es útil

En AWS, limpiar un entorno dev suele requerir:

1. Listar recursos con `aws resourcegroupstaggingapi get-resources --tag-filters Key=env,Values=dev`.
2. Borrar cada uno con su API específica (ECS service antes que task definition, dependencia por dependencia).
3. A menudo, aceptar que recursos sin tag o huérfanos quedan atrás.

En Azure, con el patrón **un RG = un ambiente de un workload**, basta `az group delete`. El plano de control resuelve el orden de dependencias y borra todo lo contenido.

Esto no es gratis: hay que **invertir en la disciplina** de un RG por ciclo de vida. Si mezclas 15 workloads en `rg-prod`, pierdes esta ventaja.

## 3. Qué NO borra `az group delete`

- Recursos **fuera** del RG, aunque estén relacionados: role assignments en otros scopes, DNS records en zonas que viven en otro RG, Key Vault secrets referenciados pero no almacenados aquí.
- **Soft-deleted** resources: Key Vault con **soft delete + purge protection** (recomendado) **sobrevive** al `delete` 90 días por defecto, protegido contra `purge`.
- Recursos con **resource lock** `CanNotDelete` o `ReadOnly`. El `delete` falla hasta que se quite el lock.
- Diagnostic settings y log destinations en otros RGs/subscriptions.

## 4. Locks: el seguro contra borrados accidentales

```bash
# Ver locks existentes (dry-run / lectura):
az lock list --resource-group rg-checkout-prod -o table

# Crear un lock CanNotDelete (NO EJECUTAR aquí, demostrativo):
# az lock create --name no-delete-checkout-prod \
#     --resource-group rg-checkout-prod \
#     --lock-type CanNotDelete \
#     --notes "Prod del workload checkout. No borrar sin aprobación."
```

Para **prod** se recomienda `CanNotDelete` en el RG; un operador que vaya a `az group delete` recibe un error que lo obliga a parar y a pensar (`AuthorizationFailed: lock in effect`).

## 5. Soft delete en Key Vault y Storage: una red extra

Independientemente del lock:

- **Key Vault**: `soft delete` **obligatorio** (no se puede desactivar); `purge protection` opcional pero recomendado en prod — una vez activado, los secretos siguen existiendo 90 días tras `delete` y nadie, ni admin, puede purgarlos antes.
- **Storage Account (Blob)**: `soft delete for blobs` + `versioning` recomendados en prod.

El `az group delete` sobre un RG con Key Vault + purge protection *elimina* el vault lógicamente pero no lo purga; el nombre global permanece reservado durante el periodo de retención.

## 6. Preguntas de autocomprobación

1. Si tu `rg-checkout-dev` tiene 20 recursos y lanzas `az group delete --yes --no-wait`, ¿cuánto tiempo tarda en volver el prompt y cuánto el borrado real?
2. ¿Por qué un Key Vault con `purge protection` complica el ciclo "crear-destruir-crear" en pipelines efímeros? ¿Cómo lo mitigas?
3. Si un developer pone un lock `CanNotDelete` en `rg-prod` y se va de vacaciones, ¿cómo lo quitas sin él?
4. Un recurso con role assignment en `/subscriptions/.../resourceGroups/other-rg/...` desaparece al borrar el RG anfitrión. ¿Qué pasa con el role assignment?
5. Si borras un RG en una subscription cuya **Billing** termina en 24 h, ¿el gasto por el RG deja de contar antes o después del delete?

Se trabajan en la actividad `01-bootstrap-safe-subscription` (lado operacional) y en `02-tagging-rg-vs-resource` (lado de gobernanza).
