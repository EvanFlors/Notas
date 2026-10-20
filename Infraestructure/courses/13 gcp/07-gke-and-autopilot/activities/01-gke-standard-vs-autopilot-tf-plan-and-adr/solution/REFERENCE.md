# REFERENCE — gcp-07-01-gke-standard-vs-autopilot-tf-plan-and-adr

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

---

## Terraform de referencia

### `terraform/standard/main.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "my-project-123" # placeholder
  region  = "europe-west1"
}

resource "google_container_cluster" "primary" {
  name     = "checkout-gke-standard"
  location = "europe-west1"

  # we create a separate node pool below; the default is removed
  remove_default_node_pool = true
  initial_node_count       = 1

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "my-project-123.svc.id.goog"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Dataplane V2 (Cilium/eBPF). Alternative: network_policy { enabled = true, provider = "CALICO" }
  datapath_provider = "ADVANCED_DATAPATH"

  # VPC-native (alias IPs); real deployments wire specific secondary ranges.
  ip_allocation_policy {}

  # Deletion protection off because this is a sample module.
  deletion_protection = false
}

resource "google_container_node_pool" "primary_nodes" {
  name     = "primary-nodes"
  location = "europe-west1"
  cluster  = google_container_cluster.primary.name

  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }

  management {
    auto_upgrade = true
    auto_repair  = true
  }

  node_config {
    machine_type = "e2-standard-4"
    disk_size_gb = 50
    disk_type    = "pd-standard"

    # Use a dedicated service account with least privilege, not the default.
    service_account = "gke-nodes@my-project-123.iam.gserviceaccount.com"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA" # required for Workload Identity Federation for GKE
    }
  }
}
```

### `terraform/autopilot/main.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = "my-project-123" # placeholder
  region  = "europe-west1"
}

