# gcp-07 — Lección: GKE Standard, Autopilot y Workload Identity

> 12 secciones. Prerrequisitos: `gcp-02`, `gcp-03`, `gcp-04`, curso Kubernetes Nivel 1–2 y, para contraste, `aws-11` (EKS).

---

## 1. Por qué GKE existe y qué resuelve respecto a EKS

Kubernetes como API es idéntico en todos lados: el mismo `kubectl apply -f` funciona en EKS, GKE, AKS o kind. La **diferencia material** entre ofertas managed está en:

1. **Cuánto pegamento tienes que instalar tú.** En EKS, el CNI (`aws-vpc-cni`), el controlador del Load Balancer (`aws-load-balancer-controller`), el autoscaler de nodes (`cluster-autoscaler` o Karpenter), y el proveedor de IAM para pods (IRSA) son componentes que tú instalas y versionas. En GKE, están **integrados** por default.
2. **Cómo se da identidad a los pods.** En EKS: **IRSA** (ServiceAccount K8s anotada con un IAM role ARN, trust policy OIDC específico, pod obtiene credenciales STS). En GKE: **Workload Identity Federation for GKE** — una anotación en el K8s SA + un binding IAM; el metadata server del cluster hace la federación transparente.
3. **Si el cluster te deja operar los nodes o no.** EKS: siempre. GKE: **Standard** sí; **Autopilot** no — Google opera los nodes por ti y te factura por pod.
4. **Cómo se gobierna el ciclo de upgrade.** EKS: upgrade manual del control plane por versión; luego actualizar el node group. GKE: **release channels** (Rapid/Regular/Stable) con auto-upgrade continuo del control plane y, opcionalmente, de los node pools.

> **Idea clave que repetiremos:** GKE Standard es "EKS pero con menos add-ons que instalar". GKE Autopilot es "una nueva forma de consumir Kubernetes, más parecida a Cloud Run para pods arbitrarios".

---

## 2. Dos modos: Standard y Autopilot

GKE ofrece dos "modos" que son clusters diferentes en el fondo, no una flag negociable después:

```
                  ┌─────────────────────────────────┐
                  │        google_container_cluster │
                  └──────────────┬──────────────────┘
                   enable_autopilot = false
                                 │
                  ┌──────────────┴───────────┐
                  ▼                          ▼
         ┌────────────────────┐   ┌─────────────────────┐
         │   GKE Standard      │  │   GKE Autopilot     │
         │   enable_autopilot  │  │   enable_autopilot  │
         │   = false           │  │   = true            │
         │                     │  │                     │
         │ - Tú defines node   │  │ - Google opera los  │
         │   pools, machine    │  │   nodes             │
         │   types, autoscaler │  │ - Pricing por pod   │
         │ - Pagas nodes 24x7  │  │ - Restricciones     │
         │ - Permite todo      │  │   endurecidas por   │
         │   (hostPath, priv)  │  │   default           │
         └────────────────────┘   └─────────────────────┘
```

### 2.1 GKE Standard

- Tú **declaras** `node_pool` (uno o varios) con machine type, `disk_size_gb`, `preemptible`/`spot`, taints, labels.
- **Cluster autoscaler** opcional: le das `min_node_count`/`max_node_count` y Google lo escala por ti, pero decides el rango.
- **Pagas por los nodes 24×7** (incluso si están idle) + un control plane fee a partir del **segundo cluster por región** (el primero por zona/región es gratis en algunas facturas; verificar).
- **Permite todo** lo que Kubernetes permite: `hostNetwork`, `hostPath`, `privileged: true`, `capabilities: [SYS_ADMIN]`, DaemonSets de infraestructura, etc.
- Usas Standard cuando necesitas **DaemonSets** (log collectors custom, service mesh sidecars manuales, GPUs con drivers custom), cuando trabajas con workloads **privilegiados** (admin de red interna, probes de hardware), o cuando quieres **control fino de bin-packing** (p. ej. mezclar un workload CPU-heavy con uno RAM-heavy en el mismo node para optimizar).

