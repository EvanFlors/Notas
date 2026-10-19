# Ejemplo 03 — Global HTTPS LB con managed cert

> Lectura y análisis. El HCL pasa `terraform validate` pero **no debe hacerse `apply`** con credenciales reales (hay recursos de pago: forwarding rule global, egress, Cloud Armor si se activa).

## 1. Objetivo

Fijar el **esqueleto mínimo** de un *external global Application Load Balancer* con:

- IP anycast reservada.
- Certificado TLS gestionado por Google (gratis, se renueva solo).
- Un backend genérico (NEG serverless apuntando a Cloud Run, o MIG).
- Opción comentada de Cloud Armor y Cloud CDN.

## 2. Diagrama del flujo de request

```
    Cliente
      │
      │ DNS: api.example.com  →  A record 34.120.0.0 (IP anycast)
      ▼
┌──────────────────────────────────────────────────────────────────────┐
│                     Google Edge PoP mas cercano                      │
│                                                                      │
│   ┌──────────────────────┐                                           │
│   │ global forwarding    │   port 443                                │
│   │ rule                 │                                           │
│   └──────────┬───────────┘                                           │
│              ▼                                                       │
│   ┌──────────────────────┐    ┌────────────────────────────────┐     │
│   │ target HTTPS proxy   │ ◀─ │ google-managed SSL certificate │     │
│   └──────────┬───────────┘    │  (dominios: api.example.com)   │     │
│              ▼                └────────────────────────────────┘     │
│   ┌──────────────────────┐                                           │
│   │ URL map              │   rutea por host/path                     │
│   │  default  →  bs-api  │                                           │
│   │  /static →  bs-cdn   │   (p. ej. a GCS)                          │
│   └──────────┬───────────┘                                           │
│              ▼                                                       │
│   ┌──────────────────────┐    ┌────────────────────────────────┐     │
│   │ backend service      │ ◀─ │  Cloud Armor policy (opcional) │     │
│   │  bs-api              │    │  Cloud CDN flag (opcional)     │     │
│   │  health check: TCP   │    └────────────────────────────────┘     │
│   └──────────┬───────────┘                                           │
└──────────────┼───────────────────────────────────────────────────────┘
               ▼
      ┌─────────────────┐
      │  NEG serverless │  →  Cloud Run service "checkout-api"
      │  (region eu-w1) │       (sin IP publica propia)
      └─────────────────┘
```

## 3. HCL anotado (esqueleto)

```hcl
variable "project_id" {
  type    = string
  default = "example-project-id"
}

# IP anycast global reservada.
resource "google_compute_global_address" "lb_ip" {
  project = var.project_id
  name    = "lb-ip-checkout"
}

# Cert TLS gestionado por Google — gratis, renueva solo.
# Requiere que api.example.com apunte via DNS a la IP reservada antes del "apply".
resource "google_compute_managed_ssl_certificate" "cert" {
  project = var.project_id
  name    = "cert-checkout"
  managed {
    domains = ["api.example.com."]
  }
}

# NEG serverless apuntando a un servicio Cloud Run (en gcp-04 lo creamos).
resource "google_compute_region_network_endpoint_group" "neg_api" {
  project               = var.project_id
  name                  = "neg-checkout-api"
  region                = "europe-west1"
  network_endpoint_type = "SERVERLESS"
  cloud_run {
    service = "checkout-api"
  }
}

# Backend service: agrupa el NEG, define health check (serverless usa el del
# runtime), timeouts y, opcionalmente, Cloud Armor + Cloud CDN.
resource "google_compute_backend_service" "bs_api" {
  project               = var.project_id
  name                  = "bs-checkout-api"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"
  timeout_sec           = 30

  backend {
    group = google_compute_region_network_endpoint_group.neg_api.id
  }

  # security_policy = google_compute_security_policy.waf.id  # Cloud Armor
  # enable_cdn      = true                                   # Cloud CDN
}

# URL map: por defecto manda todo a bs-api.
resource "google_compute_url_map" "umap" {
  project         = var.project_id
  name            = "umap-checkout"
  default_service = google_compute_backend_service.bs_api.id
}

# Target proxy HTTPS: termina TLS con el cert gestionado.
resource "google_compute_target_https_proxy" "proxy" {
  project          = var.project_id
  name             = "proxy-checkout"
  url_map          = google_compute_url_map.umap.id
  ssl_certificates = [google_compute_managed_ssl_certificate.cert.id]
}

# Forwarding rule global en 443.
resource "google_compute_global_forwarding_rule" "fr_https" {
  project               = var.project_id
  name                  = "fr-checkout-https"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb_ip.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.proxy.id
}
```

## 4. Lectura clave

1. **IP anycast reservada antes del cert**: el cert gestionado valida dominio por HTTP-01 y necesita que el DNS ya apunte a la IP del LB. Secuencia: reservar IP → crear DNS A → crear managed cert → esperar `ACTIVE`.
2. **`load_balancing_scheme = "EXTERNAL_MANAGED"`** es la variante moderna (Application LB sobre el stack *Envoy-based*). Alternativa legacy: `EXTERNAL` (deprecada en nuevos despliegues).
3. **Backend tipos**: NEG serverless (Cloud Run / Functions / App Engine), NEG zonal (GKE Pods), MIG (Compute Engine). Un backend service puede mezclar varios para patrones blue/green.
4. **Cloud Armor** se adjunta por `security_policy` en el backend service — se evalúa en el edge, antes de llegar a Cloud Run.
5. **Cloud CDN** es un flag — pagas sólo por egress cacheado (más barato que egress no cacheado).

## 5. Qué NO está aquí (deliberado)

- El servicio Cloud Run al que apunta el NEG → `gcp-04`.
- IAM del service account del LB → `gcp-02` + `gcp-04`.
- DNS zone + record → fuera del alcance de este módulo (`gcp-01` cubre `gcloud dns` básico; una landing zone con DNS compartido va en `gcp-09`).
