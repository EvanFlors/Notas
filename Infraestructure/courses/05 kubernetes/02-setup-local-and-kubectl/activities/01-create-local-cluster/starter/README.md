# Starter — k8s-02-01-create-local-cluster

Trabaja en `/tmp/k8s-02-01/`. No hay plantillas que copiar: el ConfigMap y el snapshot los produces tú siguiendo el README principal.

Checklist resumido:

1. `kind create cluster --name academy`.
2. `kubectl create namespace k8s-02-lab`.
3. `kubectl config set-context --current --namespace=k8s-02-lab`.
4. Crear `/tmp/k8s-02-01/configmap.yaml` y aplicarlo.
5. Escribir `/tmp/k8s-02-01/snapshot.md` con las cuatro secciones.
6. Correr `tests/validate.sh`.
