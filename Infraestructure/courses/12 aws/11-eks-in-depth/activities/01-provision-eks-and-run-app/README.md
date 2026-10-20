# Actividad 01 — Diseñar la provisión de EKS y correr la app en `kind`

## 1. Identificación

- **ID:** `aws-11-01-provision-eks-and-run-app`
- **Tecnología:** `aws`
- **Módulo:** `aws-11-eks-in-depth`
- **Dificultad:** advanced
- **Duración estimada:** 100–130 min
- **Tipo:** architecture (sin coste en AWS)

## 2. Contexto

Vas a diseñar la provisión de un cluster EKS "productivo típico" **sin levantarlo**. Entregas:

- Un `main.tf` que llama al módulo oficial de Terraform.
- Un `eksctl-config.yaml` equivalente.
- Manifiestos de Kubernetes para una app simple (Deployment + Service + Ingress) que **sí** vas a desplegar — pero en un cluster local **`kind`**, no en EKS.
- Un **ADR** (Architecture Decision Record) que fije 3 decisiones duras.
- Un plan `EKS_PLAN.md` con la arquitectura resumida.

### Nota de coste

**Levantar EKS cuesta $0.10/hora de control plane + nodos + NAT + LB** → mínimo ~$5/día incluso vacío. **Esta actividad NO levanta nada en AWS.** Solo `terraform validate` + `eksctl --dry-run` + `kind` local. Si tras completar la actividad decides provisionar en AWS, es bajo tu responsabilidad y tu bolsillo.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Escribir un `eksctl` config válido con managed node group, OIDC habilitado, add-ons administrados y access entries.
- Escribir un `main.tf` equivalente usando el módulo oficial `terraform-aws-modules/eks/aws`.
- Correr `terraform init -backend=false && terraform validate` y que pase.
- Desplegar manifiestos K8s (Deployment, Service, Ingress) en un cluster `kind` local, verificando pods `Ready`.
- Defender 3 decisiones de arquitectura: cómputo (MNG/self-managed/Fargate), autoscaler (CAS/Karpenter), acceso (access entries/aws-auth).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §2, §5, §8, §9).
- Haber recorrido `../../examples/01-eks-with-tf-blueprint/`.
- Herramientas locales:
  - `bash`, `grep`, `awk`.
  - **`terraform`** (>= 1.6).
  - **`eksctl`** (opcional — si no lo tienes, la validación salta ese paso).
  - **`kind`** (>= 0.20) y **`kubectl`**.
  - **`docker`** corriendo (lo usa `kind`).

**Costos AWS**: $0.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/aws-11-01/{terraform,eksctl,k8s,docs}
cd /tmp/aws-11-01
```

### 5.2 Terraform: `terraform/main.tf`

Escribe un `main.tf` que llame al módulo oficial `terraform-aws-modules/eks/aws` con, **al menos**:

- `cluster_name`, `cluster_version` pineada.
- Un **managed node group** con `instance_types`, `min_size`, `max_size`, `desired_size`.
- `enable_irsa = true`.
- `cluster_addons` con **al menos**: `coredns`, `kube-proxy`, `vpc-cni`, `aws-ebs-csi-driver`.
- `authentication_mode = "API"` y al menos una **access entry** con un ARN **ficticio** (`123456789012` como account id).
- Dependencia de un `module "vpc"` (puede ser el módulo oficial, en el mismo archivo o un segundo archivo).

Luego valida:

```bash
cd /tmp/aws-11-01/terraform
terraform init -backend=false
terraform validate
```

Debe salir `Success! The configuration is valid.`.

### 5.3 `eksctl`: `eksctl/cluster.yaml`

Escribe un `ClusterConfig` **equivalente** al Terraform: misma versión, mismo managed node group, mismo set de add-ons, mismo `authenticationMode: API` con una access entry.

Si tienes `eksctl` instalado, valida con dry-run:

```bash
eksctl create cluster --config-file=/tmp/aws-11-01/eksctl/cluster.yaml --dry-run
```

(Si no lo tienes instalado, el validador no exige este paso.)

### 5.4 Manifiestos de la app: `k8s/app.yaml`

Un `Deployment` + `Service` + `Ingress` para una app trivial (sirve con un `nginx` o un echo). Reglas:

- `Deployment` con `replicas: 2`, `resources.requests` y `resources.limits` explícitos.
- `Service` tipo `ClusterIP`.
- `Ingress` con anotación que **sería** interpretada por el AWS Load Balancer Controller (p. ej. `kubernetes.io/ingress.class: alb` y `alb.ingress.kubernetes.io/scheme: internet-facing`). En `kind` no hay ALB — la anotación es ignorada, pero el objeto es válido.

### 5.5 Desplegar en `kind` (proxy local)

Crea un cluster `kind` y aplica tus manifiestos:

```bash
kind create cluster --name aws-11-demo
kubectl --context kind-aws-11-demo apply -f /tmp/aws-11-01/k8s/app.yaml
kubectl --context kind-aws-11-demo rollout status deploy/<nombre> --timeout=120s
kubectl --context kind-aws-11-demo get pods,svc,ingress
```

Verifica que **los pods pasan a `Ready`**. Si no, itera sobre el manifest (es el punto del ejercicio).

### 5.6 `docs/EKS_PLAN.md`

Documento corto (1 página) con:

- Arquitectura resumen (3–5 líneas o un ASCII diagram).
- Lista de add-ons que incluirás y por qué.
- Lista de **lo que esta actividad NO prueba** porque `kind` ≠ EKS (p. ej. IRSA real, ALB real, VPC CNI real).

### 5.7 `docs/ADR.md`

Un ADR con **3 decisiones** (una sección por cada una). Formato:

```
## Decision 1 — Modelo de cómputo

