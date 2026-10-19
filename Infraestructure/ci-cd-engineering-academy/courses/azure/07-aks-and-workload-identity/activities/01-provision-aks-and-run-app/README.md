# Actividad 01 — Diseñar la provisión de AKS y correr la app en `kind`

## 1. Identificación

- **ID:** `az-07-01-provision-aks-and-run-app`
- **Tecnología:** `azure`
- **Módulo:** `az-07-aks-and-workload-identity`
- **Dificultad:** advanced
- **Duración estimada:** 100–140 min
- **Tipo:** architecture (sin coste en Azure)

## 2. Contexto

Vas a diseñar la provisión de un cluster AKS "productivo típico" **sin levantarlo**. Entregas:

- Un `main.tf` que llama a `azurerm_kubernetes_cluster` con OIDC + Workload Identity habilitados y al menos dos node pools.
- Manifiestos de Kubernetes para una app simple (`Deployment` + `Service` + `Ingress`) que **sí** vas a desplegar — pero en un cluster local **`kind`**, no en AKS.
- Un **ADR** (Architecture Decision Record) que fije 3 decisiones duras.
- Un plan `AKS_PLAN.md` con la arquitectura resumida.

### Nota de coste

El **control plane de AKS Free** cuesta 0 USD/hora, pero **cada node pool es una VMSS** y cuesta como VMs (típicamente ~70 USD/mes por un single-node pool pequeño vacío). **Esta actividad NO levanta nada en Azure.** Solo `terraform validate` + `kind` local. Si tras completar la actividad decides provisionar en Azure, es bajo tu responsabilidad y tu bolsillo.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Escribir un `main.tf` que llame a `azurerm_kubernetes_cluster` con:
  - `oidc_issuer_enabled = true` y `workload_identity_enabled = true`.
  - `default_node_pool` como system pool en 3 zonas, con `only_critical_addons_enabled = true`.
  - Un `azurerm_kubernetes_cluster_node_pool` adicional (`mode = "User"`) con autoscaling.
  - `network_profile` con `network_plugin = "azure"` y `network_plugin_mode = "overlay"`.
  - `identity` tipo `UserAssigned` apuntando a una `azurerm_user_assigned_identity`.
  - `azure_active_directory_role_based_access_control { azure_rbac_enabled = true }` + `local_account_disabled = true`.
- Correr `terraform init -backend=false && terraform validate` y que pase.
- Desplegar manifiestos K8s (Deployment, Service, Ingress) en un cluster `kind` local, verificando pods `Ready`.
- Defender 3 decisiones de arquitectura: mix de node pools, modo de CNI, acceso al cluster.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §2, §3, §4, §5).
- Haber recorrido `../../examples/01-aks-with-tf/`.
- Herramientas locales:
  - `bash`, `grep`, `awk`.
  - **`terraform`** (>= 1.6).
  - **`kind`** (>= 0.20) y **`kubectl`**.
  - **`docker`** corriendo (lo usa `kind`).

**Costos Azure**: 0.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/az-07-01/{terraform,k8s,docs}
cd /tmp/az-07-01
```

### 5.2 Terraform: `terraform/main.tf`

Escribe un `main.tf` que incluya, **al menos**:

- Un `provider "azurerm"` con `features {}`. Los `subscription_id` y `tenant_id` **deben** ser el placeholder canónico `00000000-0000-0000-0000-000000000000` y `11111111-1111-1111-1111-111111111111` (no uses IDs reales).
- Un `azurerm_resource_group` para el cluster.
- Un `azurerm_user_assigned_identity` que será la identidad del cluster.
- Un `azurerm_kubernetes_cluster` con:
  - `oidc_issuer_enabled = true`.
  - `workload_identity_enabled = true`.
  - `identity { type = "UserAssigned" ... }`.
  - `azure_active_directory_role_based_access_control { azure_rbac_enabled = true ... }`.
  - `local_account_disabled = true`.
  - `default_node_pool { ... }` como system pool: `zones`, `only_critical_addons_enabled = true`, autoscaling.
  - `network_profile { network_plugin = "azure", network_plugin_mode = "overlay", network_policy = ... }`.
- Un `azurerm_kubernetes_cluster_node_pool` extra con `mode = "User"` y autoscaling.

Luego valida:

```bash
cd /tmp/az-07-01/terraform
terraform init -backend=false
terraform validate
```

Debe salir `Success! The configuration is valid.`.

### 5.3 Manifiestos de la app: `k8s/app.yaml`

Un `Deployment` + `Service` + `Ingress` para una app trivial (sirve con un `nginx` o un echo). Reglas:

- `Deployment` con `replicas: 2`, `resources.requests` y `resources.limits` explícitos.
- `Service` tipo `ClusterIP`.
- `Ingress` con anotación que **sería** interpretada por el **App Routing** add-on en AKS (p. ej. `kubernetes.io/ingress.class: webapprouting.kubernetes.azure.com`). En `kind` no hay App Routing — la anotación es ignorada, pero el objeto es válido.

### 5.4 Desplegar en `kind` (proxy local)

Crea un cluster `kind` y aplica tus manifiestos:

```bash
kind create cluster --name az-07-demo
kubectl --context kind-az-07-demo apply -f /tmp/az-07-01/k8s/app.yaml
kubectl --context kind-az-07-demo rollout status deploy/<nombre> --timeout=120s
kubectl --context kind-az-07-demo get pods,svc,ingress
```

Verifica que **los pods pasan a `Ready`**. Si no, itera sobre el manifest (es el punto del ejercicio).

### 5.5 `docs/AKS_PLAN.md`

Documento corto (1 página) con:

- Arquitectura resumen (3–5 líneas o un ASCII diagram): control plane managed, system pool, user pool(s), CNI overlay, add-ons que piensas habilitar.
- Lista de **add-ons** que incluirás (al menos: OMS/Container Insights, App Routing, Key Vault secrets provider, Workload Identity webhook) y por qué.
- Lista de **lo que esta actividad NO prueba** porque `kind` ≠ AKS (p. ej. Workload Identity real, App Routing real, Container Insights real, Entra RBAC real).

### 5.6 `docs/ADR.md`

Un ADR con **3 decisiones** (una sección por cada una). Formato:

```
## Decision 1 — Mix de node pools

