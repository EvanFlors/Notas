# Ejemplo 02 — Firewall rules por service account (vs por tag)

> Lectura y análisis. Se muestran las dos variantes para contrastar; la recomendación es **SA sobre tag**.

## 1. Escenario

Una app `checkout-api` corre en VMs con la service account `app-sa@example-project.iam.gserviceaccount.com`. Habla con una base de datos Postgres en Cloud SQL privada, accesible por `db-sa@example-project.iam.gserviceaccount.com` (su proxy auth). Queremos:

1. Permitir **sólo** a `app-sa` abrir conexiones TCP:5432 a instancias con `db-sa`.
2. Permitir health checks del LB a las VMs de `app-sa`.
3. **Denegar todo lo demás** (en ingress; egress es otra regla).

## 2. Diagrama

```
                 Internet
                    │
                    ▼
          ┌────────────────────┐
          │ LB global (HTTPS)  │  health-checks desde
          │ 35.191.0.0/16      │  rangos oficiales Google
          │ 130.211.0.0/22     │
          └─────────┬──────────┘
                    │ allow 80/443 (ingress)
                    ▼
         ┌─────────────────────┐    allow 5432       ┌─────────────────────┐
         │  VMs checkout-api   │ ─────────────────▶ │  VMs db-proxy       │
         │  SA: app-sa@...     │   source: app-sa    │  SA: db-sa@...      │
         │  tag: web           │   target: db-sa     │  tag: db            │
         └─────────────────────┘                     └─────────────────────┘
                    ▲
                    │ deny-all-ingress (prio 65535, implícito)
                    │
             el resto del mundo
```

## 3. Reglas en JSON (formato `gcloud compute firewall-rules describe`)

Las tres reglas, listas para `firewall-rules.json` o para versionado en repo:

```json
[
  {
    "name": "allow-health-checks-to-app",
    "network": "projects/example-project-id/global/networks/vpc-dev",
    "direction": "INGRESS",
    "priority": 1000,
    "sourceRanges": ["35.191.0.0/16", "130.211.0.0/22"],
    "targetServiceAccounts": ["app-sa@example-project.iam.gserviceaccount.com"],
    "allowed": [
      { "IPProtocol": "tcp", "ports": ["80", "443"] }
    ]
  },
  {
    "name": "allow-app-to-db-5432",
    "network": "projects/example-project-id/global/networks/vpc-dev",
    "direction": "INGRESS",
    "priority": 1000,
    "sourceServiceAccounts": ["app-sa@example-project.iam.gserviceaccount.com"],
    "targetServiceAccounts": ["db-sa@example-project.iam.gserviceaccount.com"],
    "allowed": [
      { "IPProtocol": "tcp", "ports": ["5432"] }
    ]
  },
  {
    "name": "deny-all-ingress-explicit",
    "network": "projects/example-project-id/global/networks/vpc-dev",
    "direction": "INGRESS",
    "priority": 65534,
    "sourceRanges": ["0.0.0.0/0"],
    "denied": [
      { "IPProtocol": "all" }
    ]
  }
]
```

## 4. Variante por tag (contraste)

Equivalente **pero más débil**:

```json
{
  "name": "allow-app-to-db-5432-by-tag",
  "direction": "INGRESS",
  "priority": 1000,
  "sourceTags": ["web"],
  "targetTags": ["db"],
  "allowed": [{ "IPProtocol": "tcp", "ports": ["5432"] }]
}
```

Problema: cualquier operador con `compute.instances.setTags` sobre la VM de atacante puede ponerse el tag `web` y entrar. Con **SA**, el atacante necesita además `iam.serviceAccountUser` sobre `app-sa`, que es un permiso explícito y auditable.

## 5. Lectura clave

1. **Prioridades**: la primera regla que *matchea* y **permite** gana si no hay deny anterior con prioridad igual o mejor. Convención: baseline en prio 1000, excepciones específicas en prio 500–900, deny general en prio 65534.
2. **Rangos oficiales de health checks** (`35.191.0.0/16`, `130.211.0.0/22`) son los únicos que debes permitir — no abrir 80/443 a `0.0.0.0/0` para "que lleguen los health checks".
3. **El deny implícito** final (prio 65535) existe siempre. El `deny-all-ingress-explicit` del ejemplo es redundante pero útil para que logs/analítica muestren el deny explícitamente.
4. **Firewall rules son globales a la VPC** — no hay "regla por subnet". Si quieres aislar por región, filtra por `destinationRanges` o por SA.

## 6. Formato HCL equivalente (opcional)

```hcl
resource "google_compute_firewall" "allow_app_to_db_5432" {
  project   = var.project_id
  name      = "allow-app-to-db-5432"
  network   = google_compute_network.vpc_dev.name
  direction = "INGRESS"
  priority  = 1000

  source_service_accounts = ["app-sa@example-project.iam.gserviceaccount.com"]
  target_service_accounts = ["db-sa@example-project.iam.gserviceaccount.com"]

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }
}
```

> Terraform acepta `source_service_accounts` **o** `source_tags` **o** `source_ranges`, pero combinarlos tiene reglas estrictas — leer el provider doc antes de mezclar.
