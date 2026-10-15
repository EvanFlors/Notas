# Kubebuilder scaffold (snippets)

Este directorio contiene **sólo los fragmentos que vas a editar**. Para un proyecto Kubebuilder real necesitas también `go.mod`, `main.go`, `Makefile`, `PROJECT`, y los helpers generados (`zz_generated_deepcopy.go`).

## Camino rápido (recomendado)

```bash
mkdir -p /tmp/k8s-14-echo-operator && cd /tmp/k8s-14-echo-operator
kubebuilder init --domain academy.io --repo example.com/echo-operator
kubebuilder create api --group demo --version v1alpha1 --kind Echo --resource --controller
# Reemplaza los dos archivos:
cp /ruta/al/starter/kubebuilder-scaffold/api/v1alpha1/echo_types.go           api/v1alpha1/echo_types.go
cp /ruta/al/starter/kubebuilder-scaffold/internal/controller/echo_controller.go internal/controller/echo_controller.go
# Edita el controller: resuelve los TODOs (student).
make generate manifests
kind create cluster --name k8s-14-echo-op
make install            # aplica la CRD
make run &              # corre el controller fuera del cluster
kubectl apply -f /ruta/al/starter/kubebuilder-scaffold/config/samples/demo_v1alpha1_echo.yaml
kubectl get echoes
kubectl get configmap hello-echo -o yaml
```

## Verificación manual

- `kubectl get configmap hello-echo -o jsonpath='{.data.message}'` → `hello from a CR`.
- Edita el mensaje: `kubectl edit echo hello`, cambia `spec.message` → el ConfigMap se actualiza.
- Borra: `kubectl delete echo hello` → el ConfigMap desaparece (GC vía ownerReferences).

## Si `make run` da error

Es casi siempre un paquete `demov1alpha1` no inicializado — asegúrate de haber corrido `kubebuilder create api` que genera `groupversion_info.go` y `zz_generated_deepcopy.go`.