### 2.2 GKE Autopilot

- **No existen node pools** desde tu punto de vista. Google provisiona los nodes bajo el capó.
- **Facturas por pod/segundo**: lo que el pod *requested* (CPU, memoria, GPU opcional), multiplicado por el tiempo. Hay un sobrecargo de aproximadamente **15 %** sobre el precio de los recursos equivalentes en Standard, pero no pagas nodes idle.
- **Restricciones**: Autopilot **rechaza** admisión de pods que violan su contrato de seguridad. Entre lo que no deja (lista no exhaustiva, verificar vigente en Fase 4):
  - `hostNetwork: true`, `hostPID: true`, `hostIPC: true`.
  - `hostPath` volumes (salvo subset específico).
  - `privileged: true` o capabilities expandidas.
  - DaemonSets arbitrarios (Google corre sus propios DaemonSets de sistema; los tuyos están restringidos a casos aprobados).
  - Modificar namespaces de sistema (`kube-system`).
  - Algunos `nodeSelector` y `nodeAffinity` por labels de nodo custom (los nodes son opacos).
- **Permite** la mayoría de workloads de aplicación "normales": Deployments, StatefulSets con PersistentVolumeClaims (soportan Google Persistent Disk y Filestore), Jobs, CronJobs, Ingress, HPA, VPA.
- **Mantenimiento**: Google hace auto-upgrade del cluster entero según el *release channel*. **No puedes posponer indefinidamente** un upgrade en Autopilot.

> **Trampa habitual**: elegir Autopilot "porque es más fácil" para un workload que depende de un DaemonSet custom (p. ej. un agente antivirus). Falla en admisión; descubres tarde que debiste ir a Standard.

### 2.3 Cómo decidir en una frase

- **Autopilot**: aplicaciones *stateless* o *stateful ligeras*, bajo tráfico esporádico o pico estacional, equipo pequeño sin SRE dedicado, prioridad en reducir superficie operativa.
- **Standard**: workloads con sidecars propios, DaemonSets, GPUs con drivers custom, co-tenencia agresiva, control exacto de upgrade window, o cuando el perfil de carga sostenida hace que pagar nodes 24×7 sea más barato que pagar por pod.

---

## 3. Release channels y auto-upgrade

GKE empaqueta el ciclo de versiones de Kubernetes en tres **canales**:

| Canal | Qué recibe | Audiencia |
|-------|-----------|-----------|
| **Rapid** | Las nuevas versiones minor de K8s en cuanto estabilizan en GKE | Equipos que experimentan con features nuevas, dev clusters. |
| **Regular** | Versiones ya endurecidas, el default razonable | Clusters de staging y la mayoría de producción. |
| **Stable** | Versiones aún más conservadoras, con backports de parches | Producción crítica, workloads de larga vida. |

El cluster declara un canal (`release_channel = "REGULAR"` en Terraform) y Google **auto-upgrade** el control plane según su calendario. Los node pools pueden auto-upgrade también (recomendado) o quedarse en manual (requiere disciplina — hay que mantenerlos nunca más de 2 versiones minor por detrás del control plane).

En **Autopilot**, el canal también se elige, pero no puedes "pausar" un upgrade más allá de las *maintenance windows* configuradas. Es parte del contrato: Google opera los nodes a cambio de que acepten upgrades automáticos.

> **Fundamento interno**: el canal no es solo "qué versión instala"; es un **SLA de versión**. Rapid va, por ejemplo, `1.33`; Regular `1.32`; Stable `1.31`. Cuando GKE promueve una versión de Rapid a Regular, los clusters en Regular empiezan a recibirla sin que hagas nada. En EKS esto es siempre manual; a cambio tienes más control del timing.

---

## 4. Workload Identity Federation for GKE: identidad de pods sin keys

