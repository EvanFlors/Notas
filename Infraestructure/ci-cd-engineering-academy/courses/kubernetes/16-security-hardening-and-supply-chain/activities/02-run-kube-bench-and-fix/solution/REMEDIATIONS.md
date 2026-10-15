# Top-3 remediaciones de kube-bench

> Solucion de referencia. Los IDs CIS exactos varian segun la version del
> benchmark que detecte kube-bench. Lo que importa aqui es la forma del
> entregable (estructura + prosa concreta por subseccion).

## Resumen

- PASS: 42
- FAIL: 18
- WARN: 7
- Fuente: `kube-bench.out` (kind, nodo control-plane, benchmark cis-1.9).

---

### H1 — 1.2.19 Ensure --anonymous-auth argument is set to false

**Hallazgo**
kube-bench reporta `[FAIL] 1.2.19 Ensure --anonymous-auth argument is set to false (Automated)`
sobre el manifiesto estatico de `kube-apiserver` en `/etc/kubernetes/manifests/kube-apiserver.yaml`.
Actualmente el apiserver acepta requests sin autenticar y las mapea al usuario `system:anonymous`.

**Mecanismo**
Con `--anonymous-auth=true` el apiserver no rechaza requests sin credenciales; el authorizer (RBAC)
sigue aplicando, pero cualquier ClusterRoleBinding al grupo `system:unauthenticated` o al usuario
`system:anonymous` queda explotable desde la red. El default historico es `true` por retrocompatibilidad
con healthchecks externos.

**Impacto**
Severidad **ALTA** si el apiserver es alcanzable desde la red (nodos, LB, VPN). Un atacante con
visibilidad del endpoint puede enumerar APIs y, si hay un binding laxo (muy comun con charts
antiguos), listar namespaces o leer `/healthz` + `/metrics` para fingerprint. Combinado con el
hallazgo H2 (RBAC excesivo) escala rapido.

**Remediacion**
Editar `/etc/kubernetes/manifests/kube-apiserver.yaml` y agregar `--anonymous-auth=false` a los args.
kubelet reinicia el Pod static automaticamente. Verificar:
`kubectl get --raw '/healthz' --server https://<apiserver>:6443 --insecure-skip-tls-verify` debe
responder `401 Unauthorized`. En managed (EKS/GKE), este flag suele venir cerrado por el provider;
confirmar con el audit log del proveedor.

---

### H2 — 5.1.1 Ensure that the cluster-admin role is only used where required

**Hallazgo**
`[FAIL] 5.1.1 Ensure that the cluster-admin role is only used where required (Manual)`.
Al inspeccionar `kubectl get clusterrolebindings -o json | jq ...` encontramos 3 bindings a
`cluster-admin`: el `cluster-admin` default, un `kubeadm:cluster-admins` y un `my-app-admin`
creado por un chart Helm hace meses.

**Mecanismo**
`cluster-admin` es un ClusterRole con `*` sobre `*`. Cualquier subject bindeado puede crear nuevos
ClusterRoleBindings, leer Secrets de todos los namespaces, instalar DaemonSets privileged e
installar admission webhooks propios. Es el equivalente moral a root en el cluster.

**Impacto**
Severidad **ALTA**. Un token comprometido con `cluster-admin` es game over: no hay forma de
contener el blast radius. En particular, el binding `my-app-admin` apunta a un ServiceAccount
de un workload de app — un bug remoto en esa app se convierte en control total del cluster.

**Remediacion**
Reemplazar el binding de la app por un `Role` namespaced con los verbs/resources estrictamente
necesarios (p.ej. `get,list,watch` sobre `pods` y `services` en el namespace propio) + un
`RoleBinding`. Comando: `kubectl delete clusterrolebinding my-app-admin` y aplicar el nuevo
Role/RoleBinding desde el repo GitOps. Verificar con `kubectl auth can-i --as=system:serviceaccount:app:my-app create secrets -A` → `no`.

---

### H3 — 1.2.33 Ensure that the --encryption-provider-config argument is set appropriately

**Hallazgo**
`[FAIL] 1.2.33 Ensure that the --encryption-provider-config argument is set as appropriate (Manual)`.
El apiserver no tiene `--encryption-provider-config` y por tanto los `Secret` se guardan en etcd
como base64 (no cifrado).

**Mecanismo**
etcd persiste todos los objetos del API en disco. Sin `EncryptionConfiguration`, los valores de
`Secret` quedan como base64 — un operador con acceso al disco de etcd, un snapshot de etcd o un
backup lee los secretos en claro trivialmente.

**Impacto**
Severidad **ALTA** en entornos donde el disco de etcd es accesible por terceros (operadores de
infra sin need-to-know, backups a S3 sin bucket policy, snapshots en imagenes de nodo). Severidad
**MEDIA** en clusters managed donde el provider cifra el volumen subyacente.

**Remediacion**
Crear `/etc/kubernetes/encryption.yaml` con un provider `aescbc` (lab) o `kms` (produccion con AWS
KMS / GCP KMS / Vault). Clave de 32 bytes base64. Editar el manifest del apiserver para pasar
`--encryption-provider-config=/etc/kubernetes/encryption.yaml` y montar el archivo via hostPath.
Despues del cambio, re-encriptar los Secret existentes: `kubectl get secrets -A -o json | kubectl replace -f -`. Verificar leyendo etcd directamente con `etcdctl get /registry/secrets/<ns>/<name>` — el blob debe empezar con el prefijo del provider (p.ej. `k8s:enc:aescbc:v1:key1:`) y no con el nombre del secret en claro.
