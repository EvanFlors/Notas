# ADR 002 — Diseño de VNet para `checkout-dev` en Azure

## Estado

Propuesto (Fase 3). Objetivo: Aceptado tras revisión de Platform + Security y materializado con el Terraform de esta misma actividad en una suscripción `playground-dev` cuando la haya.

## Contexto

El workload `checkout` va a entrar en Azure empezando por el entorno `dev`. Constraints:

- **Compliance**: datos de pago (incluso en dev con datos sintéticos) exigen que ninguna conexión a Storage o Key Vault salga a internet.
- **Residencia**: `westeurope` por GDPR y por latencia a los clientes europeos.
- **Extensibilidad**: en 6 meses se añadirá `checkout-prod` como VNet separada; en 12 meses, una VNet de `shared-services` (ACR central, DNS). El plan CIDR de hoy no debe bloquearlos.
- **Operación**: equipo pequeño; preferir **ASG + NSG** sobre reglas por CIDR para minimizar re-trabajo cada vez que cambien las IPs.
- **Coste**: dev; el presupuesto está pensado para < 50 USD/mes incluyendo los Private Endpoints (unos 10 USD/mes entre los 2).

## Decisión

### 1. Plan CIDR

| Workload / entorno | VNet CIDR | Reservado para |
|---------------------|-----------|----------------|
| `checkout-dev` (esta VNet) | `10.10.0.0/16` | — |
| `checkout-stg` (futura) | `10.11.0.0/16` | — |
| `checkout-prod` (futura) | `10.12.0.0/16` | — |
| `shared-services` (futura) | `10.20.0.0/16` | ACR + DNS centralizado |
| Hub (futuro, az-03 act. 02) | `10.0.0.0/22` | Firewall + Gateway + Bastion |

Decisión: `10.10.0.0/16` para esta VNet. No se usa `10.0.0.0/16` (reservado para el hub) ni rangos "default" (`192.168.*`) para evitar colisiones con laptops y VPNs corporativas.

### 2. Subnets

| Nombre | Prefijo | Rol | Tamaño justificado |
|--------|---------|-----|-------------------|
| `snet-app` | `10.10.1.0/24` | VMs y Container Apps del workload | `/24` da 251 IPs útiles — suficiente para dev escalado |
| `snet-pe` | `10.10.2.0/27` | Private Endpoints exclusivamente | `/27` da 27 IPs útiles — basta para 10+ PEs; evita desperdicio |

**Por qué subnet dedicada para PEs**: separar reglas NSG distintas (los PE no necesitan egress a internet) y limitar el blast-radius de una NSG mal escrita.

### 3. NSG + ASG

Dos ASGs: `asg-app` (NICs del tier app) y `asg-pe` (NICs de Private Endpoints — se puede asociar por metadata/aut.).

Reglas (en `nsg-app` asociada a `snet-app`):

| Prio | Dir | Access | Protocol | Source | Dest | Puerto | Por qué |
|------|-----|--------|----------|--------|------|--------|---------|
| 100  | In  | Allow  | TCP      | `Internet` | `asg-app` | 443 | HTTP(S) a la app |
| 200  | Out | Allow  | TCP      | `asg-app`  | `asg-pe`  | 443 | Permite consumo privado de PaaS via PE |
| 300  | In  | Deny   | *        | `Internet` | `asg-pe`  | *   | Explícito aunque los PE no están en `snet-app`; defensa en profundidad para cuando se extienda el NSG |

**Por qué ASG en vez de CIDR**: dentro de 2 meses migramos la app de VMs a Container Apps y las IPs cambiarán. Con ASG las reglas no se tocan — solo se asigna el ASG a las nuevas NICs.

### 4. Private Endpoints

Dos PEs, ambos en `snet-pe`:

- `pe-storage-blob` → `stcheckoutdev<random>` subresource `blob`.
- `pe-key-vault` → `kv-checkout-dev-<random>` subresource `vault`.

Ambos servicios tienen `public_network_access_enabled = false` (Storage) y `network_acls.default_action = "Deny"` (Key Vault). El único camino de acceso es la IP privada del PE.

### 5. Private DNS Zones

Dos zonas en el mismo RG que el workload:

- `privatelink.blob.core.windows.net` linkeada a `vnet-checkout-dev`.
- `privatelink.vaultcore.azure.net` linkeada a `vnet-checkout-dev`.

**Nota de evolución**: cuando aparezca el hub (act. 02 del módulo), las zonas se moverán al RG del hub y se linkearán a hub + spokes. Hoy están "locales" porque no hay hub.

### 6. Diagrama

