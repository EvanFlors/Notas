# NOTES — cap-12-02 (solucion)

## Audit vs Enforce

- Para pasar la policy a Audit temporalmente:
  `kubectl patch cpol verify-capstone-images --type=merge -p '{"spec":{"validationFailureAction":"Audit"}}'`
- En Audit, Kyverno sigue produciendo `PolicyReport` por cada violacion sin bloquear el admission. Revisar con:
  `kubectl get polr -A -l policy.kyverno.io/policy-name=verify-capstone-images`
- Reactivar Enforce cuando `polr --field-selector result=fail` quede en 0 durante 24h.

## Namespaces excluidos

- `kube-system`, `kyverno`, `external-secrets`, `falco`: imagenes vendor que no estan firmadas por nuestro workflow.

## Pruebas estaticas offline

```bash
kyverno test .
```
