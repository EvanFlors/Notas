# Leccion — Compute Engine, Cloud Run y Cloud Functions

> Objetivo: entender los tres planos de compute gestionado de GCP y decidir — con criterio — cual tocar en cada caso. Ninguno de los ejemplos se despliega a GCP real; todo lo que corre en esta leccion corre local.

---

## 1. Panorama rapido vs AWS

| AWS | GCP equivalente | Observacion |
|-----|-----------------|-------------|
| EC2 (instancia o ASG) | **Compute Engine (GCE)** + MIG | Mismo modelo "VM que arranca con una imagen". |
| ECS/Fargate detras de ALB | **Cloud Run** (service) | Scale-to-zero + concurrencia por instancia. |
| AWS App Runner | **Cloud Run** (service) | GCP no tiene producto separado: Cloud Run cubre ambos. |
| Lambda | **Cloud Functions gen 2** o **Cloud Run** directo | gen 2 **es** Cloud Run por debajo. |
| ECS Scheduled Task / batch corto | **Cloud Run jobs** | Para procesos de corta duracion sin servidor HTTP. |
| EventBridge → Lambda | Eventarc / Pub/Sub → Cloud Functions gen 2 | El trigger lo gestiona Eventarc o Pub/Sub. |

**Idea central:** en GCP, Cloud Run absorbe la mayor parte de lo que en AWS esta repartido entre ECS/Fargate, App Runner y buena parte de Lambda. Esto reduce el numero de servicios que hay que dominar y clarifica el ADR "donde corre esto".

---

## 2. Compute Engine (GCE) — el plano de VMs

### 2.1 Primitivas

- **Instance:** una VM. Zonal (vive en una zona). Imagenes publicas (Debian, Ubuntu, COS) o custom.
- **Instance template:** receta inmutable (machine type, imagen, metadata, startup script, service account).
- **Managed Instance Group (MIG):** instancia N replicas de un template; puede ser **zonal** o **regional** (regional = replicas repartidas en >= 3 zonas de la region → HA nativo).
- **Autoscaler:** cambia el tamano del MIG por metricas (CPU, LB utilization, Stackdriver/Cloud Monitoring custom metric).

### 2.2 Patrones clave

- **MIG regional + autoscaler** es el equivalente moderno de un Auto Scaling Group multi-AZ.
- **Spot VMs** (sucesoras de preemptible): hasta 60–91% mas baratas, se pueden terminar con 30s de aviso. Buen fit para batch o stateless replicables.
- **Shielded VM:** vTPM + Secure Boot + Integrity Monitoring. Encender por default en workloads sensibles.
- **OS Login:** en lugar de distribuir claves SSH por metadata, los usuarios SSH entran con su identidad Google y permisos IAM (`roles/compute.osLogin`, `roles/compute.osAdminLogin`). Es la via moderna y auditable; **no uses `ssh-keys` en metadata**.
- **Confidential VM:** memoria cifrada por AMD SEV / Intel TDX. Solo cuando lo exija compliance; cuesta mas.

### 2.3 Cuando elegir GCE

- Workload que **necesita el SO completo** (daemon especifico, driver, kernel module).
- Software legacy que no se contenericeriza en una tarde.
- Alto throughput sostenido donde el modelo "por request" de Cloud Run resulta mas caro (ej. una VM 24/7 saturada).

### 2.4 Cuando **no** elegir GCE

- Servicio HTTP stateless → Cloud Run casi siempre gana en TCO y simplicidad.
- Workload bursty con grandes periodos de inactividad → scale-to-zero de Cloud Run ahorra dinero y operaciones.

---

## 3. Cloud Run — el plano serverless de containers

### 3.1 Modelo mental

- Despliegas una **imagen OCI** (cualquier Dockerfile vale, no hay runtime propietario).
- Cloud Run levanta instancias **por request** segun demanda; apaga cuando no hay trafico (**scale-to-zero**).
- Cada instancia atiende hasta **N requests concurrentes** (default 80). Esto es muy distinto de Lambda (1 request por instancia); una app FastAPI/async puede servir decenas de requests por instancia.
- Cada despliegue nuevo crea una **revision inmutable**. El trafico se enruta por **traffic splits** (p. ej. 95% a `rev-N`, 5% a `rev-N+1`).

### 3.2 CPU allocation modes

| Modo | Comportamiento | Casos |
|------|----------------|-------|
| **CPU only during requests** | Cobra CPU solo mientras hay request en vuelo. Scale-to-zero completo. | Default. API HTTP tipica. |
| **CPU always allocated** | Cobra CPU incluso sin request. **Permite background work** (timers, flush de buffers). | Streaming, websockets largos, trabajos que post-procesan tras devolver 200. |

### 3.3 Cold starts

- Cold start = tiempo de arrancar la instancia + importar la app + listener HTTP arriba.
- Mitigaciones:
  - **`min-instances >= 1`** (paga por instancia caliente, elimina cold start del hot path).
  - Imagen slim (Python slim-bookworm, no la full).
  - Lazy imports en el handler.
- **gVisor:** Cloud Run corre tu container dentro de **gVisor**, un sandbox userspace que intercepta syscalls. Es el motivo por el que algunas llamadas de bajo nivel no funcionan (p. ej. `ptrace`). A cambio ganas aislamiento multi-tenant seguro.

### 3.4 Revisiones y traffic splitting

```hcl
resource "google_cloud_run_v2_service" "api" {
  name     = "capstone-api"
  location = "europe-west1"

  template {
    revision = "capstone-api-v2"  # nombre explicito -> rollback trivial
    containers { image = "europe-west1-docker.pkg.dev/PLACEHOLDER/img/api:v2" }
  }

  traffic {
    type     = "TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION"
    revision = "capstone-api-v1"
    percent  = 95
  }
  traffic {
    type     = "TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION"
    revision = "capstone-api-v2"
    percent  = 5
  }
}
```

