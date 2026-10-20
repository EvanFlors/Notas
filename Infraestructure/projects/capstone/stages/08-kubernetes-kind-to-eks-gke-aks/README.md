# Capstone — Stage 08 · Portado a Kubernetes (kind → EKS/GKE/AKS)

> Fase 5 · Dominio D8 · Portado desde servicios "serverless-containers"
> (ECS Fargate / Cloud Run / Container Apps) hacia Kubernetes gestionado.
> **Local-first**: todo lo que se enseña aquí corre en `kind`; la nube se
> entrega como **plan + walkthrough** para no quemar presupuesto.

---

## 1. Resumen de la etapa

Portamos la app FastAPI + PostgreSQL del stage 7 a Kubernetes **con manifests
crudos** (sin Helm todavía). Enseñamos los primitivos: `Deployment`,
`Service`, `Ingress`, `HPA`, `PDB`, `NetworkPolicy`, `ServiceAccount`,
`ConfigMap` y `Secret` sellado localmente. El layout está pensado para
**Kustomize** (base + overlays por ambiente).

**Delta vs. stage 7**: dejamos de depender del runtime propietario del
proveedor (ECS task / Cloud Run service / Container App revision) y
pasamos a un contrato portable: *un cluster + manifests YAML*. La misma
base se materializa en kind local, EKS, GKE o AKS.

**Fuera de scope** (lo cubre el stage 9/10): Helm chart propio, Argo CD,
GitOps multi-ambiente, Argo Rollouts, Istio/Linkerd, ExternalSecrets con
Vault, mTLS entre pods.

---

## 2. Arquitectura al cierre de esta etapa

```
                         ┌──────────────────────────────────────┐
                         │ Ingress (NGINX en kind / ALB en EKS) │
                         └──────────────┬───────────────────────┘
                                        │
                                   ┌────▼────┐
                                   │ Service │   ClusterIP
                                   │  app    │
                                   └────┬────┘
                                        │
                          ┌─────────────┼─────────────┐
                     ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
                     │  Pod    │   │  Pod    │   │  Pod    │  ← HPA 2..6
                     │ fastapi │   │ fastapi │   │ fastapi │  ← PDB minAvailable=1
                     └────┬────┘   └────┬────┘   └────┬────┘
                          │             │             │
                          └─────────────┼─────────────┘
                                        │  NetworkPolicy
                                        ▼  egress: db only
                                 ┌─────────────┐
                                 │  Postgres   │  (external managed DB)
                                 └─────────────┘
```

**Recursos K8s** por ambiente: `Namespace`, `ServiceAccount`,
`ConfigMap`, `SealedSecret`, `Deployment`, `Service`, `Ingress`,
`HorizontalPodAutoscaler`, `PodDisruptionBudget`, `NetworkPolicy`.

**Recursos cloud** (walkthrough): EKS 1.30 managed node group t3.medium
×2, o GKE Autopilot, o AKS 1.30 system+user node pool. Base de datos
sigue siendo el RDS/Cloud SQL/Azure DB del stage 7.

---

## 3. Prerrequisitos verificados

- [x] Stage 1-4: app + tests + Docker image publicada.
- [x] Stage 5: pipeline que firma y produce SBOM (la imagen que
      aterriza en el cluster es la misma que firma el pipeline).
- [x] Stage 6: Terraform instalado y state remoto configurado.
- [x] Stage 7: la app corre en ECS/CR/ACA; la base de datos managed
      está disponible y accesible con host/user/pass conocidos.
- [x] `kubectl >= 1.30`, `kind >= 0.24`, `kustomize >= 5` y
      `kubeseal >= 0.27` instalados localmente (`make tools` del repo
      raíz los deja listos).

Si falta algo, **no avances**: regresa al stage correspondiente.

---

## 4. Implementación guiada

### 4.1 Cluster kind local

```bash
kind create cluster --config kind/kind-config.yaml --name capstone
kubectl cluster-info --context kind-capstone
```

El `kind-config.yaml` expone los puertos 80/443 del nodo control-plane
al host, de modo que un `Ingress` NGINX responde directamente en
`http://localhost`.

Instala el controller del ingress (una sola vez):

```bash
kubectl apply -f https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=180s
```

### 4.2 Base kustomize

Todo lo portable vive en `k8s/base/`. La base **no** fija imagen, tag,
réplicas ni dominio: eso es responsabilidad del overlay.

```bash
kubectl apply -k k8s/overlays/dev --dry-run=client --validate=false -o yaml | head -50
```

### 4.3 Overlays por ambiente

| Overlay   | Namespace | Réplicas | HPA min/max | Host                    |
|-----------|-----------|----------|-------------|-------------------------|
| `dev`     | `app-dev` | 1        | 1 / 2       | `dev.capstone.local`    |
| `staging` | `app-stg` | 2        | 2 / 4       | `stg.capstone.example`  |
| `prod`    | `app-prd` | 3        | 3 / 6       | `app.capstone.example`  |

### 4.4 Secrets locales con sealed-secrets

