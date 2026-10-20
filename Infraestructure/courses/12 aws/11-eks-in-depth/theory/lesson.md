# aws-11 — Lección: EKS en profundidad

> 10 secciones. Diseñada para estudiarse **sin levantar un cluster EKS real**.
> Prerrequisito: `aws-10` + curso kubernetes Nivel 1–2.
> **Coste de referencia:** control plane EKS = **$0.10/hora** (~$73/mes) **por cluster, aun sin nodos**.

---

## 1. Qué es EKS y qué queda bajo tu responsabilidad

**EKS (Elastic Kubernetes Service)** es la oferta administrada de Kubernetes en AWS. "Administrado" significa, en concreto:

- AWS corre y parcha el **control plane** (API server, scheduler, controller-manager, etcd), replicado en 3 AZ. No ves esos nodos, no los pagas por separado, no los parcheas.
- AWS garantiza compatibilidad con Kubernetes **vanilla**: `kubectl` upstream, manifests upstream, CRDs upstream.

Lo que **sigue siendo tu responsabilidad**:

1. El **data plane**: los nodos EC2 (managed node groups, self-managed) o Fargate.
2. La **red** (VPC, subnets, security groups, NAT) — EKS no la crea sola.
3. Los **add-ons**: CoreDNS, kube-proxy, VPC CNI vienen por defecto; EBS CSI, ALB Controller, External DNS, Karpenter — **no**.
4. El **IAM** del cluster y de los pods (IRSA / Pod Identity).
5. Los **upgrades** del data plane (el control plane lo subes tú, pero no AWS por ti).
6. **Observabilidad** y backups de estado aplicativo (etcd lo gestiona AWS, pero no tus volúmenes).

Mental model:

```
   ┌─────────────────────────────────────────────────────┐
   │ Managed by AWS                                      │
   │   control plane (API, scheduler, CM, etcd × 3 AZ)   │
   │   compatibilidad con K8s upstream                    │
   │   parches del control plane                          │
   └────────────────────────┬────────────────────────────┘
                            │  (visible via kubectl)
   ┌────────────────────────▼────────────────────────────┐
   │ Managed by YOU                                      │
   │   VPC / subnets / SG / NAT                          │
   │   nodes (EC2 managed/self-managed) o Fargate        │
   │   IAM (cluster role, node role, IRSA / Pod ID)      │
   │   add-ons (EBS CSI, ALB, External DNS, Karpenter…)  │
   │   upgrades del data plane y re-rollouts             │
   │   observabilidad + estado aplicativo                │
   └─────────────────────────────────────────────────────┘
```

Confundir el límite es el error #1 al adoptar EKS. "Es administrado" **no** significa "sin trabajo".

---

## 2. Modelos de cómputo: managed node groups, self-managed, Fargate

EKS da **tres** formas de poner pods a correr. Puedes mezclarlas en el mismo cluster.

### 2.1 Managed node groups (MNG)

- EKS crea y gestiona un **Auto Scaling Group** de EC2 por ti.
- Elige AMI (Amazon Linux 2 / 2023, Bottlerocket), lanza instancias, las registra en el cluster, hace **cordon + drain** durante upgrades.
- Es la opción **por defecto recomendada** para la mayoría de cargas.
- Lo que **no** hace: elegir el tipo de instancia óptimo por carga (eso lo decides tú o lo delegas a Karpenter), ni autoescalar más fino que el ASG.

### 2.2 Self-managed node groups

- Tú lanzas el ASG, tú gestionas el `userdata`, tú corres `bootstrap.sh`.
- Útil si necesitas control total: AMI custom, kernel patch, `kubelet` flags no soportados en MNG, GPU exótica.
- Más trabajo operativo, más riesgos de drift. Evitar salvo requisito claro.

### 2.3 Fargate profiles

