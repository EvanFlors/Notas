# REFERENCE — gcp-03-02-publish-app-global-lb

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

---

## `variables.tf`

```hcl
variable "project_id" {
  type        = string
  description = "Placeholder — NO usar un project real."
  default     = "example-project-id"
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "domain" {
  type    = string
  default = "api.example.com."
}

variable "cloud_run_service" {
  type        = string
  description = "Nombre del servicio Cloud Run (placeholder, se despliega en gcp-04)."
  default     = "checkout-api"
}
```

## `lb.tf`

```hcl
# 1. IP anycast global reservada.
resource "google_compute_global_address" "lb_ip" {
  project = var.project_id
  name    = "lb-ip-checkout"
}

# 2. Cert TLS gestionado por Google.
resource "google_compute_managed_ssl_certificate" "cert" {
  project = var.project_id
  name    = "cert-checkout"
  managed {
    domains = [var.domain]
  }
}

# 3. NEG serverless apuntando a Cloud Run (el servicio se crea en gcp-04).
resource "google_compute_region_network_endpoint_group" "neg_api" {
  project               = var.project_id
  name                  = "neg-checkout-api"
  region                = var.region
  network_endpoint_type = "SERVERLESS"
  cloud_run {
    service = var.cloud_run_service
  }
}

# 4. Backend service.
resource "google_compute_backend_service" "bs_api" {
  project               = var.project_id
  name                  = "bs-checkout-api"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"
  timeout_sec           = 30

  backend {
    group = google_compute_region_network_endpoint_group.neg_api.id
  }

  # Cloud Armor (opcional):
  # security_policy = google_compute_security_policy.waf.id
  # Cloud CDN (opcional, flag):
  # enable_cdn = true
}

# 5. URL map (por defecto manda todo a bs-api).
resource "google_compute_url_map" "umap" {
  project         = var.project_id
  name            = "umap-checkout"
  default_service = google_compute_backend_service.bs_api.id
}

# 6. Target HTTPS proxy que termina TLS con el managed cert.
resource "google_compute_target_https_proxy" "proxy" {
  project          = var.project_id
  name             = "proxy-checkout"
  url_map          = google_compute_url_map.umap.id
  ssl_certificates = [google_compute_managed_ssl_certificate.cert.id]
}

# 7. Forwarding rule global en 443.
resource "google_compute_global_forwarding_rule" "fr_https" {
  project               = var.project_id
  name                  = "fr-checkout-https"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb_ip.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.proxy.id
}
```

## `ARCHITECTURE.md`

```markdown
# Flujo de request — Global HTTPS LB para checkout-api

## Diagrama

\`\`\`
Cliente
   │
   │ DNS: api.example.com  →  A record (IP anycast reservada)
   ▼
Google Edge PoP (el más cercano al cliente)
   │
   ▼
google_compute_global_forwarding_rule  (port 443)
   │
   ▼
google_compute_target_https_proxy  ◀── google_compute_managed_ssl_certificate
   │
   ▼
google_compute_url_map  (default → bs_api)
   │
   ▼
google_compute_backend_service  (bs_api)
   │
   ▼
google_compute_region_network_endpoint_group  (SERVERLESS → Cloud Run)
   │
   ▼
Cloud Run service "checkout-api"  (sin IP pública propia)
\`\`\`

## Por qué LB global en vez de "ALB por región + Route 53 latency"

- **Una sola IP anycast**: un solo A record. En AWS tendrías que mantener un ALB por región más un hosted zone con latency records.
- **Failover automático**: si una región backend cae, el PoP enruta al siguiente backend sano sin cambios de DNS (que tardan en propagarse por TTL).
- **TLS termina en el borde** de Google, cerca del cliente — menos round-trips para el handshake.
- **Cert gratis y auto-renovado** (`managed { domains = [...] }`). En AWS tendrías ACM + validación DNS, también gratis, pero por región.
- **Un solo URL map global** para rutas, en vez de duplicar reglas en N ALBs.

## Cuándo NO conviene

- Si por residencia estricta no puedes terminar TLS fuera de una región concreta → usar **Regional** External Application LB.
- Si el workload es puramente interno → usar **Internal** HTTPS LB.
- Si es TCP/UDP puro → usar **Network LB** (L4).
```

> El bloque de código del diagrama en `ARCHITECTURE.md` usa triple-backtick (```) — en este REFERENCE lo escapamos con `\`\`\`` para que renderice.

## Notas

- Las 6 piezas obligatorias están presentes y encadenadas por `.id` / `.name`.
- El HCL **pasa `terraform validate`** si añades un `provider "google"` mínimo y haces `terraform init -backend=false`. **No** llama a GCP.
- `project_id = "example-project-id"` es un **placeholder**. Nunca commitear un project ID real en el repo.