**Status:** Accepted
**Context:** <carga que vas a correr>
**Options considered:**
  - Solo system pool
  - System + 1 user pool
  - System + user pool + Spot pool
  - System + user pool + Virtual Nodes
**Decision:** <elegida>
**Rationale:** <2–4 líneas>
**Consequences:** <trade-offs>
```

Decisiones obligatorias:

1. **Mix de node pools** (system solo vs system + user vs añadir Spot/Virtual Nodes).
2. **Modo de CNI** (Azure CNI vs Azure CNI Overlay vs kubenet).
3. **Modo de acceso al cluster** (Entra ID + Azure RBAC for Kubernetes con `local_account_disabled = true` vs modos legacy con cuentas locales).

### 5.7 Limpieza

```bash
kind delete cluster --name az-07-demo
rm -rf /tmp/az-07-01
```

## 6. Resultado esperado

En `/tmp/az-07-01`:

```
terraform/main.tf
k8s/app.yaml
docs/AKS_PLAN.md
docs/ADR.md
```

Con:

- `terraform validate` → OK.
- Pods del `kind` en `Ready`.
- ADR con 3 decisiones y rationale defendible.

El validador cubre estructura; semántica la revisas tú contra `solution/REFERENCE.md`.

## 7. Criterios de aceptación

- **Funcionalidad**: `bash tests/validate.sh /tmp/az-07-01` pasa.
- **Calidad**: ADR nombra al menos **3 trade-offs** concretos.
- **Reproducibilidad**: cualquiera con `terraform` y `kind` puede repetir lo mismo.
- **Mantenibilidad**: HCL formateado (`terraform fmt`), YAML válido, **cero IDs reales** (usa los placeholders canónicos).

## 8. Validación

```bash
bash tests/validate.sh /tmp/az-07-01
```

Lo que comprueba:

- Existen los 4 archivos entregables.
- `main.tf` menciona `azurerm_kubernetes_cluster`, `oidc_issuer_enabled`, `workload_identity_enabled`, `default_node_pool`, `azurerm_kubernetes_cluster_node_pool`, `network_plugin_mode`, `azure_active_directory_role_based_access_control`, `local_account_disabled`.
- `main.tf` usa el `subscription_id` placeholder `00000000-0000-0000-0000-000000000000` y **no** parece contener un UUID real.
- `app.yaml` tiene `Deployment`, `Service`, `Ingress`.
- `AKS_PLAN.md` menciona add-ons y lo que `kind` NO prueba.
- `ADR.md` tiene 3 decisiones con `Decision:` y `Rationale:` que tocan los temas obligatorios.
- Si `terraform` está en PATH, corre `terraform init -backend=false && terraform validate` en `terraform/`.

## 9. Preguntas de reflexión

1. ¿Qué de tu `main.tf` **no** se puede validar sin credenciales Azure? ¿Por qué?
2. ¿Qué pieza del `k8s/app.yaml` solo tendría efecto real en AKS (no en `kind`)?
3. Si cambiases el CNI a **Azure CNI plano** (sin overlay), ¿qué dos cosas del ADR cambiarían?
4. ¿Qué riesgos tiene habilitar `local_account_disabled = true` desde el día 1? ¿Cuál es tu "break-glass"?

## 10. Extensiones

- Añade un **tercer node pool Spot** con taints y toleraciones, y un `PodDisruptionBudget` al Deployment.
- Añade un manifiesto `Namespace` + `ResourceQuota` para la app.
- Añade al Terraform un `oms_agent` apuntando a un `azurerm_log_analytics_workspace`.

## 11. Limpieza

```bash
kind delete cluster --name az-07-demo
rm -rf /tmp/az-07-01
```

No queda nada en Azure porque **nada se creó**.
