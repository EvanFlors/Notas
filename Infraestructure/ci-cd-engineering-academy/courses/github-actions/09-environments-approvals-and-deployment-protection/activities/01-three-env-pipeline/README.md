# Actividad 01 — Pipeline con tres environments (dev → staging → prod)

## 1. Identificación

- **ID:** `gha-09-01-three-env-pipeline`
- **Tecnología:** `github-actions`
- **Módulo:** `09-environments-approvals-and-deployment-protection`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a construir un workflow con **tres jobs** encadenados que simulan los deploys a `dev`, `staging` y `prod`. Cada job declara `environment:`. Como el environment real vive en GitHub (no en el YAML), lo describimos como código en archivos sidecar `environment-<nombre>.yaml` que un operador (humano o CI) traducirá a llamadas `gh api`.

Soportamos **dos modos** para que el curso corra sin cuenta de GitHub:

- **`MODE=local`** (default): valida el YAML del workflow y el shape de los sidecars; no toca GitHub.
- **`MODE=live`**: crea los environments reales con `gh api`, los lee, compara con los sidecars y limpia.

Ambos modos validan la misma propiedad: **el workflow más los sidecars describen correctamente la cadena de tres environments con el gate en prod**.

## 3. Objetivos

Al terminar:
- Escribes un workflow con tres jobs: `dev`, `staging`, `prod`, cada uno con `environment:` y en orden encadenado (`needs:`).
- Produces tres sidecars `environment-dev.yaml`, `environment-staging.yaml`, `environment-prod.yaml` con la política de cada uno.
- `prod` declara `wait_timer`, al menos 1 reviewer y `deployment_branch_policy` que restringe a `refs/heads/main`.
- Validas con `tests/validate.sh` (MODE=local).
- Opcional: validas en MODE=live creando los environments en un repo propio.

## 4. Prerrequisitos

- `gha-05` y `gha-06` completados.
- `python3`, `python3-yaml` (`pip install pyyaml`).
- Opcional: `actionlint` para linting del workflow (si está, el validador lo usa).
- **MODE=live**: `gh` autenticado + repo sandbox donde seas admin. Costo: $0.

## 5. Instrucciones

### 5.1 Preparar

```bash
MODE=local bash starter/bootstrap.sh /tmp/gha09-three-env
cd /tmp/gha09-three-env
ls
# Verás un workflow PLACEHOLDER y sidecars PLACEHOLDER que debes editar.
```

### 5.2 Editar el workflow

Abre `/tmp/gha09-three-env/.github/workflows/cd.yaml` y reemplaza el placeholder por un workflow que cumpla:

- `on: push: branches: [main]` (puedes añadir `workflow_dispatch:`).
- `permissions: contents: read, deployments: write` a nivel workflow.
- Tres jobs **exactamente** nombrados `dev`, `staging`, `prod`.
- `dev` no tiene `needs:`.
- `staging` tiene `needs: [dev]`.
- `prod` tiene `needs: [staging]`.
- Cada job declara `environment:` con el nombre correspondiente (`dev` → `environment: dev`, etc.).
- `prod` declara el environment en forma de mapping con `url:`.
- Cada job tiene al menos un step (`echo "deploy to <env>"` basta).

### 5.3 Editar los sidecars

Reemplaza los tres `environment-*.yaml` para que cumplan:

- `environment-dev.yaml`: `name: dev`, `wait_timer: 0`, `reviewers: []`, `deployment_branch_policy.protected_branches: false` y `custom_branch_policies: false` (sin restricción).
- `environment-staging.yaml`: `name: staging`, `wait_timer: 2`, `reviewers: []`, mismo policy abierto.
- `environment-prod.yaml`: `name: prod`, `wait_timer: >= 5`, `prevent_self_review: true`, `reviewers:` con **al menos 1** entrada (`type: User` o `type: Team`), `deployment_branch_policy.custom_branch_policies: true` y `protected_branches: false`, `patterns: ["refs/heads/main"]`.