Rollback = cambiar los `percent` a `100/0` y re-aplicar. **No se construye nada**; es solo cambiar routing.

### 3.5 Cloud Run jobs

- Service = container que escucha HTTP y escala por request.
- Job = container que se ejecuta hasta terminar (exit 0) y se apaga. Equivalente a ECS Scheduled Tasks o Lambda sin trigger HTTP.
- Util para migraciones de DB, batch nocturno, reproceso.

---

## 4. Cloud Functions gen 2 — Cloud Run con triggers

- gen 2 **es Cloud Run** por debajo. Lo que anade: **Functions Framework** (polyfill HTTP alrededor de tu handler), **triggers** nativos (Eventarc, Pub/Sub, Firestore, Cloud Storage, HTTP, Scheduler).
- Modelo mental: escribes `def handler(event)` o `def handler(request)` y Cloud Run lo expone.
- Puedes correr el handler **local** con `functions-framework --target=handler --port 8080` — es la misma forma en la que lo correra Cloud Run.
- Elige Functions gen 2 cuando el **trigger** es lo que te importa (p. ej. "cuando se suba un objeto a GCS, procesalo"); elige Cloud Run directo cuando queres control total del Dockerfile y del server.

---

## 5. Criterio de eleccion — 3 workloads

| Workload | Plano | Por que |
|----------|-------|---------|
| API HTTP publica, trafico bursty, Python/Node, con horas de inactividad | **Cloud Run** | Scale-to-zero + concurrencia + revisiones con canary. |
| Daemon stateful que necesita acceso a `/dev/net/tun`, hostNetwork o drivers | **GCE** (MIG) | gVisor en Cloud Run no permite estos accesos; container en GCE si. |
| "Cuando entre un objeto al bucket `uploads/`, re-encodealo" | **Cloud Functions gen 2** | El trigger GCS es nativo; menos pegamento que montar Cloud Run + Eventarc manual. |

El error tipico es ir a GKE "por si acaso". GKE paga la pena solo cuando el **modelo Kubernetes** (sidecars, operadores, service mesh) aporta valor explicito. Si solo necesitas correr un container HTTP, Cloud Run gana.

---

## 6. IAM y runtime identity

- Toda carga de compute corre con una **Service Account** (SA) adjunta. Si no la pones, usa la SA de Compute Engine por default (demasiado permisiva — **evitar**).
- Para Cloud Run: `service_account = "runtime-sa@<project>.iam.gserviceaccount.com"` en el `template`.
- Para GCE: `service_account { email = ... scopes = ["cloud-platform"] }` en el instance template.
- **Nunca** generar keys JSON para la SA; se consume via la metadata API dentro del container/VM y via ADC (Application Default Credentials) desde las librerias Google.

---

## 7. Build y Registry

- Las imagenes van a **Artifact Registry** (sucesor de Container Registry). Formato Docker, pero tambien Maven/npm/Python.
- Cloud Run acepta cualquier imagen OCI; **no** hay runtime propietario. Esto significa que el mismo `Dockerfile` que corres con `docker run -p 8080:8080 ...` localmente, corre tal cual en Cloud Run (siempre que escuche en `$PORT`, por default 8080).

---

## 8. Costos — intuicion

- **Cloud Run / Functions gen 2:** se paga vCPU-s + memoria-s + requests. Scale-to-zero = cero coste en reposo (modo "only during requests"). Para una API que recibe pocos requests/minuto el coste puede ser literalmente centavos/mes.
- **GCE:** se paga la VM corra o no haya trafico. Spot/preemptible y schedules de parada bajan el coste; aun asi, para trafico bursty una VM tipica es mas cara que Cloud Run.
- **Egress a Internet:** cuidado. Dentro de la misma region hacia servicios Google es gratis; a Internet se paga por GB.

---

## 9. Lo que **nunca** vas a hacer en este modulo

- `terraform apply` a GCP real → no.
- `gcloud run deploy` → no.
- Crear un proyecto GCP real → no.

Lo que si vas a hacer:

- `docker build` y `docker run` de la imagen FastAPI, en tu laptop.
- `python -m pip install -r requirements.txt && functions-framework --target=handler` para el handler de Functions.
- `terraform init -backend=false && terraform validate` sobre los `.tf`.
- Opcionalmente, con credenciales simuladas, `terraform plan` (fallara si intenta llamar al API; es diagnostico, no apply).

---

## 10. Antipatrones comunes

1. Usar la SA default de Compute en Cloud Run / GCE "para empezar". **Siempre** una SA dedicada con permisos minimos.
2. Dockerfiles basados en `python:3.12` full (300 MB+). Usar `-slim` o distroless.
3. Hardcodear el puerto 8000 en el server pero no leer `$PORT`. Cloud Run inyecta el puerto; **debe leerse** de `PORT` (default 8080).
4. Un unico Terraform que mezcla Cloud Run + GCE + DB + red. Separar modulos por scope de cambio.
5. Confundir **Cloud Run service** con **Cloud Run job**. Service = HTTP, Job = ejecucion unica.

---

## 11. Siguiente paso

Despues de esta leccion, haz las dos actividades:

- `01-deploy-same-app-run-and-gce-compare` — forzar la comparacion escribiendo los dos despliegues.
- `02-canary-5pct-rollout` — un canary 95/5 "de verdad" en Terraform.

Luego, el modulo que viene (`gcp-05`) te conecta Cloud Run a Cloud SQL con IAM — y es ahi donde empiezan a verse las ventajas combinadas del plano.
