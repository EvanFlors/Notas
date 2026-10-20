# Plan-only. Autopilot: Google gestiona nodos.
# Reutiliza la VPC `default` por simplicidad didactica; en real,
# apunta a la del stage 6.

resource "google_container_cluster" "this" {
  name             = var.cluster_name
  location         = var.region
  min_master_version = var.kubernetes_version
  enable_autopilot = true

  # Autopilot deduce la mayoria de defaults seguros; aqui solo marcamos
  # intento declarativo.
  deletion_protection = false

  release_channel {
    channel = "REGULAR"
  }
}
