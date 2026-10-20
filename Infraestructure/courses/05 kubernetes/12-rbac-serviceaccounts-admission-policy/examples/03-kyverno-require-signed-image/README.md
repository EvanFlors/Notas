# Ejemplo 03 — Kyverno `ClusterPolicy` con `verifyImages`

Define una `ClusterPolicy` de Kyverno que exige firma **keyless** (sigstore/cosign) para cualquier imagen `ghcr.io/myorg/*`. Pods con imágenes no firmadas son rechazados en admission.

> Requiere Kyverno instalado en el cluster. Ver la actividad
> `02-enforce-signed-images-cluster-wide/` para la instalación completa.

## Aplicar

```bash
kubectl apply -f policy.yaml
```

## Probar

```bash
# Debe ser rechazado (imagen no firmada que matchea el patrón)
kubectl apply -f test-pod.yaml
```

Verás algo como:

```
Error from server: admission webhook "mutate.kyverno.svc-fail" denied the request:
  resource Pod/default/signed-image-test was blocked due to the following policies:
  require-signed-images: ...
```

## Lectura

- `verifyImages` ocurre durante **mutating admission** (Kyverno inyecta el digest tras verificar).
- `attestors.keyless` usa la [raíz de confianza pública de sigstore](https://docs.sigstore.dev/) y verifica
  identidad OIDC + presencia en el log transparente **Rekor**.
- `imageReferences` acepta globs. Puedes listar varios registries.
- `validationFailureAction: Enforce` convierte violaciones en rechazo; `Audit` solo registra.

## Limpieza

```bash
kubectl delete -f test-pod.yaml --ignore-not-found
kubectl delete -f policy.yaml
```
