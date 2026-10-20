# Topología Hub-Spoke — `westeurope`, 1 hub + 2 spokes

## Plan CIDR

| Red | CIDR | Rol |
|-----|------|-----|
| `vnet-hub` | `10.0.0.0/22` | Servicios compartidos (DNS, Firewall futuro, Bastion futuro, Gateway VPN futuro) |
| `vnet-spoke-a` | `10.1.0.0/16` | Workload `checkout` |
| `vnet-spoke-b` | `10.2.0.0/16` | Workload `analytics` |
| Reservado `spoke-c` | `10.3.0.0/16` | Para el próximo workload |
| Reservado `shared-services` | `10.4.0.0/16` | ACR central / tooling en el futuro |

Elegimos un **`/22` para el hub** porque las subnets especiales son `/26` y `/27` (pequeñas) y no se espera meter workloads allí. Los spokes toman `/16` porque un `/16` da margen para 250+ subnets `/24`, suficientes para el crecimiento de un workload sin re-numerar.

## Diagrama

```
                    ┌──────────────────────────────────────────┐
                    │             vnet-hub  10.0.0.0/22         │
                    │                                           │
                    │   AzureFirewallSubnet   10.0.0.0/26       │
                    │   GatewaySubnet         10.0.0.64/27      │
                    │   AzureBastionSubnet    10.0.0.96/27      │
                    │                                           │
                    │   Private DNS Zones (en RG hub):          │
                    │     privatelink.blob.core.windows.net     │
                    │     privatelink.vaultcore.azure.net       │
                    │                                           │
                    └────┬──────────────────────┬───────────────┘
                         │  peer-hub-to-spoke-a │  peer-hub-to-spoke-b
                         │  (fwd+gwt)           │  (fwd+gwt)
                         │                      │
                         │  peer-spoke-a-to-hub │  peer-spoke-b-to-hub
                         │                      │
          ┌──────────────▼──────────┐  ┌────────▼──────────────┐
          │   vnet-spoke-a           │  │   vnet-spoke-b         │
          │   checkout  10.1.0.0/16  │  │   analytics 10.2.0.0/16│
          │                          │  │                        │
          │   snet-app  10.1.1.0/24  │  │   snet-data 10.2.1.0/24│
          │   snet-pe   10.1.2.0/27  │  │   snet-pe   10.2.2.0/27│
          └──────────────────────────┘  └────────────────────────┘

          << NO existe peering spoke-a <-> spoke-b >>
          (Non-transitividad: A<->B y B<->C no implica A<->C)

          DNS link del hub a los 3 VNets:
             link-blob-vnet-hub     -> vnet-hub
             link-blob-vnet-spoke-a -> vnet-spoke-a
             link-blob-vnet-spoke-b -> vnet-spoke-b
```

## Flujo de tráfico

### Caso 1 — VM en `spoke-a` lee Blob Storage via Private Endpoint (en `spoke-a`)

1. La VM hace `nslookup mystorage.blob.core.windows.net`.
2. Azure DNS consulta las zonas privadas linkeadas a `vnet-spoke-a`. Encuentra `privatelink.blob.core.windows.net` (linkeada desde el hub) y responde con la IP privada del PE: `10.1.2.4`.
3. La VM abre TCP 443 contra `10.1.2.4`. El tráfico queda **dentro de `vnet-spoke-a`** — no cruza peering ni sale a internet.

### Caso 2 — VM en `spoke-a` quiere hablar con una VM en `spoke-b`

1. La VM intenta `10.2.1.5`.
2. **No hay peering spoke-a ↔ spoke-b** → no hay ruta → timeout.
3. **Habilitación futura (no implementada hoy)**:
   - Desplegar Azure Firewall en `AzureFirewallSubnet` del hub.
   - En `vnet-spoke-a`, crear un `azurerm_route_table` con `0.0.0.0/0 → next_hop = VirtualAppliance (10.0.0.4)` (IP del Firewall).
   - Mismo en `vnet-spoke-b`.
   - El peering ya tiene `allow_forwarded_traffic = true` desde el hub, por lo que el hub puede reenviar.
   - El Firewall decide (via policy) si permite o no `spoke-a → spoke-b`.

Esto es exactamente el valor del patrón Hub-Spoke: la **policy de cross-spoke vive centralizada en el hub**, no dispersa por N peerings.

## Non-transitividad y `spoke-a` ↔ `spoke-b`

El peering de Azure es **no-transitivo** por diseño. Que `vnet-hub` ↔ `vnet-spoke-a` y `vnet-hub` ↔ `vnet-spoke-b` existan **no** implica que `vnet-spoke-a` pueda hablar con `vnet-spoke-b`.

Esto es una **feature**, no una limitación:

- Impide que cualquier spoke "descubra" por accidente a otro.
- Fuerza a canalizar todo tráfico cross-spoke por el hub, donde el equipo de red impone política (Firewall, logging, inspección).
- Simplifica auditoría: todas las conversaciones inter-workload pasan por un punto donde se registran.

Habilitarlo requiere, como se explicó arriba, un **NVA / Azure Firewall** en el hub + **UDRs** en los spokes. Nunca se hace añadiendo peering directo spoke-a ↔ spoke-b (eso rompe el modelo).

## Decisiones de peering

| Setting | Hub → Spoke | Spoke → Hub | Por qué |
|---------|-------------|-------------|---------|
| `allow_virtual_network_access` | `true` | `true` | Permite la comunicación básica, obvio. |
| `allow_forwarded_traffic` | **`true`** | `false` | El hub reenvía tráfico desde/hacia otros spokes vía Firewall; los spokes no reenvían. |
| `allow_gateway_transit` | **`true`** | `false` | El hub expone su (futuro) VPN/ExpressRoute Gateway al spoke. Solo el hub lo expone. |
| `use_remote_gateways` | `false` | **hoy `false`, futuro `true`** | Cuando el hub tenga un Gateway desplegado, los spokes lo consumirán. Hoy no hay Gateway → mantenerlo `true` **bloquearía el peering**. |

Lección importante: **`use_remote_gateways = true` sin un Gateway en el hub rompe el peering**. Hay que activarlo *después* de desplegar el Gateway, no antes.

## Qué llevarse

- 4 peerings (2 por par) + 3 links DNS (1 por VNet) para cubrir hub + 2 spokes con una sola zona centralizada.
- `AzureFirewallSubnet` y `GatewaySubnet` reservados por nombre literal — Azure los exige para desplegar Firewall / VPN Gateway en el futuro.
- Spokes aislados entre sí por **diseño** (non-transitividad); el día que necesiten hablar, se habilita policy en el hub.
- CIDR plan con rangos no-solapados, dejando huecos para los próximos workloads (`10.3`, `10.4`).
