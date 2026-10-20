# Ejemplo 04 — `ValidatingAdmissionPolicy` con CEL

Define una `ValidatingAdmissionPolicy` (GA en K8s 1.30+) que exige que **todos los contenedores** de un Pod declaren `runAsNonRoot: true`. Se evalúa dentro del API server sin webhook externo.

## Aplicar

```bash
kubectl apply -f policy.yaml
kubectl apply -f binding.yaml
```

## Probar

```bash
# Debe ser rechazado por la VAP
kubectl apply -f bad-pod.yaml

# Debe crearse
kubectl apply -f good-pod.yaml
```

## Lectura

- `ValidatingAdmissionPolicy` define la regla CEL; `ValidatingAdmissionPolicyBinding`
  la activa sobre un conjunto (en este caso, Pods en namespaces con
  `environment=prod`).
- `expression` es CEL puro. Puede referirse a `object` (el objeto bajo validación),
  `oldObject`, `params`, `namespaceObject`.
- `failurePolicy: Fail` significa que si la expresión no puede evaluarse (bug CEL,
  objeto malformado), la request se rechaza.
- Es la alternativa in-process a `ValidatingWebhookConfiguration`: menos latencia,
  menos dependencias, pero no muta ni genera.

## Limpieza

```bash
kubectl delete -f good-pod.yaml --ignore-not-found
kubectl delete -f bad-pod.yaml --ignore-not-found
kubectl delete -f binding.yaml
kubectl delete -f policy.yaml
```
