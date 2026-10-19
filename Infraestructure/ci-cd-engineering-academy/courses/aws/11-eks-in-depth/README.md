# aws-11 — EKS en profundidad

## Identificación

- **ID:** `aws-11-eks-in-depth`
- **Curso:** `aws`
- **Nivel:** avanzado
- **Duración estimada:** 8 h
- **Prerrequisitos:** `aws-10` (compute: EC2, ASG, ALB) y curso **kubernetes** Nivel 1–2.

## Objetivo

Operar un cluster **EKS** productivo con **identidad por workload**. Al terminar deberías poder:

- Diseñar un cluster EKS con **control plane administrado** + al menos un modelo de cómputo (managed node groups, self-managed, o **Fargate profiles**), justificando la elección.
- Elegir entre **`aws-auth` ConfigMap** (legacy) y **EKS access entries** (moderno) para dar acceso humano/CI al cluster.
- Darle a un pod permisos AWS **sin keys estáticas** usando **IRSA (IAM Roles for Service Accounts)** y migrar la misma solución a **EKS Pod Identity**.
- Decidir, con criterio, entre **Cluster Autoscaler (CAS)** y **Karpenter** como provisionador de nodos.
- Enumerar y justificar los **add-ons** típicos (VPC CNI, CoreDNS, kube-proxy, EBS CSI, AWS Load Balancer Controller, External DNS, Karpenter o CAS).

## Alcance

Este módulo cubre:

- **Modelos de cómputo** en EKS: managed node groups vs self-managed vs Fargate (y cuándo cada uno encaja).
- **Versionado y upgrades** del control plane y data plane (ventanas, orden, Pod Disruption Budgets).
- **Acceso al cluster**: diferencias prácticas entre `aws-auth` ConfigMap y **access entries** (con tabla de equivalencias).
- **IRSA**: trust via OIDC provider, anotación `eks.amazonaws.com/role-arn` en el ServiceAccount, token proyectado, `AssumeRoleWithWebIdentity`.
- **EKS Pod Identity**: alternativa más simple basada en un agente DaemonSet; comparación directa con IRSA.
- **Add-ons** administrados y por qué son el camino recomendado frente a instalar los charts "a mano".
- **Karpenter** como *scheduler-driven provisioner* (NodePool + EC2NodeClass) y su ventaja frente a CAS.
- Integración con **ALB / NLB** vía AWS Load Balancer Controller y con **DNS** vía External DNS.

Lo que **no** cubre (se verá después):

- Observabilidad de EKS (CloudWatch Container Insights, AMP, ADOT) → `aws-12`.
- Service mesh (App Mesh, Istio en EKS) → fuera del roadmap base.
- Multi-cluster federation.

### Nota crítica sobre coste

El **control plane de EKS** cuesta **~$0.10/hora** por cluster (≈ $73/mes) **aun sin nodos**. Este módulo está diseñado para **$0 de gasto real**: todo se practica con `terraform plan`, validación de `eksctl` config files, y un cluster local **`kind`** para probar manifiestos. **No se levanta ningún cluster EKS real** salvo que el alumno decida pagarlo bajo su responsabilidad.

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones.
- **`examples/`** — tres ejemplos para lectura y adaptación local:
  - `01-eks-with-tf-blueprint/` — llamada al módulo oficial `terraform-aws-modules/eks/aws` + `eksctl` config equivalente, con comentarios sobre cada bloque.
  - `02-irsa-s3-access-from-pod/` — walkthrough anotado: OIDC provider, IAM role trust policy, ServiceAccount, Deployment que llama a S3 vía SDK.
  - `03-karpenter-provisioner/` — manifiestos `NodePool` + `EC2NodeClass` con comentarios sobre familia/arquitectura/spot, y comparación con un `ClusterAutoscaler` tradicional.
- **`activities/`** — dos actividades **independientes**:
  - `01-provision-eks-and-run-app/` — diseñar la provisión (Terraform plan + eksctl config), desplegar la app en `kind` como proxy local y escribir un ADR.
  - `02-migrate-irsa-to-pod-identity/` — plan de migración razonado de IRSA a Pod Identity con manifiestos antes/después y matriz de decisión.
- **`resources/links.md`** — enlaces oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar qué significa "control plane administrado" en EKS y qué queda bajo responsabilidad del cliente. Diferenciar IRSA de Pod Identity con precisión. |
| Operativa (sin coste) | Escribir un `eksctl` config válido y una llamada Terraform al módulo oficial. Desplegar un `Deployment + Service + Ingress` en `kind` que **sería** compatible con EKS + ALB Controller. |
| Arquitectónica | Elegir entre managed node groups, self-managed y Fargate para una carga dada. Elegir entre CAS y Karpenter. Elegir entre IRSA y Pod Identity. |

## Criterios de evaluación

- Entrega las dos actividades con sus validadores estructurales en verde.
- La **decisión argumentada IRSA vs Pod Identity** (actividad 02) está defendida con criterios técnicos, no con preferencias.
- El ADR de la actividad 01 nombra al menos **3 trade-offs** concretos (p. ej. managed vs self-managed, CAS vs Karpenter, access entries vs aws-auth).

## Entregables

- `EKS_PLAN.md` + `eksctl-config.yaml` + manifiestos de app + `ADR.md` (actividad 01).
- `MIGRATION.md` con comparación IRSA ↔ Pod Identity + manifiestos anotados antes/después (actividad 02).

## Siguiente módulo

→ `aws-12-observability-cloudwatch-xray-cloudtrail` — observabilidad nativa de AWS, con mirada específica a workloads en EKS.
