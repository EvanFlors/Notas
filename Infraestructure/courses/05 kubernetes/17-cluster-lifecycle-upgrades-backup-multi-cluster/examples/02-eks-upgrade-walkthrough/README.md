# Ejemplo 02 — Walkthrough de upgrade de EKS (lectura, no ejecución)

> Walkthrough comentado de un upgrade **EKS 1.30 → 1.31**. **No se ejecuta** contra una cuenta AWS. Se lee, se razona y se contrasta con lo que harías en self-hosted con `kubeadm`.

Objetivo didáctico: entender el **orden**, los **puntos de validación** y los **modos de fallo** de un upgrade managed real.

## Contexto del escenario

- Cluster `prod-eu` en EKS, versión actual **1.30**.
- 3 node groups managed: `system` (m5.large, 2 nodos), `app` (m5.xlarge, 6 nodos), `batch` (c5.2xlarge, spot, 0–20 nodos vía Karpenter).
- Add-ons gestionados: `vpc-cni`, `kube-proxy`, `coredns`, `aws-ebs-csi-driver`.
- Workloads: 3 Deployments app (3 réplicas, PDB `minAvailable: 2`), un StatefulSet Postgres (3 réplicas, PDB `maxUnavailable: 1`), observability stack (Prometheus Operator) en `system`.

Objetivo: migrar a **1.31**.

## Fase 0 — Pre-check (D-7 a D-1)

### 0.1 Revisar deprecations

```bash
# APIs deprecadas que la 1.31 remueve o marca como no-default.
# Verificar en release notes:
#   https://kubernetes.io/releases/notes/
#   https://kubernetes.io/docs/reference/using-api/deprecation-guide/

# Herramientas:
#   pluto detect-helm --target-versions k8s=v1.31.0
#   kubent --target-version 1.31.0

pluto detect-helm --target-versions k8s=v1.31.0 --output wide
```

Si aparece alguna API `REMOVED` en 1.31, **parar aquí**: actualizar los charts o manifests que la usan y repetir el check.

### 0.2 Verificar compatibilidad de add-ons

Cada add-on managed en EKS tiene una matriz de versiones compatibles por versión de K8s. Antes del upgrade del control plane, consultar:

```bash
aws eks describe-addon-versions \
    --kubernetes-version 1.31 \
    --addon-name coredns \
    --query 'addons[0].addonVersions[0].addonVersion'
# ej. v1.11.3-eksbuild.1
```

Repetir para `kube-proxy`, `vpc-cni`, `aws-ebs-csi-driver`.

### 0.3 Backup Velero del cluster entero

```bash
velero backup create preupgrade-1.30-$(date +%Y%m%d-%H%M) \
    --include-cluster-resources=true \
    --wait
```

### 0.4 Confirmar PDBs sensatas

```bash
kubectl get pdb -A
# Verificar que ninguna tenga minAvailable == replicas (bloquearía drain).
```

### 0.5 Comunicación

- Email al canal `#eng-platform` con ventana de mantenimiento (incluso si el impacto esperado es cero, un upgrade mal te deja sin cluster).
- Punto de rollback acordado por escrito.

## Fase 1 — Upgrade del control plane (D-day, T+0)

```bash
aws eks update-cluster-version \
    --name prod-eu \
    --kubernetes-version 1.31

# Polling hasta Successful (~20–40 min)
aws eks describe-update \
    --name prod-eu \
    --update-id <update-id>
```

**Qué puede pasar**:

- EKS **rechaza** el upgrade si detecta APIs deprecadas en lo desplegado o si un add-on managed está en versión incompatible → corregir y reintentar.
- Durante el upgrade el apiserver sigue sirviendo (EKS tiene control plane HA). El impacto es nulo *para el data plane existente*.

**Validar** al terminar:

```bash
kubectl version          # Server: v1.31.x
kubectl get nodes        # Nodes aún en v1.30.x (ESPERADO, aún no tocamos nodos)
```

En este punto el cluster está en **skew válida** (control plane 1.31, kubelets 1.30 = 1 minor atrás).

## Fase 2 — Add-ons managed (T+45 min)

```bash
for addon in coredns kube-proxy vpc-cni aws-ebs-csi-driver; do
  aws eks update-addon \
    --cluster-name prod-eu \
    --addon-name "$addon" \
    --addon-version <versión-compatible-con-1.31> \
    --resolve-conflicts PRESERVE
done
```

`--resolve-conflicts PRESERVE` mantiene cambios manuales que hayas hecho a los configmaps del add-on. Si no has tocado nada, también sirve `OVERWRITE`.