- Serverless: ni ASG ni EC2 visibles. Tú defines un **Fargate profile** (namespace + labels) y los pods que machean corren en Fargate.
- Cada pod recibe su propia micro-VM (Firecracker). **No comparten kernel** entre tenants.
- Trade-offs:
  - **Pros:** no gestionas nodos, buena fit para cargas burst-y, baseline muy pequeño, aislamiento fuerte.
  - **Contras:** más caro por CPU-hora que EC2 reservado, **no DaemonSets** (no hay nodo), no soporta `hostNetwork`/`hostPort`, no soporta `type: NodePort`, GPUs limitadas, `/var/log/*` del nodo no accesible (toca sidecar para logs).
- Encaje típico: control plane de add-ons sin estado (p. ej. Karpenter mismo), apps web pequeñas con tráfico impredecible, tenants aislados.

### 2.4 Cómo elegir

| Carga | Modelo recomendado | Por qué |
|-------|---------------------|---------|
| Backend típico 24/7 con tráfico predecible | **Managed node groups** | Sencillo, Spot opcional, upgrades automatizados. |
| Jobs batch cortos muy variables | **Fargate** o Karpenter con Spot | Fargate: cero gestión; Karpenter: tipos óptimos. |
| GPU training con driver custom | **Self-managed** | Requiere control sobre AMI y driver. |
| Multi-tenant SaaS con tenants no confiables | **Fargate** | Aislamiento vía micro-VM. |
| App que necesita DaemonSet (CNI custom, agente propio) | **Managed** o self-managed | Fargate no soporta DaemonSets. |

---

## 3. Versionado y upgrades

EKS sigue el ciclo de Kubernetes upstream: una minor cada ~4 meses, EKS soporta **~14 meses** cada versión como *standard support* y hasta **26 meses** como *extended support* (con precio adicional por hora de control plane).

### 3.1 Orden canónico de upgrade

1. **Verificar deprecations** con `kubectl` + herramientas (`pluto`, `kubent`) → `apiVersion`s eliminadas rompen cargas al upgrade.
2. **Actualizar el control plane** (`eks update-cluster-version`). AWS garantiza compatibilidad con node groups N-1 y N-2.
3. **Actualizar los add-ons administrados** (CoreDNS, kube-proxy, VPC CNI) a la versión compatible con el nuevo control plane. Hay una matriz oficial.
4. **Actualizar node groups** uno por uno con Pod Disruption Budgets configurados. Managed node groups hacen cordon+drain automáticamente respetando el `terminationGracePeriodSeconds` del pod.
5. **Validar workloads** (health checks, dashboards, SLOs).

### 3.2 Trampas típicas

- Olvidar un add-on heredado (p. ej. una vieja release de `metrics-server` con `apiVersion` deprecated) → crash loop tras upgrade del control plane.
- No tener **PDB** en workloads críticos → una ventana de mantenimiento tumba el servicio.
- Nodes con AMI pineada a mano: el upgrade MNG no toca la AMI, hay que re-lanzar.
- `aws-auth` ConfigMap mal editado durante el proceso → nadie puede entrar al cluster. Access entries elimina este riesgo (ver §5).

---

## 4. Networking de EKS

### 4.1 VPC CNI (`aws-node`)

Por defecto, EKS asigna a cada pod una **ENI secundaria** o IP secundaria de la VPC. Consecuencias:

- Los pods tienen IP **ruteable** en la VPC. SG a nivel de pod posible con *security groups for pods*.
- El **tamaño de las subnets** limita cuántos pods caben: una `/24` con nodos m5.large (~29 pods por nodo) se queda sin IPs rápido. Dimensionar subnets de workload en `/18` o `/20`.
- Alternativas: `prefix delegation` (más IPs por ENI, menos ENIs) y modos custom networking (pods en subnets distintas a nodos).

### 4.2 Load Balancer Controller

El `AWS Load Balancer Controller` (helm chart) traduce:

- `Ingress` → **ALB** (Application LB, L7, path-based).
- `Service type: LoadBalancer` con anotaciones → **NLB** (Network LB, L4, soporta IPs estáticas).

Sin este controller, un `Service type: LoadBalancer` crea un **CLB** clásico (desaconsejado hoy).

