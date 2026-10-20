# Ejemplo 03 — S3 Gateway Endpoint: por qué es gratis y cómo evita NAT

> Lectura y razonamiento numérico. **Sin despliegue.**

## 1. Problema

Una app corre en subnet privada. Hace `aws s3 cp` de 500 GB/mes a un bucket S3 en la **misma región**. Sin endpoint, el flujo es:

```
app (10.0.1.x)
  -> rt-private  (0.0.0.0/0 -> nat-a)
  -> NAT Gateway (10.0.0.x, IP publica elástica)
  -> IGW
  -> Internet (pero realmente a la red AWS)
  -> endpoint publico de S3 (s3.us-east-1.amazonaws.com)
```

Cada byte pasa por el NGW. Cobro: **$0.045/GB procesado**.

- 500 GB × $0.045 = **$22.5/mes** solo en NAT processing.
- Más la hora base del NGW: $0.045 × 24 × 30 ≈ **$32.4/mes**.

## 2. Con S3 Gateway endpoint

Añades un recurso `aws_vpc_endpoint` tipo Gateway y lo asocias a la(s) route table(s) privada(s). AWS inyecta automáticamente una ruta:

```
pl-xxxxxxx (prefix-list de S3 en la región) -> vpce-xxx
```

Como el *prefix match* más específico gana, el tráfico a S3 ya no usa la ruta `0.0.0.0/0 -> nat`. Flujo nuevo:

```
app (10.0.1.x)
  -> rt-private  (match: pl-S3 -> vpce-xxx)
  -> S3 (dentro de la red AWS, sin salir por NAT)
```

Precio del Gateway endpoint: **$0.00/h** y **$0.00/GB**.

## 3. ¿Por qué AWS lo da gratis?

Porque sin él, AWS cobraría doble: tú pagas NAT por bytes que **ya están** dentro de la red AWS y jamás salen a Internet real. El Gateway endpoint es una concesión racional de AWS para no cobrar peaje por tráfico interno.

El Interface endpoint (ENI con IP interna, para el resto de servicios) **sí** cuesta porque requiere infraestructura dedicada por AZ.

## 4. Terraform (fragmento)

```hcl
data "aws_vpc_endpoint_service" "s3" {
  service      = "s3"
  service_type = "Gateway"
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = data.aws_vpc_endpoint_service.s3.service_name
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id
  tags              = { Name = "s3-gw-endpoint" }
}
```

Observa `route_table_ids`: hay que asociarlo a **todas** las RTs privadas donde quieres que el shortcut aplique. Olvidar una AZ es un bug típico (una AZ sigue pagando NAT).

## 5. Trampa habitual

Un bucket **cross-region** (`eu-west-1` desde una VPC en `us-east-1`) **no** cae en el prefix-list regional. El Gateway endpoint es por región. Si realmente necesitas S3 de otra región, pagas egress inter-region por NAT igualmente — eso es un cost smell: casi siempre lo correcto es replicar el bucket a tu región.

## 6. Resumen numérico

| Escenario                            | Coste mensual aprox. |
|--------------------------------------|----------------------|
| 500 GB S3 por NAT                    | ~$22.5 + hora NGW    |
| 500 GB S3 por S3 Gateway endpoint    | $0 (procesamiento)   |
| 500 GB S3 por NAT en 3 AZ            | ×3 si cross-AZ       |

Primera optimización de VPC con endpoints, siempre: **el Gateway endpoint de S3**. Es dinero regalado.
