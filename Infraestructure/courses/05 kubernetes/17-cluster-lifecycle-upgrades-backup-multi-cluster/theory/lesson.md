# Lección: Ciclo de vida del cluster — upgrades, backup, DR y multi-cluster

> **ID:** `k8s-17-cluster-lifecycle-upgrades-backup-multi-cluster` · **Nivel:** producción · **Duración:** 6 h
> **Prerrequisitos:** `k8s-11`, `k8s-16`.

---

## 1. Introducción intuitiva

Hasta aquí el cluster "estaba ahí". Lo creabas con `kind create cluster` o lo recibías de Terraform y, a partir de allí, trabajabas *dentro* del cluster: Pods, Services, policies, firma de imágenes. Este módulo cambia el objeto de estudio: ahora el cluster **es** el workload. Un cluster vive, envejece y muere. Cada 4 meses sale un release nuevo; cada ~12 meses tu versión actual queda sin soporte; nodos fallan, zonas enteras fallan, regiones enteras fallan. Y tu organización, mientras tanto, espera que la plataforma siga funcionando.

Tres preguntas forman la columna vertebral del módulo:

1. **¿Cómo actualizo el cluster sin que la aplicación caiga?** → *upgrades + skew policy + drain + PDB*.
2. **¿Qué pasa si lo pierdo?** → *backup/restore + DR + RPO/RTO*.
3. **¿Qué hago cuando tengo muchos?** → *multi-cluster + fleet management + FinOps*.

La respuesta mala a cualquiera de las tres es cara. Un upgrade *in-place* mal planificado deja APIs rotas (ingresses que no sirven, workloads en `CrashLoopBackOff` porque un webhook de admission ya no es compatible). Un cluster perdido sin backup externo es una semana de downtime y un *post-mortem* interesante. Una fleet de 30 clusters sin estrategia GitOps es una matriz 30×N de "quién tiene qué versión de qué chart". Las decisiones de este módulo son **arquitectónicas** aunque se cuenten como "operativas".

El ritmo mental correcto es: *diseña asumiendo que el cluster se rompe mañana*. Si tu DR plan existe y lo has probado al menos una vez, el upgrade asusta menos — en el peor caso, lo tratas como un DR controlado.

---

## 2. Versionado y política de soporte

Kubernetes sigue **SemVer** modificado: `major.minor.patch`, con `major = 1` desde 2015. Un **minor** sale aproximadamente cada **4 meses** (~3 por año). Un **patch** sale aproximadamente cada **mes** por cada minor soportada.

**Política de soporte oficial** (upstream, verificar en Fase 4 contra `kubernetes.io/releases`):

- Se soportan las **últimas 3 minors**. Cuando sale `1.N`, se mantienen `1.N`, `1.N-1`, `1.N-2`. La `1.N-3` queda EOL.
- Soporte = patches de seguridad y bug fixes **para esa minor**. No hay backports de features.
- Managed (EKS/GKE/AKS) suelen añadir soporte **extendido** pagado (12–24 meses adicionales por minor, con precio) y mantienen sus propios calendarios de deprecation.

Consecuencia práctica: tu cluster **debe** moverse al menos **una minor por año** para no caer fuera de soporte. Si estás en `1.N-3` y no has planificado el upgrade, llegas tarde.

**APIs y deprecation**. Las APIs tienen su propio ciclo:

- `alpha` → se puede quitar en cualquier release, deshabilitada por default.
- `beta` → mínimo 9 meses o 3 minors antes de remoción; habilitada por default (desde `1.20` las APIs nuevas no entran como beta por default).
- `GA` (v1) → compromiso de compatibilidad largo (12 meses mínimo o 3 minors tras deprecation).

Casos históricos que rompieron upgrades:

- `extensions/v1beta1 Ingress` → removida en 1.22, reemplazada por `networking.k8s.io/v1`.
- `policy/v1beta1 PodDisruptionBudget` → removida en 1.25 por `policy/v1`.
- `PodSecurityPolicy` → removida en 1.25 completo; migración obligatoria a Pod Security Admission.
- `CronJob batch/v1beta1` → removida en 1.25 por `batch/v1`.
- `FlowSchema flowcontrol.apiserver.k8s.io/v1beta2` → removida en 1.29.