### 4.3 External DNS

Controller que **lee** `Ingress` / `Service` y **escribe** records en Route 53 para que `my-app.example.com` apunte al ALB creado. Elimina el paso manual.

---

## 5. Acceso al cluster: `aws-auth` vs EKS access entries

Para que un principal IAM pueda hablar con la API de K8s, EKS necesita saber **qué usuario/grupo RBAC** representa.

### 5.1 Modelo legacy: `aws-auth` ConfigMap

- Un ConfigMap en `kube-system` lista `mapRoles` y `mapUsers`.
- **Editas YAML a mano** o vía `eksctl create iamidentitymapping`.
- Problemas históricos:
  - Si **borras o rompes** el ConfigMap, nadie entra al cluster — hay que recrearlo con el role creator original.
  - **No es auditable** por CloudTrail (es un objeto K8s, no una llamada AWS).
  - No soporta assignments granulares desde Terraform sin wrappers.

### 5.2 Modelo moderno: EKS access entries

Lanzado 2023. Cada **access entry** es un recurso IAM-aware: enlaza un ARN IAM con uno o varios **access policies** (p. ej. `AmazonEKSClusterAdminPolicy`, `AmazonEKSAdminPolicy`, `AmazonEKSViewPolicy`) y/o grupos K8s custom.

Ventajas:

- Gestionable por **IAM / Terraform** directamente (no hay que `kubectl` para dar acceso).
- Auditable vía CloudTrail (es API de EKS).
- Imposible dejarte fuera: borrar la access entry del creator original es una llamada API bloqueada.
- Convive con `aws-auth` durante migración (modo `API_AND_CONFIG_MAP`).

### 5.3 Tabla de equivalencias

| Caso | `aws-auth` | Access entries |
|------|-----------|-----------------|
| Dar acceso de admin a un rol de CI | `mapRoles` con `system:masters` | Access entry + `AmazonEKSClusterAdminPolicy` |
| Dar acceso de solo-lectura a un rol de SRE | `mapRoles` con grupo custom + Role K8s | Access entry + `AmazonEKSViewPolicy` |
| Dar acceso a un usuario IAM concreto | `mapUsers` | Access entry (ARN del usuario) |
| Auditar quién dio acceso | manual (git log) | CloudTrail nativo |

Recomendación: **access entries** para todo lo nuevo. `aws-auth` solo si tienes dependencias legacy.

---

## 6. IRSA (IAM Roles for Service Accounts)

El problema: un pod necesita llamar a AWS (p. ej. subir un objeto a S3) **sin** incrustar `AWS_ACCESS_KEY_ID` en el contenedor.

### 6.1 Mecánica

1. El cluster EKS tiene un **OIDC provider** asociado (una URL `https://oidc.eks.<region>.amazonaws.com/id/<cluster-id>`).
2. En IAM creas un rol cuya **trust policy** confía en ese OIDC provider y restringe por `sub` al ServiceAccount concreto: `system:serviceaccount:<ns>:<sa-name>`.
3. En el cluster creas un `ServiceAccount` con la anotación `eks.amazonaws.com/role-arn: arn:aws:iam::<acct>:role/<role>`.
4. Un **mutating admission webhook** inyecta en los pods que usan ese SA:
   - La variable `AWS_WEB_IDENTITY_TOKEN_FILE` apuntando a un **token proyectado**.
   - La variable `AWS_ROLE_ARN`.
5. El SDK AWS (versiones recientes) detecta esas variables y llama a **`AssumeRoleWithWebIdentity`** usando el token proyectado. Recibe credenciales temporales válidas ~1 h.

### 6.2 Ventajas

- Credenciales **temporales, por-pod**, rotadas automáticamente.
- **Granularidad por workload**: cada SA tiene su propio rol con su propia política mínima.
- Auditable vía CloudTrail (`sts:AssumeRoleWithWebIdentity`).

### 6.3 Puntos dolorosos

