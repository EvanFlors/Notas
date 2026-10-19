# REFERENCE — aws-11-02-migrate-irsa-to-pod-identity

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## `manifests/sa-irsa.yaml` (modelo)

```yaml
# ANTES: ServiceAccount con IRSA.
#
# IAM role: arn:aws:iam::123456789012:role/app-s3-rw
#
# Trust policy (IAM, en formato JSON — aquí como comentario):
#
# {
#   "Version": "2012-10-17",
#   "Statement": [{
#     "Effect": "Allow",
#     "Principal": {
#       "Federated": "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLEDXXXXXXXXXXXXXXXXX"
#     },
#     "Action": "sts:AssumeRoleWithWebIdentity",
#     "Condition": {
#       "StringEquals": {
#         "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLEDXXXXXXXXXXXXXXXXX:sub": "system:serviceaccount:default:app",
#         "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLEDXXXXXXXXXXXXXXXXX:aud": "sts.amazonaws.com"
#       }
#     }
#   }]
# }
#
# Policy adjunta (IAM, mínima):
#
# {
#   "Version": "2012-10-17",
#   "Statement": [{
#     "Effect": "Allow",
#     "Action": ["s3:GetObject", "s3:PutObject"],
#     "Resource": "arn:aws:s3:::my-demo-bucket/*"
#   }]
# }
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/app-s3-rw
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: default
spec:
  replicas: 2
  selector: { matchLabels: { app: app } }
  template:
    metadata: { labels: { app: app } }
    spec:
      serviceAccountName: app
      containers:
        - name: app
          image: public.ecr.aws/aws-cli/aws-cli:latest
          command: ["/bin/sh", "-c", "aws sts get-caller-identity && sleep 3600"]
```

## `manifests/sa-pod-identity.yaml` (modelo)

```yaml
# DESPUES: mismo rol, mismo SA, mismo Deployment — pero trust distinta y
# una Pod Identity Association en lugar de la anotacion del SA.
#
# IAM role: arn:aws:iam::123456789012:role/app-s3-rw   (puede reusarse)
#
# Trust policy (IAM, simplificada):
#
# {
#   "Version": "2012-10-17",
#   "Statement": [{
#     "Effect": "Allow",
#     "Principal": { "Service": "pods.eks.amazonaws.com" },
#     "Action": ["sts:AssumeRole", "sts:TagSession"]
#   }]
# }
#
# Policy adjunta (igual que antes):
#
# {
#   "Version": "2012-10-17",
#   "Statement": [{
#     "Effect": "Allow",
#     "Action": ["s3:GetObject", "s3:PutObject"],
#     "Resource": "arn:aws:s3:::my-demo-bucket/*"
#   }]
# }
#
# Pod Identity Association (crear via CLI o Terraform):
#
#   aws eks create-pod-identity-association \
#     --cluster-name eks-demo \
#     --role-arn arn:aws:iam::123456789012:role/app-s3-rw \
#     --namespace default \
#     --service-account app
#
# Terraform equivalente:
#
#   resource "aws_eks_pod_identity_association" "app" {
#     cluster_name    = "eks-demo"
#     namespace       = "default"
#     service_account = "app"
#     role_arn        = aws_iam_role.app_s3_rw.arn
#   }
#
# Prerequisito en el cluster: add-on eks-pod-identity-agent instalado.
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app
  namespace: default
  # Sin anotacion eks.amazonaws.com/role-arn: ya no hace falta.
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  namespace: default
spec:
  replicas: 2
  selector: { matchLabels: { app: app } }
  template:
    metadata: { labels: { app: app } }
    spec:
      serviceAccountName: app
      containers:
        - name: app
          image: public.ecr.aws/aws-cli/aws-cli:latest
          command: ["/bin/sh", "-c", "aws sts get-caller-identity && sleep 3600"]
```

## `docs/MIGRATION.md` (modelo, extracto)

