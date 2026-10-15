# Ejemplo 01 — RBAC least privilege (Role + RoleBinding)

Define un `ServiceAccount` llamado `pod-reader-sa` en el namespace `demo` y le otorga únicamente permisos para leer Pods y sus logs en ese namespace.

## Aplicar

```bash
kubectl apply -f manifests.yaml
```

## Verificar

```bash
# Debe decir "yes"
kubectl auth can-i get pods -n demo \
  --as=system:serviceaccount:demo:pod-reader-sa

# Debe decir "no"
kubectl auth can-i list secrets -n demo \
  --as=system:serviceaccount:demo:pod-reader-sa

# Debe decir "no" (fuera del namespace)
kubectl auth can-i get pods -n kube-system \
  --as=system:serviceaccount:demo:pod-reader-sa
```

## Lectura

- Un `Role` existe solo dentro de un namespace. El `RoleBinding` asocia subjects al `Role`.
- `apiGroups: [""]` es el *core group* (Pod, Service, ConfigMap, Secret, Namespace, Node…).
- `pods/log` es un subresource: necesitas listarlo explícitamente para `kubectl logs`.
- Nunca verbos `["*"]` ni resources `["*"]` en producción.

## Limpieza

```bash
kubectl delete -f manifests.yaml
```
