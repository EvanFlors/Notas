# Actividad 01 — GKE Standard vs Autopilot: Terraform y ADR

## 1. Identificación

- **ID:** `gcp-07-01-gke-standard-vs-autopilot-tf-plan-and-adr`
- **Tecnología:** `gcp`
- **Módulo:** `gcp-07-gke-and-autopilot`
- **Dificultad:** advanced
- **Duración estimada:** 90–120 min
- **Tipo:** architecture (independent — sin dependencia de la actividad 02)

## 2. Contexto

Una org con dos workloads nuevos quiere entrar a GKE y necesita decidir el modo:

- **`checkout-api`**: API HTTP stateless en Python, 3–10 pods, picos de ×3 a mediodía, SLA 99.9 %. Usa un sidecar oficial de Istio-managed (no custom) y no requiere `hostPath`.
- **`training-jobs`**: Jobs batch de ML que entrenan modelos usando GPUs L4 con drivers NVIDIA **estándar** (no custom), ejecución diaria, duración de 30–90 min por job, 5–20 pods en paralelo.

Finance pide un modelo de coste razonado. Security pide:

- Private cluster (nodes sin IP pública).
- Workload Identity Federation for GKE habilitada.
- Release channel declarado explícitamente (nunca "sin canal").
- Dataplane V2 o NetworkPolicy habilitado para microsegmentación.

Tu encargo: **escribir el Terraform de dos clusters** (uno Standard, uno Autopilot) y un **ADR** que decida qué modo asignas a cada workload. Validas localmente con `terraform validate` (sin `apply`, sin credenciales GCP).

**Importante**: no hay project GCP real. Usa `my-project-123` como placeholder; **no incluyas IDs reales**. El entregable es texto + Terraform.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Escribir `google_container_cluster` para los dos modos con los bloques mínimos de seguridad del baseline.
- Explicar qué bloques Terraform **solo** aplican a Standard (`node_pool`, `cluster_autoscaling`) y cuáles aplican a ambos (`workload_identity_config`, `release_channel`, `private_cluster_config`).
- Decidir modo por workload y defender la decisión en un ADR con alternativas descartadas.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §2, §3, §4, §9).
- Haber recorrido `../../examples/01-gke-autopilot-vs-standard/`.
- **Terraform CLI** instalado (opcional pero recomendado; sin él, el validador omite las comprobaciones de `terraform validate` y solo hace comprobaciones de contenido).

**Costos**: ninguno. No se ejecuta `terraform apply`.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gcp-07-01-gke-tf-adr/terraform/standard
mkdir -p /tmp/gcp-07-01-gke-tf-adr/terraform/autopilot
cd /tmp/gcp-07-01-gke-tf-adr
```

Puedes usar otro directorio, pero pásalo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `terraform/standard/main.tf`

Debe declarar al menos:

- Un bloque `terraform { required_providers { google = { source = "hashicorp/google" } } }` y un `provider "google"` con `project` y `region` (placeholders, p. ej. `my-project-123`, `europe-west1`).
- Un `resource "google_container_cluster" "primary"` con:
  - `name = "checkout-gke-standard"` (o similar).
  - `location` regional (p. ej. `europe-west1`).
  - `remove_default_node_pool = true` + `initial_node_count = 1`.
  - `workload_identity_config { workload_pool = "my-project-123.svc.id.goog" }`.
  - `release_channel { channel = "REGULAR" }` (o "STABLE" para prod).
  - `private_cluster_config { enable_private_nodes = true, enable_private_endpoint = false, master_ipv4_cidr_block = "172.16.0.0/28" }`.
  - `network_policy { enabled = true, provider = "CALICO" }` **o** `datapath_provider = "ADVANCED_DATAPATH"` (Dataplane V2).
- Un `resource "google_container_node_pool" "primary_nodes"` con:
  - `node_count` o autoscaling (`min_node_count`, `max_node_count`).
  - `node_config { machine_type, service_account, oauth_scopes, shielded_instance_config { enable_secure_boot = true, enable_integrity_monitoring = true } }`.
  - `management { auto_upgrade = true, auto_repair = true }`.

### 5.3 Escribe `terraform/autopilot/main.tf`

Debe declarar al menos:

- Mismo bloque `terraform` y `provider`.
- Un `resource "google_container_cluster" "autopilot"` con:
  - `enable_autopilot = true`.
  - `name = "checkout-gke-autopilot"` (o similar).
  - `location` regional.
  - `workload_identity_config { workload_pool = "my-project-123.svc.id.goog" }`.
  - `release_channel { channel = "REGULAR" }` (o "STABLE").
  - `private_cluster_config { enable_private_nodes = true, enable_private_endpoint = false, master_ipv4_cidr_block = "172.16.1.0/28" }`.

**No** declares `node_pool` en el Autopilot — es un error de Terraform.

### 5.4 Valida localmente los dos módulos (opcional pero recomendado)

Si tienes Terraform instalado:

```bash
cd /tmp/gcp-07-01-gke-tf-adr/terraform/standard
terraform init -backend=false
terraform validate
terraform fmt -check

