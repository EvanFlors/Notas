# Ejemplo 03 — `concurrency` como lock de deploy a producción

## Concepto que demuestra

Cómo `concurrency` serializa (o cancela) runs que compiten por un recurso compartido — típicamente un entorno de producción.

## Contexto

Dos pushes rápidos a `main`. Sin `concurrency`, los dos workflows corren hasta `deploy` y hay dos deploys solapándose contra el mismo entorno (carrera: estado inconsistente, rollbacks a mitad, assets corruptos). Con `concurrency` nombrada por `deploy-prod`, GitHub garantiza que a lo sumo un run del grupo está activo.

Vemos **dos variantes** del comportamiento según `cancel-in-progress`.

## Objetivo

Al terminar, podrás responder:
- ¿Qué pasa con el run #2 cuando `cancel-in-progress: false` y hay un run #1 en curso?
- ¿Y cuando `cancel-in-progress: true`?
- ¿Por qué el grupo típico de CD a prod **no** incluye `${{ github.ref }}` pero el de CI de PRs sí?

## Prerrequisitos

- Haber leído `theory/lesson.md` sección 4.3.

## Workflow (variante A — serializar: `cancel-in-progress: false`)

Archivo: `workflow-serialize.yml`.

```yaml
name: ex-03a-deploy-serialize
on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: deploy-prod
  cancel-in-progress: false     # el segundo run espera en cola

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Simulate deploy
        run: |
          echo "[$(date -u +%H:%M:%S)] starting deploy for ${{ github.sha }}"
          sleep 60
          echo "[$(date -u +%H:%M:%S)] deploy done"
```

Comportamiento con dos pushes rápidos:

```
t=0s   push #1 → run #1 arranca, hace sleep 60
t=10s  push #2 → run #2 queda PENDING (grupo deploy-prod ocupado)
t=60s  run #1 termina
t=60s  run #2 arranca, hace sleep 60
t=120s run #2 termina
```

Nunca hay dos deploys simultáneos.

## Workflow (variante B — reemplazar: `cancel-in-progress: true`)

Archivo: `workflow-cancel.yml`.

```yaml
name: ex-03b-deploy-cancel
on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: deploy-prod
  cancel-in-progress: true      # el nuevo cancela al que corre

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Simulate deploy
        run: |
          echo "[$(date -u +%H:%M:%S)] starting deploy for ${{ github.sha }}"
          sleep 60
          echo "[$(date -u +%H:%M:%S)] deploy done"
```

Comportamiento con dos pushes rápidos:

```
t=0s   push #1 → run #1 arranca
t=10s  push #2 → run #1 cancelado, run #2 arranca
t=70s  run #2 termina
```

**Peligroso para CD a prod**: si el deploy #1 ya empujó la mitad de los recursos cuando se cancela, podés quedar en estado inconsistente. Esta variante tiene sentido en **CI de PRs** (donde cancelar un build obsoleto no deja efecto lateral), **no** en CD.

## Resultado esperado

- Al hacer dos pushes rápidos a `main` con la variante A: en la UI de Actions el segundo run aparece como *pending/queued*, con un ícono distintivo, hasta que termina el primero.
- Con la variante B: el primer run aparece con estado *cancelled* y el segundo *in-progress*.

## Interpretación

- `concurrency` a **nivel workflow** aplica a todos los jobs; a **nivel job** solo a ese job. Para "cola solo al deploy", declaralo en el job `deploy:`.
- El grupo es un **string arbitrario**. GitHub lo trata como opaco: `deploy-prod` ≠ `deploy-${{ github.ref }}`.
- Si querés *un lock por branch* (p. ej. CI de PRs), incluí `${{ github.ref }}` o `${{ github.workflow }}-${{ github.ref }}`. Si querés *lock global* (CD a prod único), no.

## Errores frecuentes

- **`concurrency` a nivel step**: no existe. Es a nivel workflow o job.
- **Grupo con `${{ github.sha }}`**: cada push tiene un SHA único, el grupo nunca colisiona → no serializa nada.
- **`cancel-in-progress: true` en releases que firman assets**: podés dejar firmas a medias.

## Relación con escenarios reales

- Deploys a Kubernetes vía Argo CD (serializar aplicaciones del commit a la rama de infra).
- Publicación a GHCR + attestations (secuenciar para que la attestation referencie la imagen correcta).
- CI de PRs: `concurrency: group: ci-${{ github.workflow }}-${{ github.ref }}; cancel-in-progress: true`.

## Limpieza

No aplica.
