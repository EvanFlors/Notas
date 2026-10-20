# Recursos — gcp-03

Referencias oficiales y lecturas de apoyo. **Verificar en Fase 4** del curso para asegurar vigencia (consolas, nombres y pricing cambian).

## Oficiales (Google Cloud)

- **VPC overview**: `https://cloud.google.com/vpc/docs/overview`
- **VPC networks (auto vs custom)**: `https://cloud.google.com/vpc/docs/vpc`
- **Firewall rules overview**: `https://cloud.google.com/firewall/docs/firewalls`
- **Firewall rules by service account**: `https://cloud.google.com/firewall/docs/firewalls#serviceaccounts`
- **Cloud NAT overview**: `https://cloud.google.com/nat/docs/overview`
- **Private Google Access**: `https://cloud.google.com/vpc/docs/private-google-access`
- **Private Service Connect**: `https://cloud.google.com/vpc/docs/private-service-connect`
- **Shared VPC overview**: `https://cloud.google.com/vpc/docs/shared-vpc`
- **VPC Network Peering**: `https://cloud.google.com/vpc/docs/vpc-peering`
- **Network Connectivity Center**: `https://cloud.google.com/network-connectivity/docs/network-connectivity-center/concepts/overview`
- **Cloud Interconnect**: `https://cloud.google.com/network-connectivity/docs/interconnect`
- **Cloud VPN**: `https://cloud.google.com/network-connectivity/docs/vpn/concepts/overview`

## Load Balancing

- **Cloud Load Balancing overview**: `https://cloud.google.com/load-balancing/docs/load-balancing-overview`
- **External Application Load Balancer (global)**: `https://cloud.google.com/load-balancing/docs/https`
- **Google-managed SSL certificates**: `https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs`
- **URL maps**: `https://cloud.google.com/load-balancing/docs/url-map-concepts`
- **Backend services**: `https://cloud.google.com/load-balancing/docs/backend-service`
- **Health checks**: `https://cloud.google.com/load-balancing/docs/health-checks`

## Seguridad y edge

- **Cloud Armor overview**: `https://cloud.google.com/armor/docs/cloud-armor-overview`
- **Cloud Armor WAF rules (OWASP CRS)**: `https://cloud.google.com/armor/docs/waf-rules`
- **Cloud CDN overview**: `https://cloud.google.com/cdn/docs/overview`

## Terraform (provider google)

- **`google_compute_network`**: `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network`
- **`google_compute_subnetwork`**: `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork`
- **`google_compute_firewall`**: `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_firewall`
- **`google_compute_router` + `router_nat`**: `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat`
- **`google_compute_shared_vpc_host_project`**: `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_shared_vpc_host_project`
- **`google_compute_managed_ssl_certificate`**: `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_managed_ssl_certificate`
- **`google_compute_global_forwarding_rule`**: `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule`
- **`google_compute_target_https_proxy`**: `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_https_proxy`
- **`google_compute_url_map`**: `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_url_map`
- **`google_compute_backend_service`**: `https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_service`

## Lecturas largas recomendadas

- **Best practices for VPC design (GCP)**: `https://cloud.google.com/architecture/best-practices-vpc-design`
- **Landing zones on Google Cloud**: `https://cloud.google.com/architecture/landing-zones`
- **GCP vs AWS networking** (post comparativo oficial): `https://cloud.google.com/docs/compare/aws/networking`
