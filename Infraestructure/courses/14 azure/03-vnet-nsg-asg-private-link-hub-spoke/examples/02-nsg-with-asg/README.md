# Ejemplo 02 — NSG apoyada en ASG (patrón tiered web/app/db)

> **Lectura y análisis.** El objetivo es ver cómo una NSG puede referenciar grupos lógicos de NICs (ASG) en vez de rangos CIDR.

## 1. Topología lógica

```
                       Internet
                          │
                          │ TCP 443
                          ▼
    ┌─────────────────────────── NSG "nsg-tiered" ───────────────────────────┐
    │                                                                         │
    │  prio 100  Allow  Inbound  Internet       → asg-web   :443             │
    │  prio 200  Allow  Inbound  asg-web        → asg-app   :8080            │
    │  prio 300  Allow  Inbound  asg-app        → asg-db    :5432            │
    │  prio 400  Deny   Inbound  *              → asg-db    *                │
    │  prio 500  Deny   Outbound asg-db         → Internet  *                │
    │  (default DenyAllInBound 65500)                                        │
    └─────────────────────────────────────────────────────────────────────────┘
            │                       │                      │
         ┌──▼──┐                 ┌──▼──┐                ┌──▼──┐
         │ web │                 │ app │                │ db  │
         │ NIC │                 │ NIC │                │ NIC │
         │     │                 │     │                │     │
         │ ASG = asg-web         │ ASG = asg-app        │ ASG = asg-db
         └─────┘                 └─────┘                └─────┘
         (en snet-app)           (en snet-app)          (en snet-app o snet-db)
```

## 2. Qué pretende enseñar

- Las reglas **no mencionan IPs**: usan `source_application_security_group_ids` y `destination_application_security_group_ids`.
- Un cambio de IP (re-numeración, nuevas instancias) **no toca** las reglas: solo cambia la membresía del ASG.
- La regla `prio 400 Deny *→asg-db *` es un **cinturón de seguridad**: aunque alguien añada por error una regla permisiva con prioridad mayor, esta la frena.
- La regla `prio 500 Deny asg-db → Internet` evita exfiltración desde el tier de datos.

## 3. HCL anotado

```hcl
resource "azurerm_resource_group" "main" {
  name     = "rg-example-nsg-asg"
  location = "westeurope"
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-tiered"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.30.0.0/16"]
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.30.1.0/24"]
}

# ----- 3 ASGs: uno por tier -----
resource "azurerm_application_security_group" "web" {
  name                = "asg-web"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_application_security_group" "app" {
  name                = "asg-app"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_application_security_group" "db" {
  name                = "asg-db"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# ----- NSG + reglas -----
resource "azurerm_network_security_group" "tiered" {
  name                = "nsg-tiered"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_network_security_rule" "internet_to_web" {
  name                        = "AllowInternetToWeb443"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "Internet"
  destination_application_security_group_ids = [azurerm_application_security_group.web.id]
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.tiered.name
}

resource "azurerm_network_security_rule" "web_to_app" {
  name                                       = "AllowWebToApp8080"
  priority                                   = 200
  direction                                  = "Inbound"
  access                                     = "Allow"
  protocol                                   = "Tcp"
  source_port_range                          = "*"
  destination_port_range                     = "8080"
  source_application_security_group_ids      = [azurerm_application_security_group.web.id]
  destination_application_security_group_ids = [azurerm_application_security_group.app.id]
  resource_group_name                        = azurerm_resource_group.main.name
  network_security_group_name                = azurerm_network_security_group.tiered.name
}

resource "azurerm_network_security_rule" "app_to_db" {
  name                                       = "AllowAppToDb5432"
  priority                                   = 300
  direction                                  = "Inbound"
  access                                     = "Allow"
  protocol                                   = "Tcp"
  source_port_range                          = "*"
  destination_port_range                     = "5432"
  source_application_security_group_ids      = [azurerm_application_security_group.app.id]
  destination_application_security_group_ids = [azurerm_application_security_group.db.id]
  resource_group_name                        = azurerm_resource_group.main.name
  network_security_group_name                = azurerm_network_security_group.tiered.name
}

resource "azurerm_network_security_rule" "deny_anything_to_db" {
  name                                       = "DenyAnyToDb"
  priority                                   = 400
  direction                                  = "Inbound"
  access                                     = "Deny"
  protocol                                   = "*"
  source_port_range                          = "*"
  destination_port_range                     = "*"
  source_address_prefix                      = "*"
  destination_application_security_group_ids = [azurerm_application_security_group.db.id]
  resource_group_name                        = azurerm_resource_group.main.name
  network_security_group_name                = azurerm_network_security_group.tiered.name
}

resource "azurerm_network_security_rule" "deny_db_to_internet" {
  name                                  = "DenyDbToInternet"
  priority                              = 500
  direction                             = "Outbound"
  access                                = "Deny"
  protocol                              = "*"
  source_port_range                     = "*"
  destination_port_range                = "*"
  source_application_security_group_ids = [azurerm_application_security_group.db.id]
  destination_address_prefix            = "Internet"
  resource_group_name                   = azurerm_resource_group.main.name
  network_security_group_name           = azurerm_network_security_group.tiered.name
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.tiered.id
}
```

## 4. Lectura dirigida

1. **¿Qué pasa si una NIC pertenece a dos ASGs (`asg-web` y `asg-app`)?** Las reglas se evalúan por membresía: la NIC es *destination* para la regla web→app y *source* para app→db. Útil para VMs de propósito mixto; peligroso si rompes el principio de rol único.
2. **¿Por qué `prio 400 Deny *→db` si ya tenemos `AllowAppToDb` arriba?** Porque las reglas default *AllowVNetInBound* son prioridad 65000 — abrirían la DB a toda la VNet si no explicitas un deny.
3. **¿Qué pasa si cambias `destination_port_range = "5432"` por `"5432-5433"`?** Permites también el puerto 5433 (p. ej. para una réplica Postgres). El rango es inclusivo.
4. **¿Por qué `nsg-tiered` se asocia a la subnet y no a cada NIC?** Operativamente es más mantenible asociarlo a la subnet; las NICs se incorporan al modelo al ser creadas en esa subnet y asignadas a los ASGs correspondientes.

## 5. Validación local

```bash
cd <ruta-del-ejemplo-copiado-a-tu-tmp>
terraform init -backend=false
terraform validate
terraform fmt -check -recursive
```

## 6. Qué llevarte

- Las reglas con **ASG** son más legibles, más estables y escalan mejor que las reglas con CIDR.
- Reglas de **deny explícitas** evitan sorpresas con las defaults.
- La asociación de la NSG a la **subnet** es el patrón habitual; NSG en NIC se reserva para excepciones.
