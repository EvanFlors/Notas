# Ejercicio operativo — Azure Landing Zone + Identity (nivel `terraform validate`)

**Tiempo sugerido:** 40–50 min dentro del examen.

**Entorno:** máquina local con Terraform ≥ 1.6 (u OpenTofu equivalente) y el provider `azurerm` ≥ 3.100. **Sin credenciales Azure.** Toda la validación es offline. Opcionalmente, para OP-task-2 se puede usar **Azurite** como emulador de Blob — si no está disponible, declara `SKIP: Azurite no disponible` en tu entregable (no se penaliza).

**Comandos permitidos y únicos esperados:**

```bash
terraform fmt -recursive
terraform init -backend=false
terraform validate
```

**Prohibido:**

- `terraform apply`, `terraform plan` contra una suscripción real.
- `az login` interactivo contra un tenant corporativo.
- Agregar providers que no estén ya declarados.
- Usar `terraform state rm` para "ocultar" un error.
- Hardcodear GUIDs reales (todos los GUIDs ya son dummy — no los sustituyas).

---

## Contexto del stack

El equipo anterior dejó este stack en `operative/`:

- `versions.tf` — declaración de providers (incompleta y con pinning laxo).
- `main.tf` — Management Groups, Subscriptions placeholder, un Resource Group, un Key Vault, un Storage Account, un Service Principal con secret (anti-patrón), una user-assigned MI huérfana, dos policy assignments.
- `variables.tf` — algunas variables sin tipo, sin `validation`.
- `outputs.tf` — un output filtra el secret del SP (red flag intencional).
- `aks-wi.tf` — scaffold de Workload Identity para AKS que no está terminado.

El código **no pasa `terraform validate`** por: provider mal declarado, scope de policy incorrecto, dependencia circular en el MG, y un recurso referenciado por un nombre que no existe.

---

## Tus tareas

### OP-task-1 — Landing Zone y Policy baseline (C10)

1. Corregir `versions.tf` para que `required_providers` declare `azurerm` con pinning `~>` en una minor estable y agregue `azuread` (requerido por los recursos de identity).
2. Reorganizar la jerarquía Management Group en `main.tf` para que siga el patrón CAF mínimo:
   ```
   root (Tenant Root Group — NO lo tocamos, solo lo referenciamos)
    └── mg-platform
    └── mg-landing-zones
         ├── mg-landing-zones-prod
         └── mg-landing-zones-dev
    └── mg-sandbox
    └── mg-decommissioned
   ```
   El código actual mete `mg-sandbox` como hijo de `mg-landing-zones` — corrígelo.
3. Reasignar la policy `deny-public-ip` al scope **`mg-landing-zones`** (no al Tenant Root). Reasignar la policy `require-tags` al scope de cada subscription (dejar un `for_each` sobre el `map` de subscriptions). Usar el effect correcto para cada caso (una debe prevenir, la otra puede ser `modify` para añadir tags por default).
4. Agregar una policy assignment con effect **`deployIfNotExists`** que cree un Diagnostic Setting en cada Storage Account nuevo, asignándole correctamente la **Managed Identity** necesaria para remediar (usar la user-assigned MI `uami-policy-remediator`, ya declarada pero no utilizada).
5. En `variables.tf`, agregar `variable "environment"` con `validation` que acepte únicamente `dev`, `stg`, `prod`.

### OP-task-2 — Identidad y Key Vault (C3)

1. Eliminar el recurso `azuread_service_principal_password.workload_sp` (secret-based SP, anti-patrón) y el `azuread_application.workload`.
2. Usar la user-assigned MI `uami-workload` (ya declarada) como la identidad del workload.
3. Asignarle el role **`Key Vault Secrets User`** sobre el Key Vault `kv-exam-${var.environment}` — **nunca `Contributor` ni `Owner`**.
4. Habilitar en el Key Vault: `soft_delete_retention_days = 90`, `purge_protection_enabled = true`, `enable_rbac_authorization = true`, `public_network_access_enabled = false`. Dejar un comentario explicando cuándo _no_ activarías `purge_protection` (pista: entornos efímeros de CI).
5. En `outputs.tf`, eliminar el output `workload_sp_secret` (fuga de secreto) y marcar como `sensitive` cualquier output que exponga un `principal_id`.

### OP-task-3 — AKS Workload Identity + OIDC Federation (C8, C12)

En `aks-wi.tf`, completar:

