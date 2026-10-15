# Recursos — k8s-07 Networking (CNI, NetworkPolicy, Ingress, Gateway API)

## Documentación oficial

- Kubernetes — **Cluster Networking**: <https://kubernetes.io/docs/concepts/cluster-administration/networking/>
- Kubernetes — **NetworkPolicy**: <https://kubernetes.io/docs/concepts/services-networking/network-policies/>
- Kubernetes — **Ingress**: <https://kubernetes.io/docs/concepts/services-networking/ingress/>
- Kubernetes — **Service**: <https://kubernetes.io/docs/concepts/services-networking/service/>
- Kubernetes — **DNS for Services and Pods**: <https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/>
- **Gateway API** (SIG-Network): <https://gateway-api.sigs.k8s.io/>
- Gateway API conformance: <https://gateway-api.sigs.k8s.io/concepts/conformance/>

## CNI plugins

- **CNI** spec (CNCF): <https://github.com/containernetworking/cni/blob/main/SPEC.md>
- **Calico** docs: <https://docs.tigera.io/calico/latest/>
- **Cilium** docs: <https://docs.cilium.io/>
- Cilium eBPF datapath + kube-proxy replacement: <https://docs.cilium.io/en/stable/network/kubernetes/kubeproxy-free/>
- **Hubble** (observabilidad L7 con Cilium): <https://docs.cilium.io/en/stable/overview/intro/#hubble>
- **Flannel**: <https://github.com/flannel-io/flannel>
- **AWS VPC CNI**: <https://docs.aws.amazon.com/eks/latest/userguide/pod-networking.html>
- **GKE Dataplane v2**: <https://cloud.google.com/kubernetes-engine/docs/concepts/dataplane-v2>

## Ingress controllers

- **ingress-nginx**: <https://kubernetes.github.io/ingress-nginx/>
- **Traefik Kubernetes CRD**: <https://doc.traefik.io/traefik/providers/kubernetes-crd/>
- **Contour**: <https://projectcontour.io/>
- **Istio Gateway** (dentro de mesh): <https://istio.io/latest/docs/tasks/traffic-management/ingress/>

## Gateway API — implementaciones

- **Envoy Gateway**: <https://gateway.envoyproxy.io/>
- **Istio Gateway API support**: <https://istio.io/latest/docs/tasks/traffic-management/ingress/gateway-api/>
- **Cilium Gateway API**: <https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/>
- **Contour Gateway API**: <https://projectcontour.io/docs/main/config/gateway-api/>

## Herramientas de diagnóstico

- `netshoot` (imagen con tcpdump/dig/ss/mtr): <https://github.com/nicolaka/netshoot>
- `kubectl debug node/...`: <https://kubernetes.io/docs/tasks/debug/debug-cluster/kubectl-node-debug/>
- `calicoctl`: <https://docs.tigera.io/calico/latest/operations/calicoctl/>
- `cilium` CLI y `hubble` CLI: <https://cilium.io/>

## cert-manager (TLS en producción)

- cert-manager: <https://cert-manager.io/docs/>

## Lecturas conceptuales

- "Why Gateway API?" (SIG-Network): <https://gateway-api.sigs.k8s.io/concepts/>
- "Kubernetes networking from the ground up" — serie de artículos (buscar en kubernetes.io/blog).
- CNCF Landscape — Network: <https://landscape.cncf.io/?group=projects-and-products&view-mode=card&category=cloud-native-network>

## Especificaciones/estándares relacionados

- **TLS 1.3** RFC 8446: <https://www.rfc-editor.org/rfc/rfc8446>
- **CoreDNS** plugins: <https://coredns.io/plugins/>
- **mTLS** patterns: <https://www.rfc-editor.org/rfc/rfc8705> (mTLS for OAuth2) — como contexto.
