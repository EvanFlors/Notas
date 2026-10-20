# REFERENCE — cap-12-01

## Decisiones

- **`ClusterSecretStore` cluster-scoped**: la app vive en varios namespaces (capstone, canary, preview); duplicar `SecretStore` por namespace multiplica mantenimiento.
- **Vault kubernetes-auth**: elimina la necesidad de un token estatico. ESO presenta su SA token y Vault lo valida contra el API server.
- **`refreshInterval: 30s`**: suficientemente rapido para rotacion sin martillar Vault. En prod bajar a `5m` si hay cientos de ES.
- **`creationPolicy: Owner`**: borrar el ExternalSecret borra el Secret derivado; evita leftovers.
- **Dos entradas `data[]` separadas en vez de `dataFrom`**: queda explicito que claves acabamos materializando (auditabilidad).

## Checks manuales

```bash
kubectl -n capstone describe externalsecret capstone-app
kubectl -n capstone get events --field-selector involvedObject.name=capstone-app
```
