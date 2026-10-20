# Ejemplo 03 — VM Linux con Azure AD login (sin claves SSH locales)

> Lectura y analisis. Objetivo: ver una receta Terraform de VM Linux que usa la extension **AADSSHLoginForLinux** para que los usuarios entren con su identidad de Entra ID — nunca con `authorized_keys` compartidos.

## 1. El `main.tf`

```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-vm-aad-demo"
  location = "westeurope"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-demo"
  address_space       = ["10.20.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnet-vms"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipcfg"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    # Sin public_ip_address_id — accedemos via Bastion.
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                            = "vm-demo"
  location                        = azurerm_resource_group.rg.location
  resource_group_name             = azurerm_resource_group.rg.name
  size                            = "Standard_B1s"
  admin_username                  = "azureuser"
  network_interface_ids           = [azurerm_network_interface.nic.id]
  # Sin password; sin SSH keys locales. Entry point = AAD.
  disable_password_authentication = true

  # Pseudo-key requerida por el schema aunque no la usemos
  # (la extension AAD la ignora).
  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.throwaway.public_key_openssh
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

  identity {
    type = "SystemAssigned"
  }
}

# La extension es LA pieza clave: instala el agente que valida tokens AAD.
resource "azurerm_virtual_machine_extension" "aad_login" {
  name                       = "AADSSHLoginForLinux"
  virtual_machine_id         = azurerm_linux_virtual_machine.vm.id
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADSSHLoginForLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

# Role assignment: quien puede entrar como usuario normal.
resource "azurerm_role_assignment" "vm_user" {
  scope                = azurerm_linux_virtual_machine.vm.id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = data.azurerm_client_config.current.object_id
}
```

## 2. Lectura clave

1. **La VM no tiene public IP.** El acceso humano se hace via **Azure Bastion** (no mostrado aqui para brevedad) o via `az ssh vm --name vm-demo` que negocia conectividad.
2. **La extension `AADSSHLoginForLinux`** instala un `pam_oidc` que valida el token de Entra ID al login. Sin la extension, el `admin_ssh_key` dummy no abre nada.
3. **Dos roles RBAC** controlan el acceso:
   - `Virtual Machine User Login` -> login como usuario normal.
   - `Virtual Machine Administrator Login` -> login + `sudo`.
4. **Login real** desde el laptop del dev:
   ```bash
   az login
   az ssh vm --resource-group rg-vm-aad-demo --vm-name vm-demo
   ```
   La CLI negocia un cert efimero firmado por Entra ID, lo entrega a la VM via la extension y abre sesion. No hay `~/.ssh/authorized_keys` modificado jamas.
5. **`identity { type = "SystemAssigned" }`** da a la VM una Managed Identity propia (equivalente a IAM Role de EC2). Util para que la VM lea Key Vault / Storage sin credenciales en disco.

## 3. Por que esto es importante

- **Zero local SSH keys**: offboardear a un empleado = quitar el role assignment. La VM lo pierde en ~1 min. No hay que buscar su clave en `authorized_keys` de 40 VMs.
- **MFA automatico**: si Entra ID exige MFA al grupo del dev, el login SSH tambien lo exige.
- **Auditoria centralizada**: cada login queda en el Sign-in log de Entra ID y en Activity Log.
- **RBAC jerarquico**: puedes dar `Virtual Machine User Login` a nivel de RG o Suscripcion, no VM a VM.

## 4. Mapeo con AWS

- **EC2 Instance Connect** + **AWS SSO** es el equivalente mas cercano. Ambos reemplazan `authorized_keys`.
- **SSM Session Manager** cubre el "sin IP publica + auditoria" (es el mas directo analogo a Bastion + AAD login combinados).

## 5. Que no muestra este ejemplo

- La creacion de la **Bastion host** (`azurerm_bastion_host`) — se omite para que la lectura sea corta.
- El NSG restrictivo que bloquea 22 excepto desde la subnet del Bastion.
- Un Diagnostic Setting para enviar logs de VM a Log Analytics.