El problema: un pod necesita leer un bucket GCS, un secret, o emitir eventos a Pub/Sub. ¿Cómo autenticar?

- **Mal**: montar una **service account key** JSON como secret y usar `GOOGLE_APPLICATION_CREDENTIALS`. Rotación manual, filtra fácil, y en una org con `iam.disableServiceAccountKeyCreation` ni siquiera puedes crearla.
- **Bien**: **Workload Identity Federation for GKE** (antes "Workload Identity"). El K8s ServiceAccount se anota con un Google Service Account; el pod, al pedir token al metadata server del cluster, recibe un **token federado** del GSA. Sin secretos de larga duración, sin keys.

### 4.1 Piezas

```
┌───────────────────────────────────────────────────────────────┐
│  GKE cluster (project proj-platform)                          │
│                                                               │
│  workload_pool = "proj-platform.svc.id.goog"   ← identidad    │
│                                                 pool asociada │
│                                                 al cluster    │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │  namespace: checkout                                    │  │
│  │                                                         │  │
│  │  ServiceAccount: checkout-app                           │  │
│  │    annotations:                                         │  │
│  │      iam.gke.io/gcp-service-account:                    │  │
│  │        checkout-app@proj-platform.iam.gserviceaccount.com│  │
│  │                                                         │  │
│  │  Deployment -> spec.template.spec.serviceAccountName    │  │
│  │                 = checkout-app                          │  │
│  └─────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────┘
                              │
                              │ GKE metadata server intercepta
                              │ metadata.google.internal y devuelve
                              │ token federado del GSA
                              ▼
                 ┌─────────────────────────────┐
                 │  Google Service Account      │
                 │  checkout-app@proj-platform  │
                 │  .iam.gserviceaccount.com    │
                 │                              │
                 │  IAM binding:                │
                 │   roles/iam.workloadIdenti-  │
                 │   tyUser                     │
                 │   member =                   │
                 │   serviceAccount:            │
                 │   proj-platform.svc.id.goog  │
                 │   [checkout/checkout-app]    │
                 └──────────────┬───────────────┘
                                │
                                ▼
                 ┌─────────────────────────────┐
                 │  Recursos GCP destino        │
                 │  (bucket, secret, Pub/Sub)   │
                 │  policies IAM referencian al │
                 │  GSA (no al K8s SA)          │
                 └─────────────────────────────┘
```

### 4.2 Pasos conceptuales (lo que debes poder recitar)

1. **Habilitar el workload pool en el cluster** (`workload_identity_config { workload_pool = "<project>.svc.id.goog" }` en Terraform; `--workload-pool` en gcloud).
2. **Crear el Google Service Account** destino con los roles IAM que la app necesita (`roles/storage.objectViewer`, por ejemplo).
3. **Conceder el rol `roles/iam.workloadIdentityUser`** en el GSA al principal especial `serviceAccount:<project>.svc.id.goog[<namespace>/<ksa_name>]`.
4. **Crear el K8s ServiceAccount** en el cluster, anotado con `iam.gke.io/gcp-service-account: <email_del_GSA>`.
5. **Usar el K8s SA en el Deployment** (`spec.template.spec.serviceAccountName`).

El pod, al llamar a cualquier librería cliente de Google Cloud, obtiene credenciales **federadas** del GSA sin configurar nada más. No hay secret montado, no hay `GOOGLE_APPLICATION_CREDENTIALS`.

### 4.3 WIF for GKE vs IRSA (AWS)

