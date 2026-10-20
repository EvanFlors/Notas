# k8s-02 — Recursos

## Documentación oficial

- Kubernetes — [Install Tools (kubectl, kind, minikube)](https://kubernetes.io/docs/tasks/tools/)
- Kubernetes — [kubectl Overview](https://kubernetes.io/docs/reference/kubectl/overview/)
- Kubernetes — [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- Kubernetes — [Organizing Cluster Access Using kubeconfig Files](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)
- Kubernetes — [Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- Kubernetes — [Server-Side Apply](https://kubernetes.io/docs/reference/using-api/server-side-apply/)
- Kubernetes — [Declarative management of config via kubectl apply](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/declarative-config/)
- Kubernetes — [JSONPath Support](https://kubernetes.io/docs/reference/kubectl/jsonpath/)

## Herramientas

- kind — [Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/) y [Configuration](https://kind.sigs.k8s.io/docs/user/configuration/)
- k3d — [Documentación](https://k3d.io/)
- minikube — [Documentación](https://minikube.sigs.k8s.io/docs/)
- kubectx / kubens — [github.com/ahmetb/kubectx](https://github.com/ahmetb/kubectx)
- kube-ps1 — [github.com/jonmosco/kube-ps1](https://github.com/jonmosco/kube-ps1) (prompt que previene el "oops cluster equivocado")
- stern — [github.com/stern/stern](https://github.com/stern/stern) (logs multi-pod)
- krew — [plugin manager de kubectl](https://krew.sigs.k8s.io/)

## Lecturas complementarias

- Kelsey Hightower, [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) — para después, cuando quieras saber qué hace kind "en 90 pasos manuales".
- Burns, Beda, Hightower, Villalba — *Kubernetes Up & Running*, caps. 2–3 (setup y kubectl).
- Daniel Mangum, [Everything You Need to Know About kubeconfig](https://danielmangum.com/posts/everything-kubeconfig/).

## Para los curiosos

- OpenAPI schema del apiserver: con `kubectl proxy` activo, `curl http://127.0.0.1:8001/openapi/v3`. Esto es lo que `kubectl explain` lee.
- `kubectl config view --raw` — muestra el kubeconfig con las credenciales **sin ocultar**. Útil para debugging; peligroso para capturas de pantalla.
- `kubectl --v=8 get pods` — modo verbose. Imprime las requests HTTP exactas que `kubectl` manda al apiserver. Educativo.
