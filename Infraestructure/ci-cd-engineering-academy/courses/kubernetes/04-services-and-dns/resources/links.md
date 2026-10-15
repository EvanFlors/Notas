# Recursos — k8s-04 Services y DNS

## Documentación oficial de Kubernetes

- [Service (concepto)](https://kubernetes.io/docs/concepts/services-networking/service/) — tipos, selectores, puertos, afinidad.
- [DNS para Services y Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) — formato FQDN, A/AAAA records, SRV records, headless.
- [EndpointSlices](https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/) — por qué sustituyen a Endpoints.
- [Connect Pods to Services](https://kubernetes.io/docs/concepts/services-networking/connect-applications-service/) — walkthrough oficial, buen complemento al ejemplo 01.
- [Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/) — la checklist "oficial" de depuración; muy cercana a la de la sección 10 de la teoría.
- [`kube-proxy` iptables vs IPVS vs userspace](https://kubernetes.io/docs/reference/networking/virtual-ips/) — detalle de cómo se materializan las reglas.
- [`sessionAffinity`](https://kubernetes.io/docs/concepts/services-networking/service/#session-stickiness) — caveats y configuración.
- [`externalTrafficPolicy`](https://kubernetes.io/docs/tasks/access-application-cluster/create-external-load-balancer/#preserving-the-client-source-ip) — Cluster vs Local.

## CoreDNS

- [CoreDNS en el cluster](https://kubernetes.io/docs/tasks/administer-cluster/coredns/) — plantilla Corefile por default.
- [CoreDNS plugins](https://coredns.io/plugins/) — forward, cache, kubernetes, rewrite.
- [Debug DNS resolution](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/) — procedimiento oficial de troubleshooting.

## kind

- [kind quickstart](https://kind.sigs.k8s.io/docs/user/quick-start/) — instalación y creación de clusters.
- [Configuración de kind](https://kind.sigs.k8s.io/docs/user/configuration/) — `extraPortMappings`, varios nodos.

## Headless Services y StatefulSet (preview)

- [StatefulSet basics](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/) — identidad de red, serviceName.
- [DNS para StatefulSet](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#stable-network-id) — nombres `<pod>.<svc>.<ns>.svc.cluster.local`.

## Lectura complementaria

- "Kubernetes Networking: a tutorial for the curious" — artículos de Learnk8s sobre `kube-proxy` y Services (buscar la serie actual).
- "Kubernetes Up & Running" (Burns, Beda, Hightower, Villalba) — capítulo de Services y Discovery.
- Cilium docs: [`kube-proxy` replacement](https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/) — cuándo y por qué sustituir `kube-proxy` por eBPF.

## Herramientas útiles al depurar

- `nicolaka/netshoot` — imagen con `curl`, `dig`, `nslookup`, `tcpdump`, `nc`, `ip`, `iptables`.
- `curlimages/curl` — imagen minimalista para pruebas HTTP.
- `registry.k8s.io/e2e-test-images/jessie-dnsutils` — `nslookup`/`dig` que usa el repo de Kubernetes para e2e.
- `stern` o `kubectl stern` — logs multi-pod, útil para rastrear qué backend recibió qué request.
