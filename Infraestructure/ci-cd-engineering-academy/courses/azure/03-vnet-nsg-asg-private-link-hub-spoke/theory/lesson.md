# az-03 — Lección: VNet, NSG, ASG, Private Link y Hub-Spoke

> 12 secciones. Mayoritariamente conceptual + patrones Terraform `azurerm`. Prerrequisitos: `az-01`, `az-02`.

---

## 1. VNet: la unidad de red regional en Azure

Una **Virtual Network (VNet)** es el equivalente conceptual de una **VPC** en AWS: un espacio IP privado, aislado, dentro de una **región**. Diferencias clave respecto a AWS:

- **La VNet es regional**, no multi-AZ en su propia definición. Las *availability zones* se escogen por recurso (una VM en zona 1, otra en zona 2), no por subnet. Esto cambia la discusión AWS clásica de "una subnet por AZ".
- **Address space** es una o varias listas CIDR (`10.0.0.0/16`, `172.16.0.0/20`). Se puede ampliar en caliente.
- **Subnets** son particiones del address space. **No se asocian a AZ**; una subnet cruza las 3 AZ de la región. Pequeña consecuencia: no hay "una subnet por AZ"; hay "una subnet por **rol lógico**" (`subnet-web`, `subnet-app`, `subnet-db`).
- **Subnet reservada**: Azure reserva **5 IPs por subnet** (`.0`, `.1`, `.2`, `.3`, `.255` en una `/24`). AWS reserva 5 similares; conviene recordar que un `/29` útil solo da 3 IPs.
- **Subnets especiales**: algunos recursos exigen una subnet dedicada con un nombre fijo:
  - `GatewaySubnet` para VPN/ExpressRoute Gateway.
  - `AzureFirewallSubnet` para Azure Firewall.
  - `AzureBastionSubnet` para Bastion.
  - **Delegated subnets** para servicios como Container Apps, App Service Environment, PostgreSQL Flexible, etc. — una delegación "cede" la subnet al servicio.

Esqueleto Terraform mínimo:

```hcl
resource "azurerm_virtual_network" "main" {
  name                = "vnet-platform-dev"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.10.0.0/16"]
}

resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.1.0/24"]
}
```

> **Idea clave:** una VNet no es "la red" entera de la empresa. Es la red de **un** workload (o un grupo pequeño). Cuando necesitas conectar varias VNets, apareces en el territorio de VNet Peering y Hub-Spoke (§9).

---

## 2. CIDR plan: evitar solapamientos antes de que duelan

El mayor error de red en Azure (y en AWS) no es técnico: es un **CIDR plan ad-hoc**. Dos VNets con solapamiento no pueden hacer peering nunca; el día que necesites conectarlas vas a tener que re-numerar — un ejercicio caro y arriesgado.

Reglas prácticas:

1. **Reservar un prefijo corporativo** (p. ej. `10.0.0.0/8` para toda la organización) y partirlo por región, entorno y workload.
2. **No reusar rangos RFC 1918** en varios entornos sin coordinar: si `dev-westeurope` usa `10.1.0.0/16` y `prod-westeurope` también usa `10.1.0.0/16`, el día que necesites peerear ambos con un hub, estás bloqueado.
3. **Dejar espacio para crecimiento**: una VNet pequeña (`/22`) parece suficiente hoy; dentro de 2 años con 5 Private Endpoints por workload y servicios delegados puede quedar corta.
4. **No tocar `169.254.0.0/16`, `168.63.129.16`, `172.17.0.0/16`**: Azure reserva estos para su control plane (DNS virtual, metadata). Overlaparlos rompe recursos.

Plan ejemplo para una org pequeña con 1 hub + 3 spokes:

| Entorno | CIDR | Notas |
|---------|------|-------|
| Hub `westeurope` | `10.0.0.0/22` | Firewall + Gateway + DNS |
| Spoke `checkout-prod` | `10.1.0.0/16` | PCI-light |
| Spoke `checkout-dev` | `10.2.0.0/16` | Dev |
| Spoke `analytics` | `10.3.0.0/16` | Interno |
| Futuro `shared-services` | `10.4.0.0/16` | Reservado |

> **Trampa habitual:** aceptar el default de Terraform o del portal (`10.0.0.0/16`). Dos equipos lo hacen a la vez → colisión asegurada.

---

## 3. NSG: firewall stateful a nivel subnet o NIC

Un **Network Security Group (NSG)** es un firewall **stateful** (devuelve el tráfico de respuesta automáticamente) que se asocia a:

