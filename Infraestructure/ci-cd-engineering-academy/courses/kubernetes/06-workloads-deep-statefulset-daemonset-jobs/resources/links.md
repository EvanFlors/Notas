# Recursos — k8s-06

## Documentación oficial

### Workload controllers

- **StatefulSet** — <https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/>
- **StatefulSet basics (tutorial)** — <https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/>
- **DaemonSet** — <https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/>
- **Job** — <https://kubernetes.io/docs/concepts/workloads/controllers/job/>
- **CronJob** — <https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/>
- **Parallel Processing using Expansions** — <https://kubernetes.io/docs/tasks/job/parallel-processing-expansion/>
- **Indexed Jobs** — <https://kubernetes.io/docs/tasks/job/indexed-parallel-processing-static/>
- **Coarse Parallel Processing Using a Work Queue** — <https://kubernetes.io/docs/tasks/job/coarse-parallel-processing-work-queue/>

### Storage y PVC

- **Persistent Volumes** — <https://kubernetes.io/docs/concepts/storage/persistent-volumes/>
- **StatefulSet PVC retention policy (`persistentVolumeClaimRetentionPolicy`)** — <https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#persistentvolumeclaim-retention>
- **Local-path provisioner (default en kind)** — <https://github.com/rancher/local-path-provisioner>

### Service y DNS

- **Headless Services** — <https://kubernetes.io/docs/concepts/services-networking/service/#headless-services>
- **DNS for Services and Pods** — <https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/>

### CronJob — zona horaria y schedule

- **CronJob time zones (`spec.timeZone`, GA desde 1.27)** — <https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/#time-zones>
- **cron format reference** — <https://en.wikipedia.org/wiki/Cron>

## KEPs relevantes

- **KEP-3140 TimeZone support in CronJob** — <https://github.com/kubernetes/enhancements/tree/master/keps/sig-apps/3140-TimeZone-support-in-CronJob>
- **KEP-1847 Autoremove PVCs on StatefulSet scale/delete** — <https://github.com/kubernetes/enhancements/tree/master/keps/sig-apps/1847-autoremove-statefulset-pvcs>
- **KEP-2214 Indexed Job** — <https://github.com/kubernetes/enhancements/tree/master/keps/sig-apps/2214-indexed-job>

## Operadores de Postgres (lectura para §12 de la lección)

- **CloudNativePG** — <https://cloudnative-pg.io/>
- **Zalando Postgres Operator** — <https://github.com/zalando/postgres-operator>
- **Crunchy Postgres for Kubernetes** — <https://github.com/CrunchyData/postgres-operator>

## DaemonSets típicos del mundo real

- **fluent-bit on K8s** — <https://docs.fluentbit.io/manual/installation/kubernetes>
- **Vector on K8s** — <https://vector.dev/docs/setup/installation/platforms/kubernetes/>
- **node_exporter** — <https://github.com/prometheus/node_exporter>
- **Falco (eBPF security agent)** — <https://falco.org/docs/getting-started/running/#kubernetes-using-helm>

## Herramientas útiles

- **kind** (local K8s) — <https://kind.sigs.k8s.io/>
- **k9s** (TUI para kubectl) — <https://k9scli.io/>
- **stern** (multi-pod logs) — <https://github.com/stern/stern>
- **kubectl explain** — tu amigo. Ej.: `kubectl explain statefulset.spec.volumeClaimTemplates`.

## Lecturas complementarias

- **"Running stateful workloads in Kubernetes"** (CNCF whitepaper) — <https://www.cncf.io/reports/>
- **"Why your StatefulSet isn't a DBA"** — tema recurrente en charlas de KubeCon; buscar `KubeCon postgres operator` y comparar enfoques.
