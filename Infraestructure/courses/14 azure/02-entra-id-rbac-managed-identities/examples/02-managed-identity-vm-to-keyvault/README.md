# Ejemplo 02 — VM con Managed Identity leyendo un secreto de Key Vault

> Lectura y análisis. **No ejecutes** nada contra un tenant real; los IDs son placeholders. Hay costes reales de la VM y el Vault si lo materializaras — fuera del alcance de este módulo.

## 1. Flujo end-to-end

```
┌──────────────────────────┐    1. HTTP a IMDS                 ┌──────────────┐
│ App dentro de la VM      │ ───────────────────────────────► │ IMDS         │
│ (Python, dotnet, Go...)  │ ◄────────────── 2. access token  │ 169.254.169…│
└──────────────────────────┘                                    └──────┬───────┘
                                                                      │
                                                        3. Azure resource
                                                        provider del token
                                                                      │
                                                                      ▼
┌──────────────────────────┐    4. GET /secrets/<name>?...   ┌───────────────┐
│ App usa el token como    │ ───────────────────────────────►│ Key Vault     │
│ Bearer                   │ ◄──────────── 5. 200 + secret   │ (data plane)  │
└──────────────────────────┘                                 └───────────────┘
```

**Lo que NO existe en el flujo:** ningún secreto en el código, ni en variables de entorno, ni en archivos de configuración. La única "cosa secreta" es el token que vive en memoria durante ~1 hora y lo gestiona el SDK.

## 2. Terraform (`azurerm`) — esqueleto

```hcl
# IDs ilustrativos — reemplaza por tus valores reales en producción.
# Nunca commits de UUIDs reales de tenant/subscription.
variable "location" { default = "westeurope" }

resource "azurerm_resource_group" "demo" {
  name     = "rg-mi-demo"
  location = var.location
}

# ---------- Managed Identity (user-assigned) ----------
resource "azurerm_user_assigned_identity" "app" {
  name                = "mi-checkout-app"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
}

# ---------- Key Vault en modo RBAC data-plane ----------
resource "azurerm_key_vault" "kv" {
  name                        = "kv-checkout-demo-xyz"      # debe ser globalmente único
  resource_group_name         = azurerm_resource_group.demo.name
  location                    = azurerm_resource_group.demo.location
  sku_name                    = "standard"
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  enable_rbac_authorization   = true                        # moderno (vs access policies legacy)
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false                       # true en prod
}

data "azurerm_client_config" "current" {}

# ---------- RBAC: la MI puede LEER secretos del vault ----------
resource "azurerm_role_assignment" "mi_reads_secrets" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
  description          = "User-assigned MI 'mi-checkout-app' lee secretos del vault."
}

# ---------- VM Linux con la MI adjunta ----------
# (se omiten NIC, subnet, imagen por brevedad — se verán en az-03/az-04)
resource "azurerm_linux_virtual_machine" "app" {
  name                = "vm-checkout-app"
  resource_group_name = azurerm_resource_group.demo.name
  location            = azurerm_resource_group.demo.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.app.id]

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app.id]
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # SSH key omitida; en producción usar Azure Bastion / AAD login.
}
```

Observa las tres piezas RBAC:

1. **`azurerm_user_assigned_identity.app`** — crea la MI (que es un SPN gestionado por Azure).
2. **`identity { type = "UserAssigned"; identity_ids = [...] }`** dentro de la VM — adjunta la MI al recurso (IMDS la expondrá).
3. **`azurerm_role_assignment.mi_reads_secrets`** — concede `Key Vault Secrets User` a esa MI en el scope del vault concreto.

Sin el (3) la VM obtiene token pero Key Vault le devuelve `403` al pedir el secreto. Sin el (2) IMDS no sabe qué identidad presentar. Sin el (1) no hay nada que asignar.

## 3. Código en la VM (Python, muy breve)

```python
# Pseudocódigo — no es parte de los entregables del módulo.
from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

VAULT_URL = "https://kv-checkout-demo-xyz.vault.azure.net"

credential = DefaultAzureCredential()           # 1. intenta MI primero (IMDS)
client     = SecretClient(VAULT_URL, credential)
secret     = client.get_secret("db-password")   # 2. GET con Bearer <token>
print(secret.value)
```

`DefaultAzureCredential` resuelve en este orden: variables de entorno, Managed Identity (IMDS), Azure CLI local, Visual Studio Code... En una VM con MI adjunta la primera opción productiva es MI.

## 4. Decisiones de scope en el RBAC

- `scope = azurerm_key_vault.kv.id` → la MI puede leer secretos **de ese vault** (y no de ningún otro).
- Si hubiéramos puesto `scope = azurerm_resource_group.demo.id`, podría leer secretos de **cualquier** Key Vault presente o futuro de ese RG. Peor por default — no lo hagas salvo que sea deliberado.

## 5. Qué NO estás haciendo (y por qué importa)

- **No** estás almacenando un client secret del SPN en ningún Key Vault / variable de entorno.
- **No** necesitas rotar nada: Azure rota el token de la MI cada ~24h de forma transparente.
- **No** hay un `az login` persistente dentro de la VM.
- Si la VM se destruye, la MI *user-assigned* sobrevive (puedes reasignarla a la siguiente VM). Si fuera *system-assigned*, se destruiría con la VM y perderías cualquier role assignment asociado — por eso user-assigned es mejor cuando el workload es "más estable que la VM".

## 6. Lecturas sugeridas

- Lección §3 (MI system vs user-assigned) y §8 (jerarquía de credenciales).
- Ejemplo `01-role-assignment-at-rg-scope/` para la fórmula role/principal/scope.
- Actividad `02-mi-vs-sp-with-secret/` para el análisis comparativo contra SPN+secret.
