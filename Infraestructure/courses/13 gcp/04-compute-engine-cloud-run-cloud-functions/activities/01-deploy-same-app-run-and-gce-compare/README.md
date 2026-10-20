# Actividad 01 — Misma app en Cloud Run y en GCE, y DECISION.md

## 1. Identificacion

- **ID:** `gcp-04-01-deploy-same-app-run-and-gce-compare`
- **Tecnologia:** `gcp`
- **Modulo:** `gcp-04-compute-engine-cloud-run-cloud-functions`
- **Dificultad:** intermediate
- **Duracion estimada:** 80-100 min
- **Tipo:** guided-lab

## 2. Contexto

El equipo del capstone tiene una API HTTP en Python (FastAPI) y necesita decidir **donde la corre en GCP**. Para evitar discusiones de pizarra, el ejercicio es escribir **los dos despliegues en Terraform** (Cloud Run v2 y Compute Engine MIG) con la misma imagen, construir la imagen localmente, y escribir un `DECISION.md` corto justificando la eleccion final.

**No se despliega nada a un proyecto GCP real.** Todo queda en tu disco. El validador comprueba estructura; la correccion semantica es tuya (comparando con `solution/`).

## 3. Objetivos

Al terminar deberias poder, **sin consultar la leccion**:

- Explicar en una frase por que Cloud Run suele ganar para APIs HTTP bursty (`scale-to-zero` + concurrencia).
- Explicar que gana GCE y que paga como contrapartida (control del SO vs coste 24/7).
- Redactar Terraform minimo de un `google_cloud_run_v2_service` con **service account dedicada** (no la default) y lectura de `$PORT`.
- Redactar Terraform minimo de un `google_compute_instance_template` y un `google_compute_region_instance_group_manager` para la misma app.
- Escribir un `DECISION.md` con **al menos 3 criterios** comparados y una decision explicita.

## 4. Prerrequisitos

- Haber leido `../../theory/lesson.md`.
- Haber recorrido `../../examples/01-fastapi-on-cloud-run/` como referencia.
- Herramientas locales: `bash`, `jq`, `terraform` (>= 1.3), `docker`, `python3`. **No** se necesita proyecto GCP ni credenciales reales.
- Costos esperados: **cero**.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gcp-04-run-vs-gce
cp -r starter/* /tmp/gcp-04-run-vs-gce/
cd /tmp/gcp-04-run-vs-gce
```

Puedes trabajar en otra ruta pasandola al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Construye y corre la imagen local

```bash
docker build -t capstone-local .
docker run --rm -p 8080:8080 capstone-local
# en otra terminal
curl -s localhost:8080/healthz   # {"status":"ok"}
```

Esto reproduce exactamente lo que haria Cloud Run.

### 5.3 Completa `cloud-run.tf`

Debes anadir, sobre el starter:

- `resource "google_cloud_run_v2_service" "api"` con:
  - `location = "europe-west1"`.
  - `template.service_account` apuntando a una SA **no** default.
  - Un `containers` block con `image`, `ports.container_port = 8080` y una `env` que setee `PORT=8080`.
  - Un `traffic` block con `percent = 100`.

### 5.4 Completa `gce.tf`

Debes anadir:

- `resource "google_compute_instance_template" "api"` con `machine_type`, `disk`, `network_interface`, `metadata_startup_script` que arranque la app (puede ser un `echo "would run docker here"` — es papel) y un bloque `service_account` con `email` **distinto** del default.
- `resource "google_compute_region_instance_group_manager" "api"` referenciando el template, `region = "europe-west1"`, `base_instance_name`, `target_size`.

### 5.5 Escribe `DECISION.md`

Debe contener, como minimo:

- Un titulo de seccion con la cadena `Decision` o `Decisión`.
- Mencion explicita de **Cloud Run** y **Compute Engine** (o GCE).
- Al menos **3 criterios** comparados (ej. coste en reposo, cold start, control del SO, operaciones).
- Una decision final del tipo "elegimos X porque ...".

### 5.6 Validar

```bash
bash tests/validate.sh /tmp/gcp-04-run-vs-gce
```

Opcional:

```bash
cd /tmp/gcp-04-run-vs-gce
terraform init -backend=false -input=false
terraform validate
```

## 6. Entregables

- `Dockerfile`, `main.py`, `requirements.txt` ya listos en el starter — asegurate de que `docker build` funciona.
- `cloud-run.tf` completo.
- `gce.tf` completo.
- `DECISION.md` con la seccion `Decision`, los dos planos y >=3 criterios.

## 7. Autoevaluacion

Compara tu `cloud-run.tf`, `gce.tf` y `DECISION.md` con `solution/`.