- **Setup por cluster**: hay que crear el OIDC provider una vez por cluster (lo hace `eksctl utils associate-iam-oidc-provider` o Terraform).
- **Trust policy** es verbosa y propensa a typos; el `sub` debe ser exacto.
- **No funciona fuera de EKS** (es específico al OIDC provider del cluster): un workload que corre también en ECS no puede reusar el mismo setup.
- Un rol **por SA** → inflación de roles IAM si tienes muchos microservicios.

---

## 7. EKS Pod Identity: la alternativa simplificada

Lanzado 2023, Pod Identity ataca los puntos dolorosos de IRSA sin romper el modelo.

### 7.1 Mecánica

1. Instalas el **add-on `eks-pod-identity-agent`** (DaemonSet oficial).
2. Creas un **Pod Identity Association** vía API de EKS: enlaza un `ServiceAccount` concreto (ns + nombre) con un `Role ARN`.
3. El agente actúa como un **servicio local** (equivalente conceptual a IMDS) que escucha en una IP de link-local.
4. El SDK AWS detecta las variables `AWS_CONTAINER_CREDENTIALS_FULL_URI` y `AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE` que inyecta el webhook y pide credenciales al agente.
5. El agente las obtiene de la API de EKS firmando con la identidad del nodo.

### 7.2 Comparación directa

| Dimensión | IRSA | Pod Identity |
|-----------|------|--------------|
| Setup por cluster | OIDC provider + trust policies | Instalar add-on + crear associations |
| Trust policy IAM | Verbosa, por SA | **Única y simple**: confía en `pods.eks.amazonaws.com` |
| Reuso del rol en varios clusters | **No** (OIDC distinto) | **Sí** (misma trust, varias associations) |
| Mecanismo | Token proyectado + `AssumeRoleWithWebIdentity` | Agente local + API EKS |
| Dependencias en el pod | Variables + token file | Variables + token file (otro formato) |
| Compatibilidad SDK | SDK v2 + versiones recientes v1 | SDK v2 + versiones recientes v1 |
| Observabilidad | CloudTrail STS | CloudTrail EKS |
| Casos borde | Pod sin kubelet proyection → falla | Agente caído → falla |

### 7.3 ¿Cuál elegir?

Regla práctica:

- **Greenfield** → **Pod Identity**: menos setup, trust reusable, roles compartibles.
- **Clusters con IRSA ya en producción** → **mantén IRSA** hasta que haya razón explícita (p. ej. compartir rol entre clusters, simplificar trust) y migra workload a workload.
- **Workloads que corren también fuera de EKS** (ECS, EC2) → **IRSA no sirve**; usar Pod Identity (compatible con ECS task roles) o un patrón de assume-role explícito.
- **Equipos con política IAM centralizada estricta** que prefieren una única trust policy auditable → **Pod Identity**.

La migración IRSA → Pod Identity es el tema de la actividad 02.

---

## 8. Add-ons: lo que viene y lo que no

### 8.1 Por defecto en todo cluster EKS

- **VPC CNI** (`amazon-vpc-cni`): red por pod via ENIs.
- **CoreDNS**: DNS cluster-internal.
- **kube-proxy**: iptables/IPVS para `Service`.

### 8.2 Managed add-ons recomendados (hay que activarlos)

| Add-on | Qué resuelve |
|--------|--------------|
| **EBS CSI driver** | Volúmenes `PersistentVolumeClaim` dinámicos en EBS. Sin esto, los PVCs no funcionan. |
| **EFS CSI driver** | PVCs en EFS (ReadWriteMany). Opcional. |
| **AWS Load Balancer Controller** | ALB/NLB vía Ingress / Service annotations. |
| **External DNS** | Records Route 53 automáticos. |
| **Pod Identity Agent** | Habilita EKS Pod Identity (ver §7). |
| **Cluster Autoscaler** o **Karpenter** | Autoscaling de nodos (uno u otro, no ambos). |
| **CloudWatch Observability** / **ADOT** | Métricas y logs (se cubre en `aws-12`). |

