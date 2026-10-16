# Starter — sec-11-01-admission-policy-set-for-capstone

Esta actividad es **independiente**. Produces archivos YAML + un `POLICIES.md`.

## Pasos

1. Lee `../README.md`.
2. Prepara el scratch:
   ```bash
   mkdir -p /tmp/sec-11-admission/{policies,manifests}
   cd /tmp/sec-11-admission
   ```
3. Escribe las 3 `ClusterPolicy` en `policies/` y los 4 manifests de prueba en `manifests/`.
4. Escribe `POLICIES.md` con las 3 secciones mínimas (Contrato, Rollout, Excepciones).
5. Valida:
   ```bash
   bash <repo>/courses/devsecops/11-k8s-admission-kyverno-and-policy-controller/activities/01-admission-policy-set-for-capstone/tests/validate.sh /tmp/sec-11-admission
   ```
6. (Opcional) Si tienes `kyverno` CLI:
   ```bash
   kyverno apply /tmp/sec-11-admission/policies/ --resource /tmp/sec-11-admission/manifests/
   ```
7. Compara con `../solution/REFERENCE.md`.

## Limpieza

```bash
rm -rf /tmp/sec-11-admission
```
