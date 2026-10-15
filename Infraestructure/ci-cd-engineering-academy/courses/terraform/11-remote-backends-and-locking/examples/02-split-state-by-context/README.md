# Ejemplo 02 — Split de state por bounded context

Patrón de layout: **un state por bounded context, por ambiente**. No "un state por microservicio" (demasiado fino) ni "un state para todo" (ingobernable).

Este ejemplo no se "aplica" — es un **patrón de referencia** para que leas la estructura, los contratos entre states y la convención de keys en S3.

## Layout

```
examples/02-split-state-by-context/
├── bootstrap/                      # crea bucket + tabla (una vez)
│   └── main.tf                     #   backend local; se corre a mano
└── envs/
    └── dev/
        ├── network/                # state 1: VPC, subnets, NAT
        │   ├── main.tf
        │   ├── backend.hcl
        │   └── outputs.tf          #   exporta vpc_id, subnet_ids
        ├── platform/               # state 2: EKS, IRSA, DNS
        │   ├── main.tf
        │   ├── backend.hcl
        │   └── data.tf             #   lee outputs de network via terraform_remote_state
        └── app-payments/           # state 3: microservicio Payments
            ├── main.tf
            ├── backend.hcl
            └── data.tf             #   lee outputs de network y platform
```

Convención de keys en S3:

```
s3://acme-tf-state-dev/network/terraform.tfstate
s3://acme-tf-state-dev/platform/terraform.tfstate
s3://acme-tf-state-dev/app-payments/terraform.tfstate
```

Y para los otros ambientes, un bucket por ambiente (no una key diferente dentro del mismo bucket):

```
s3://acme-tf-state-stg/...
s3://acme-tf-state-prod/...
```

**Por qué un bucket por ambiente** y no un prefijo:

- Las políticas IAM son por bucket; separar por bucket permite dar al rol de "CI de prod" acceso **solo** al bucket de prod.
- Un error de prefijo (apunta a `prod/...` desde una config que debía ser `dev/...`) deja de ser catastrófico si prod ni siquiera está en el mismo bucket.
- CloudTrail data events se filtran por bucket; auditar prod aparte es trivial.

## Grafo de dependencias entre states

```
network  ─────► platform ─────► app-payments
   │               │                  │
   │               └─────► app-orders │
   └───────────────────────────────────┘
                 (todos leen network)
```

`terraform_remote_state` es la lectura; es un **contrato** entre states. Cambiar un output en `network` que `platform` consume es un breaking change y debe tratarse como tal (semver mental, aunque Terraform no lo imponga).

## Qué está en cada state

- `network/`: VPC, subnets public/private, NAT gateways, route tables. Casi nunca cambia (una vez al trimestre).
- `platform/`: cluster EKS, add-ons, DNS zones, cert-manager. Cambia por releases de plataforma.
- `app-*/`: service, ALB target group, IAM role del pod, service account. Cambia con cada release de la app.

El criterio es **ritmo de cambio + ownership + blast radius**, no "qué recursos AWS cerca".

## Para 50 microservicios

No crees 50 states separados. Agrupa por "familia" (3-10 microservicios con el mismo owner y mismo ritmo de release). Por ejemplo:

```
app-identity/   (login, oauth, sessions)
app-payments/   (payments, refunds, wallets)
app-catalog/    (products, pricing, search)
app-orders/     (orders, cart, checkout)
...
```

Resultado típico: ~10 states de app + 3-4 de plataforma = ~15 states por ambiente. Manejable.

## Archivos de ejemplo

Los `main.tf`/`backend.hcl` incluidos son **stubs mínimos** (no se aplican sin un bootstrap real). Léelos para ver cómo se conectan:

- `bootstrap/main.tf` — crea bucket + tabla.
- `envs/dev/network/main.tf` — expone `vpc_id` y `subnet_ids` como outputs.
- `envs/dev/platform/data.tf` — consume esos outputs via `terraform_remote_state`.
- `envs/dev/app-payments/data.tf` — consume outputs de `network` y `platform`.