**Validar**:

```bash
kubectl -n kube-system get pods -l k8s-app=kube-proxy
kubectl -n kube-system get pods -l k8s-app=coredns
# Esperable: nuevos Pods en rolling update, sin errores.
```

## Fase 3 — Upgrade de node groups (T+1 h a T+4 h)

Orden recomendado: **system → app → batch**. Primero el menos crítico y más tolerante.

### Para cada node group:

```bash
aws eks update-nodegroup-version \
    --cluster-name prod-eu \
    --nodegroup-name system \
    --kubernetes-version 1.31

# El flag --force se usa SI algún drain está bloqueado por PDB.
# Antes de usarlo, entender POR QUÉ está bloqueado.
```

EKS rolea los nodos uno a uno:

1. Lanza nodo nuevo con AMI de 1.31.
2. `cordon` + `drain` del nodo viejo (respeta PDBs **por default**).
3. Termina el nodo viejo.
4. Siguiente.

**Monitorear en vivo**:

```bash
watch -n 5 'kubectl get nodes -o wide | awk "{print \$1, \$2, \$5}"'
kubectl get events --sort-by='.lastTimestamp' -A | tail -20
```

**Modos de fallo típicos**:

- Drain bloqueado por PDB mal configurada → corregir la PDB (`minAvailable` razonable) y reanudar.
- Pods sin controller (naked Pods) → no evictables, `--force` los mata, pero **investigar quién los creó**.
- IRSA webhook (`pod-identity-webhook`) en un namespace a drenar sin PDB → service account inyection cae momentáneamente; mitigar programando el deploy en varios nodos con `topologySpreadConstraints`.

## Fase 4 — Validación post-upgrade (T+4 h a T+5 h)

```bash
kubectl get nodes -o wide
# TODAS las versiones en v1.31.x

kubectl get pods -A -o wide --field-selector=status.phase!=Running
# Esperable: vacío o solo Completed de Jobs.

# Smoke test endpoints externos
curl -I https://api.prod-eu.example.com/healthz
curl -I https://admin.prod-eu.example.com/

# Métricas: tasa de errores (5xx), latencia p99, saturación CPU/mem
# Dashboards Grafana → "post-upgrade" view.
```

## Fase 5 — Cierre (D+1 a D+7)

- Actualizar documentación interna de "versión actual del cluster".
- Programar el siguiente upgrade (1.32) con calendario.
- Rotar el backup `preupgrade-1.30-*` a storage "cold" tras ~30 días.
- Revisar métricas durante una semana — algunos bugs post-upgrade se manifiestan sólo bajo carga.

## Rollback

**En managed, un rollback del control plane NO existe**. EKS no te deja bajar de 1.31 a 1.30. Las opciones si algo rompe:

1. **Hot-fix forward**: parchear la causa en el workload o chart (p. ej. actualizar un ingress a la nueva API). Preferible.
2. **Rollback de node groups**: posible si solo rompió el data plane. Lanza un node group viejo (AMI 1.30) y migra workloads.
3. **Blue/green cluster**: si rompió el control plane de forma catastrófica, provisionar `prod-eu-rollback` con Terraform en 1.30, restaurar Velero backup, repuntar DNS.

Por eso el **backup Velero preupgrade** no es opcional.

## Diferencias clave con `kubeadm` self-hosted

| Fase | EKS managed | `kubeadm` self-hosted |
|------|-------------|-----------------------|
| Upgrade control plane | `aws eks update-cluster-version` | `kubeadm upgrade apply` por nodo CP |
| etcd backup | Gestionado por AWS, no accesible | **Tú** haces `etcdctl snapshot save` antes |
| Add-ons | Managed addons (versiones curadas) | Tú mantienes CNI, CoreDNS, kube-proxy |
| Drain de nodos | Automático en node group update | Manual con `kubectl drain` |
| Rollback CP | **No** | Restore etcd snapshot + reinstalar kubeadm |

## Checklist resumen

- [ ] Pluto / kubent limpio contra 1.31.
- [ ] Add-ons con versiones compatibles verificadas.
- [ ] Backup Velero reciente.
- [ ] PDBs sanas.
- [ ] Ventana comunicada y rollback acordado.
- [ ] Control plane upgrade OK.
- [ ] Add-ons upgrade OK.
- [ ] Node groups upgrade OK (uno a uno, orden sistema → app → batch).
- [ ] Smoke test post-upgrade.
- [ ] Versiones nodos homogéneas.
- [ ] Documentación actualizada.
- [ ] Próximo upgrade agendado.
