# aws-03 — VPC Basics (multi-AZ, SG vs NACL, endpoints)

## Identificación

- **ID:** `aws-03-vpc-basics`
- **Curso:** `aws`
- **Nivel:** fundamentos
- **Duración estimada:** 5 h
- **Prerrequisitos:** T-3 networking (CIDR, routing, L3/L4), `aws-02-iam-fundamentals`.

## Objetivo

Construir y entender una **VPC multi-AZ segura** sin encender infraestructura real. Al terminar deberías poder diseñar una VPC con **separación pública/privada**, **route tables** correctas, **Security Groups** mínimos, **NACLs** cuando toque, y usar **VPC endpoints** para evitar que todo el egress pague NAT Gateway.

## Alcance

Este módulo cubre:

- **VPC CIDR**: planificación de bloques `/16` → `/20` → `/24`, por qué AWS reserva 5 IPs por subnet, cálculo real de hosts disponibles.
- **Subnets**: la definición *operativa* de "pública" (**tiene ruta `0.0.0.0/0` a un IGW**) vs "privada" (sin IGW directo), y por qué el flag `map_public_ip_on_launch` no basta.
- **Internet Gateway (IGW)**: cómo habilita el egress para subnets públicas y por qué una sola instancia por VPC.
- **NAT Gateway vs NAT Instance**: coste real (hourly + per-GB), por qué NAT Gateway es la **fuente #1 de facturas sorpresa**, y cuándo una NAT Instance es defendible.
- **Route tables**: una por "intención de ruteo", asociación a subnets, prioridad por *longest prefix match*.
- **Security Groups (SG)**: **stateful**, allow-only, evaluación por *superunión* de reglas; por qué no requieren regla de retorno; referenciar SGs por ID.
- **NACLs**: **stateless**, allow+deny, **ordenadas por `rule_number`**, evaluación en orden; cuándo tiene sentido añadir una NACL encima del SG.
- **DNS en VPC**: `enableDnsSupport` + `enableDnsHostnames`, qué habilita cada uno.
- **VPC endpoints**:
  - **Gateway endpoints** (S3, DynamoDB): **gratis**, se añaden a la route table.
  - **Interface endpoints** (todo lo demás): pagan por hora + por GB, pero evitan egress por NAT y mantienen tráfico dentro de la red AWS.
- **Peering** (introducción): one-to-one, sin tránsito, para contexto antes de `aws-07`.

Lo que **no** cubre (se verá después):

- Transit Gateway, PrivateLink avanzado, Cloud WAN → `aws-07`.
- ALB/NLB/GWLB → `aws-07`.
- Route 53 avanzado, CloudFront, ACM → `aws-13`.

Este módulo se trabaja **sin crear recursos en AWS**. Todos los ejemplos y actividades se validan con `terraform plan` (sin `apply`), cálculos de CIDR, y revisión estructural de reglas SG/NACL y diagramas ASCII. **No se requiere cuenta AWS activa.**

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones.
- **`examples/`** — ejemplos demostrativos (lectura, `terraform plan`, no `apply`):
  - `01-vpc-multi-az-with-tf/` — VPC `/16` con 3 AZ, públicas + privadas + endpoints, revisión del plan.
  - `02-sg-vs-nacl-matrix/` — matriz de decisión Security Group vs NACL con 6 escenarios.
  - `03-s3-gateway-endpoint/` — por qué el S3 Gateway Endpoint es gratis y cómo evita que `aws s3 cp` pague NAT.
- **`activities/`** — dos actividades **independientes**:
  - `01-provision-vpc-via-tf-module/` — escribir un módulo Terraform de VPC multi-AZ y verificar su `plan`.
  - `02-reduce-nat-cost-with-endpoints/` — auditar un stack con egress caro y proponer endpoints para reducir la factura.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Definir con precisión por qué una subnet es "pública". Enumerar la diferencia SG vs NACL en una tabla. Explicar el modelo de costo de NAT Gateway y de los dos tipos de endpoint. |
| Operativa (sin infra) | Escribir un módulo Terraform de VPC multi-AZ (3 AZ) con subnets públicas y privadas, IGW, route tables, SG mínimo, S3 Gateway endpoint, y pasar `terraform plan` sin aplicar. |
| Arquitectónica | Dado un stack con egress caro, proponer un rediseño con endpoints que reduzca el gasto en NAT, justificando numéricamente el ahorro. |

## Criterios de evaluación

- Calcula correctamente el número de hosts utilizables en una subnet AWS dada su máscara.
- Distingue en 1 frase SG vs NACL (stateful vs stateless; allow-only vs allow+deny; evaluación por unión vs por orden).
- Dado un diagrama con egress por NAT, identifica qué tráfico puede moverse a Gateway endpoint (S3/DynamoDB) y cuál a Interface endpoint.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- Módulo Terraform propio de VPC con `terraform plan` limpio (sale de la actividad 01).
- Análisis de reducción de costo NAT con endpoints (sale de la actividad 02).

## Siguiente módulo

→ `aws-04-ec2-fundamentals` — compute básico, IMDSv2, instance profile, user-data idempotente.
