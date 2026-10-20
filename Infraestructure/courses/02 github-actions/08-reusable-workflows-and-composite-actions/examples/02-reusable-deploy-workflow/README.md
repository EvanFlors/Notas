# Ejemplo 02 — Reusable workflow: deploy con inputs + secrets + outputs

## Concepto que demuestra

Cómo escribir un **reusable workflow** (`on: workflow_call`) con:
- **`inputs`** tipados (`string`, `number`, `boolean`) con `required` y `default`.
- **`secrets`** declarados que el caller debe pasar explícitamente.
- **`outputs`** que se propagan desde un step → job → reusable → caller.
- `permissions:` propias.

Y cómo invocarlo desde un **caller workflow**, consumiendo el output en un job downstream.

## Qué aprendes

- La diferencia entre `uses:` a nivel step (composite / action) y `uses:` a nivel job (reusable workflow).
- Por qué `secrets:` requiere lista explícita (o `secrets: inherit` consciente).
- La cadena de dos saltos para outputs: `step.$GITHUB_OUTPUT` → `job.outputs.*` → `reusable.outputs.*` → `needs.<call-job>.outputs.*` en el caller.
- Que un reusable corre en **jobs propios** (y runners propios) separados del caller.

## Prerrequisitos

- `gha-06` (jobs, needs, outputs, matrix).
- `gha-05` (secrets, `permissions:`).
- `bash` local. (No requiere GitHub real; se simula en `/tmp/`.)

**Costos**: ninguno.

## Archivos

- `files/deploy.yml` — el reusable workflow (va en `.github/workflows/deploy.yml` del repo que lo publica).
- `files/caller-ci.yml` — el caller (va en `.github/workflows/ci.yml` del repo que lo consume).
- `files/run-example.sh` — materializa dos repos (`shared/` y `client/`) en `/tmp/reuse-demo/`.

## Ejecución (modo local)

```bash
bash files/run-example.sh /tmp/reuse-demo
find /tmp/reuse-demo -not -path '*/.git*' | sort
```

Resulta en:

```
/tmp/reuse-demo/
├── shared/
│   └── .github/workflows/deploy.yml      (el reusable)
└── client/
    └── .github/workflows/ci.yml          (el caller)
```

**Nota**: en este ejemplo (y en el modo local en general) **no ejecutamos GHA de verdad** — validamos *estructuralmente* el YAML. Para una ejecución real, publicarías el `shared/` como un repo en una org, le pondrías `git tag v1 && git push origin v1`, y el `client/` cambiaría el `uses:` local a `uses: my-org/shared/.github/workflows/deploy.yml@v1`.

## El reusable (fragmento comentado)

```yaml
# .github/workflows/deploy.yml  (en el repo "shared")
name: Reusable deploy

on:
  workflow_call:
    inputs:
      environment:
        description: 'Target env (staging | prod)'
        required: true
        type: string
      image-tag:
        description: 'Image tag to deploy'
        required: true
        type: string
      dry-run:
        required: false
        type: boolean
        default: false
    secrets:
      DEPLOY_TOKEN:
        description: 'Deploy API token (never printed, redacted in logs)'
        required: true
    outputs:
      deployment-url:
        description: 'URL of the resulting deployment'
        value: ${{ jobs.deploy.outputs.url }}

permissions:
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    outputs:
      url: ${{ steps.push.outputs.url }}
    steps:
      - id: push
        env:
          TOKEN: ${{ secrets.DEPLOY_TOKEN }}       # secret solo en env, nunca interpolado en comando
          IMAGE: ${{ inputs.image-tag }}
          ENV:   ${{ inputs.environment }}
          DRY:   ${{ inputs.dry-run }}
        run: |
          if [ "$DRY" = "true" ]; then
            echo "[dry-run] would deploy $IMAGE to $ENV"
          else
            echo "Deploying $IMAGE to $ENV using token ***"
            # (demo) aquí iría la llamada real a la API de deploy
          fi
          url="https://${ENV}.example.com/releases/${IMAGE}"
          echo "url=$url" >> "$GITHUB_OUTPUT"
```

Comentarios no obvios:

- **`type:` es obligatorio** en reusable workflows (no así en composite). Olvidarlo falla el parse.
- El secret `DEPLOY_TOKEN` se usa vía `env:` y no se interpola directamente en el `run:`. Es higiene de inyección (ver `gha-02`).
- `outputs:` a nivel reusable (`outputs.deployment-url.value`) referencia **el output del job** (`jobs.deploy.outputs.url`), que a su vez viene de `steps.push.outputs.url`. Dos saltos.

## El caller (fragmento comentado)

```yaml
# .github/workflows/ci.yml  (en el repo "client")
name: CI
on: [push]

permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      tag: ${{ steps.t.outputs.tag }}
    steps:
      - id: t
        run: echo "tag=sha-${GITHUB_SHA::7}" >> "$GITHUB_OUTPUT"

  call-deploy-staging:
    needs: build
    # Nota: este `uses:` es a NIVEL JOB (no step).
    # En modo local usamos ruta ./ ; en producción sería:
    #   uses: my-org/shared/.github/workflows/deploy.yml@v1
    uses: ./.github/workflows/deploy.yml
    with:
      environment: staging
      image-tag:   ${{ needs.build.outputs.tag }}
      dry-run:     false
    secrets:
      DEPLOY_TOKEN: ${{ secrets.STAGING_DEPLOY_TOKEN }}

  announce:
    needs: call-deploy-staging
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deployed to ${{ needs.call-deploy-staging.outputs.deployment-url }}"
```

Observa que `announce` consume el **output del reusable** vía `needs.call-deploy-staging.outputs.deployment-url`. El job `call-deploy-staging` no tiene `steps:` propios (no se pueden mezclar con `uses:` a reusable).

## Trade-offs clave visibles en este ejemplo

- El caller tiene **3 jobs** (`build`, `call-deploy-staging`, `announce`). El reusable añade **1 job más** (`deploy`). Total = **4 runners** = 4 veces el startup cost.
- Si quisieras ahorrarte un runner, podrías pasar `build` como step dentro del reusable — pero eso acopla y mata la reutilización.
- Si fuera **composite** en vez de reusable, podría ejecutarse como un bloque de steps dentro del job `call-deploy-staging` (0 runners extra), **pero** no podrías tenerlo con su propio `environment:` ni usarlo como `required workflow`.

## Limpieza

```bash
rm -rf /tmp/reuse-demo
```

## Preguntas de reflexión

1. ¿Qué cambia en el `uses:` del caller si publicas el `shared` en `github.com/my-org/shared-workflows` y pinneas a `v1`? ¿Y si pinneas a SHA?
2. Si cambias `secrets: ...` por `secrets: inherit`, ¿qué ganas y qué pierdes?
3. ¿Qué pasa si el caller declara `permissions: contents: read` y el reusable intenta `permissions: packages: write`?
4. Si quisieras que el deploy fuera por `matrix` para `staging`, `prod` y `dr`, ¿dónde pondrías el `matrix:`? ¿En el reusable o en el caller?