```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system

# generar un secret y sellarlo (ejemplo con valor DUMMY)
kubectl create secret generic app-db \
  --from-literal=DATABASE_URL='postgresql://user:DUMMY@db:5432/app' \
  --dry-run=client -o yaml | \
  kubeseal --format=yaml > k8s/overlays/dev/sealed-db.yaml
```

Los sellados sí se commitean. Los `Secret` crudos **nunca**.

### 4.5 Nube (plan-only)

Cada carpeta `terraform/<cloud>/` contiene un stack **mínimo**:

- Red (reutiliza VPC del stage 6).
- Cluster gestionado + node group pequeño.
- IAM/Workload Identity para que los pods obtengan credenciales sin
  llaves estáticas.
- Outputs: `cluster_name`, `endpoint`, `kubeconfig_command`.

Flujo en todas las nubes:

```bash
cd terraform/aws/eks         # o gcp/gke, o azure/aks
terraform init -backend=false
terraform validate
terraform plan -out=tfplan   # NO aplicar en el aula
```

El walkthrough explica qué pediría la nube si se corriera `apply`
(tiempo, costo, dependencias), para que el estudiante lo recorra sin
gastar.

---

## 5. Actividades del estudiante

1. `01-kind-apply-and-smoke` — **guided-lab**: levanta kind, aplica
   overlay `dev`, verifica rollout y `kubectl apply --dry-run=client` en
   los tres overlays.
2. `02-eks-tf-plan-walkthrough` — **independent**: ejecuta
   `terraform plan` para EKS/GKE/AKS, interpreta el plan y responde 5
   preguntas en `WALKTHROUGH.md`.
3. `03-adr-managed-k8s-choice` — **architecture (ADR)**: decide qué
   nube de las tres lleva el capstone al siguiente stage y justifica
   con criterios (costo, madurez, ergonomía del equipo).

---

## 6. Entregables

- `k8s/base/**` con los 8 recursos listados.
- `k8s/overlays/{dev,staging,prod}/` aplicables en kind.
- `kind/kind-config.yaml` reproducible.
- `terraform/{aws,gcp,azure}/**` con `init && validate && plan` ok.
- `activities/*/README.md` + `activity.yaml` + `tests/validate.sh`.
- `resources/links.md` con la bibliografía mínima.

---

## 7. Pruebas y criterios de aceptación

Automatizadas (ejecuta `./validate.sh` desde la raíz de la stage):

- `kubectl apply --dry-run=client --validate=false -k k8s/overlays/<env>`
  sale 0 en los 3 overlays (sin cluster necesario).
- `kustomize build k8s/overlays/<env>` produce YAML válido.
- `terraform init -backend=false && terraform validate` sale 0 en las
  3 nubes.
- `yamllint` (si está) no reporta errores de sintaxis en los manifests.
- `activity.yaml` de cada actividad tiene `id`, `technology=capstone`
  y `module=08-kubernetes-kind-to-eks-gke-aks`.

Manual (criterios de calidad):

- Ninguna secret cruda en git (grep de `password:` / `token:`).
- `securityContext` con `runAsNonRoot: true`.
- `NetworkPolicy` default-deny de ingress en el namespace.
- `PDB` presente para proteger drains.

---

## 8. Costos y limpieza

Local: **$0**. Un cluster kind + sealed-secrets corren en ~400 MB RAM.

Nube (si decidieras aplicar, lo cual **no** haremos en esta stage):

| Cloud | Recurso                     | USD/mes aprox |
|-------|-----------------------------|---------------|
| AWS   | EKS control plane           | 73            |
| AWS   | 2× t3.medium                | 60            |
| GCP   | GKE Autopilot (idle)        | 73            |
| Azure | AKS control plane (free)    | 0             |
| Azure | 2× Standard_B2s             | 60            |

Limpieza:

```bash
# local
kind delete cluster --name capstone

# nube (si llegaste a aplicar — fuera de scope)
cd terraform/<cloud> && terraform destroy
```

---

## 9. Riesgos y mitigaciones

| Riesgo                                           | Mitigación                                          |
|--------------------------------------------------|-----------------------------------------------------|
| Estudiante aplica `terraform apply` sin querer   | README avisa, `plan` graba `tfplan`, no `apply`.    |
| Secretos reales en git                           | `kubeseal` obligatorio; `.gitignore` ignora Secret. |
| Image pull privada falla en kind                 | Documentado `kind load docker-image` como fallback. |

Hints progresivos (si se atasca):

1. `kubectl get events -A --sort-by=.lastTimestamp | tail -20`.
2. `kubectl describe pod <pod>` y mira `ImagePullBackOff`.
3. Revisa que el overlay apunte al namespace correcto.

---

## 10. Puente con la siguiente etapa

Habilita el stage 9 (Helm chart + Argo CD): ya tienes manifests que
sirven de **referencia** para parametrizar un chart; ya tienes 3
overlays que se vuelven 3 `Application` de Argo CD.

Qué dejar corriendo: nada en nube. En local, puedes dejar kind o
borrarlo — el stage 9 lo recrea.

Cliffhanger: *"¿cómo garantizo que lo que está en main es exactamente
lo que corre en el cluster, sin que nadie haga `kubectl apply` a mano?"*
→ GitOps.