| Dimensión | IRSA (EKS) | WIF for GKE |
|-----------|------------|-------------|
| Piezas que crear | IAM OIDC provider del cluster, IAM role con trust policy OIDC, K8s SA anotado | GSA, binding IAM, K8s SA anotado |
| Trust policy | Explícita, acopla el role al provider OIDC del cluster | Implícita vía el rol `roles/iam.workloadIdentityUser` sobre el principal `svc.id.goog` |
| Rotación | Automática | Automática |
| Vulnerable a confused-deputy entre clusters | Posible si trust policy mal escrita | Posible si el binding no restringe por `[namespace/ksa]` |
| Cambiar cluster | Hay que re-emitir el OIDC provider | Nuevo workload pool, re-binding |
| Nombre del principal | `arn:aws:iam::<acct>:role/<role>` | `<project>.svc.id.goog[<ns>/<ksa>]` |

Ambos son equivalentes conceptualmente. WIF for GKE tiene **menos piezas** y menos JSON de trust policy; a cambio, el principal especial `svc.id.goog[...]` es menos intuitivo la primera vez.

> **Fundamento interno**: el metadata server de GKE escucha en la IP virtual `169.254.169.254` como en EC2. En un cluster con WIF habilitado, un sidecar (`gke-metadata-server`) corre por node e intercepta las requests al metadata server, autenticando al pod por su ServiceAccount y devolviendo el token federado del GSA correspondiente. En EKS, la pieza equivalente es `eks-pod-identity-agent` (el modelo nuevo) o la inyección de variables de entorno `AWS_WEB_IDENTITY_TOKEN_FILE` y `AWS_ROLE_ARN` (modelo IRSA clásico).

---

## 5. Networking de GKE: VPC-native, aliases y Private Clusters

GKE sobre VPC global de GCP (ver `gcp-03`) tiene algunas peculiaridades:

- **VPC-native (alias IPs)**: por default moderno, los pods obtienen IPs del rango secundario de la subnet (no de una red overlay propia). Esto significa que un pod es **ruteable** directamente desde la VPC — no hace falta NAT para que un pod hable con Cloud SQL o con otro servicio en la misma VPC. Es un cambio significativo respecto al modelo "overlay" clásico.
- **Secondary ranges**: la subnet declara dos rangos secundarios: uno para **pods**, otro para **services**. Son grandes (por tamaño típico, `/14` para pods, `/20` para services). Planificar bien al inicio evita migraciones.
- **Private cluster**: `private_cluster_config { enable_private_nodes = true, enable_private_endpoint = true/false, master_ipv4_cidr_block = ... }`. Los nodes no tienen IP pública; el control plane es accesible solo desde `master_authorized_networks` configuradas (típicamente, la red interna o un bastión). **Recomendado para producción.**
- **Firewall**: GKE crea automáticamente reglas de firewall en la VPC para permitir el tráfico cluster-interno. Puedes añadir las tuyas por **service account** del node o por **tag** (ver `gcp-03`).

> **Trampa**: elegir rangos secundarios demasiado pequeños al principio y descubrir, 6 meses después, que el cluster no puede escalar más allá de 500 pods. Se cambia, pero duele.

---

## 6. GKE Ingress y Gateway API: dos caminos

Para publicar un Service externamente, GKE ofrece dos APIs:

### 6.1 Ingress (clásico)

- `kind: Ingress` con `ingressClassName: "gce"` (o `"gce-internal"`).
- Google materializa un **Global HTTP(S) Load Balancer** anycast (o un Regional Internal LB).
- **ManagedCertificate** (CRD de Google) genera y renueva el certificado TLS automáticamente contra el ACME de Google (si el dominio apunta a la IP del LB).
- **FrontendConfig** y **BackendConfig** (CRDs de Google) añaden settings como `redirect-http-to-https`, `ssl_policy`, `cdn: true`, timeout de backend, logging.

### 6.2 Gateway API (recomendado nuevo)

- `kind: Gateway` con `gatewayClassName: "gke-l7-global-external-managed"` (u otras clases para interno, regional, etc.).
- Mismo backend (los LBs de Google), pero API más expresiva y vendor-neutral.
- Rutas definidas por `HTTPRoute` (host + path + backendRef) con splits por peso, matches por header, etc.
- Soporta multi-tenant (varios equipos comparten un Gateway) con `ReferenceGrant`.