cd /tmp/gcp-07-01-gke-tf-adr/terraform/autopilot
terraform init -backend=false
terraform validate
terraform fmt -check
```

**No ejecutes `terraform plan` ni `apply`** — no hay credenciales GCP y no queremos coste. El validador del ejercicio ya cubre `validate`.

### 5.5 Escribe `ADR-GKE-MODE.md`

Formato ADR estándar. Secciones obligatorias (el validador las busca):

1. **`# ADR`** (encabezado con la palabra "ADR").
2. **`## Estado`** (o `Status`).
3. **`## Contexto`** (o `Context`).
4. **`## Decisión`** (o `Decision`).
5. **`## Consecuencias`** (o `Consequences`).
6. **`## Alternativas`** (o `Alternatives` — al menos 2 descartadas).

Contenido mínimo obligatorio:

- Decisión explícita por workload: `checkout-api` → modo X; `training-jobs` → modo Y. **Justificar.**
- Comparación **GKE Standard vs GKE Autopilot vs EKS** (al menos un párrafo por opción).
- Mención del **release channel** elegido y por qué (Rapid/Regular/Stable).
- Mención explícita de **Workload Identity Federation for GKE**.
- Mención de al menos **3 restricciones de Autopilot** que son relevantes para la decisión.
- Mención del **modelo de coste** (per-node 24×7 vs per-pod/second).
- Mención de **Europa** / `europe-west1` o similar (compliance de región).

### 5.6 Entregables

```
/tmp/gcp-07-01-gke-tf-adr/
├── terraform/
│   ├── standard/main.tf
│   └── autopilot/main.tf
└── ADR-GKE-MODE.md
```

## 6. Resultado esperado

- Los dos `main.tf` existen, con los bloques mínimos declarados.
- Si Terraform está instalado, `terraform validate` pasa en los dos.
- El `ADR-GKE-MODE.md` tiene las 6 secciones y el contenido mínimo.
- Validador en verde: `0 issue(s)`.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Correctitud**: Terraform parseable; bloques mínimos presentes.
- **Calidad**: cada decisión del ADR está **justificada** (no solo listada).
- **Reproducibilidad**: alguien en Fase 4 podría tomar este Terraform, pegarle `project_id` real y `terraform apply` sin editarlo.
- **Mantenibilidad**: Markdown válido; Terraform formateado (`terraform fmt`).

## 8. Validación

```bash
bash tests/validate.sh /tmp/gcp-07-01-gke-tf-adr
```

El validador comprueba:

1. Existencia de los 3 archivos (`standard/main.tf`, `autopilot/main.tf`, `ADR-GKE-MODE.md`).
2. Bloques mínimos en cada `main.tf` (grep).
3. Si `terraform` CLI está disponible, `terraform init -backend=false` + `terraform validate` en cada módulo.
4. Secciones del ADR y contenido obligatorio.

**No** comprueba que el Terraform crearía el cluster correctamente en GCP (eso requiere credenciales y `plan` real).

## 9. Preguntas de reflexión

1. Si `checkout-api` crece a 50 pods sostenidos 24×7, ¿sigue siendo Autopilot la elección correcta? Haz la cuenta.
2. ¿Por qué pones `remove_default_node_pool = true` en el cluster Standard?
3. Si tu org exige Dataplane V2 por política, ¿puedes seguir usando Autopilot? ¿Y Standard?
4. Un desarrollador propone usar `hostPath` para un volumen compartido en `checkout-api`. ¿Cómo cambia tu decisión Standard vs Autopilot?
5. ¿Qué pasa el día que GKE promueve una versión de Regular a Stable mientras tu cluster está en Rapid? ¿Y en Stable?

## 10. Extensiones

- Añade un `terraform/standard-gpu/main.tf` con un `node_pool` adicional configurado para GPUs L4 (`guest_accelerator`, `taints`) orientado a `training-jobs` si decidiste Standard para ese workload.
- Añade variables (`variables.tf`) y un `terraform.tfvars.example` para parametrizar `project_id` y `region`.
- Añade un `backend.tf` con un `backend "gcs"` placeholder (comentado) para producción.

## 11. Limpieza

```bash
rm -rf /tmp/gcp-07-01-gke-tf-adr
```

No hay infraestructura que detener (nunca se hizo `apply`).