- **Una subnet entera** — todas las NICs de esa subnet heredan las reglas.
- **Una NIC individual** — más granular pero más difícil de operar.
- **Ambas** — las reglas se evalúan en orden: primero las de la NIC, luego las de la subnet. La *effective rule* por NIC es la combinación.

Elementos de una regla:

- **Priority** (100–4096): se evalúa de menor a mayor. La primera que **matchea** gana; no hay "mejor match" como en algún firewall L7.
- **Direction**: `Inbound` o `Outbound`.
- **Access**: `Allow` o `Deny`.
- **Protocol**: `Tcp`, `Udp`, `Icmp`, `Esp`, `Ah`, `*`.
- **Source** / **Destination**: `*`, un CIDR, un **service tag** (`VirtualNetwork`, `Internet`, `AzureStorage`, `AzureKeyVault`), o un **ASG** (ver §4).
- **Port**: puertos o rango.

Reglas por defecto (no se borran, se pueden sobrescribir con una prioridad menor):

- `AllowVNetInBound`, `AllowAzureLoadBalancerInBound`, `DenyAllInBound`.
- `AllowVNetOutBound`, `AllowInternetOutBound`, `DenyAllOutBound`.

Esqueleto Terraform:

```hcl
resource "azurerm_network_security_group" "app" {
  name                = "nsg-app"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_network_security_rule" "allow_https_in" {
  name                        = "AllowHTTPSIn"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.app.name
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}
```

> **Trampa habitual:** confiar en `AllowInternetOutBound` por defecto para que la app "simplemente funcione". En cuanto apliques una regla `DenyAllOutBound` para endurecer, se te caen las dependencias no mapeadas (NTP, update servers, APIs externas no documentadas). Rastrear esto en producción es doloroso.

---

## 4. ASG: agrupar NICs por rol lógico

Un **Application Security Group (ASG)** es una **etiqueta** que se asigna a NICs. Permite escribir reglas NSG como "desde `asg-web`, hacia `asg-app`, puerto 8080" sin listar IPs.

Ventajas sobre listar CIDRs:

- **Escala**: si añades 10 VMs al tier `app`, las metes en el ASG y las reglas no cambian.
- **Legibilidad**: `source_application_security_group_ids = [asg-web.id]` es más autoexplicativo que `source_address_prefixes = ["10.10.1.0/24"]`.
- **Independencia del CIDR**: puedes re-numerar la subnet sin tocar las reglas si usan ASGs.

Patrón canónico tiered app (web → app → db):

```
                     ┌─────────────┐
                     │  Internet   │
                     └──────┬──────┘
                            │ 443
                            ▼
       ┌─────── NSG ──────────────────────────┐
       │  Allow Internet → asg-web :443       │
       │  Allow asg-web → asg-app :8080       │
       │  Allow asg-app → asg-db  :5432       │
       │  Deny  *  → asg-db *                 │
       └──────────────────────────────────────┘
            │             │             │
         ┌──▼──┐       ┌──▼──┐       ┌──▼──┐
         │ web │       │ app │       │ db  │
         │ NIC │       │ NIC │       │ NIC │
         │ ASG │       │ ASG │       │ ASG │
         │=web │       │=app │       │=db  │
         └─────┘       └─────┘       └─────┘
```

HCL:

```hcl
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

resource "azurerm_network_security_rule" "web_to_app" {
  name                                       = "AllowWebToApp"
  priority                                   = 200
  direction                                  = "Inbound"
  access                                     = "Allow"
  protocol                                   = "Tcp"
  source_port_range                          = "*"
  destination_port_range                     = "8080"
  source_application_security_group_ids      = [azurerm_application_security_group.web.id]
  destination_application_security_group_ids = [azurerm_application_security_group.app.id]
  resource_group_name                        = azurerm_resource_group.main.name
  network_security_group_name                = azurerm_network_security_group.app.name
}
```

> **Equivalencia AWS:** Security Group AWS es stateful y referenciable como fuente/destino en otras reglas — el mismo patrón que ASG + NSG, pero combinado en una pieza. En Azure la pieza se descompone: ASG = agrupación de NICs, NSG = reglas que las referencian.

---

## 5. Service Endpoints vs Private Endpoints: por qué Private Link gana

Problema: una VM en una subnet quiere leer un **Storage Account**. Opciones:

1. **Public endpoint + firewall de Storage** (restringir por IP). Tráfico sale a internet y vuelve. Mala para compliance y mala para latencia.
2. **Service Endpoint**: una extensión del *service tag* `AzureStorage` que, al activarla en la subnet, hace que el tráfico salga por una **ruta optimizada de la red de Azure** (no internet pública). **Sigue** usando el endpoint público del servicio pero con origen identificable. Útil, pero obsolescente en patrones modernos.
3. **Private Endpoint** (parte de **Azure Private Link**): se crea una **NIC virtual dentro de tu VNet** con una **IP privada** que apunta al servicio PaaS. El servicio pasa a ser alcanzable **solo** por esa IP privada. No hay egress a internet, no hay firewall de Storage que mantener, y el DNS resuelve el nombre del servicio (`mystorage.blob.core.windows.net`) a la IP privada via **Private DNS Zone**.

Comparativa:

| Dimensión | Service Endpoint | Private Endpoint |
|-----------|------------------|------------------|
| Dónde vive | Config de subnet | NIC real en la VNet |
| IP | Pública del servicio | Privada en la VNet |
| DNS | Público, apunta a IP pública | Overridden via Private DNS Zone |
| Cross-region | No | Sí (via peering) |
| Cross-tenant | No | Sí (shared PE) |
| Coste | Gratis | Por hora + por GB |
| Compliance | Mejor que público | **El estándar moderno** |

**Regla práctica:** para cualquier servicio PaaS que soporte Private Endpoint y en workloads con cualquier requisito de compliance → **Private Endpoint**. Service Endpoint queda para casos legacy o puramente de laboratorio.

Esqueleto Terraform de Private Endpoint a un Storage Account:

```hcl
resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-storage-blob"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.pe.id

  private_service_connection {
    name                           = "psc-storage-blob"
    private_connection_resource_id = azurerm_storage_account.main.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob.id]
  }
}

resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.main.name
}
```

Importantísimo: el **Private DNS Zone** debe estar **linkeada a cada VNet** que resuelva el nombre, con un `azurerm_private_dns_zone_virtual_network_link`. Si falta ese link, el nombre `*.blob.core.windows.net` sigue resolviendo a la IP pública y rompe la ilusión.

---

## 6. Private DNS Zones: la pieza silenciosa que todo lo pega

Cada servicio PaaS con Private Link tiene su **zona** canónica:

| Servicio | Zona privada |
|----------|-------------|
| Blob Storage | `privatelink.blob.core.windows.net` |
| File Storage | `privatelink.file.core.windows.net` |
| Key Vault | `privatelink.vaultcore.azure.net` |
| Azure SQL | `privatelink.database.windows.net` |
| Postgres Flexible | `privatelink.postgres.database.azure.com` |
| Container Registry | `privatelink.azurecr.io` |
| Cosmos (SQL API) | `privatelink.documents.azure.com` |

Flujo mental:

```
       cliente (VM en VNet-A)
                │  nslookup mystorage.blob.core.windows.net
                ▼
     Azure DNS (168.63.129.16)
                │
                ▼
  ¿Existe privatelink.blob.core.windows.net linkeada a VNet-A?
     SÍ → devuelve IP privada del Private Endpoint (10.10.2.4)
     NO → devuelve IP pública del servicio (sales a internet)
```

En Hub-Spoke, el patrón habitual es: **las Private DNS Zones viven en el hub** y se linkean a hub + todos los spokes. Así, cualquier recurso de cualquier spoke resuelve correctamente los PEs sin que cada equipo deba montar sus zonas.

> **Trampa habitual:** crear el Private Endpoint pero olvidar el `private_dns_zone_group` o el link al VNet. El PE existe, la conexión existe, pero el nombre resuelve a la IP pública y "no cambia nada". Debuggear esto en un ticket es el 60 % del dolor con Private Link.

---

## 7. NAT Gateway: egress controlado y determinista

Por defecto, una subnet con NSG permisivo tiene **egress a internet** vía un **public outbound** administrado por Azure. Problema: la IP origen es dinámica (SNAT masquerade) y puede cambiar; APIs externas que requieran IP allowlisting no funcionan.

**NAT Gateway** da:

- Una (o varias) **IP pública estática** como origen SNAT para todas las VMs de las subnets asociadas.
- Más **puertos SNAT** disponibles que el default (importante en workloads con muchas conexiones salientes).
- Alta disponibilidad zonal.

Patrón: en una subnet `snet-app`, el egress a internet "limpio" pasa por NAT Gateway; el egress a servicios PaaS pasa por Private Endpoints (sin tocar NAT porque es tráfico privado dentro de la VNet).

```hcl
resource "azurerm_public_ip" "nat" {
  name                = "pip-nat"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "main" {
  name                    = "nat-main"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}

resource "azurerm_nat_gateway_public_ip_association" "nat" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "app" {
  subnet_id      = azurerm_subnet.app.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}
```

