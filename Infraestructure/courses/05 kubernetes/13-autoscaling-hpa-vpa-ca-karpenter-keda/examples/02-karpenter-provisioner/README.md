# Ejemplo 02 — Karpenter `NodePool` + `EC2NodeClass` (v1)

> Walkthrough de lectura. Karpenter solo corre contra EC2 real; no se puede probar en kind.
> Los manifests están en `manifests/`.

## Contexto

Karpenter v1 (API `karpenter.sh/v1`, GA 2024) sustituye al viejo `Provisioner` por dos objetos:

- **`NodePool`** — qué *forma* de nodos puede crear el controlador y cómo los dispone (`disruption`, `limits`, `weight`, `taints`).
- **`EC2NodeClass`** (API `karpenter.k8s.aws/v1`) — detalles AWS-específicos del nodo (AMI family, subnets, security groups, IAM role, user data, bloques EBS).

Esta separación permite tener un `EC2NodeClass` "base" y varios `NodePool` que lo reutilizan (p. ej. uno para GPU, otro para spot CPU, otro para on-demand crítico).

## Qué muestra el manifest `nodepool.yaml`

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["3"]
        - key: karpenter.k8s.aws/instance-cpu
          operator: In
          values: ["2", "4", "8", "16"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64", "arm64"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]
        - key: topology.kubernetes.io/zone
          operator: In
          values: ["us-east-1a", "us-east-1b", "us-east-1c"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      expireAfter: 720h  # 30 d → fuerza reemplazo para absorber parches de AMI.
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 30s
  limits:
    cpu: 1000
    memory: 1000Gi
  weight: 10
```

Lectura dirigida:

1. **`requirements`** son el `nodeSelector` *virtual* del Pool. Karpenter nunca creará un nodo fuera de estas restricciones. Cada clave es un label well-known (`karpenter.k8s.aws/*`, `kubernetes.io/*`, `karpenter.sh/*`).
2. Permitimos **c/m/r** (compute, memoria balanceada, memoria alta) generación > 3 (c4/m4/r4 en adelante). Dejamos que Karpenter elija entre spot y on-demand; prioriza spot por costo.
3. **Multi-arch** `amd64, arm64`: Karpenter escogerá Graviton si tus imágenes lo soportan (ahorro ~20 %).
4. **`expireAfter: 720h`**: cada nodo vive máximo 30 días; se recicla ordenadamente respetando PDBs. Clave para que no quede un nodo spot "ancla" con AMI vieja.
5. **`consolidationPolicy: WhenEmptyOrUnderutilized`** + `consolidateAfter: 30s`: Karpenter busca continuamente si puede empacar los Pods en menos nodos (o nodos más baratos) y hace el reemplazo. Es el comportamiento más eficiente; `WhenEmpty` es más conservador.
6. **`limits`** son el techo de recursos totales del pool: Karpenter no superará 1000 vCPU / 1000 GiB en este pool, aun si hay Pods pendientes.
7. **`weight`** se usa cuando hay varios NodePools: el más alto gana primero (p. ej. priorizar on-demand reservado antes de spot).

## `EC2NodeClass`

```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2023
  amiSelectorTerms:
    - alias: al2023@latest
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: my-cluster
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: my-cluster
  role: KarpenterNodeRole-my-cluster
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 50Gi
        volumeType: gp3
        encrypted: true
        deleteOnTermination: true
  metadataOptions:
    httpTokens: required          # IMDSv2 obligatorio
    httpPutResponseHopLimit: 1    # endurece contra escape de credenciales
```

Puntos clave:

- `amiFamily: AL2023` + `alias: al2023@latest` → Karpenter usa el AMI oficial más reciente de AWS; no fijes AMIs manuales salvo necesidad.
- `subnetSelectorTerms` / `securityGroupSelectorTerms` por **tags**: la infra (Terraform) etiqueta subnets y SGs con `karpenter.sh/discovery=<cluster>` y Karpenter los descubre dinámicamente. No hay listas hardcodeadas.
- `metadataOptions.httpTokens: required` **IMDSv2 obligatorio**: evita el patrón clásico de SSRF que roba credenciales de instancia.

## Flujo observable

1. Un Deployment pide 20 Pods con `requests.cpu: 500m`.
2. El scheduler coloca los primeros donde quepan; sobran, digamos, 12 Pods Pending.
3. Karpenter los agrupa (batching) y simula un `scheduling` virtual: `12 × 500m = 6 vCPU` + overhead → "mete todo en un `m7a.xlarge` spot".
4. `karpenter_pods_startup_time_seconds` arranca; nodo listo en ~45 s.
5. Si el pico pasa y los Pods se van, Karpenter detecta un nodo vacío/subutilizado y lo drena (respetando `disruption.budgets` y PDBs).

## Lo que *no* se puede probar en kind

- La provisión real de EC2 (requiere AWS Account + VPC + IAM + Karpenter instalado vía Helm con IRSA).
- La métrica `karpenter_*` del controller (no hay nodos reales que crear).

Para una demo end-to-end usa `eksctl` o Terraform con los módulos oficiales de Karpenter y sigue <https://karpenter.sh/docs/getting-started/>.

## Lo que *sí* practicas aquí

- Leer un `NodePool` y defender cada restricción.
- Explicar por qué `consolidationPolicy: WhenEmptyOrUnderutilized` cambia el perfil de disrupciones vs `WhenEmpty`.
- Diseñar varios NodePools con `weight` distintos (p. ej. "GPU dedicado", "spot genérico", "on-demand crítico").