> **Recomendación**: para proyectos nuevos, **Gateway API**. Para proyectos legacy, Ingress sigue siendo soportado. Lo que **no** debe hacerse: `Service type=LoadBalancer` apuntando a un Network LB TCP cuando lo que quieres es un HTTP(S) LB con terminación TLS — es un antipatrón habitual.

---

## 7. Diferencias prácticas vs EKS

| Dimensión | EKS | GKE |
|-----------|-----|-----|
| CNI por default | `aws-vpc-cni` (instala y versiona tú) | Native VPC CNI (built-in) |
| Load Balancer controller | `aws-load-balancer-controller` (helm install) | Built-in para Ingress y Gateway API |
| Cluster autoscaler | `cluster-autoscaler` o Karpenter (instala tú) | Built-in; en Autopilot, no necesario (no hay nodes) |
| Identidad de pods | IRSA (OIDC provider + IAM role + anotación) | WIF for GKE (binding + anotación) |
| Upgrade control plane | Manual por versión | Auto por release channel |
| Upgrade de nodes | Rolling, manual o GitOps | Auto (en Autopilot forzoso; en Standard opcional) |
| Modo "sin nodes" | **Fargate** (parcial, con limitaciones) | **Autopilot** (contrato más amplio) |
| Pricing control plane | 0,10 USD/h por cluster | Primero gratis por región, luego 0,10 USD/h (verificar vigente) |

El patrón que suele emerger: en GCP terminas con **menos helm charts y menos operadores que mantener** porque Google ya los incluye; a cambio, estás más acoplado a decisiones de Google (nombres de IngressClass, GatewayClass, versiones).

---

## 8. Observabilidad: lo mínimo que viene gratis

Un cluster GKE recién creado ya emite:

- **Logs del control plane** (hasta Cloud Logging) — opt-in por default moderno.
- **Logs de workloads** (stdout/stderr de pods) — opt-in por default.
- **Métricas de nodes y pods** (hasta Cloud Monitoring).

Esto se controla con `logging_config` y `monitoring_config` en el Terraform del cluster. En **Autopilot**, los agentes vienen pre-instalados y son **inmutables**. En **Standard**, puedes desactivar algunos componentes de logging para reducir coste (ingesta de logs cuesta por GB).

El resto (dashboards custom, SLOs, tracing OTel) se cubre en `gcp-08`.

---

## 9. Patrones de seguridad obligatorios

Baseline recomendado para un cluster de producción:

1. **Private cluster** con nodes sin IP pública.
2. **`workload_identity_config.workload_pool`** habilitado (sin esto, no hay WIF for GKE).
3. **Shielded nodes** (`shielded_instance_config` activado) — vTPM e integridad medida en los nodes.
4. **Node service accounts específicos** (no el default de Compute Engine) con **mínimo privilegio** (`roles/logging.logWriter`, `roles/monitoring.metricWriter`, `roles/stackdriver.resourceMetadata.writer` y poco más).
5. **Release channel = REGULAR** o STABLE (nunca "sin canal" en producción).
6. **`network_policy`** o **Dataplane V2** (eBPF, Cilium bajo el capó) habilitado para NetworkPolicy entre pods.
7. **Binary Authorization** (que verás en `gcp-10`) para que solo imágenes firmadas sean admitidas.
8. **`master_authorized_networks`** limitados a la red interna o un bastión.

En **Autopilot**, varios de estos (private, shielded, dataplane, workload identity) son **default** o incluso **obligatorios**. Es parte de por qué Autopilot es "más seguro por default".

---

## 10. Elegir en una tabla concreta

Dado un workload, decidir Standard vs Autopilot vs EKS:

| Workload | Standard | Autopilot | EKS |
|----------|----------|-----------|-----|
| API HTTP stateless, 2–20 pods, poco tráfico | Posible | **Preferido** | Posible |
| StatefulSet con DaemonSet de observabilidad custom | **Preferido** | No (DaemonSet rechazado) | Posible |
| Workload GPU con driver NVIDIA custom | **Preferido** | Posible (si el driver es standard) | Posible |
| Job batch con picos esporádicos de 1000 pods | Posible (con autoscaler) | **Preferido** (facturación por segundo) | Posible (Fargate) |
| Service mesh "manual" con sidecars custom | **Preferido** | No (sidecar inyection restringida) | Posible |
| App regulada que exige evidencia de que nadie opera nodes | **Preferido** si quieres el log, pero mayor superficie | **Preferido** por default (nadie los opera) | Fargate equivalente |
| Multi-tenant con tenants que piden `hostNetwork` | **Preferido** | No | **Preferido** |
| Equipo sin SRE y quiere "olvidar" los nodes | — | **Preferido** | Fargate parcial |

---

## 11. Fundamentos internos (lo que suele doler en producción)

Cuatro cosas que **no se intuyen**:

1. **Autopilot no permite `hostPath` incluso para casos "inofensivos"** como un volumen temporal compartido con un sidecar. Fuerza a usar `emptyDir` (que ya existía) o un PVC. Si el workload asumía `hostPath`, hay que refactorizar.
2. **El principal especial `svc.id.goog[<ns>/<ksa>]` no aparece en la UI de "Service Accounts"** de GCP: aparece solo al listar bindings IAM del GSA destino. Primera vez que lo buscas, parece que no existe. Es correcto: no es una identidad "autónoma", es un *impersonator* reconocido.
3. **Un cluster sin `workload_identity_config.workload_pool` no acepta anotaciones WIF.** Si pones la anotación y el pool no está habilitado, el pod obtiene credenciales **del node** (que son del service account del node, no del GSA que querías). Es un error silencioso, no una denegación — descubres meses después que la app estaba corriendo con permisos del node.
4. **Release channels no son "set-and-forget" completo.** Google envía notificaciones de upgrade; algunas features entre versiones de K8s rompen APIs deprecadas. Mantener la app con **versiones de API vigentes** (sin `extensions/v1beta1` ni similares) es tu responsabilidad.

---

## 12. Alternativas y qué llevarse

### Alternativas a GKE

- **Cloud Run** (ya visto en `gcp-04`): si la app es stateless y HTTP, Cloud Run suele ser más barato operacionalmente que incluso Autopilot. Usa GKE solo cuando necesitas **capacidades K8s nativas** (StatefulSets, DaemonSets, CRDs, operators, service mesh, sidecars propios).
- **EKS** (si la org ya está en AWS): no cambies de nube por GKE Autopilot a secas. La diferencia operativa es real pero no gigantesca; el coste de ser multi-cloud lo supera casi siempre.
- **GKE Enterprise / Fleet**: para gestionar múltiples clusters (p. ej. uno por región, uno por tenant) con **Config Sync** (GitOps nativo), **Policy Controller** (OPA/Gatekeeper managed) y **Service Mesh** (Istio managed). Se cubre tangencialmente aquí; propio de un curso dedicado.

### Qué llevarse en una frase

> GKE Standard es Kubernetes "con menos pegamento" que EKS. GKE Autopilot es un contrato distinto: Google opera los nodes, tú pagas por pod, y aceptas restricciones de seguridad por default. **Workload Identity Federation for GKE** es el equivalente de IRSA, con menos piezas. Elige Standard cuando necesitas DaemonSets, GPUs raras o co-tenencia agresiva; elige Autopilot cuando el workload es "aplicación normal" y quieres reducir operación.

### Qué sigue

- `gcp-08` — observabilidad: logs/metrics/traces, SLOs, OTel.
- `gcp-10` — Workload Identity Federation **para pipelines** (GitHub Actions → GCP) y Binary Authorization en GKE.
