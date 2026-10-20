# Example 02 — `helm test` para smoke

Chart con un `Deployment` de nginx, un `Service` ClusterIP y un `templates/tests/test-connection.yaml` que ejerce el `Service` con `wget --spider`.

## Install y test

```sh
helm install smoke . --namespace smoke --create-namespace --wait
helm test smoke --namespace smoke
```

`helm test` crea el Pod efímero, espera a que termine, reporta el resultado y lo borra (por la delete-policy).

## Qué prueba el test

- Que el `Service` existe y resuelve DNS dentro del cluster.
- Que al menos un Pod del Deployment está `Ready` y responde en el puerto 80.
- Que no hay NetworkPolicy que bloquee tráfico pod-to-service.

No prueba lógica de negocio — es un **smoke test**, confirma que "la cosa está encendida". Para pruebas más profundas (p. ej. autenticar y ejecutar un flujo), el patrón es el mismo: Pod `test` con la imagen y comandos adecuados.

## Observar

```sh
# Lista los hooks (incluye el test)
helm get hooks smoke --namespace smoke

# El Pod de test desaparece tras éxito (delete-policy hook-succeeded)
kubectl -n smoke get pods
```

## Limpieza

```sh
helm uninstall smoke --namespace smoke
kubectl delete namespace smoke
```