**Regla operativa**: *antes de cualquier upgrade*, correr un **deprecation API checker** sobre los manifests que ya están en el cluster y sobre los charts que vas a reinstalar. Herramientas: `pluto` (FairwindsOps) lee manifests y Helm releases, `kubent` (`kube-no-trouble`) lee del API server lo que hay desplegado y lo compara con la tabla de deprecations. Siempre complementadas con las **release notes** oficiales de la minor destino.

---

## 3. Skew policy — por qué define el orden del upgrade

La **skew policy** describe cuánta diferencia de versión se tolera *entre componentes* del cluster al mismo tiempo. Es la razón por la que se actualiza **control plane primero** y nodos después, no al revés.

Resumen (verificar contra `kubernetes.io/releases/version-skew-policy/`):

| Componente | Puede estar hasta ... atrás respecto a `kube-apiserver` |
|-----------|---------------------------------------------------------|
| `kube-apiserver` (en HA) | 1 minor entre instancias |
| `kube-controller-manager`, `kube-scheduler`, `cloud-controller-manager` | 1 minor atrás |
| `kubelet`, `kube-proxy` | hasta **3 minors** atrás (desde 1.28), antes eran 2 |
| `kubectl` | ±1 minor respecto al apiserver |

Reglas prácticas que salen de esto:

1. **El `apiserver` se actualiza primero**, siempre. Los demás componentes del control plane después. Nodos (kubelet/kube-proxy) al final.
2. **Nunca se salta una minor** en control plane. `1.28 → 1.30` NO es upgrade válido en un solo paso; es `1.28 → 1.29 → 1.30`. (Para kubelet sí hay más tolerancia desde 1.28, pero el apiserver obliga.)
3. En **managed**, el proveedor te fuerza este orden: no te deja saltar y a veces no te deja actualizar nodos a una minor mayor que el control plane (lo rechaza).
4. **`kubectl` del cliente** debe estar dentro de ±1 minor. Si tu laptop tiene `kubectl` 1.26 y el cluster está en 1.30, verás errores raros (CRDs no imprimen bien, `--server-side` falla, etc.).

Esto explica por qué un upgrade no es un `apt upgrade -y`: es una **secuencia** con puntos de rollback y validación en cada paso.

---

## 4. Upgrades managed (EKS, GKE, AKS)

En **managed clusters** el proveedor opera el control plane. Tú controlas el **cuándo** y los **nodos**.

**Patrón común a los tres**:

1. **Revisar deprecations** entre tu minor actual y la objetivo.
2. **Actualizar add-ons** si lo requiere la minor nueva (CNI, kube-proxy, CoreDNS, CSI driver). En EKS esto es explícito con "EKS Add-ons".
3. **Upgrade del control plane** (una minor cada vez). Puede tardar 20–40 min; es *managed*, pero no instantáneo.
4. **Upgrade de node groups** / node pools. Dos modelos:
   - *Rolling* in-place: el proveedor drena y reemplaza nodos uno a uno según `maxUnavailable`.
   - *Blue/green de node group*: creas un node group nuevo con la minor nueva, cordonas el viejo, drenas workloads, borras el viejo.
5. **Validar**: `kubectl get nodes` todos en versión nueva, probar readiness de workloads críticos, revisar métricas de scheduler y de tasa de errores.

**EKS específicamente** (resumir, verificar en Fase 4 contra `docs.aws.amazon.com/eks`):

```bash
# 0. Pre-check: APIs deprecadas en lo desplegado
kubectl krew install deprecations  # o usar pluto / kubent
pluto detect-helm --target-versions k8s=v1.31.0

# 1. Upgrade control plane
aws eks update-cluster-version \
    --name prod \
    --kubernetes-version 1.31

aws eks describe-update \
    --name prod \
    --update-id <id>  # polling hasta Successful

# 2. Upgrade add-ons gestionados (CoreDNS, kube-proxy, VPC CNI, EBS CSI)
aws eks update-addon --cluster-name prod --addon-name coredns \
    --addon-version v1.11.3-eksbuild.1 \
    --resolve-conflicts PRESERVE

# 3. Upgrade node groups managed
aws eks update-nodegroup-version \
    --cluster-name prod \
    --nodegroup-name app-ng \
    --kubernetes-version 1.31 \
    --force  # respeta PDB; --force solo si hay drains bloqueados
```