resource "google_container_cluster" "autopilot" {
  name     = "checkout-gke-autopilot"
  location = "europe-west1"

  enable_autopilot = true

  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "my-project-123.svc.id.goog"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.1.0/28"
  }

  ip_allocation_policy {}

  deletion_protection = false

  # NOTE: do not declare node_pool for Autopilot. Google manages nodes.
}
```

---

# ADR 001 — Modo GKE por workload (Standard vs Autopilot vs EKS)

## Estado

Propuesto (Fase 3). Objetivo: ser Aceptado tras revisión de Platform + Security y materializado con Terraform en Fase 4.

## Contexto

Dos workloads nuevos entran a Kubernetes:

- **`checkout-api`**: API HTTP stateless en Python, 3–10 pods, picos de ×3 a mediodía, SLA 99.9 %. Usa Istio-managed (sidecar oficial de Google Cloud Service Mesh, no custom). No requiere `hostPath`, `hostNetwork` ni privilegios elevados.
- **`training-jobs`**: Jobs batch de ML con GPUs L4, drivers NVIDIA **estándar** (no custom), ejecución diaria 30–90 min por job, 5–20 pods en paralelo con picos esporádicos.

Constraints adicionales:

- **Residencia**: `europe-west1` por GDPR.
- **Private cluster** obligatorio (nodes sin IP pública).
- **Workload Identity Federation for GKE** obligatorio (sin service account keys).
- **Release channel declarado**.
- **Dataplane V2 o NetworkPolicy** habilitado para microsegmentación.
- Equipo de Platform de 2 personas (no SRE dedicado 24×7).
- Finance exige modelo de coste razonado por workload.

## Decisión

### 1. Modo por workload

| Workload | Modo | Razón resumida |
|----------|------|----------------|
| `checkout-api` | **GKE Autopilot** | Aplicación "normal" HTTP stateless. Sin DaemonSets custom. Equipo pequeño gana al no operar nodes. Picos de ×3 encajan en la facturación per-pod sin pagar nodes idle. |
| `training-jobs` | **GKE Autopilot** (con GPU) | Jobs batch esporádicos (30–90 min/día). Pagar GPUs 24×7 en Standard sería ~30× más caro. Autopilot soporta GPUs L4 con drivers estándar. Si el entrenamiento creciera a 24×7 sostenido, se re-evaluaría Standard. |

### 2. Clusters y layout

- **Un cluster por entorno** (`dev`, `stg`, `prod`) × 2 workloads **compartiendo cluster** por entorno (sin cross-contamination gracias a namespaces + RBAC + NetworkPolicies).
  - Alternativa descartada: un cluster por workload × entorno (6 clusters). Más overhead sin beneficio claro al principio.
- **Release channel**:
  - `dev`: **RAPID** (equipo prueba features nuevas antes).
  - `stg`: **REGULAR** (clon de prod).
  - `prod`: **REGULAR** (balance stability/freshness; **STABLE** si en Fase 4 Security pide más conservador).
- **Region**: `europe-west1` (regional, multi-AZ dentro de la región para HA).

### 3. Baseline de seguridad aplicado a los dos clusters

- `enable_autopilot = true`.
- `workload_identity_config.workload_pool = "<project>.svc.id.goog"`.
- `private_cluster_config.enable_private_nodes = true`.
- `release_channel.channel = "REGULAR"` (configurable por entorno).
- Node service accounts dedicados (en Autopilot, Google los gestiona pero con roles mínimos por default).

### 4. Workload Identity Federation for GKE

Cada aplicación tendrá:

- Un **Google Service Account** por app (`checkout-app@...`, `training-runner@...`).
- Un **K8s ServiceAccount** por app anotado con `iam.gke.io/gcp-service-account`.
- Binding IAM `roles/iam.workloadIdentityUser` del principal `svc.id.goog[<ns>/<ksa>]` al GSA correspondiente.
- Ninguna service account key JSON montada en ningún pod. Nunca.

### 5. Modelo de coste razonado

- **`checkout-api`** (10 pods promedio, 500 mCPU, 512 Mi cada uno):
  - **Autopilot**: ~10 × (0.5 vCPU + 0.5 Gi) × factor Autopilot ≈ coste bajo-medio, con sobrecargo ~15 % frente al equivalente requested en Standard.
  - **Standard**: 2–3 nodes `e2-standard-4` 24×7 = ~200–300 USD/mes **solo nodes**. Autopilot sale igual o más barato con picos esporádicos.
- **`training-jobs`** (5–20 pods de GPU × 1 h/día):
  - **Autopilot**: pagas la hora de GPU × 20 pods × 30 días. Coste significativo pero acotado a uso real.
  - **Standard**: necesitarías mantener el GPU node pool activo (o aceptar latencia de scale-up de 2–5 min por cada job). Autopilot gana claramente por el patrón esporádico.

## Consecuencias

### Positivas

- Zero node management: el equipo Platform (2 personas) no gestiona kernels, patches ni auto-upgrade de nodes.
- Baseline de seguridad por default: Autopilot fuerza private cluster, shielded nodes, WIF, dataplane V2 — no hay riesgo de olvidar un flag.
- Facturación granular (per-pod): Finance puede atribuir coste por workload sin necesidad de nodeSelectors ni taints.
- Preparados para `gcp-10` (Binary Authorization, WIF para pipelines) sin re-estructurar los clusters.

### Negativas

- Pérdida de control fino: no podemos elegir machine type, co-tenencia de pods ni ajustes de kernel. Mitigación: aceptable para los workloads actuales; si uno exige control, se migra a Standard sin tocar los otros.
- Upgrade forzoso de nodes en maintenance windows: la app debe tolerar restarts. Mitigación: `PodDisruptionBudget` + readiness probes bien configuradas.
- Sobrecargo del ~15 % en recursos requested vs Standard: aceptable dado el ahorro operativo. Se re-evaluaría si la utilización sostenida de un workload supera el 80 %.
- Dependencia más fuerte de GKE/Google: la portabilidad a EKS requeriría re-escribir las restricciones de Autopilot (`hostPath`, DaemonSets) si en algún momento se usan. Hoy no se usan.

## Alternativas descartadas

### Alternativa A: GKE Standard para los dos workloads

- Nodes dedicados con autoscaler.
- **Por qué no**: ni `checkout-api` ni `training-jobs` justifican el overhead de gestionar nodes propios. Para `training-jobs`, pagar GPUs idle 24×7 sería ineficiente; para `checkout-api`, los picos esporádicos no amortizan el pool de nodes mínimo.

### Alternativa B: EKS en lugar de GKE

- Si la org ya estuviera en AWS, EKS sería razonable. Pero: la org está decidiendo entrar a cloud y las razones por las que eligió GCP (BigQuery pre-existente para analytics, equipo con experiencia GCP) no cambian con esta decisión. EKS implicaría mantener IRSA (más piezas de JSON de trust policies que WIF for GKE), instalar `aws-load-balancer-controller` y `cluster-autoscaler`/`karpenter`, y usar Fargate como análogo parcial de Autopilot (más restrictivo). Sin ganancia neta.

### Alternativa C: Cloud Run en lugar de GKE para `checkout-api`

- Para una API HTTP stateless, Cloud Run suele ser mejor opción que incluso Autopilot (ver `gcp-04`). **No descartada completamente**: si el sidecar de Istio managed resultara ser el único motivo para quedarse en K8s y se pudiera resolver con Cloud Run + Gateway, migraríamos `checkout-api` a Cloud Run. Decisión diferida: evaluar tras 6 meses en Autopilot.

### Alternativa D: GKE Autopilot con GPUs pero `training-jobs` en Vertex AI

- Vertex AI sería más natural para entrenamiento ML, pero añade otra plataforma al stack y nuestros scripts actuales son nativos K8s (Kubeflow). Se re-evaluará en Fase 4.

---

## Nota sobre IDs

Todos los IDs usados en el Terraform (`my-project-123`, `my-project-123.svc.id.goog`) son placeholders. En Fase 4, los IDs reales se parametrizarán vía `variables.tf` + `terraform.tfvars` **fuera** del repo (o en un sops/vault).
