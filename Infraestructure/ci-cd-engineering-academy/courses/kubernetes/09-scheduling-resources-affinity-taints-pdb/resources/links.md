# Recursos — k8s-09

## Documentación oficial

- Managing Resources for Containers — <https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/>
- Quality of Service for Pods — <https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/>
- Node-pressure Eviction — <https://kubernetes.io/docs/concepts/scheduling-eviction/node-pressure-eviction/>
- Assigning Pods to Nodes — <https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/>
- Taints and Tolerations — <https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/>
- Pod Priority and Preemption — <https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/>
- Pod Topology Spread Constraints — <https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/>
- Specifying a Disruption Budget — <https://kubernetes.io/docs/tasks/run-application/configure-pdb/>
- Safely Drain a Node — <https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/>
- Dynamic Resource Allocation — <https://kubernetes.io/docs/concepts/scheduling-eviction/dynamic-resource-allocation/>
- Scheduler Framework — <https://kubernetes.io/docs/concepts/scheduling-eviction/scheduling-framework/>

## Kernel / cgroups (para entender OOM y throttling)

- cgroup v2 docs — <https://docs.kernel.org/admin-guide/cgroup-v2.html>
- CPU Bandwidth Control (CFS) — <https://docs.kernel.org/scheduler/sched-bwc.html>
- OOM killer heuristics — <https://docs.kernel.org/filesystems/proc.html#oom-score>

## Lecturas y charlas recomendadas

- "For the Love of God, Stop Using CPU Limits on Kubernetes" (debate práctico sobre throttling).
- KEP-3063 "Dynamic Resource Allocation" — <https://github.com/kubernetes/enhancements/tree/master/keps/sig-node/3063-dynamic-resource-allocation>
- Burns, Beda, Hightower, Villalba — *Kubernetes Up & Running* (capítulos de scheduling y QoS).
- SIG-Scheduling meeting notes — <https://github.com/kubernetes/community/tree/master/sig-scheduling>

## Herramientas útiles

- `kubectl top` (requiere metrics-server) — <https://github.com/kubernetes-sigs/metrics-server>
- `goldilocks` (recomienda requests/limits) — <https://github.com/FairwindsOps/goldilocks>
- `kube-capacity` (visión rápida de requests/limits por nodo) — <https://github.com/robscott/kube-capacity>
- `kubectl-view-allocations` — <https://github.com/davidB/kubectl-view-allocations>
