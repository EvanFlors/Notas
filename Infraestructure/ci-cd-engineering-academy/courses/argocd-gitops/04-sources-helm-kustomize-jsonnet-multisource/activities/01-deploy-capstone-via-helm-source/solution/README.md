# Solución — argo-04-01

El archivo `application.yaml` muestra la versión completa.

Puntos clave de la solución:

- `releaseName: podinfo` evita que Argo CD use el `metadata.name` como release name (en este caso coincide, pero el hábito es explícito).
- `values` inline con `replicaCount: 2` y `hpa.enabled: false` desactiva el autoscaler para que `replicaCount` no sea "pisado" por el HPA.
- `parameters` fija `image.tag` a `6.7.1` como string (coherente con el `targetRevision` del chart). Esto es análogo a `--set image.tag=6.7.1`.

Observación clave que debes articular en la pregunta 1 de reflexión:

- `helm list -n podinfo` sale vacío porque Argo CD no corre `helm install`. El objeto que no se crea es el Secret `sh.helm.release.v1.podinfo.v1` (donde Helm serializa el release). Como Helm consulta sus releases vía ese Secret, no ve nada.

Para producción se añadirían:

- `argocd-image-updater` o pipeline que haga PR al repo de infra con el bump de `image.tag`.
- Un `Project` propio con `sourceRepos` y `destinations` restringidos.
- `syncOptions: [RespectIgnoreDifferences=true]` + `ignoreDifferences` si llegaras a reactivar el HPA.