> **Equivalencia AWS:** NAT Gateway de AWS es idéntico en concepto (SNAT con IP estática). La diferencia es que en Azure vive a nivel subnet-asociada, no en una subnet pública dedicada.

---

## 8. VNet Peering: conectar VNets sin solapamiento

**VNet Peering** conecta dos VNets de la **misma región** (regional peering) o de **regiones distintas** (global peering) con **tráfico privado** y **baja latencia**. Características:

- **Bidireccional**: hay que crear el peering en **ambos lados**. Si solo lo creas en uno, no fluye.
- **Non-transitive**: si A ↔ B y B ↔ C, entonces A **no** habla con C por defecto. Esto es la base para que el patrón Hub-Spoke no permita "spoke-A hablando directo con spoke-B" sin pasar por el hub.
- **No puede haber solapamiento de CIDR** entre las VNets. Esto obliga a un plan CIDR previo (§2).
- **Settings** importantes:
  - `allow_virtual_network_access` (true normalmente).
  - `allow_forwarded_traffic` (true si el hub reenvía tráfico — p. ej. a través de Azure Firewall).
  - `allow_gateway_transit` (true en el hub, para que los spokes usen el VPN/ExpressRoute del hub).
  - `use_remote_gateways` (true en los spokes, para consumir el gateway del hub).

HCL:

```hcl
resource "azurerm_virtual_network_peering" "hub_to_spoke_a" {
  name                      = "peer-hub-to-spoke-a"
  resource_group_name       = azurerm_resource_group.hub.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_a.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = true
}

resource "azurerm_virtual_network_peering" "spoke_a_to_hub" {
  name                      = "peer-spoke-a-to-hub"
  resource_group_name       = azurerm_resource_group.spoke_a.name
  virtual_network_name      = azurerm_virtual_network.spoke_a.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  use_remote_gateways       = true
}
```

> **Trampa habitual:** olvidar que el peering es bidireccional y pasarse una hora debugueando por qué "spoke no ve hub". Siempre dos recursos de peering, siempre.

---

## 9. Hub-Spoke: el patrón regional estándar

El **Hub-Spoke** es la topología de referencia Azure para separar **servicios compartidos** (hub) de **workloads** (spokes).

```
                    ┌──────────────────────────┐
                    │          HUB VNet         │
                    │  10.0.0.0/22              │
                    │                           │
                    │  AzureFirewallSubnet      │
                    │  GatewaySubnet (VPN/ER)   │
                    │  Private DNS Zones        │
                    │  Bastion                  │
                    └──────┬────────┬───────────┘
                           │        │
          peering          │        │          peering
      ┌────────────────────┘        └────────────────────┐
      ▼                                                   ▼
┌──────────────────┐                            ┌──────────────────┐
│  Spoke A         │                            │  Spoke B         │
│  checkout-prod   │                            │  analytics       │
│  10.1.0.0/16     │       sin peering          │  10.3.0.0/16     │
│                  │   (non-transitive)         │                  │
│  snet-app        │                            │  snet-data       │
│  snet-pe         │                            │  snet-pe         │
└──────────────────┘                            └──────────────────┘
```

Lo que va en el hub:

- **Azure Firewall** (o NVA): inspección L4/L7 del tráfico entre spokes y hacia internet.
- **VPN Gateway / ExpressRoute**: conectividad on-premises centralizada.
- **Azure Bastion**: SSH/RDP a VMs de los spokes sin IPs públicas.
- **Private DNS Zones**: linkeadas al hub y a cada spoke, para que todos resuelvan Private Endpoints igual.
- **Shared services** opcionales: Container Registry central con PE, servidores de identidad, etc.

Lo que va en cada spoke:

- Un workload (o grupo pequeño de workloads relacionados).
- Sus NSGs, ASGs, PEs específicos.
- **Nada que deba ser compartido** con otros spokes a nivel red.

Reglas de oro:

1. **Spokes no se peerean entre sí.** Si necesitan hablar, van vía el hub (Azure Firewall decide).
2. **CIDR plan global**: cada spoke tiene su propio rango no-solapado; el hub también.
3. **DNS centralizado en el hub** (Private DNS Zones linkeadas por `azurerm_private_dns_zone_virtual_network_link`).
4. **Governance en el hub**: policies, logging, Firewall rules — operadas por el equipo de plataforma, no por los equipos de workload.

Cuándo **no** usar Hub-Spoke:

- Un solo workload — hub-spoke es overkill, una VNet basta.
- Más de ~50 spokes o conectividad any-to-any compleja — subir a **Azure Virtual WAN** (hub as a service con mesh gestionada).