1. Un `azurerm_federated_identity_credential` que ate la user-assigned MI `uami-workload` a un `ServiceAccount` llamado `workload-sa` del namespace `app` en un cluster AKS cuyo OIDC issuer URL vendrá por variable (`var.aks_oidc_issuer_url`). El `subject` debe ser `system:serviceaccount:app:workload-sa` y el `audience` `["api://AzureADTokenExchange"]`.
2. Un segundo `azurerm_federated_identity_credential` para GitHub Actions con **`subject` pinneado** a `repo:example-org/example-repo:environment:prod` (nunca `:*`). El `issuer` es `https://token.actions.githubusercontent.com`.
3. Un ejemplo de manifest de K8s en `aks-wi.tf` como `locals.service_account_manifest` (string YAML) que anote el `ServiceAccount` con `azure.workload.identity/client-id` apuntando al Client ID de la MI (via `azurerm_user_assigned_identity.uami_workload.client_id`). Dejar un comentario explicando por qué este anotado es lo que permite al pod proyectar el token correcto.
4. Dejar un comentario `# NOTAS` al final de `aks-wi.tf` con:
   - Qué garantiza y qué **no** garantiza el `subject` pinneado a `environment:prod`.
   - Por qué una user-assigned MI es preferible a system-assigned para este caso.
   - Qué cambiarías si el workload no estuviera en AKS sino en Container Apps (pista: Container Apps también soporta Workload Identity pero el `subject` es distinto).

---

## Entregables

- Los 5 archivos `.tf` modificados en `operative/`.
- Un bloque de comentarios `# NOTAS FINALES` al final de `main.tf` con:
  - Por qué `mg-landing-zones` es el scope correcto para `deny-public-ip` (y qué romperías si lo pusieras en Tenant Root).
  - Qué garantiza `deployIfNotExists` que `audit` no garantiza, y qué permiso necesita la MI de remediación.
  - Qué protege `purge_protection` y en qué caso es un error activarlo.

## Validación automática (lo que corre el instructor)

```bash
cd operative/
terraform fmt -check -recursive                                         # debe salir 0
terraform init -backend=false                                            # ok si solo descarga providers del registry
terraform validate                                                       # debe decir "Success!"

# OP-task-1 — Landing Zone
grep -q 'mg-landing-zones' main.tf
grep -q 'mg-sandbox' main.tf
grep -q 'deployIfNotExists' main.tf
grep -q 'validation' variables.tf
! grep -q 'azurerm_management_group.sandbox.*parent_management_group_id *= *azurerm_management_group.landing_zones' main.tf   # sandbox NO debe colgar de landing-zones

# OP-task-2 — Identity
! grep -q 'azuread_service_principal_password' main.tf                   # debe estar eliminado
! grep -q 'azuread_application\.workload' main.tf                        # debe estar eliminado
grep -q 'Key Vault Secrets User' main.tf
grep -q 'purge_protection_enabled *= *true' main.tf
grep -q 'enable_rbac_authorization *= *true' main.tf
grep -q 'public_network_access_enabled *= *false' main.tf
! grep -q 'workload_sp_secret' outputs.tf                                # el output filtrador debe estar fuera

# OP-task-3 — Workload Identity
grep -q 'azurerm_federated_identity_credential' aks-wi.tf
grep -q 'system:serviceaccount:app:workload-sa' aks-wi.tf
grep -q 'repo:example-org/example-repo:environment:prod' aks-wi.tf
! grep -q 'repo:example-org/example-repo:\*' aks-wi.tf                   # red flag — subject sin pinning
grep -q 'api://AzureADTokenExchange' aks-wi.tf

# Red flags generales
! grep -rE '[A-Z0-9]{20}' operative/ --include='*.tf' | grep -v '0{20,}' # heurística laxa contra secretos pegados
! grep -q 'azurerm_role_assignment.*role_definition_name *= *"Owner"' main.tf
! grep -q 'azurerm_role_assignment.*role_definition_name *= *"Contributor".*uami_workload' main.tf
```

## Prohibiciones (red flags que invalidan la entrega)

- Hardcodear algo que parezca un secret real (incluso dummy con formato real como `AKIA...` o `AccountKey=...`).
- Sustituir los GUIDs dummy por GUIDs de un tenant propio o cliente.
- Usar `terraform state rm`, `-target`, o `-refresh=false` para "ocultar" un error.
- Agregar providers `aws`, `google`: no son necesarios ni permitidos.
- Dejar role `Owner`/`Contributor` sobre un workload o policy.
- Mantener el SP con password en vez de migrar a MI.
- Dejar el `subject` del federated credential como `*` o `refs/heads/*` sin justificación.
- Marcar todo como `sensitive` sin criterio.
- Pegar output de `terraform validate` ficticio (el instructor correrá los comandos).