### 5.4 Validar en modo local (default)

```bash
MODE=local bash tests/validate.sh /tmp/gha09-three-env
```

Debe reportar `OK: actividad completada correctamente`.

### 5.5 Validar en modo live (opcional)

```bash
export GH_OWNER=your-user GH_REPO=your-sandbox-repo
MODE=live bash tests/validate.sh /tmp/gha09-three-env
# El validador:
#   1. Repite las validaciones locales.
#   2. Crea environments dev, staging, prod con la política de cada sidecar.
#   3. Los re-lee y confirma shape.
#   4. Te deja los environments; borra con:
#        gh api -X DELETE repos/$GH_OWNER/$GH_REPO/environments/dev
#        gh api -X DELETE repos/$GH_OWNER/$GH_REPO/environments/staging
#        gh api -X DELETE repos/$GH_OWNER/$GH_REPO/environments/prod
```

## 6. Resultado esperado

- `/tmp/gha09-three-env/.github/workflows/cd.yaml` existe, es YAML válido, declara los tres jobs encadenados.
- Los tres sidecars `environment-*.yaml` existen, son parseables y cumplen el shape.
- `tests/validate.sh` termina en `OK` (MODE=local).
- En MODE=live: los environments existen en GitHub con la configuración correcta.

## 7. Criterios de aceptación

- [ ] Workflow con 3 jobs nombrados `dev`, `staging`, `prod`.
- [ ] Cada job tiene `environment:` con el nombre correcto.
- [ ] `staging` tiene `needs: [dev]`; `prod` tiene `needs: [staging]`.
- [ ] Sidecar `environment-prod.yaml` tiene `wait_timer >= 5`, ≥1 reviewer, `prevent_self_review: true`, branch policy restringida a `main`.
- [ ] Sidecar `environment-dev.yaml` sin reviewers y sin restricción de branch.
- [ ] Sidecar `environment-staging.yaml` con `wait_timer: 2`.
- [ ] `tests/validate.sh` sale 0 en MODE=local.

## 8. Validación

```bash
MODE=local bash tests/validate.sh /tmp/gha09-three-env
MODE=live  bash tests/validate.sh /tmp/gha09-three-env   # opcional
```

## 9. Preguntas de reflexión

1. El gate de `prod` se evalúa *antes* de que el runner corra. ¿Qué problema de seguridad resolverías si siempre fuera así, incluso cuando no hay reviewers?
2. ¿Por qué `staging` lleva `wait_timer` pero no reviewers? ¿Cuándo cambiarías esa decisión?
3. Si pones `custom_branch_policies: true` en `prod` **y no añades patrones**, ¿qué pasa en el próximo deploy?
4. En `MODE=local` no se crea nada en GitHub. ¿Qué parte del comportamiento real **no** estás validando?
5. ¿Qué pasa si alguien edita `prod` desde la UI y relaja los reviewers? ¿Lo detectaría tu CI con los sidecars actuales?

## 10. Extensiones

- **E1** — Añade `workflow_dispatch:` con un input `target_env` y usa un solo job con `environment: ${{ inputs.target_env }}`. Observa cómo el gate cambia según el input.
- **E2** — Modela multi-región: `strategy.matrix.region: [us, eu]` con `environment: prod-${{ matrix.region }}`. Cuántos deployment records se crean por run?
- **E3** — Añade `environment.url: https://${{ matrix.region }}.example.com` dinámico.
- **E4** — Escribe un script que lea los tres sidecars y haga drift detection contra lo que hay en GitHub (`gh api environments`).

## 11. Limpieza

```bash
rm -rf /tmp/gha09-three-env
# Si corriste MODE=live:
for env in dev staging prod; do
  gh api -X DELETE "repos/$GH_OWNER/$GH_REPO/environments/$env" || true
done
```