```markdown
# Migración IRSA → EKS Pod Identity

## Comparación IRSA vs Pod Identity

| Dimensión                 | IRSA                                    | Pod Identity                           |
|---------------------------|-----------------------------------------|----------------------------------------|
| Setup por cluster         | OIDC provider + trust por SA            | Add-on `eks-pod-identity-agent`        |
| Trust policy IAM          | Verbosa (Federated + sub + aud)         | Simple (`Service: pods.eks.amazonaws.com`) |
| Mecanismo de token        | Token proyectado + `AssumeRoleWithWebIdentity` | Agente local (link-local) + API EKS |
| Reuso del rol en N clusters | No (OIDC distinto por cluster)        | Sí (misma trust + varias associations) |
| Observabilidad            | CloudTrail `sts:AssumeRoleWithWebIdentity` | CloudTrail eks:AssumeRoleForPodIdentity |
| SDK AWS mínimo            | Antiguo (hace años)                     | Reciente (comprobar matriz oficial)    |
| Compatibilidad fuera EKS  | No                                      | No (es específico EKS)                 |
| Granularidad              | 1 rol por SA (típico)                   | 1 rol por SA o compartido              |
| Fallback si el mecanismo falla | SDK no puede renovar token         | Agente local caído = no credenciales   |

## Plan de migración por fases

### Fase 1 — Dual-run (1–2 semanas)
- Instalar add-on `eks-pod-identity-agent` en el cluster.
- Crear la Pod Identity Association **sin** quitar la anotación IRSA del SA.
- SDK: por orden de prioridad, elegirá IRSA (la variable `AWS_WEB_IDENTITY_TOKEN_FILE`
  está presente) salvo que fuerces `AWS_CONTAINER_CREDENTIALS_FULL_URI`.
- Observar métricas: `sts:AssumeRoleWithWebIdentity` vs `eks:AssumeRoleForPodIdentity`
  en CloudTrail. Validar que no hay regressions.

### Fase 2 — Cutover (por workload)
- Rollout del Deployment con la anotación IRSA del SA **eliminada**.
- El pod reinicia; el SDK ya no ve la variable IRSA y usa el agente Pod Identity.
- Validar `aws sts get-caller-identity` dentro del pod: debe reportar
  `arn:aws:sts::123456789012:assumed-role/app-s3-rw/eks-...`.

### Fase 3 — Rollback (si algo sale mal)
- Re-aplicar el SA con la anotación IRSA (todavía existe en git).
- Rollout. El SDK vuelve a IRSA.
- Postmortem: ¿SDK muy viejo? ¿Agente mal instalado? ¿Trust policy nueva incompleta?

## Matriz de decisión por escenario

### Escenario A — Greenfield, 1 cluster nuevo
**Decisión:** Pod Identity.
**Justificación:** Setup más corto, trust simple, roles reusables si mañana hay un
segundo cluster. Ningún coste de migración porque no hay IRSA preexistente.

### Escenario B — Legacy, 20 workloads IRSA en producción
**Decisión:** Dual-run por 1–2 sprints, migrar workload a workload, mantener IRSA
para los que no justifican el esfuerzo.
**Justificación:** IRSA no está roto; migrar todo "porque sí" tiene coste y
cero ganancia operativa. Reservar la migración para workloads que ganan algo
concreto (reuso de rol, simplificación de trust, consistencia con nuevos clusters).

### Escenario C — Workload cross-platform (corre también en ECS)
**Decisión:** NI IRSA NI Pod Identity "puros".
**Justificación:** IRSA es específico EKS; Pod Identity también. Para el pod EKS,
usa Pod Identity. Para la task ECS, usa **ECS Task Role** (patrón hermano,
distinto mecanismo pero mismo concepto: credenciales temporales por workload).
El código AWS SDK no cambia — ambos patrones exponen credenciales via las
variables `AWS_CONTAINER_CREDENTIALS_*`.

## Límite claro: lo que Pod Identity NO resuelve

- No funciona fuera de EKS (ECS, EC2, Lambda tienen sus propios patrones).
- No reemplaza una buena política IAM mínima (sigue siendo cosa tuya escribirla).
- No elimina la necesidad de **un rol por workload crítico**: compartir rol entre
  10 workloads con requisitos distintos vuelve al mismo problema de IRSA
  (política demasiado ancha).
- No es automático: hay que **instalar el add-on**, **crear la association** y
  **asegurarse de que el SDK es reciente**.

## 7 preguntas antes de autorizar una migración

1. ¿El SDK AWS del workload soporta Pod Identity? ¿Qué versión mínima?
2. ¿Está instalado el add-on `eks-pod-identity-agent` en el cluster?
3. ¿La trust policy nueva reemplaza completamente a la antigua o convive?
4. ¿Hay observabilidad en CloudTrail para distinguir ambos flujos durante dual-run?
5. ¿El workload tiene SLO que no tolera un rollout fallido?
6. ¿Hay otros workloads que reusarían el mismo rol? ¿Justifica Pod Identity?
7. ¿Qué pasa con los jobs batch de >1 h que renuevan credenciales a medio ejecutar?
```

## Comentarios de autoevaluación

- Si tu tabla de comparación tiene **menos de 6 filas**, repítela.
- Si tu plan por fases **no** contempla rollback, repítelo: todo cambio productivo
  necesita rollback explícito.
- Si el Escenario C sugiere "Pod Identity en ECS", repítelo: ECS tiene su propio
  mecanismo (**ECS Task Role**), independiente de EKS.
