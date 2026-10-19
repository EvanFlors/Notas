# Ejemplo 03 — Transit Gateway hub-and-spoke vs peering 1:1

> Lectura y análisis. **No se aplica** (TGW cobra por attachment-hora y GB).

## 1. El problema que resuelve TGW

Con 5 VPCs completamente malladas vía peering: `5*(5-1)/2 = 10` peerings y 10 route-tables tocadas. Con 10 VPCs: 45 peerings. Peor: peering **no es transitivo**, así que no puedes "ir por un hub".

```
   Antes (peering 1:1 mallado, 5 VPCs = 10 peerings)

        VPC-A ─────── VPC-B
         │  ╲        ╱  │
         │   ╲      ╱   │
         │    ╲    ╱    │
        VPC-E ─ VPC-C ─ VPC-D
         │       │       │
         └───────┴───────┘   (y asi hasta 10 peerings y 10 route tables)
```

Con Transit Gateway, cada VPC se "attachea" **una vez** al hub:

```
   Despues (TGW hub-and-spoke, 5 attachments)

           ┌─────────────────────┐
           │   Transit Gateway    │
           │   (route tables:     │
           │    - prod            │
           │    - nonprod         │
           │    - shared)         │
           └─────────────────────┘
             ▲    ▲    ▲    ▲    ▲
             │    │    │    │    │
          VPC-A  VPC-B VPC-C VPC-D VPC-E
```

## 2. Fragmento Terraform (anotado)

```hcl
# El hub.
resource "aws_ec2_transit_gateway" "hub" {
  description                     = "Hub de conectividad regional"
  default_route_table_association = "disable"  # queremos tablas custom
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "enable"   # para RAM cross-account
}

# Dos route tables: una para prod, otra para shared services.
resource "aws_ec2_transit_gateway_route_table" "prod" {
  transit_gateway_id = aws_ec2_transit_gateway.hub.id
  tags = { Name = "tgw-rt-prod" }
}

resource "aws_ec2_transit_gateway_route_table" "shared" {
  transit_gateway_id = aws_ec2_transit_gateway.hub.id
  tags = { Name = "tgw-rt-shared" }
}

# Attachment de VPC-A (ejemplo).
resource "aws_ec2_transit_gateway_vpc_attachment" "vpc_a" {
  transit_gateway_id = aws_ec2_transit_gateway.hub.id
  vpc_id             = aws_vpc.a.id
  subnet_ids         = aws_subnet.a_tgw[*].id  # subnet dedicada /28 por AZ

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
}

# VPC-A pertenece al "segmento prod": se asocia a esa route table...
resource "aws_ec2_transit_gateway_route_table_association" "vpc_a_prod" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_a.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod.id
}

# ...y PROPAGA sus prefijos a la route table de shared (asi los shared services ven a A).
resource "aws_ec2_transit_gateway_route_table_propagation" "vpc_a_to_shared" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.vpc_a.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.shared.id
}

# En la route table de la VPC-A, ruta por default al TGW para los CIDRs del hub.
resource "aws_route" "a_to_tgw" {
  route_table_id         = aws_route_table.a_private.id
  destination_cidr_block = "10.0.0.0/8"  # supra-CIDR del network segment
  transit_gateway_id     = aws_ec2_transit_gateway.hub.id
}
```

## 3. Puntos a leer con cuidado

1. **Default association/propagation disabled**: si lo dejas en `enable`, todo attachment va a parar a la *default route table* del TGW y todos se ven entre sí. Para segmentación (prod ≠ dev) necesitas tablas custom y asociar/propagar explícitamente.
2. **Asociación vs propagación**: *asociar* un attachment a una route table decide **qué tabla usa ese attachment** para enrutar (una sola asociación por attachment). *Propagar* decide **a qué tablas se anuncian** los prefijos del attachment (muchas posibles). Son conceptos distintos y mezclarlos es la fuente #1 de "no me pasa el ping".
3. **Subnets de attachment**: AWS recomienda **una subnet dedicada /28 por AZ** solo para el attachment TGW. No metas allí workloads.
4. **Coste**: ~$0.05/attachment-hora + $0.02/GB (US). Con 10 attachments y 1 TB/mes: ~$360 + $20 = $380/mes. **Diseña bien antes de encender.**
5. **Cross-account vía RAM**: `aws_ram_resource_share` + `aws_ram_resource_association` del TGW permite que cuentas distintas attacheen sus VPCs al mismo hub.
6. **Inter-región**: TGW peering TGW-a-TGW; dos hubs, uno por región, interconectados. No es gratis.

## 4. Alternativa decisión

| Escenario | Elige |
|-----------|-------|
| 2 VPCs, siempre serán 2 | **Peering**. TGW es overkill y cobra fijo. |
| 3–4 VPCs, estables, pocos cambios | **Peering** aún viable; evalúa si crecerás. |
| 5+ VPCs, roadmap de crecer | **TGW**. Fórmula N² dolerá. |
| Multi-cuenta con shared services centralizados | **TGW + RAM**. |
| Multi-región enterprise con política global | **Cloud WAN**. |

## 5. Qué no vemos aquí

- **Blackhole routes** para bloquear tráfico entre segmentos aún sin SGs.
- **TGW Flow Logs** a S3/CloudWatch — observabilidad del hub.
- **Appliance VPC** (firewall en una VPC dedicada que inspecciona todo el tráfico este-oeste del TGW).