**GKE**: `gcloud container clusters upgrade NAME --master` seguido de upgrade de node pools. GKE expone **release channels** (`rapid`, `regular`, `stable`) que automatizan la cadencia — útil si no quieres decidir *cuándo* actualizar pero sí *cuánto riesgo* aceptar.

**AKS**: `az aks upgrade --name NAME --kubernetes-version X.Y.Z`. Soporta `--control-plane-only` y después `--node-image-only` por node pool.

**Qué va mal en managed**:

- APIs deprecadas en charts que no has actualizado: el upgrade del control plane *puede* completarse y los charts siguientes fallan al reaplicar.
- Add-ons gestionados en versión demasiado vieja para la nueva minor: el proveedor bloquea el upgrade.
- `maxUnavailable` del node group demasiado agresivo + PDBs ajustadas → drain se bloquea indefinidamente.
- IRSA / Workload Identity: trust policies ligadas a un OIDC issuer; borrar y recrear el cluster rompe esos trusts.

---

## 5. Upgrades self-hosted con kubeadm

En self-hosted (bare metal, VMs en cloud, on-prem) se usa típicamente **`kubeadm`**. El proceso en el *control plane node* es:

```bash
# 1. Determinar la versión objetivo (una minor adelante)
apt-mark unhold kubeadm
apt-get update
apt-get install -y kubeadm=1.31.0-1.1

# 2. kubeadm valida que el salto es permitido y lista cambios
kubeadm upgrade plan

# 3. Aplica el upgrade del control plane de este nodo
kubeadm upgrade apply v1.31.0

# 4. Si hay otros control-plane nodes: en cada uno
kubeadm upgrade node

# 5. En CADA nodo (control plane y workers), actualizar kubelet y kubectl
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.31.0-1.1 kubectl=1.31.0-1.1
systemctl daemon-reload
systemctl restart kubelet
apt-mark hold kubelet kubeadm kubectl
```

En **workers** el flujo adicional es:

```bash
# Desde un control plane node:
kubectl drain WORKER --ignore-daemonsets --delete-emptydir-data

# En el worker:
apt-mark unhold kubeadm
apt-get install -y kubeadm=1.31.0-1.1
kubeadm upgrade node          # actualiza config del nodo
apt-get install -y kubelet=1.31.0-1.1 kubectl=1.31.0-1.1
systemctl restart kubelet

# De vuelta al control plane:
kubectl uncordon WORKER
```

**Nunca** saltar más de una minor en control plane. Si vas de 1.28 a 1.31, es: 1.28→1.29, validar, 1.29→1.30, validar, 1.30→1.31. Cada salto puede durar horas-días si se hace con cordura.

**Qué va mal en self-hosted**:

- `apt-mark unhold` no se hizo y la versión no cambia.
- Repos de Kubernetes cambiaron (los **nuevos repos pkgs.k8s.io** reemplazaron a `apt.kubernetes.io` en 2023); si el host tiene el repo viejo, no ve versiones nuevas.
- `kubeadm upgrade plan` encuentra APIs deprecadas en configmaps gestionados por kubeadm.
- CNI o container runtime (containerd) versiones demasiado viejas para la minor nueva.

---

## 6. Estrategias de upgrade: in-place vs blue/green cluster

Dos estrategias principales. Elegir una **no es dogmático**: depende de SLOs, criticidad, tamaño del equipo, costo tolerable y stateful vs stateless.

### In-place

Actualizas el cluster existente, nodo a nodo, respetando skew policy y PDBs. El cluster es "el mismo" antes y después.

**Ventajas**:
- Barato (no se duplican nodos ni storage).
- Simple operacionalmente: no hay que migrar DNS, secretos, PVs, LBs.
- IPs internas, nombres DNS internos y objetos estables.

