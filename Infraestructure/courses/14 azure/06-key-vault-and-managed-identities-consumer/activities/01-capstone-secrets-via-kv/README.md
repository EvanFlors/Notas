# Actividad 01 — Diseñar Key Vault + Managed Identity para el capstone

## 1. Identificación

- **ID:** `az-06-01-capstone-secrets-via-kv`
- **Tecnología:** `azure`
- **Módulo:** `az-06-key-vault-and-managed-identities-consumer`
- **Dificultad:** intermediate
- **Duración estimada:** 70–80 min
- **Tipo:** architecture (sin aplicar en una suscripción real)

## 2. Contexto

El equipo de Platform te pide dejar diseñado — en Terraform *plan-ready* — el **Key Vault** del capstone y el **role assignment data-plane** que permitirá al Container App del capstone (`ca-capstone`) leer un secret via Managed Identity. **No vas a aplicar nada**: no hay subscription Azure, no se gasta un céntimo. El entregable son archivos de texto que Fase 4 aplicará con `terraform apply` cuando toque.

**Importante**:

- **No hay suscripción Azure** y no la hace falta.
- **No uses secretos reales**: todos los *values* deben ser *dummies* como `CHANGE-ME-DUMMY-NOT-A-REAL-SECRET`.
- **No uses tenant / subscription IDs reales**: usa el GUID placeholder `00000000-0000-0000-0000-000000000000`.
- **No llames al documento `ANALYSIS.md`** — otros validadores del repo tratan ese nombre con convenciones especiales. Usa **`README-INTENT.md`**.

## 3. Objetivos

Al terminar deberías poder:

- Escribir HCL de Azure moderno con `azurerm_key_vault` + `azurerm_user_assigned_identity` + `azurerm_role_assignment`.
- Elegir correctamente el `principal_id` (no `client_id`) y el `scope` (el vault, no el RG).
- Escribir un `role-assignment-kv-secrets-user.json` que podría pasarse a `az role assignment create` o a un Deployment Stack.
- Justificar por escrito las decisiones de `enable_rbac_authorization`, `soft_delete_retention_days` y `purge_protection_enabled`.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§3, §4, §5, §6) y recorrido `../../examples/01-key-vault-rbac-dataplane/`.
- Herramientas: `bash`, `jq` (parser JSON), `terraform fmt` (opcional). Un editor de texto.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/az-06-01
cd /tmp/az-06-01
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `main.tf`

Debe contener, como mínimo:

- `terraform { required_providers { azurerm = { source = "hashicorp/azurerm" ... } } }`.
- `provider "azurerm" { features {} }`.
- `data "azurerm_client_config" "current" {}`.
- `azurerm_resource_group` (RG donde vive todo).
- `azurerm_user_assigned_identity` (la MI del capstone).
- `azurerm_key_vault` con **`enable_rbac_authorization = true`** y **`sku_name = "standard"`**.
- `azurerm_role_assignment` con `role_definition_name = "Key Vault Secrets User"`, `scope = azurerm_key_vault.<name>.id`, `principal_id = azurerm_user_assigned_identity.<name>.principal_id`.
- `azurerm_key_vault_secret` con `value = "CHANGE-ME-DUMMY-NOT-A-REAL-SECRET"` (secret dummy — el validador rechaza algo que parezca una contraseña real).

### 5.3 Escribe `variables.tf`

Al menos las variables:

- `location` (default `"westeurope"`).
- `resource_group_name`.
- `key_vault_name`.
- `identity_name`.

### 5.4 Escribe `role-assignment-kv-secrets-user.json`

Debe ser **JSON válido** (parseable por `jq .`) con estas keys:

```json
{
  "principalId": "00000000-0000-0000-0000-000000000000",
  "principalType": "ServicePrincipal",
  "roleDefinitionId": "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6",
  "scope": "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-capstone-dev/providers/Microsoft.KeyVault/vaults/kv-capstone-dev"
}
```

Requisitos:

- `principalId` presente, GUID (puede ser el placeholder `00000000-...`).
- `principalType == "ServicePrincipal"` (porque una MI es un SP gestionado).
- `roleDefinitionId` debe terminar en `4633458b-17de-408a-b874-0445c86b69e6` (el GUID built-in de **Key Vault Secrets User**).
- `scope` debe contener `Microsoft.KeyVault/vaults/` (es decir, scopeado al vault, no al RG ni a la subscription).

### 5.5 Escribe `README-INTENT.md`

Secciones obligatorias (el validador las busca):

- `## key-vault` — qué vault se crea, por qué `enable_rbac_authorization`, `soft_delete_retention_days`, `purge_protection_enabled` tienen los valores que tienen.
- `## managed-identity` — qué MI se crea, por qué **User-Assigned** y no System-Assigned, qué recurso la consumirá en el futuro.
- `## role-assignment` — qué rol, qué scope, qué principal; por qué `principal_id` y no `client_id`; por qué scope al vault y no al RG.

Además debes mencionar explícitamente:

- La frase **RBAC data-plane** (o equivalente) justificando por qué no se usan access policies legacy.
- La palabra **Managed Identity**.
- El rol **Key Vault Secrets User**.

### 5.6 Entregables

```
/tmp/az-06-01/
├── main.tf
├── variables.tf
├── role-assignment-kv-secrets-user.json
└── README-INTENT.md
```

## 6. Resultado esperado

- `terraform fmt -check main.tf variables.tf` pasa (opcional pero recomendado).
- `jq . role-assignment-kv-secrets-user.json` imprime JSON válido.
- `bash tests/validate.sh /tmp/az-06-01` termina con `0 issue(s)`.

## 7. Criterios de aceptación

- **Funcionalidad**: validador pasa en verde.
- **Correctitud sintáctica**: HCL parseable, JSON válido.
- **Correctitud conceptual** (autoevaluación): comparar con `solution/REFERENCE.md`.
- **Mantenibilidad**: nombres descriptivos (`kv-capstone-dev`, `id-capstone-api`), tags coherentes.

## 8. Validación

```bash
bash tests/validate.sh /tmp/az-06-01
```

El validador comprueba:

- Existencia y sintaxis mínima de los 4 entregables.
- Que `main.tf` declare `azurerm_key_vault`, `azurerm_user_assigned_identity`, `azurerm_role_assignment` y use `enable_rbac_authorization = true`.
- Que el JSON del role assignment tenga las claves obligatorias y el GUID del rol correcto.
- Que `README-INTENT.md` tenga las 3 secciones y mencione los conceptos clave.

**No** comprueba que el HCL aplicado contra una suscripción real haga exactamente lo que dice el documento. Esa validación es Fase 4.

## 9. Preguntas de reflexión

1. ¿Qué pasa si cambias `principal_id = ...principal_id` por `principal_id = ...client_id`?
2. ¿Por qué el `scope` apunta al vault y no al RG?
3. ¿Qué cambiarías en `main.tf` si fuera un entorno de producción (no dev)?
4. ¿Cómo escribirías el secret real sin que aparezca en el *state file*? (pista: `azurerm_key_vault_secret` + `lifecycle { ignore_changes = [value] }` + escritura fuera de Terraform).
5. Si otro workload (`ca-capstone-worker`) también necesita leer el mismo secret, ¿creas otra MI o reutilizas la existente? ¿Por qué?

## 10. Extensiones

- Añade un `azurerm_key_vault_key` (clave RSA 2048) con un `role_assignment` adicional de **Key Vault Crypto User** para cifrar/descifrar datos sensibles en la app.
- Añade un `azurerm_monitor_diagnostic_setting` que envíe los logs del vault a Log Analytics (preparando `az-08`).
- Convierte el `azurerm_key_vault_secret` en un `for_each` sobre una lista de nombres de secret.

## 11. Limpieza

```bash
rm -rf /tmp/az-06-01
```

No hay infraestructura que detener (no se ha aplicado nada).
