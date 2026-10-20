# Actividad cap-12-01 — ESO + Vault wiring

## Objetivo

Partiendo de un `starter/` con un `ClusterSecretStore` y un `ExternalSecret` incompletos, dejarlos funcionando contra una instancia de Vault en modo `-dev` sobre `kind`. Al final, un `kubectl get secret capstone-app` debe devolver un `Secret` real cuyos datos vienen de `kv/capstone/app` en Vault.

## Pasos

1. Copia el starter a `/tmp/cap-12-01`:
   ```bash
   cp -R starter/ /tmp/cap-12-01
   ```
2. Arranca Vault dev y sembla el KV (los comandos exactos están en `starter/bootstrap-vault.sh`, no se corren por el validator; es `--help`-friendly):
   ```bash
   bash /tmp/cap-12-01/bootstrap-vault.sh
   ```
3. Edita `/tmp/cap-12-01/clustersecretstore.yaml` para rellenar los campos marcados con `# TODO`.
4. Edita `/tmp/cap-12-01/externalsecret.yaml` para que apunte a `kv/capstone/app` y declare las dos propiedades (`database_url`, `jwt_signing_key`).
5. Aplica los manifiestos (si tienes cluster disponible). El validador NO exige cluster activo: valida la forma de los YAMLs y la ausencia de secretos literales.

## Qué chequea el validator

- Que los dos YAML existan y parseen.
- Que `ClusterSecretStore` sea del tipo correcto y use `kubernetes` auth.
- Que `ExternalSecret` tenga `secretStoreRef.kind: ClusterSecretStore` y al menos un `data[].remoteRef`.
- Que no haya `kind: Secret` con bloque `data:` en el directorio (todo pasa por ESO).

## Verificación manual con cluster

```bash
kubectl apply -f /tmp/cap-12-01/clustersecretstore.yaml
kubectl apply -f /tmp/cap-12-01/externalsecret.yaml
kubectl -n capstone get externalsecret capstone-app -o jsonpath='{.status.conditions}'
kubectl -n capstone get secret capstone-app -o jsonpath='{.data.DATABASE_URL}' | base64 -d
```

## Comparar con solución

`solution/` contiene la versión final; revisa `solution/REFERENCE.md` para la explicación de cada campo.