**Desventajas**:
- Rollback real es difícil: una vez que el apiserver subió a 1.31, bajar a 1.30 no es un `kubectl rollback`. Se restaura etcd desde snapshot, que implica downtime.
- Ventana de "mitad y mitad" (unos nodos nuevos, otros viejos) existe sí o sí.
- Un bug del upstream en la minor nueva te afecta a todos los workloads *simultáneamente*.

### Blue/green cluster

Creas un **cluster nuevo** (`green`) con la minor objetivo. Instalas addons y policies. Despliegas los workloads vía GitOps. Validás. Cambias el DNS / Load Balancer / ingress externo para que apunte al `green`. Mantienes el `blue` disponible para rollback N días. Lo destruyes.

**Ventajas**:
- Rollback real y limpio: devolver DNS al `blue`.
- Puedes aprovechar para **limpiar deuda** (cambiar CNI, mover a CSI nuevo, migrar de ingress-nginx a Gateway API).
- Un bug del upstream en la nueva minor afecta sólo al green; recortas tráfico y vuelves al blue.

**Desventajas**:
- Doble costo durante la ventana (dos clusters corriendo).
- **PVs y estado**: hay que mover datos (snapshot + restore con Velero, replicación de bases al nuevo cluster, o DNS-fail-over con la DB *fuera* del cluster — típicamente la mejor opción).
- Complejidad de red: dos clusters compartiendo DNS externo, LB, certificados.
- IPs internas y nombres cambian: cualquier cosa que haga TLS pinning por SAN o IP falla.

### Cuándo usar cada una

| Factor | In-place | Blue/green |
|-------|----------|-----------|
| Cluster único + stateless + equipo pequeño | ✅ | ❌ overkill |
| Multi-tenant crítico, SLO 99.95%+ | ❌ ventana riesgosa | ✅ |
| Hay deuda arquitectónica (CNI, Ingress) | ❌ | ✅ aprovechar |
| DB stateful dentro del cluster | ⚠️ con cuidado | ❌ caro de migrar — mejor sacar la DB fuera primero |
| Presupuesto justo | ✅ | ❌ |
| Managed con upgrades automatizados y canary de node group | ✅ "casi blue/green" en el data plane | — |

Un patrón intermedio común en EKS/GKE: **in-place en control plane**, **blue/green en node groups** (nuevo node group con la minor nueva, cordonar y drenar el viejo). Combina barato con rollback de data plane.

---

## 7. Node drain y PodDisruptionBudget

**`kubectl drain NODE`** marca el nodo *unschedulable* (equivalente a `cordon`) y luego **evicta** todos los Pods, respetando PDBs. Flags claves:

- `--ignore-daemonsets`: los DaemonSets no se evictan "normalmente" (son por-nodo). Imprescindible en la práctica.
- `--delete-emptydir-data`: Pods con `emptyDir` requieren confirmación explícita de que los datos se pierden.
- `--grace-period=<s>`: respetar un `terminationGracePeriodSeconds` adicional.
- `--force`: para Pods *standalone* (no gestionados por un controller). **Evitar** salvo justificación.

Un drain **se bloquea** si una eviction viola un PDB. Esto es *correcto*: la PDB existe precisamente para proteger disrupciones *voluntarias* (drains, upgrades, scale-down del cluster autoscaler) manteniendo un mínimo de réplicas disponibles.

Patrón de PDB para app crítica:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-pdb
spec:
  minAvailable: 2            # o "60%" ; nunca "1" si solo tienes 2 réplicas
  selector:
    matchLabels:
      app: web