### 8.3 Por qué usar managed add-ons

- AWS mantiene versiones compatibles con la minor del control plane.
- Instalación/upgrade declarativa vía API de EKS, no via helm charts "a mano".
- Rollback nativo en caso de fallo.

Instalar el chart Helm "a mano" sigue funcionando, pero quedas tú con la responsabilidad de la matriz de compatibilidad.

---

## 9. Autoscaling de nodos: Cluster Autoscaler vs Karpenter

Dos filosofías distintas.

### 9.1 Cluster Autoscaler (CAS)

- **Scheduler-aware pero ASG-driven**: observa pods `Pending` y escala ASGs. Un ASG = un **node group** homogéneo.
- Para tener variedad (p. ej. m5.large, m5.xlarge, c6i.large), creas **múltiples ASGs** y CAS elige cuál escalar.
- **Tiempos**: pod `Pending` → CAS lo nota → escala ASG → ASG lanza EC2 → EC2 arranca kubelet → nodo `Ready` → scheduler asigna pod. 2–4 min típico.

### 9.2 Karpenter

- **Scheduler-driven**: observa pods `Pending` y lanza EC2 **directo** sin ASG intermedio.
- Define pools con **NodePool** (requirements CPU/arch/zone/instance-category) y **EC2NodeClass** (AMI family, subnets, SG).
- Elige la instancia **óptima** por carga: puede mezclar on-demand y spot, familias e instancias de distinto tamaño, en función de qué requiere cada pod `Pending`.
- **Tiempos** típicamente mejores que CAS porque no pasa por ASG. 30–60 s con AMIs cacheadas.
- **Consolidation**: redistribuye pods a nodos más baratos cuando hay oportunidad (feature clave de FinOps).

### 9.3 Tabla de decisión

| Dimensión | CAS | Karpenter |
|-----------|-----|-----------|
| Flexibilidad de tipos de instancia | **Baja** (homogéneo por ASG) | **Alta** (mezcla libre) |
| Latencia de scale-up | 2–4 min | 30–60 s |
| Soporte Spot | Sí vía ASG mixto | **Nativo y granular** |
| Consolidation / bin packing | Limitado | **Nativo** |
| Dependencias | ASG | **Ninguna**, EC2 directo |
| Curva de aprendizaje | Baja (conocido desde hace años) | Media (NodePool/EC2NodeClass CRDs) |
| Riesgo | Maduro | Maduro desde 2023, pero más joven |

Regla práctica: **Karpenter por defecto para greenfield**. CAS si tienes requisitos operativos específicos de ASG (p. ej. integraciones existentes), o cargas super-homogéneas donde la flexibilidad no aporta.

---

## 10. Qué llevarse

Al terminar este módulo deberías poder, sin consultar la lección:

- Enumerar los **tres modelos de cómputo** EKS y elegir uno para una carga dada defendiendo la decisión.
- Explicar el **flujo IRSA** (OIDC → trust policy → SA annotation → token proyectado → `AssumeRoleWithWebIdentity`) y el **flujo Pod Identity** (association → agente local → API EKS).
- Decidir entre **CAS y Karpenter** nombrando al menos 3 criterios.
- Enumerar los **add-ons mínimos** para un cluster "productivo" (VPC CNI, CoreDNS, kube-proxy por defecto + EBS CSI + ALB Controller + External DNS + autoscaler + pod identity agent).
- Recordar que el **control plane EKS cuesta $0.10/hora** aun sin nodos: ni creas clusters "para probar" sin propósito ni los dejas corriendo olvidados.

Síntesis:

> **EKS es "kubernetes administrado hasta la línea del data plane". El control plane lo paga y mantiene AWS; el data plane, la red, el IAM y los add-ons los diseñas tú. IRSA y Pod Identity son los dos caminos para darle identidad AWS a un pod — ambos sin keys estáticas, con Pod Identity ganando terreno por simplicidad. Karpenter se come a Cluster Autoscaler en flexibilidad y velocidad para la mayoría de cargas modernas.**
