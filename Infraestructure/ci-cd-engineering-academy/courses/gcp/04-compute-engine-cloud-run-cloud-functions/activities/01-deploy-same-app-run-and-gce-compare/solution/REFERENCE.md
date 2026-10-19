# Reference — gcp-04-01

Autoevaluacion:

1. **`Dockerfile`:** multi-stage, slim, no-root (UID 10001), `CMD` que lee `$PORT`. `docker build .` debe funcionar en tu laptop.
2. **`cloud-run.tf`:** `google_cloud_run_v2_service` con `location="europe-west1"`, `service_account` **distinto** del default, `containers.ports.container_port=8080`, `env{name="PORT"}`, `traffic{percent=100}`.
3. **`gce.tf`:** `google_compute_instance_template` + `google_compute_region_instance_group_manager` en `europe-west1` con `base_instance_name`, `target_size`, y una `service_account` dedicada.
4. **`DECISION.md`:** titulo "Decision" (o Decisión), menciona Cloud Run y Compute Engine (o GCE), compara >=3 criterios y declara una eleccion.

**No se despliega nada**: `terraform init -backend=false && terraform validate` basta. El validador cubre todos los puntos anteriores de forma estructural.
