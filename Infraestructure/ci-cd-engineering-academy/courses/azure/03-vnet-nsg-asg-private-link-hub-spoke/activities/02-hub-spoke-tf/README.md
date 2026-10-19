# Actividad 02 — Hub-Spoke mínimo en Terraform + diagrama ASCII

## 1. Identificación

- **ID:** `az-03-02-hub-spoke-tf`
- **Tecnología:** `azure`
- **Módulo:** `az-03-vnet-nsg-asg-private-link-hub-spoke`
- **Dificultad:** intermediate
- **Duración estimada:** 80–100 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

El equipo de Platform quiere preparar la base de red para **dos workloads** (`checkout` y `analytics`) que, en 3 meses, convivirán en Azure. Dos requisitos no negociables de la revisión arquitectónica:

- **Centralización** de piezas comunes (DNS, Firewall futuro, Bastion futuro) en una VNet "hub".
- **Aislamiento** entre workloads: `analytics` **no** debe poder hablar con `checkout` sin pasar por una política explícita del equipo de red (que vivirá en el hub).

Tu encargo: **escribir el Terraform** de la topología Hub-Spoke mínima (1 hub + 2 spokes) con los peerings bidireccionales correctos y al menos una Private DNS Zone centralizada en el hub, y producir un **`TOPOLOGY.md`** con un diagrama ASCII explicando el flujo de tráfico y por qué los spokes **no** se peerean entre sí.

**Importante**: no hay suscripción Azure real. Solo HCL + diagrama. Validación estructural + opcional `terraform validate` sin credenciales.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Dividir el HCL en 4 archivos lógicos (`hub.tf`, `spoke-a.tf`, `spoke-b.tf`, `peering.tf`) para que un equipo nuevo encuentre las piezas rápido.
- Explicar por qué el peering es bidireccional y qué significan `allow_forwarded_traffic`, `allow_gateway_transit`, `use_remote_gateways`.
- Centralizar una Private DNS Zone en el hub y linkearla a los 3 VNets (hub + 2 spokes).
- Diseñar un plan CIDR sin solapamientos entre hub (`/22` suele bastar) y spokes (`/16` cada uno).
- Argumentar por qué los spokes no se peerean entre sí y cómo se habilitaría ese tráfico vía rutas en el hub (sin implementarlas aquí).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` secciones 8–9 (Peering + Hub-Spoke).
- Haber recorrido `examples/03-hub-spoke-skeleton`.
- Herramientas: `bash`, `terraform` ≥ 1.5 (opcional), editor Markdown.

**Costos**: ninguno. Nada se despliega.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/az-03-02-hub-spoke
cd /tmp/az-03-02-hub-spoke
```

### 5.2 Escribe el Terraform

Produce **5 archivos** HCL:

- `providers.tf` — `terraform { required_providers {...} }` + `provider "azurerm" { features {} }`.
- `hub.tf` — RG hub + `vnet-hub` + al menos las subnets `AzureFirewallSubnet` y `GatewaySubnet` (nombres obligatorios) + al menos una Private DNS Zone.
- `spoke-a.tf` — RG spoke-a + `vnet-spoke-a` + al menos una subnet.
- `spoke-b.tf` — RG spoke-b + `vnet-spoke-b` + al menos una subnet.
- `peering.tf` — los **4 peerings** (hub↔spoke-a: 2 recursos; hub↔spoke-b: 2 recursos) + los **3 links** de la Private DNS Zone a hub, spoke-a y spoke-b.

Requisitos de contenido (el validador los exige):

1. **Provider azurerm** declarado con `features {}` sin IDs reales.
2. **3 `azurerm_virtual_network`**: una por hub y una por cada spoke.
3. **CIDRs sin solapamiento**: hub debe ser distinto de ambos spokes, y los dos spokes distintos entre sí.
4. **Subnets especiales en el hub**: al menos `AzureFirewallSubnet` y `GatewaySubnet` (nombres literales exactos; Azure los exige para desplegar Firewall / VPN Gateway en el futuro).
5. **4 `azurerm_virtual_network_peering`**:
   - `hub → spoke-a` con `allow_forwarded_traffic = true` y `allow_gateway_transit = true`.
   - `spoke-a → hub`.
   - `hub → spoke-b` con `allow_forwarded_traffic = true` y `allow_gateway_transit = true`.
   - `spoke-b → hub`.