**Status:** Accepted
**Context:** <carga que vas a correr>
**Options considered:**
  - Managed node groups
  - Self-managed node groups
  - Fargate profiles
**Decision:** <elegida>
**Rationale:** <2–4 líneas>
**Consequences:** <trade-offs>
```

Decisiones obligatorias:

1. **Modelo de cómputo** (MNG vs self-managed vs Fargate).
2. **Autoscaler de nodos** (Cluster Autoscaler vs Karpenter).
3. **Modo de acceso al cluster** (access entries vs `aws-auth`).

### 5.8 Limpieza

```bash
kind delete cluster --name aws-11-demo
rm -rf /tmp/aws-11-01
```

## 6. Resultado esperado

En `/tmp/aws-11-01`:

```
terraform/main.tf
eksctl/cluster.yaml
k8s/app.yaml
docs/EKS_PLAN.md
docs/ADR.md
```

Con:

- `terraform validate` → OK.
- Pods del `kind` en `Ready`.
- ADR con 3 decisiones y rationale defendible.

El validador cubre estructura; semántica la revisas tú contra `solution/REFERENCE.md`.

## 7. Criterios de aceptación

- **Funcionalidad**: `bash tests/validate.sh /tmp/aws-11-01` pasa.
- **Calidad**: ADR nombra al menos **3 trade-offs** concretos.
- **Reproducibilidad**: cualquiera con `terraform`, `eksctl`, `kind` puede repetir lo mismo.
- **Mantenibilidad**: HCL formateado (`terraform fmt`) y YAML válido.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-11-01
```

Lo que comprueba:

- Existen los 5 archivos entregables.
- `main.tf` menciona `terraform-aws-modules/eks/aws`, `enable_irsa`, `cluster_addons`, `authentication_mode`, un access entry.
- `cluster.yaml` menciona `kind: ClusterConfig`, `managedNodeGroups`, `withOIDC`, `addons`, `authenticationMode`.
- `app.yaml` tiene `Deployment`, `Service`, `Ingress`.
- `EKS_PLAN.md` menciona add-ons y lo que `kind` NO prueba.
- `ADR.md` tiene 3 decisiones con `Decision:` y `Rationale:`.
- Si `terraform` está en PATH, corre `terraform init -backend=false && terraform validate` en `terraform/`.

## 9. Preguntas de reflexión

1. ¿Qué de tu `main.tf` **no** se puede validar sin credenciales AWS? ¿Por qué?
2. ¿Qué pieza del `k8s/app.yaml` solo tendría efecto real en EKS (no en `kind`)?
3. Si cambiases el modelo de cómputo a Fargate, ¿qué dos cosas del ADR cambiarían?
4. ¿Qué riesgos tiene empezar con `authentication_mode = "API"` desde el día 1 vs `API_AND_CONFIG_MAP`?

## 10. Extensiones

- Añade un **segundo managed node group** solo-Spot con taints y toleraciones.
- Añade un `PodDisruptionBudget` al Deployment y verifica en `kind` que un `kubectl drain` lo respeta.
- Añade un manifiesto `Namespace` + `ResourceQuota` para la app.

## 11. Limpieza

```bash
kind delete cluster --name aws-11-demo
rm -rf /tmp/aws-11-01
```

No queda nada en AWS porque **nada se creó**.