```
                   Internet
                      │ 443
                      ▼
┌────────────────────────── vnet-checkout-dev 10.10.0.0/16 ────────────────────┐
│                                                                               │
│   ┌─────── snet-app 10.10.1.0/24 ────────┐    ┌── snet-pe 10.10.2.0/27 ───┐   │
│   │                                       │    │                            │   │
│   │  NIC-app1    [ASG asg-app]            │    │  pe-storage-blob          │   │
│   │  NIC-app2    [ASG asg-app]            │    │   (NIC, IP 10.10.2.4)     │   │
│   │                                       │    │                            │   │
│   │  NSG nsg-app:                         │    │  pe-key-vault             │   │
│   │   100 Allow Internet->asg-app:443    │    │   (NIC, IP 10.10.2.5)     │   │
│   │   200 Allow asg-app ->asg-pe :443    │    │                            │   │
│   │   300 Deny  Internet->asg-pe  *      │    │                            │   │
│   └───────────────────────────────────────┘    └────────────────────────────┘   │
│                                                                               │
│   Private DNS Zones linkeadas:                                                │
│     privatelink.blob.core.windows.net   -> blob PE                            │
│     privatelink.vaultcore.azure.net     -> KV   PE                            │
└───────────────────────────────────────────────────────────────────────────────┘
                     │                                      │
                     ▼                                      ▼
             Storage Account                           Key Vault
             (public_network_access=false)        (network_acls default=Deny)
             Alcanzable SOLO por 10.10.2.4        Alcanzable SOLO por 10.10.2.5
```

## Consecuencias

### Positivas

- `checkout-dev` queda **sin egress a internet** para Storage ni Key Vault. Compliance satisfecho.
- El patrón ASG + NSG escala: añadir nodos no requiere tocar reglas.
- Plan CIDR deja espacio claro para `stg`, `prod` y shared-services, evitando re-numeración futura.
- La VNet está lista para peerear con un hub en `10.0.0.0/22` sin colisión.

### Negativas

- Los dos Private Endpoints cuestan ~5 USD/mes cada uno (fijo + por GB procesado). En dev es asumible; multiplicar por N workloads sí requiere budget alert.
- Dos Private DNS Zones por workload es duplicación respecto al patrón hub. Hay deuda técnica (menor) hasta que llegue el hub.
- `azurerm_key_vault` con `purge_protection_enabled = true` **no se puede borrar** antes de 7 días (soft-delete). En dev esto puede molestar en destruciones rápidas; es intencional por compliance.
- Nombres globalmente únicos (Storage, Key Vault) requieren sufijo random — el nombre real no es determinista entre `apply`s si se re-genera.

## Alternativas descartadas

### Alt A — Service Endpoints en vez de Private Endpoints

Activar `service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]` en `snet-app` y restringir el firewall de los servicios por IP de subnet.

**Por qué no**:
- El tráfico sigue saliendo al endpoint **público** del servicio (aunque por ruta optimizada); compliance quiere **IP privada en nuestra VNet**.
- No es cross-region ni cross-tenant.
- No se puede resolver vía Private DNS Zone — queda la resolución pública, que es lo que queremos eliminar.

### Alt B — Una sola subnet (`snet-app`) para todo

Mezclar NICs de la app y de los Private Endpoints en la misma subnet.

**Por qué no**:
- Rompe la separación de responsabilidades: las NSGs para apps y para PEs necesitan reglas distintas; mezclarlos obliga a reglas más laxas en una de las dos.
- Dificulta auditoría: "¿quién puede hablar con el PE?" se responde más claro si el PE vive en una subnet separada.
- Microsoft recomienda explícitamente subnet dedicada para Private Endpoints en entornos productivos.

### Alt C — Public endpoint + firewall de Storage con IP allowlist

Dejar Storage público y cerrarlo con `network_acls.ip_rules = [<ip-publica-de-la-oficina>, <nat-gateway-ip>]`.

**Por qué no**:
- Depende de IPs públicas estables, y la oficina y el NAT pueden cambiar.
- No funciona para Container Apps / Functions sin IPs estáticas.
- Deja un camino público abierto que debe ser auditado permanentemente.

### Alt D — Delegar la subnet a un servicio PaaS directamente (sin PE)

Para App Service / Container Apps hay opciones de "VNet Integration" que no usan Private Endpoint.

**Por qué no (hoy)**:
- Hoy la decisión es sobre **Storage + Key Vault**, servicios que no se delegan: la vía canónica es Private Endpoint.
- Se evaluará para la pieza compute en `az-04`.

---

## Nota sobre IDs

- `tenant_id` se obtiene con `data "azurerm_client_config" "current"` — nunca se hardcodea en el repo.
- `subscription_id` se inyecta vía la variable de entorno `ARM_SUBSCRIPTION_ID` del provider `azurerm`; nunca se hardcodea.
- Si durante pruebas locales necesitas placeholders, usa `00000000-0000-0000-0000-000000000000`.