6. **No** debe existir peering `spoke-a ↔ spoke-b` (comprobable por ausencia).
7. **Al menos una `azurerm_private_dns_zone`** en el RG del hub con nombre `privatelink.*`.
8. **3 `azurerm_private_dns_zone_virtual_network_link`**: uno a hub, uno a spoke-a, uno a spoke-b.
9. **Ningún GUID real** en los archivos (misma regla que la actividad 01).

### 5.3 Escribe `TOPOLOGY.md`

Formato libre pero con secciones mínimas:

```
# Topologia Hub-Spoke — <nombre descriptivo>

## Plan CIDR
(tabla con hub + spokes y rangos; justificar)

## Diagrama
(dentro de code fence; mostrar hub + 2 spokes + peerings + Private DNS Zone)

## Flujo de trafico
(que ruta sigue una peticion desde una VM en spoke-a a Storage expuesta via PE en spoke-a; y una peticion de spoke-a a algo en spoke-b, explicando por que hoy no funciona)

## Non-transitividad y spoke-a <-> spoke-b
(por que no hay peering directo; que se necesitaria para habilitarlo via hub, mencionando Azure Firewall o NVA y UDRs)

## Decisiones de peering
(por que allow_forwarded_traffic y allow_gateway_transit en el hub, por que use_remote_gateways se deja a false hoy)
```

Contenido mínimo que el validador busca:

- Un diagrama ASCII en code fence.
- Las palabras `hub`, `spoke`, `peering`, `non-transit`, `Firewall`.
- Mención de `allow_forwarded_traffic` y `allow_gateway_transit`.
- Al menos una tabla o lista de CIDRs tipo `10.X.0.0/XX`.

### 5.4 Entregables

```
/tmp/az-03-02-hub-spoke/
├── providers.tf
├── hub.tf
├── spoke-a.tf
├── spoke-b.tf
├── peering.tf
└── TOPOLOGY.md
```

## 6. Resultado esperado

- Los 6 archivos existen.
- El validador pasa en verde.
- (Opcional) `terraform init -backend=false && terraform validate` corre sin errores.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Correctness**: 4 peerings presentes y simétricos; 3 links DNS; subnets especiales con nombres exactos.
- **Reproducibilidad**: cualquier ingeniero puede leer `TOPOLOGY.md` y entender dónde cuelga qué sin abrir el HCL.

## 8. Validación

```bash
bash tests/validate.sh /tmp/az-03-02-hub-spoke
```

## 9. Preguntas de reflexión

1. ¿Por qué `AzureFirewallSubnet` requiere ese nombre literal?
2. Si creas solo `hub → spoke-a` y olvidas `spoke-a → hub`, ¿qué pasa cuando una VM del spoke intenta hablar con el hub?
3. ¿Por qué la Private DNS Zone vive en el hub y no se duplica por spoke?
4. ¿Qué cambia si pones `use_remote_gateways = true` en los spokes antes de desplegar un VPN Gateway en el hub?
5. ¿Cuándo migrarías de Hub-Spoke clásico a Virtual WAN?

## 10. Extensiones

- Añade un tercer spoke `spoke-c` siguiendo el patrón (debe implicar 2 peerings nuevos + 1 link DNS nuevo).
- Modela un `azurerm_route_table` en spoke-a con `0.0.0.0/0 → next_hop = VirtualAppliance` apuntando a la IP que ocuparía Azure Firewall en el hub (`10.0.0.4`, por convención).
- Añade una segunda Private DNS Zone (`privatelink.vaultcore.azure.net`) con sus 3 links.

## 11. Limpieza

```bash
rm -rf /tmp/az-03-02-hub-spoke
```
