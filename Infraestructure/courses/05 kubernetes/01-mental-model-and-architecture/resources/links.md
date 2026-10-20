# Recursos — k8s-01

## Docs oficiales (fuente primaria)

- **Kubernetes Components** — <https://kubernetes.io/docs/concepts/overview/components/>
- **Kubernetes Architecture** — <https://kubernetes.io/docs/concepts/architecture/>
- **What is Kubernetes** — <https://kubernetes.io/docs/concepts/overview/>
- **Controllers** — <https://kubernetes.io/docs/concepts/architecture/controller/>
- **Nodes** — <https://kubernetes.io/docs/concepts/architecture/nodes/>
- **Control plane–node communication** — <https://kubernetes.io/docs/concepts/architecture/control-plane-node-communication/>
- **Pods** — <https://kubernetes.io/docs/concepts/workloads/pods/>
- **Objects, spec and status** — <https://kubernetes.io/docs/concepts/overview/working-with-objects/kubernetes-objects/>
- **API Overview** — <https://kubernetes.io/docs/reference/using-api/>
- **etcd (upstream)** — <https://etcd.io/docs/>

## Interfaces estándar

- **CRI (Container Runtime Interface)** — <https://kubernetes.io/docs/concepts/architecture/cri/>
- **CNI spec** — <https://github.com/containernetworking/cni/blob/main/SPEC.md>
- **CSI spec** — <https://github.com/container-storage-interface/spec>

## Conformance y distribución

- **CNCF Software Conformance** — <https://www.cncf.io/certification/software-conformance/>
- **sonobuoy** (ejecutor oficial de conformance) — <https://sonobuoy.io/>

## Managed vs self-hosted

- **EKS** — <https://docs.aws.amazon.com/eks/>
- **GKE** — <https://cloud.google.com/kubernetes-engine/docs>
- **AKS** — <https://learn.microsoft.com/azure/aks/>
- **kubeadm** — <https://kubernetes.io/docs/reference/setup-tools/kubeadm/>
- **Cluster API** — <https://cluster-api.sigs.k8s.io/>
- **k3s** — <https://docs.k3s.io/>
- **kind** — <https://kind.sigs.k8s.io/>
- **k3d** — <https://k3d.io/>

## Lectura conceptual

- Burns, Beda, Hightower, Villalba — *Kubernetes Up & Running* (3ª ed.). Caps. 1–3.
- Verma, Pedrosa, Korupolu et al. — *Large-scale cluster management at Google with Borg* (EuroSys 2015). <https://research.google/pubs/pub43438/>
- Burns, Oppenheimer — *Design patterns for container-based distributed systems* (HotCloud 2016). <https://www.usenix.org/conference/hotcloud16/workshop-program/presentation/burns>
- Kelsey Hightower — **Kubernetes The Hard Way** (lab canónico para entender el control plane desde cero) — <https://github.com/kelseyhightower/kubernetes-the-hard-way>

## KEPs y comunidad

- **Kubernetes Enhancement Proposals (KEPs)** — <https://github.com/kubernetes/enhancements>
- **kubernetes/community** — <https://github.com/kubernetes/community>
- **SIG-Architecture** — <https://github.com/kubernetes/community/tree/master/sig-architecture>

## Herramientas de exploración (contexto para `k8s-02`)

- **kubectl** — <https://kubernetes.io/docs/reference/kubectl/>
- **k9s** (TUI para explorar el cluster) — <https://k9scli.io/>
- **stern** (logs de múltiples Pods) — <https://github.com/stern/stern>

## Nota de verificación

Última verificación de enlaces: pendiente de validar en Fase 4 (lecciones ejecutables). Todos los enlaces son dominios canónicos del ecosistema (`kubernetes.io`, `etcd.io`, `cncf.io`, `cluster-api.sigs.k8s.io`, repos oficiales en `github.com/kubernetes`, `github.com/containernetworking`, `github.com/container-storage-interface`); verificar fecha y disponibilidad al momento de desarrollar el curso en producción.
