# Starter — gcp-03-02-publish-app-global-lb

Esta actividad es **independiente**. Los entregables son HCL + Markdown escritos por ti. **No** se ejecuta `terraform apply`.

## Pasos

1. Lee `../README.md` y `../../examples/03-global-https-lb-with-managed-cert/README.md`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gcp-03-global-lb
   cd /tmp/gcp-03-global-lb
   ```
3. Crea `variables.tf` con `project_id` placeholder.
4. Crea `lb.tf` con las 6 piezas del LB global:
   - `google_compute_global_address`
   - `google_compute_managed_ssl_certificate`
   - `google_compute_region_network_endpoint_group` (o `instance_group`)
   - `google_compute_backend_service`
   - `google_compute_url_map`
   - `google_compute_target_https_proxy`
   - `google_compute_global_forwarding_rule`
5. Crea `ARCHITECTURE.md` con diagrama ASCII del flujo y justificación "LB global vs ALB regional".
6. (Opcional) `terraform init -backend=false && terraform validate` localmente.
7. Valida con el repo:
   ```bash
   bash <ruta-repo>/courses/gcp/03-vpc-global-and-networking/activities/02-publish-app-global-lb/tests/validate.sh /tmp/gcp-03-global-lb
   ```
8. Compara con `../solution/REFERENCE.md`.

> **Importante:** el validador comprueba estructura, no semántica. Y **no** llama a GCP.

## Plantilla mínima de `lb.tf`

```hcl
resource "google_compute_global_address" "lb_ip" {
  project = var.project_id
  name    = "lb-ip-checkout"
}

resource "google_compute_managed_ssl_certificate" "cert" {
  project = var.project_id
  name    = "cert-checkout"
  managed {
    domains = ["api.example.com."]
  }
}

# ... (completa con las piezas restantes)
```
