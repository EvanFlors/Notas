# Solución de referencia — argo-07-02

Dos manifests y el repo mock. Cualquier variante que cumpla los criterios del README es aceptable.

## appset-mock.yaml

Usa `git.files` sobre `pulls/*.yaml` del repo local. Las claves top-level de cada archivo (`number`, `branch`, `head_sha`) quedan disponibles como variables en el template, idénticas al shape que expone el `pullRequest` generator real → el mock es *drop-in* para desarrollo local.

Ciclo:

- Añadir `pulls/104.yaml` + commit → aparece `myapp-pr-104`.
- Borrar `pulls/101.yaml` + commit → desaparece `myapp-pr-101` y sus recursos.

## appset-github.yaml

Para producción. Usa `pullRequest.github` con `tokenRef`, filtro `labels: ["preview"]`, `requeueAfterSeconds: 60`, y `targetRevision: '{{.head_sha}}'` para desplegar el commit *exacto* del PR (immutable), no la rama (mutable).

## Decisiones clave

- **No** `preserveResourcesOnDeletion: true`: el objetivo del preview es desaparecer con el PR.
- `destination.namespace: 'myapp-pr-{{.number}}'` + `metadata.name: 'myapp-pr-{{.number}}'` para fácil rastreo.
- `project: previews` conceptual — en producción crearías un `AppProject` con destino `*myapp-pr-*` para contener el blast radius.
