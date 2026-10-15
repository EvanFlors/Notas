# EVALUATION — Echo operator (modo documentación / camino B)

> Completa este documento si no tienes Go/Kubebuilder instalados.
> Reemplaza los bloques `TODO (student)` con tu solución.

## 1. CRD YAML completa

<!-- TODO (student): pega aquí el YAML completo de la CRD Echo.
     Debe incluir: apiVersion, kind, group demo.academy.io, version v1alpha1,
     scope Namespaced, spec.message (string, minLength 1), status (observedMessage,
     lastReconciledAt), subresources.status: {}, y al menos 2 printer columns. -->

```yaml
# TODO (student): CRD YAML aquí
```

## 2. Pseudocódigo del Reconcile

<!-- TODO (student): escribe el pseudocódigo del Reconcile para Echo.
     Debe cubrir estos 5 pasos: fetch CR, build desired ConfigMap,
     SetControllerReference, create-or-update, StatusUpdate. -->

```
TODO (student): Reconcile pseudocode here
```

## 3. Preguntas de reflexión

### 3.1 ¿Qué pasa si olvidas `SetControllerReference` al crear el ConfigMap?

<!-- TODO (student): responde en 2–4 frases. -->

### 3.2 ¿Por qué `r.Status().Update(...)` y no `r.Update(...)` para actualizar status?

<!-- TODO (student): responde en 2–4 frases. -->

### 3.3 ¿Por qué el Reconcile debe ser idempotente?

<!-- TODO (student): responde en 2–4 frases. -->

### 3.4 ¿Qué permisos RBAC necesitaría este operador y por qué?

<!-- TODO (student): lista los verbs sobre los recursos involucrados. -->

## 4. (Opcional) Aplicación de la CRD a kind

Si tienes `kind` + `kubectl`:

```bash
kind create cluster --name k8s-14-echo-doc
kubectl apply -f ../../../examples/01-crd-echo-controller/crd-echo.yaml
kubectl apply -f ../../../examples/01-crd-echo-controller/echo-sample.yaml
kubectl get echoes
# Nota: sin controller, status queda vacío. Es lo esperado.
kind delete cluster --name k8s-14-echo-doc
```