```

**Trampa habitual**: `minAvailable: 1` con `replicas: 1` = drain **jamás** termina. La PDB protege contra lo imposible. Regla: `replicas >= minAvailable + 1`.

**maxUnavailable** es la cara opuesta: útil para "no más de X Pods caídos a la vez" en apps con muchas réplicas.

Pods **sin controller** (naked Pods) no son evictables: hay que resolverlos manualmente antes del drain. Un cluster "sano" no debería tener naked Pods.

Durante un **upgrade de nodo** correctamente ejecutado, el ciclo por cada nodo es:

```
cordon → drain (respeta PDB) → upgrade kubelet / reemplazo del nodo → uncordon → verificación
```

---

## 8. Velero — backup y restore cluster-side

**Velero** (OSS, originalmente Heptio, ahora VMware/CNCF) backupea **recursos de la API** y, opcionalmente, **volúmenes**. No reemplaza a los backups aplicativos ni al `pg_dump` ni al operador de base de datos; **complementa**.

### Arquitectura

- **Controller** `velero` (Deployment) en el namespace `velero`.
- **CRDs** nuevos: `Backup`, `Restore`, `Schedule`, `BackupStorageLocation`, `VolumeSnapshotLocation`, `PodVolumeBackup`, `PodVolumeRestore`.
- **Object storage externo** para los metadatos y, con restic/kopia, para los datos de volumen: S3/GCS/Azure Blob/MinIO/cualquier S3-compatible.
- **Volumen snapshots** vía uno de:
  - **CSI snapshots** (preferido, requiere driver CSI con snapshotter) — Velero copia la referencia; el snapshot vive en el storage del cloud.
  - **File-system backup** con `node-agent` (ex-`restic`, hoy también **kopia**) — un DaemonSet lee los files del volumen y los sube al object store. Independiente del CSI, más lento.
- **Hooks**: comandos `exec` en Pods *antes* y *después* del backup. Útil para flush/freeze de aplicaciones (p. ej. Postgres `pg_backup_start`).

### Flujo de un backup

```
velero backup create NAME --include-namespaces=app
    │
    ├─ 1. Lista recursos (api-resources filtrados)
    ├─ 2. Para cada PV con backup habilitado:
    │       → CSI snapshot (si CSI) O
    │       → node-agent sube los files al object store
    ├─ 3. Serializa los manifests (YAML) y los sube al bucket
    └─ 4. Marca el Backup como Completed
```

Un restore invierte el flujo: lee del bucket, recrea namespaces y recursos (con `--namespace-mappings` si quieres restaurar a otro ns), restaura PVs/PVCs y, con node-agent, repopula los files.

### Qué incluir y qué excluir

Por default Velero backupea **casi todo** menos events. Suele interesar excluir:

- Workloads de observabilidad voluminosos (Prometheus TSDB) — se backupean aparte si hay que preservar historia.
- Namespaces del sistema (`kube-system`) — restaurarlos sobre un cluster nuevo rompe más de lo que arregla.
- CRs gestionados por operadores que se recrean solos (p. ej. certs de cert-manager — mejor que se re-emitan).

Buenas prácticas:

- Un **Schedule** diario de todo + un Schedule por hora para namespaces críticos.
- **BackupStorageLocation** en una **región distinta** de la del cluster — si pierdes la región, pierdes los backups también.
- **Retention** sensata (`ttl: 720h` = 30 d por default; combinar con lifecycle del bucket).
- **Probar el restore periódicamente** en un cluster scratch. Un backup que nunca se restauró **no es un backup**.

### CSI vs node-agent

| Dimensión | CSI snapshots | node-agent (kopia/restic) |
|-----------|---------------|---------------------------|
| Velocidad | Rápido (snapshot del cloud) | Lento (lee files y sube) |
| Portabilidad | Snapshot ligado al cloud | Portable entre clouds |
| Requisitos | CSI driver con snapshotter | Ninguno especial |
| Granularidad | Bloque | Archivo |
| Caso típico | Mismo cloud, misma región | Backup cross-cloud o lab local (MinIO) |

En la actividad 01 usamos **MinIO + node-agent** porque kind no tiene CSI snapshotter completo y queremos reproducibilidad local sin cloud.

---

## 9. etcd backup y recuperación

**etcd** es la única fuente de verdad del cluster. Si pierdes etcd, pierdes el cluster. Dos niveles de backup conviven y resuelven cosas distintas:

| Nivel | Qué protege | Herramienta |
|-------|-------------|-------------|
| **etcd snapshot** | Todo el estado del apiserver en un instante consistente | `etcdctl snapshot save` |
| **Velero backup** | Manifests "lógicos" + volúmenes de workloads | `velero backup` |

**No son intercambiables**: etcd snapshot permite rebuild del cluster idéntico (mismo UID de objetos). Velero permite "mover la carga a un cluster nuevo". En DR real querrás **ambos** para self-hosted, **solo Velero** para managed (porque etcd en EKS/GKE/AKS es *gestionado* y no accesible).

### etcd snapshot (self-hosted)

```bash
# Desde un host con acceso a los certs de etcd (p. ej. control plane node)
ETCDCTL_API=3 etcdctl \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/backups/etcd/snap-$(date +%F-%H%M).db

