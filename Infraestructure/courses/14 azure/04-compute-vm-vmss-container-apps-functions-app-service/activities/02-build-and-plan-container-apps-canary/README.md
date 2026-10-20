# Actividad 02 — Dockerfile buildable + Terraform plan de Container Apps con canary 90/10

## 1. Identificacion

- **ID:** `az-04-02-build-and-plan-container-apps-canary`
- **Tecnologia:** `azure`
- **Modulo:** `az-04-compute-vm-vmss-container-apps-functions-app-service`
- **Dificultad:** intermediate
- **Duracion estimada:** 90-120 min
- **Tipo:** mini-project (independent — no depende de la actividad 01)

## 2. Contexto

El capstone necesita desplegar la API FastAPI (`checkout-api`) en **Azure Container Apps** con **canary 90/10** entre dos revisions (`v1` y `v2`). El equipo de Platform te pide:

- un **Dockerfile multistage** que buildee localmente y produzca una imagen pequena (<300 MB).
- un **modulo Terraform** con un `azurerm_container_app` que use `revision_mode = "Multiple"`, Managed Identity y traffic split declarativo 90/10.
- validacion local: `terraform init -backend=false` + `terraform validate` + `docker build`, **sin cloud real**, sin tenant / subscription IDs reales, sin secretos.

El modulo lo aplicara Fase 4 en una suscripcion sandbox. Hoy solo generamos el artefacto.

**Importante**: no hay suscripcion Azure. No se provisiona nada. `terraform plan` contra cloud **no se corre** — solo `terraform validate`.

## 3. Objetivos

- Escribir un Dockerfile multistage buildable localmente (`docker build .`).
- Escribir `main.tf` + `variables.tf` con el recurso `azurerm_container_app` + `azurerm_container_app_environment` + `azurerm_resource_group` + `azurerm_log_analytics_workspace`.
- `revision_mode = "Multiple"`.
- Dos bloques `traffic_weight`: uno con `revision_suffix = "v1"` + `percentage = 90`, otro con `revision_suffix = "v2"` + `percentage = 10`.
- Identity bloque con `type = "SystemAssigned"`.
- `terraform validate` pasa.
- No secretos en env vars (no `AZURE_CLIENT_SECRET`, no `AZURE_TENANT_ID` hardcoded).

## 4. Prerrequisitos

- Haber leido `../../theory/lesson.md` y recorrido `../../examples/01-fastapi-on-container-apps/` y `../../examples/02-canary-with-revisions/`.
- Herramientas:
  - `bash`
  - `docker` (>= 20)
  - `terraform` (>= 1.5)
  - `az` CLI opcional (no requerido para la validacion offline)

**Costos**: ninguno. Nada toca cloud.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/az-04-02/app
cd /tmp/az-04-02
```

Estructura final esperada:

```
/tmp/az-04-02/
├── Dockerfile
├── main.tf
├── variables.tf
└── app/
    └── main.py
```

### 5.2 Escribe `app/main.py`

Una API FastAPI minima con un endpoint `/health` y uno `/version`:

```python
from fastapi import FastAPI
import os

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/version")
def version():
    return {"version": os.getenv("APP_VERSION", "v1")}
```

### 5.3 Escribe `Dockerfile` (multistage)

Requisitos:

- `FROM python` multistage (etapa `builder` + etapa final slim).
- Instala `fastapi` + `uvicorn[standard]`.
- `EXPOSE 8000`.
- `CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]`.
- Usuario no root (`USER` != root).

Debe buildear con `docker build -t az04-canary:test .` **localmente** (sin cloud).

### 5.4 Escribe `main.tf`

Requisitos obligatorios (el validador los exige):

- `terraform { required_providers { azurerm = ... } }` con version `~> 3.100` o similar.
- `provider "azurerm" { features {} }`.
- `azurerm_resource_group`.
- `azurerm_log_analytics_workspace`.
- `azurerm_container_app_environment`.
- `azurerm_container_app` con:
  - `revision_mode = "Multiple"`.
  - `identity { type = "SystemAssigned" }`.
  - `template { container { ... } min_replicas max_replicas }`.
  - `ingress { external_enabled = true target_port = 8000 }`.
  - Dos bloques `traffic_weight`: `v1` al 90% y `v2` al 10%.

### 5.5 Escribe `variables.tf`

Al menos:

- `variable "location"` con `default = "westeurope"`.
- `variable "image"` con default (puede ser `"mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"` como placeholder).

**Prohibido**: variables con `default` que contengan tenant IDs, subscription IDs o secretos reales. Usa placeholders obvios (`00000000-0000-0000-0000-000000000000`) si fuera necesario, pero preferiblemente ni los declares.

### 5.6 Entregable

```
/tmp/az-04-02/
├── Dockerfile
├── main.tf
├── variables.tf
└── app/main.py
```

**No incluyas** `ANALYSIS.md`. Otros validadores del repo tratan ese nombre con convenciones especiales.

## 6. Resultado esperado

Al correr el validador:

- Los 4 archivos existen.
- `docker build -q .` termina OK (imagen construida localmente).
- `terraform init -backend=false` + `terraform validate` termina OK.
- `main.tf` contiene los bloques requeridos (grep estructural).
- No hay secretos / tenant IDs hardcoded.

## 7. Criterios de aceptacion

- **Funcionalidad**: validador pasa en verde.
- **Correctitud**: `terraform validate` OK y `docker build` OK.
- **Seguridad**: zero secretos en texto plano.
- **Portabilidad**: el Dockerfile buildea en cualquier host con Docker >= 20.

## 8. Validacion

```bash
bash tests/validate.sh /tmp/az-04-02
```

El validador:

1. Comprueba existencia de los 4 archivos.
2. Corre `docker build` sobre el `Dockerfile` del alumno (etiquetado `az04-canary:test`).
3. Copia los `.tf` a un directorio temporal, corre `terraform init -backend=false` + `terraform validate`.
4. Grepea bloques obligatorios en `main.tf` (`revision_mode = "Multiple"`, `traffic_weight`, `SystemAssigned`, etc.).
5. Grepea anti-patrones (secretos hardcoded).

El validador **no** llama a Azure. Nunca autentica. Nunca aplica.

## 9. Preguntas de reflexion

1. Si cambiaras los pesos a `v1 = 50, v2 = 50` y aplicaras, cuanto trafico migraria? Como lo verificarias en App Insights?
2. Por que `min_replicas = 0` seria peligroso para `checkout-api`? Que valor usarias y por que?
3. Si el `template.container.image` apunta a `ghcr.io/example/api:v2` pero `v2` no existe, en que momento falla? (`terraform plan`? apply? primer request?)
4. Como anadirias un `custom_scale_rule` KEDA para escalar por `requests_per_second` leido de App Insights?
5. Si manana migras a AKS, que piezas de este `main.tf` cambian y que piezas (p. ej. el Dockerfile) se mantienen?

## 10. Extensiones

- Anade un `azurerm_container_app_environment_dapr_component` apuntando a una Service Bus queue (puede ser con placeholders).
- Anade un `azurerm_key_vault` + `azurerm_role_assignment` dando `Key Vault Secrets User` a la MI del Container App.
- Anade un `custom_scale_rule` para una cola Service Bus con `azure-servicebus` scaler KEDA.
- Convierte el Dockerfile a usar `distroless` como base final.

## 11. Limpieza

```bash
rm -rf /tmp/az-04-02
docker rmi az04-canary:test 2>/dev/null || true
```

No hay infraestructura cloud que detener.
