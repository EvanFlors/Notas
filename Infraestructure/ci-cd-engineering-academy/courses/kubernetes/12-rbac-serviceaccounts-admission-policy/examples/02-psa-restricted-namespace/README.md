# Ejemplo 02 — Pod Security Admission `restricted`

Crea un namespace `secure-apps` con los labels de **Pod Security Admission** en modo `enforce=restricted`. Un Pod permisivo es rechazado; un Pod compatible pasa.

## Aplicar

```bash
kubectl apply -f namespace.yaml
```

## Probar rechazo

```bash
# Debe fallar con "violates PodSecurity "restricted:latest""
kubectl apply -f bad-pod.yaml
```

## Probar aceptación

```bash
# Debe crearse normalmente
kubectl apply -f good-pod.yaml
kubectl -n secure-apps get pod good-pod
```

## Lectura

- El perfil `restricted` exige: `runAsNonRoot: true`, `allowPrivilegeEscalation: false`,
  `capabilities.drop: [ALL]`, `seccompProfile.type: RuntimeDefault`, y bloquea
  `hostPath`, `hostNetwork`, `hostPID`, `hostIPC`.
- `enforce` rechaza, `warn` solo avisa y `audit` solo registra. Útil combinar
  `warn=restricted` + `enforce=baseline` durante una migración.

## Limpieza

```bash
kubectl delete -f good-pod.yaml --ignore-not-found
kubectl delete -f bad-pod.yaml --ignore-not-found
kubectl delete -f namespace.yaml
```