# Verificar integridad del snapshot
etcdctl snapshot status --write-out=table /var/backups/etcd/snap-*.db
```

**Restore** (destructivo, cluster nuevo):

```bash
etcdctl snapshot restore /var/backups/etcd/snap-X.db \
  --data-dir=/var/lib/etcd-restored

# Reemplazar la data-dir en el manifest estático
# /etc/kubernetes/manifests/etcd.yaml y reiniciar kubelet
```

Buenas prácticas:

- Snapshot **cada 30 min** si tolerancia a pérdida es baja (más abajo RPO).
- Snapshots en storage **off-cluster** (bucket, otro host).
- Verificar `snapshot status` tras cada backup — un snapshot *corrupto que nadie leyó* es un hallazgo clásico de post-mortem.
- En managed: *no toques etcd*. El provider ya tiene snapshots internos; tu equivalente operativo es Velero + restore en cluster nuevo (que te crearía Terraform).

---

## 10. Disaster Recovery del cluster — RPO, RTO y playbook

**RPO** (Recovery Point Objective): cuánto *dato* puedes perder, medido en tiempo. "Hasta 1 hora" = necesitas backups al menos horarios.

**RTO** (Recovery Time Objective): cuánto *tiempo* puedes estar caído. "Hasta 2 horas" = tus procedimientos deben entregar un cluster funcional en ≤ 2 h.

Son **números negociados con negocio**, no decididos por el equipo de plataforma solo. Un RPO de 1 min para un blog interno es desperdicio; un RPO de 24 h para pagos es inaceptable.

### Qué cubre un plan DR serio

1. **Qué pierdes y qué sobrevive**:
   - Estado K8s (manifests, CRDs, ConfigMaps, Secrets) → **Velero** + etcd snapshots.
   - Datos persistentes (PV/PVC) → **snapshots regionales + replicación cross-region** del CSI driver, o **la base de datos vive fuera del cluster** (RDS/CloudSQL).
   - Imágenes de contenedor → **registry externo** replicado (ECR replication, Artifact Registry multi-region).
   - Secretos externos → secret manager (AWS/GCP Secrets Manager, Vault) con replicación.
   - DNS externo → gestionado por el provider con replicación global (Route53, Cloud DNS).
   - Certificados → cert-manager re-emite si Let's Encrypt está disponible; pin certs en un volumen montado si no.

2. **Dependencias externas documentadas**: la lista anterior ES el inventario DR. "Si no está en el inventario, no se recupera."

3. **Playbook de recuperación paso a paso** — ejecutable por alguien que no diseñó el sistema, de madrugada, con pánico:

```markdown
# Playbook DR: cluster perdido (región A)

Prereqs: tener acceso al bucket Velero cross-region (región B),
         registry replicado, secret manager accesible.

1. Provisionar cluster nuevo en región B:
   terraform -chdir=infra/eks apply -var region=B -var name=prod-dr
   Tiempo esperado: 20 min.

2. Instalar Velero apuntando al bucket cross-region:
   velero install --provider aws --bucket backups-prod-crossregion ...
   Tiempo esperado: 5 min.

3. Listar backups disponibles y elegir el más reciente:
   velero backup get | head
   velero restore create --from-backup prod-daily-YYYYMMDD-HHMM
   Tiempo esperado: 15–40 min según tamaño.

4. Repuntar DNS (Route53) al nuevo LB:
   terraform -chdir=dns apply -var target=prod-dr
   Tiempo esperado: TTL + 5 min.

5. Verificar readiness de workloads críticos:
   kubectl get pods -n app -o wide
   curl -I https://api.example.com/healthz

