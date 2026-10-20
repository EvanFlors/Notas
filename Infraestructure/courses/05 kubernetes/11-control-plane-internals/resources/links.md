# Recursos — k8s-11

## Componentes del control plane (docs oficiales)

- **kube-apiserver** — <https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/>
- **kube-scheduler** — <https://kubernetes.io/docs/reference/command-line-tools-reference/kube-scheduler/>
- **kube-controller-manager** — <https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/>
- **cloud-controller-manager** — <https://kubernetes.io/docs/concepts/architecture/cloud-controller/>
- **kubelet** — <https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/>
- **kube-proxy** — <https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/>

## etcd

- **Documentación oficial** — <https://etcd.io/docs/>
- **Raft consensus (paper)** — <https://raft.github.io/raft.pdf>
- **Hardware recommendations** — <https://etcd.io/docs/latest/op-guide/hardware/>
- **Disaster recovery (snapshot/restore)** — <https://etcd.io/docs/latest/op-guide/recovery/>
- **Operating etcd for Kubernetes** — <https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/>

## Admission

- **Admission controllers reference** — <https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/>
- **ValidatingAdmissionPolicy (CEL)** — <https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/>
- **MutatingAdmissionWebhook + ValidatingAdmissionWebhook** — <https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/>

## Scheduling

- **Scheduling framework** — <https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/>
- **Scheduler configuration (`KubeSchedulerConfiguration`)** — <https://kubernetes.io/docs/reference/scheduling/config/>
- **Default plugins** — <https://kubernetes.io/docs/reference/scheduling/config/#scheduling-plugins>

## Interfaces

- **CRI (Container Runtime Interface)** — <https://kubernetes.io/docs/concepts/architecture/cri/>
- **CNI (Container Network Interface)** — <https://github.com/containernetworking/cni>
- **CSI (Container Storage Interface)** — <https://kubernetes-csi.github.io/docs/>

## Audit y events

- **Auditing (`audit.k8s.io/v1`)** — <https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/>
- **`events.k8s.io/v1` API** — <https://kubernetes.io/docs/reference/kubernetes-api/cluster-resources/event-v1/>
- **`kubectl events` command** — <https://kubernetes.io/docs/reference/kubectl/generated/kubectl_events/>

## Leader election

- **Lease API y leader election** — <https://kubernetes.io/docs/concepts/architecture/leases/>

## Herramientas útiles

- **`kubectl -v` niveles de verbosidad** — <https://kubernetes.io/docs/reference/kubectl/quick-reference/#kubectl-output-verbosity-and-debugging>
- **`kind`** — <https://kind.sigs.k8s.io/>
- **`kubeadm`** — <https://kubernetes.io/docs/reference/setup-tools/kubeadm/>
- **`etcdctl`** (via Homebrew: `brew install etcd`) — <https://github.com/etcd-io/etcd/tree/main/etcdctl>

## Lecturas recomendadas

- *Programming Kubernetes* (Hausenblas & Schimanski) — capítulos sobre API Machinery y controllers.
- *Kubernetes Up & Running* (Burns/Beda/Hightower/Villalba) — capítulos de arquitectura y control plane.
- **KEP-624 (Scheduling Framework)** — <https://github.com/kubernetes/enhancements/tree/master/keps/sig-scheduling/624-scheduling-framework>
- **KEP-3488 (ValidatingAdmissionPolicy)** — <https://github.com/kubernetes/enhancements/tree/master/keps/sig-api-machinery/3488-cel-admission-control>

## Para producción (puente a k8s-17)

- **Velero** — <https://velero.io/docs/>
- **etcd-backup-restore operator (gardener)** — <https://github.com/gardener/etcd-backup-restore>