> **Equivalencia AWS:** el hub es el análogo de un **Transit Gateway** con una VPC *shared services*. En Azure la pieza es más explícita (una VNet real) y menos service-managed, lo que da más control y más trabajo operativo.

---

## 10. Load Balancing: L4 (LB) vs L7 (AGW) vs global (Front Door)

Las tres piezas de balanceo que coexisten en Azure:

| Pieza | Capa | Scope | Cuándo |
|-------|------|-------|--------|
| **Azure Load Balancer** | L4 (TCP/UDP) | Regional | Tráfico interno TCP, backends VM/VMSS, pass-through. |
| **Application Gateway** | L7 (HTTP) | Regional | HTTP routing, path-based, host-based, **WAF** opcional. |
| **Front Door** | L7 (HTTP) | Global (anycast) | Multi-region, CDN, WAF global, SSL termination en el edge. |

Patrones típicos:

- API interna entre spokes: **Internal Load Balancer** (L4) en el hub o en el spoke.
- App web pública con una región: **Application Gateway + WAF** delante.
- App web pública multi-región con failover y edge caching: **Front Door** delante de Application Gateways regionales.

Este módulo **no** profundiza en el config de las piezas — se cubren en `az-04` (Container Apps lleva ingress propio) y en módulos avanzados. Lo que debes retener aquí: **no pongas tu app pública con una IP pública directa en una VM**; mete siempre al menos un LB/AGW/FD delante.

---

## 11. Fundamentos internos (lo que suele doler)

Cinco cosas que **no se intuyen** y conviene fijar:

1. **La *effective rule* por NIC es la unión de NSG-de-NIC + NSG-de-subnet.** Si tienes una regla `Allow` en la NIC y una `Deny` en la subnet para el mismo tráfico, el `Deny` gana si tiene prioridad menor. Hay un cálculo explícito que puedes pedir con `az network nic list-effective-nsg --name <nic>`; úsalo cuando dudes.
2. **Las reglas default no se borran, se sobrescriben.** `AllowInternetOutBound` con prioridad 65001 — si quieres bloquear egress a internet, añade `DenyInternetOutBound` con prioridad < 65001. Olvidar esto es el bug "mi NSG dice deny pero sale igual".
3. **Peering ≠ transitividad.** A ↔ B ↔ C no implica A ↔ C. Para que A hable con C hace falta **routing explícito** vía Azure Firewall / NVA en B (que es exactamente lo que hace Hub-Spoke).
4. **Private DNS Zones son recursos independientes** del Private Endpoint. Puedes crear el PE sin la zona (y el DNS fallará) o crear la zona sin PE (y resolver nombres a nada). El `private_dns_zone_group` del PE **registra automáticamente** el A record cuando creas el PE con esa zona asociada — pero solo si la zona está linkeada a la VNet correcta.
5. **Service Endpoints y Private Endpoints coexisten pero son excluyentes conceptualmente.** Si activas ambos para el mismo servicio en la misma subnet, lo que gana es… ambiguo según servicio. Elige uno (y en 2026 ese uno es **Private Endpoint**).

---

## 12. Alternativas y qué llevarse

### Alternativas a Hub-Spoke clásico

- **Flat (una sola VNet grande)**: aceptable para 1–2 workloads pequeños. No escala; no da separación operativa.
- **Virtual WAN**: hub como *servicio gestionado* con mesh entre hubs regionales y conectividad SD-WAN integrada. Mejor para multi-región y >50 spokes; peor en flexibilidad y en coste base.
- **Mesh de peerings sin hub**: cada VNet peereada con todas las demás. O(N²) peerings; ingobernable rápidamente.

### Alternativas a Private Endpoint

- **Service Endpoint**: válido para experimentos y para servicios sin soporte de PE todavía. Pierde en compliance y en DNS.
- **Public endpoint + firewall del servicio con IP allowlist**: solo si el servicio no soporta PE y la VNet tiene IPs públicas estables (NAT Gateway).

### Qué llevarse en una frase

> La VNet es la unidad de red regional. **NSG + ASG** son el firewall por rol lógico. **Private Endpoint + Private DNS Zone** eliminan egress por internet a PaaS. **Hub-Spoke** separa servicios compartidos (hub) de workloads (spokes) con peerings bidireccionales y non-transitivos. Un plan CIDR previo evita el 80 % del dolor futuro.

### Qué sigue

- `az-04` — Container Apps, VMSS, Functions: todos consumen VNets, subnets delegadas y Private Endpoints de este módulo.
- `az-05` — Postgres Flexible, Storage y Cosmos — todos con Private Endpoint como camino moderno.
- `az-06` — Key Vault consumido vía Managed Identity + Private Endpoint.