RTO objetivo: 90 min.
RPO objetivo: 1 h (Velero schedule horario).
```

4. **Pruebas periódicas**: ejecutar el playbook al menos **1 vez por trimestre** en un cluster scratch. Un plan DR nunca ejecutado es ficción.

### Trampas en DR

- **Backup en la misma región** del cluster: pierdes ambos juntos.
- **Secretos no replicados**: la app está desplegada, no arranca porque no puede leer la DB.
- **Depender de DNS interno del cluster viejo**: hosts hardcodeados a `pod-X.svc.cluster.local` del cluster anterior.
- **IRSA / Workload Identity**: trust policies ligadas a un OIDC issuer; el cluster nuevo tiene **otro** issuer; hay que recrear los role trusts.
- **Imágenes con `:latest`** o pulled desde el registry público con rate-limit: el restore se bloquea esperando pulls que se rate-limitean.

---

## 11. Multi-cluster, fleet management y FinOps

### Cuándo adoptar multi-cluster

**Primero: ¿por qué?** Multi-cluster añade complejidad proporcional al número de clusters al cuadrado (comunicación cross-cluster, policy consistente, versiones divergentes). Antes de adoptar, pregunta si *un cluster bien operado* resuelve el problema. Razones legítimas:

- **Blast radius**: aislar producción de staging de dev. Caída de uno no afecta a los otros.
- **Regulación / soberanía de datos**: EU vs US vs APAC con regulaciones distintas.
- **Latencia**: usuarios en 3 continentes.
- **Multi-tenant hard**: tenants que exigen aislamiento más fuerte que namespaces + policies.
- **DR**: el cluster secundario *es* el plan DR (activo-pasivo o activo-activo).

Si ninguna aplica, **no adoptes multi-cluster**. Un cluster con namespaces y policies es más barato.

### Patrones de fleet management

- **Argo CD app-of-apps / ApplicationSet** sobre varios clusters: GitOps uniforme, estado deseado en Git, un Argo "control" gestiona N clusters. Patrón más común en organizaciones medianas.
- **Rancher Fleet**: nativo multi-cluster, declara "bundles" aplicables a grupos de clusters por labels. Fuerte en edge y escenarios 100+ clusters.
- **Cluster API (CAPI)**: declara **los propios clusters** como CRs en un *management cluster*. "Kubernetes para gestionar Kubernetes". Útil cuando los clusters se crean y destruyen a menudo (previews, tenants).
- **Karmada** / **KubeFed v2** (legacy): intentos de "cluster federation". Han perdido tracción frente a app-of-apps + mesh.

### Workload portability

Los manifests **no deben asumir el cluster**. Prácticas que ayudan:

- Nada hardcodeado al nombre del cluster, a su UID ni a IPs de nodo.
- StorageClass con un nombre lógico (`fast`, `standard`) y el driver real detrás, no `gp3-us-east-1a-xyz`.
- Ingresses con hostnames externos (`api.example.com`), no DNS interno.
- Secretos vienen de External Secrets Operator apuntando a un secret manager externo — mover la app a otro cluster solo cambia el secret store **mount point**, no los nombres.

### Service discovery cross-cluster (introducción)

Tres niveles:

1. **Nada**: cada cluster expone sus servicios públicamente, se descubren por DNS externo. Simple, latente, caro.
2. **ExternalName / stub DNS**: un Service `ExternalName` apunta a un hostname del otro cluster. Funciona para HTTP; TLS requiere SNI correcto.
3. **Mesh multi-cluster**: Istio multi-primary, Linkerd multi-cluster, Cilium Cluster Mesh, Submariner. mTLS automático, service discovery global. **Costo**: operacional y de rendimiento. Service mesh profundo se cubre aparte en `k8s-18`.

### FinOps cluster-side

Costear K8s es difícil: una factura cloud dice "EC2: 42k USD" pero no cuál namespace lo gastó. Dos herramientas de referencia:

- **OpenCost** — proyecto CNCF, OSS, se instala con Helm. Modelo: lee métricas de kube-state-metrics + requests/usage reales de Prometheus + pricing del cloud (public pricing o CUR de billing). Expone endpoints `/allocation` que atribuyen costo por `namespace`, `label`, `controller`, `pod`. Es el **estándar emergente**.
- **Kubecost** — producto comercial encima de OpenCost. UI más completa, alertas, recomendaciones de right-sizing, free tier limitado.

Decisiones típicas que habilita FinOps cluster-side:

- "Namespace `team-x` consume 40% del cluster y produce 5% del tráfico → revisar."
- "Workload Y tiene `requests` 10× su uso real → `vpa` recommend, bajar requests."
- "Namespaces con `limits` sin `requests` en Burstable → QoS impredecible y waste."
- "Nodes consistentemente a 30% CPU → consolidación / Karpenter."

Integrar con el **billing del cloud real** (AWS CUR, GCP Billing export) convierte "atribución por namespace" en "USD reales".

---

## 12. Mantenimiento sin dolor: síntesis y evaluación

### Checklist operativo del ciclo de vida

Antes de cada upgrade:

- [ ] Revisar release notes de todas las minors entre la actual y la objetivo.
- [ ] Ejecutar `pluto` o `kubent` contra los manifests y charts.
- [ ] Validar add-ons compatibles con la minor nueva (CNI, CSI, ingress, cert-manager, kube-proxy, CoreDNS).
- [ ] **Backup Velero** del cluster entero inmediatamente antes.
- [ ] Si self-hosted: **snapshot de etcd** inmediatamente antes.
- [ ] Ventana de mantenimiento comunicada; stakeholders avisados.
- [ ] Playbook de rollback escrito y revisado.

Durante:

- [ ] Upgrade control plane primero, validar.
- [ ] Un node group / pool a la vez, respetando PDB.
- [ ] Monitorear tasa de errores de workloads críticos en tiempo real.
- [ ] Si algo rompe: **parar**, no continuar al siguiente nodo esperando que mejore.

Después:

- [ ] Validar versiones: `kubectl get nodes -o wide` todos uniformes.
- [ ] Revisar `kubectl events --sort-by='.lastTimestamp'`.
- [ ] Workloads críticos: smoke test de endpoints externos.
- [ ] Actualizar la documentación interna de "versión actual".
- [ ] Programar el siguiente upgrade antes de que la minor caiga fuera de soporte.

### Preguntas de evaluación

Responde por escrito, sin consultar la lección:

1. ¿Por qué no se puede saltar una minor en `kube-apiserver`? ¿Qué pasaría si lo intentaras?
2. Tu cluster está en 1.26 y la última release es 1.31. ¿Qué secuencia sigues? ¿Cuánto tiempo total razonable?
3. Un drain está bloqueado por "`cannot evict pod as it would violate the pod's disruption budget`". El PDB dice `minAvailable: 2` y la app tiene `replicas: 2`. ¿Qué está mal y cómo lo arreglas sin tirar la app?
4. ¿Qué protege un snapshot de etcd que **no** protege Velero? ¿Y al revés?
5. En managed (EKS), ¿por qué tiene sentido usar Velero aunque el provider gestione etcd?
6. Diseña RPO y RTO para: (a) un blog interno; (b) la plataforma de pagos; (c) un cluster de ML con batch jobs. Justifica.
7. Propón un **plan DR** para el capstone del curso: RPO, RTO, qué se backupea, dónde, cómo se restaura, qué dependencias externas hay y cómo se prueba.
8. Tu equipo quiere "ir a multi-cluster". Lista 5 preguntas que harías antes de aceptar.
9. ¿Qué diferencia hay entre `kubectl drain` y `kubectl delete pod` sobre un nodo? ¿Cuál respeta PDB?
10. OpenCost dice que el namespace `data-eng` consume 60% del cluster. ¿Qué pasos sigues para validar que es waste y no uso legítimo?

### Ejercicio final

Elige un cluster que operes o un hipotético realista. Escribe:

- **Inventario DR** completo (qué sobrevive naturalmente, qué requiere backup explícito).
- **RPO/RTO** justificados.
- **Playbook de recuperación** paso a paso, ejecutable por un ingeniero de guardia.
- **Fecha de la última prueba DR** o, si no se hizo, cómo la propondrías agendar.
- **ADR de upgrade** eligiendo in-place o blue/green con razones.

Esto es la antesala directa del entregable del capstone del curso.
