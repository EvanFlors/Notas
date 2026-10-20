# Actividad 02 — Publicar una app con Global External HTTPS LB

## 1. Identificación

- **ID:** `gcp-03-02-publish-app-global-lb`
- **Tecnología:** `gcp`
- **Módulo:** `gcp-03-vpc-global-and-networking`
- **Dificultad:** foundational
- **Duración estimada:** 80–100 min
- **Tipo:** independent (no depende de la actividad 01)

## 2. Contexto

El equipo quiere publicar la API `checkout-api` (que corre en Cloud Run — se montará en `gcp-04`) detrás de un **Global External HTTPS Load Balancer** con:

- **Una única IP anycast** anunciada desde todos los PoPs europeos.
- **Managed SSL cert** de Google (gratis, auto-renovación) para `api.example.com`.
- **URL map** mínimo (`default → bs-api`).
- Backend tipo **NEG serverless** apuntando a un servicio Cloud Run (placeholder; el servicio real se despliega en `gcp-04`).
- Opcional: **Cloud Armor** y **Cloud CDN** declarados pero comentados.

**Importante**: no se provisiona nada en GCP real. Esta actividad produce **HCL que pasa `terraform validate` sin credenciales** y un diagrama ASCII. No se ejecuta `terraform apply`. **No hay costo**.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Nombrar las 6 piezas obligatorias de un LB global HTTPS: `global_address`, `managed_ssl_certificate`, `backend_service`, `url_map`, `target_https_proxy`, `global_forwarding_rule`.
- Encadenarlas correctamente en HCL con referencias cruzadas.
- Dibujar el flujo de request desde DNS hasta el backend.
- Justificar la elección "LB global vs regional + Route 53" (contraste con AWS).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` §9 (Load Balancing).
- Haber recorrido `../../examples/03-global-https-lb-with-managed-cert/`.
- Herramientas: `bash`, editor Markdown, y **opcionalmente** `terraform` CLI local para validar sin credenciales (`terraform init -backend=false && terraform validate`). El validador del repo **no** depende de `terraform` instalado — comprueba el HCL por patrones.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gcp-03-global-lb
cd /tmp/gcp-03-global-lb
```

### 5.2 Escribe `variables.tf`

Debe declarar al menos una variable `project_id` con un **placeholder** (no un project ID real):

```hcl
variable "project_id" {
  type        = string
  description = "Placeholder — NO usar un project real."
  default     = "example-project-id"
}
```

### 5.3 Escribe `lb.tf`

Debe declarar **las 6 piezas obligatorias**:

1. `resource "google_compute_global_address" "lb_ip"` — IP anycast.
2. `resource "google_compute_managed_ssl_certificate" "cert"` con bloque `managed { domains = [...] }`.
3. `resource "google_compute_region_network_endpoint_group" "neg_api"` apuntando a Cloud Run (`network_endpoint_type = "SERVERLESS"`) **o** un `instance_group` genérico.
4. `resource "google_compute_backend_service" "bs_api"` con `load_balancing_scheme = "EXTERNAL_MANAGED"`.
5. `resource "google_compute_url_map" "umap"` con `default_service` apuntando al backend service.
6. `resource "google_compute_target_https_proxy" "proxy"` con `ssl_certificates = [...]`.
7. `resource "google_compute_global_forwarding_rule" "fr_https"` con `port_range = "443"` apuntando al target proxy.

### 5.4 Escribe `ARCHITECTURE.md`

Un diagrama ASCII (dentro de code fence) del flujo:

```
Cliente → DNS → IP anycast → forwarding rule → target HTTPS proxy
       → URL map → backend service → NEG → Cloud Run
```

Y una sección breve justificando "LB global vs ALB + Route 53 latency".

### 5.5 Entregable

Tres archivos:

```
/tmp/gcp-03-global-lb/variables.tf
/tmp/gcp-03-global-lb/lb.tf
/tmp/gcp-03-global-lb/ARCHITECTURE.md
```

> **Prohibido**: `ANALYSIS.md`. La justificación va en `ARCHITECTURE.md`.

### 5.6 (Opcional) Validar con terraform local

Si tienes `terraform` instalado:

```bash
cd /tmp/gcp-03-global-lb
cat > versions.tf <<'EOF'
terraform {
  required_version = ">= 1.5"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
  }
}
provider "google" {
  project = var.project_id
  region  = "europe-west1"
}
EOF
terraform init -backend=false
terraform validate
```

`terraform validate` **no** llama a GCP ni requiere credenciales. Si falla, revisa referencias cruzadas.

## 6. Resultado esperado

- Los tres archivos existen.
- El validador pasa en verde (`0 issue(s)`).
- El diagrama es legible y las 6 piezas del LB están encadenadas correctamente en HCL.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada recurso del LB está referenciado por el siguiente (no son recursos sueltos).
- **Reproducibilidad**: el HCL podría llevarse a Fase 4 añadiendo únicamente el provider y, opcionalmente, el servicio Cloud Run real.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gcp-03-global-lb
```

El validador comprueba **estructura del HCL**, no semántica contra GCP. Compara tu entrega con `solution/REFERENCE.md`.

## 9. Preguntas de reflexión

1. ¿Por qué el managed cert necesita que el DNS ya apunte a la IP del LB antes de que se vuelva `ACTIVE`?
2. ¿Qué beneficios aporta la IP anycast frente a un ALB por región + Route 53 latency routing?
3. ¿Dónde habilitarías Cloud Armor y por qué (en el `backend_service` o en el `target_proxy`)?
4. Si mañana añades `/static` sirviendo desde un bucket GCS, ¿qué pieza del LB se modifica?
5. ¿Qué health check usa un backend service con NEG serverless? ¿Por qué?

## 10. Extensiones

- Añade un `google_compute_security_policy` (Cloud Armor) con una rule de bloqueo por país y referénciala desde el backend service.
- Añade `enable_cdn = true` en el backend service y comenta el impacto en coste de egress.
- Añade un segundo backend (bucket GCS para `/static`) y la rule correspondiente en el URL map.

## 11. Limpieza

```bash
rm -rf /tmp/gcp-03-global-lb
```

No hay procesos ni infraestructura que detener en GCP (nada se provisionó).
