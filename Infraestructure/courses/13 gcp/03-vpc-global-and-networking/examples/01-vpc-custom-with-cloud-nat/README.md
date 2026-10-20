# Ejemplo 01 — VPC custom con Cloud NAT y Private Google Access

> Lectura y análisis. **No** se provisiona nada. El HCL de abajo pasa `terraform validate` pero **no debe ejecutarse `apply`** con credenciales reales — hay recursos de pago (Cloud NAT).

## 1. Objetivo

Fijar en memoria la topología mínima de una VPC `custom` que:

- Vive como VPC **global** (como siempre en GCP).
- Tiene subnets en **dos regiones europeas** con CIDR planeado.
- Tiene **Cloud NAT** regional para egress sin IP externa.
- Tiene **Private Google Access** habilitado por subnet.

## 2. Diagrama

```
                    VPC: vpc-dev        (global, custom)
                    10.10.0.0/16
                    ┌────────────────────────────────────────────┐
                    │                                            │
   ┌────────────────┤  subnet: eu-west1-primary  10.10.0.0/20    │
   │ europe-west1   │   privateIpGoogleAccess: true              │
   │                │                                            │
   │  Cloud Router  │  subnet: eu-west4-primary  10.10.16.0/20   │
   │  Cloud NAT     │   privateIpGoogleAccess: true              │
   │  (regional)    │                                            │
   └────────────────┤                                            │
                    │  (sin subnets en otras regiones todavía)   │
                    └────────────────────────────────────────────┘

                           Egress a internet
                                 ▲
                                 │
                                 │ via Cloud NAT (eu-west1)
                                 │
                     VM sin IP externa (eu-west1)
```

## 3. HCL anotado

```hcl
# NOTA: project_id es un placeholder. No usar un project ID real aqui.
variable "project_id" {
  type    = string
  default = "example-project-id"
}

resource "google_compute_network" "vpc_dev" {
  project                 = var.project_id
  name                    = "vpc-dev"
  auto_create_subnetworks = false   # modo custom
  routing_mode            = "GLOBAL" # anuncia rutas inter-region por BGP
}

resource "google_compute_subnetwork" "eu_west1_primary" {
  project                  = var.project_id
  name                     = "eu-west1-primary"
  region                   = "europe-west1"
  network                  = google_compute_network.vpc_dev.id
  ip_cidr_range            = "10.10.0.0/20"
  private_ip_google_access = true   # PGA: APIs de Google sin IP externa
}

resource "google_compute_subnetwork" "eu_west4_primary" {
  project                  = var.project_id
  name                     = "eu-west4-primary"
  region                   = "europe-west4"
  network                  = google_compute_network.vpc_dev.id
  ip_cidr_range            = "10.10.16.0/20"
  private_ip_google_access = true
}

# Cloud Router + Cloud NAT en europe-west1 para egress sin IP externa.
# Nota: cada region que necesite egress NAT quiere su propio router + NAT.
resource "google_compute_router" "nat_router_eu_west1" {
  project = var.project_id
  name    = "nat-router-eu-west1"
  region  = "europe-west1"
  network = google_compute_network.vpc_dev.id
}

resource "google_compute_router_nat" "nat_eu_west1" {
  project                            = var.project_id
  name                               = "nat-eu-west1"
  router                             = google_compute_router.nat_router_eu_west1.name
  region                             = "europe-west1"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
```

## 4. Lectura clave

1. **`routing_mode = GLOBAL`** permite que las subnets de distintas regiones se enruten entre sí por el backbone de Google con menor coste de latencia que `REGIONAL`.
2. **`private_ip_google_access = true`** se decide por subnet; es gratis y evita rutas innecesarias a internet para hablar con APIs de Google.
3. **Cloud NAT por región**: una VM en `europe-west4` **no** sale por el NAT de `europe-west1`. Si esa región necesita egress sin IP externa, se añade otro `google_compute_router_nat` en `europe-west4`.
4. **CIDR planeado**: `10.10.0.0/16` deja espacio para 16 subnets `/20` (más de las que una VPC típica necesita). El patrón "una `/16` por entorno" es sostenible.

## 5. Qué NO está aquí (deliberado)

- Firewall rules → ver `../02-firewall-by-service-account/`.
- Load Balancer → ver `../03-global-https-lb-with-managed-cert/`.
- VMs reales → fuera de alcance de este módulo (ver `gcp-04`).
- Shared VPC → ver actividad `01-shared-vpc-host-and-service`.
