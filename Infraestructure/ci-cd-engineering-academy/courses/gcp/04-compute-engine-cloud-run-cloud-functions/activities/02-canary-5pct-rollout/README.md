# Actividad 02 — Canary 95/5 en Cloud Run

## 1. Identificacion

- **ID:** `gcp-04-02-canary-5pct-rollout`
- **Tecnologia:** `gcp`
- **Modulo:** `gcp-04-compute-engine-cloud-run-cloud-functions`
- **Dificultad:** intermediate
- **Duracion estimada:** 50-70 min
- **Tipo:** independent

## 2. Contexto

El equipo quiere introducir una nueva revision de la API con **5% del trafico** antes de abrir al 100%. En Cloud Run esto es cambiar `traffic{}` en Terraform, sin construir ni redeployar. Para dejarlo bien hay que:

- Nombrar explicitamente las revisiones (`capstone-api-v1`, `capstone-api-v2`) para poder apuntar a ellas por nombre y hacer rollback trivial.
- Dejar escrito el procedimiento en `README-INTENT.md` para que cualquiera del equipo lo ejecute igual.

## 3. Objetivos

- Escribir `cloud-run.tf` con un `google_cloud_run_v2_service` que tenga **dos** bloques `traffic` sumando 100%.
- La revision nueva (`capstone-api-v2`) va en `template.revision`; recibe el 5%.
- Mantener la service account dedicada y lectura de `$PORT`.
- Escribir `README-INTENT.md` justificando la estrategia y el procedimiento de rollback.

## 4. Prerrequisitos

- `../../theory/lesson.md` seccion de revisiones y traffic splitting.
- `../../examples/02-cloud-run-traffic-splitting-canary/` como referencia.
- Herramientas: `bash`, `jq`, `terraform` (>= 1.3). **No** se necesita proyecto GCP.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/gcp-04-canary
cp -r starter/* /tmp/gcp-04-canary/
cd /tmp/gcp-04-canary
```

### 5.2 Completa `cloud-run.tf`

- `template.revision = "capstone-api-v2"` (nombre explicito).
- `template.service_account` apuntando a una SA dedicada.
- Dos bloques `traffic`:
  - `revision = "capstone-api-v1"` con `percent = 95`.
  - `revision = "capstone-api-v2"` con `percent = 5`.
- Ambos con `type = "TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION"`.

### 5.3 Escribe `README-INTENT.md`

Debe contener:

- Un titulo con la cadena `Canary` (o `canary`).
- Mencion explicita del split **95/5**.
- Un procedimiento de **rollback** (cambiar `percent` a 100/0 y re-aplicar).
- Mencion a **ambas** revisiones por nombre (`capstone-api-v1` y `capstone-api-v2`).

### 5.4 Validar

```bash
bash tests/validate.sh /tmp/gcp-04-canary
```

## 6. Entregables

- `cloud-run.tf` con el servicio y los dos `traffic` blocks.
- `README-INTENT.md`.
