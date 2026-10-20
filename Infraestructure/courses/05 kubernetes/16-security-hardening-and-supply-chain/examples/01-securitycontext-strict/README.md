# Ejemplo 01 — `securityContext` strict y PSA `restricted`

Demuestra el contrato `securityContext` productivo (lección §4) y cómo **Pod Security Admission** `restricted` rechaza explícitamente lo que no cumple.

## Qué contiene

- `namespace.yaml` — namespace `app` con los tres labels PSA (`enforce`, `audit`, `warn`) = `restricted`.
- `deploy-strict.yaml` — Deployment con `runAsNonRoot`, `readOnlyRootFilesystem`, `drop: [ALL]`, `seccompProfile: RuntimeDefault`, `allowPrivilegeEscalation: false`, resources, `automountServiceAccountToken: false`. **Debe admitirse.**
- `pod-insecure.yaml` — Pod intencionalmente laxo (sin `securityContext`, `privileged: true`). **Debe ser rechazado** por PSA con mensaje legible.

## Requisitos

- `kind` + `kubectl` instalados.
- Cluster activo. Si no tienes uno, en 30 segundos:

```bash
kind create cluster --name k8s-16-ex01
```

Al terminar, limpia con `kind delete cluster --name k8s-16-ex01`.

## Ejecución

Todo opera en `/tmp/k8s-16-ex01` para no ensuciar el repo.

```bash
mkdir -p /tmp/k8s-16-ex01
cd /tmp/k8s-16-ex01

# Copia los manifests
cp courses/kubernetes/16-security-hardening-and-supply-chain/examples/01-securitycontext-strict/*.yaml .

# 1) Crea el namespace restricted
kubectl apply -f namespace.yaml
kubectl get ns app -L pod-security.kubernetes.io/enforce
# Esperado:
#   NAME   STATUS   AGE   ENFORCE
#   app    Active   1s    restricted

# 2) Deploy que cumple: debe admitirse y arrancar
kubectl apply -f deploy-strict.yaml
kubectl -n app rollout status deploy/web --timeout=60s
# Esperado:
#   deployment "web" successfully rolled out

# 3) Pod intencionalmente laxo: debe ser rechazado
kubectl apply -f pod-insecure.yaml
# Esperado (NO se crea el Pod):
#   Error from server (Forbidden): error when creating "pod-insecure.yaml":
#     pods "insecure" is forbidden: violates PodSecurity "restricted:latest":
#       privileged (container "bad" must not set securityContext.privileged=true),
#       allowPrivilegeEscalation != false,
#       unrestricted capabilities,
#       runAsNonRoot != true,
#       seccompProfile (...)
```

## Qué aprendiste

- El mensaje de error de PSA es **tu checklist en vivo**: lista exactamente cada campo que falta o viola el nivel.
- `enforce` rechaza. Si pusieras solo `audit` + `warn`, el Pod se admitiría pero quedaría log y warning (útil para rollout gradual: `audit`/`warn` primero, `enforce` después).
- El Deployment strict no requiere Helm, operador, ni CRDs — solo YAML plano.

## Limpieza

```bash
kubectl delete ns app --wait=false
rm -rf /tmp/k8s-16-ex01
# Si creaste el cluster solo para este ejemplo:
kind delete cluster --name k8s-16-ex01
```
