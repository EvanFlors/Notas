# Actividad 01 — Full Terraform CI/CD pipeline (dual-mode)

## 1. Identificación

- **ID:** `tf-13-01-full-cicd-tf`
- **Tecnología:** `terraform`
- **Módulo:** `13-cicd-and-opentofu`
- **Dificultad:** advanced
- **Duración estimada:** 120–180 min
- **Tipo:** guided-lab (dual-mode: `MODE=local` por defecto, `MODE=live` opcional)

## 2. Contexto

Construyes el **pipeline completo** de Terraform CI/CD contra AWS:

1. `.github/workflows/tf-plan.yml` — PR → `fmt` + `validate` + `plan`, con comentario en PR.
2. `.github/workflows/tf-apply.yml` — merge → `apply` desde el artefacto `plan.tfplan`, gated por `environment: production`.
3. `.github/workflows/tf-drift.yml` — schedule → `plan -refresh-only -detailed-exitcode` que abre issue si detecta drift.
4. `terraform/versions.tf` + lockfile versionado — coherencia de versión.
5. `trust-policies/plan.json` + `trust-policies/apply.json` — dos trust policies IAM distintas, una por rol.
6. `docs/pipeline.md` — explica el flujo, por qué el plan se guarda como artefacto, y por qué dos roles.

En `MODE=local` (default) el validator inspecta los YAML y JSON estructuralmente (parsear + checks semánticos) sin tocar la cloud. En `MODE=live` adicionalmente verifica que `aws sts get-caller-identity` funciona en el host (precondición para un deploy real en tu propia cuenta).

## 3. Objetivos

- Workflow de PR correcto: OIDC a rol **read-only**, `fmt`/`validate`/`plan`, artefacto, comentario sticky.
- Workflow de apply correcto: OIDC a rol **de mutación**, `environment: production`, consume `plan.tfplan`, sin recalcular.
- Workflow de drift: `schedule:` + `plan -refresh-only -detailed-exitcode`, abre issue en exit=2.
- Trust policies: dos JSONs separados, cada uno con `sub` pinneado adecuadamente (`:pull_request` para plan, `:environment:production` para apply).
- Coherencia: `required_version` presente, lockfile versionado, `setup-terraform` con versión fijada.
- Sin ningún `AKIA...`, `secrets.AWS_ACCESS_KEY_ID`, `secrets.AWS_SECRET_ACCESS_KEY`, `permissions: write-all`.

## 4. Prerrequisitos

- `MODE=local` (default): `bash`, `python3` (3.8+) con `pyyaml` (`pip install pyyaml`).
- `MODE=live` (opcional): `aws` CLI configurada en el host con creds válidas; cuenta AWS sandbox.
- No requiere binario `terraform` ni `tofu` para la validación local (solo validamos la **estructura** del pipeline — el pipeline mismo descargaría TF en el runner).

**Costos**: USD 0 en `MODE=local`. En `MODE=live`, USD 0 por STS/IAM (si solo verificas `get-caller-identity`); cualquier `apply` real contra una cuenta corre a tu riesgo y queda fuera del alcance del validator.

## 5. Instrucciones

### 5.1 Preparar

```bash
bash starter/bootstrap.sh /tmp/tf-cicd
```

Crea `/tmp/tf-cicd/project/` con la estructura base y stubs vacíos para rellenar.

### 5.2 Tareas

Trabaja en `/tmp/tf-cicd/project/`:

1. **`terraform/versions.tf`** con `required_version = "~> 1.9.0"` y provider `aws ~> 5.60`.
2. **`terraform/.terraform.lock.hcl`** versionado (puede ser un stub: el validator solo verifica que exista y contenga `provider "registry.terraform.io/hashicorp/aws"`).
3. **`.github/workflows/tf-plan.yml`**:
   - `on: pull_request` (al menos a `main`).
   - `permissions: {}` top-level.
   - Un job con `permissions: { id-token: write, contents: read, pull-requests: write }`.
   - Steps: `actions/checkout`, `hashicorp/setup-terraform` con versión explícita, `aws-actions/configure-aws-credentials` con `role-to-assume` apuntando a `arn:aws:iam::000000000000:role/terraform-plan-ro`, `terraform fmt -check`, `terraform init`, `terraform validate`, `terraform plan -out=plan.tfplan`, `actions/upload-artifact`.
4. **`.github/workflows/tf-apply.yml`**:
   - `on: push` a `main`.
   - `permissions: {}` top-level.
   - Un job con `environment: production` y `permissions: { id-token: write, contents: read }`.
   - Steps: `actions/checkout`, `setup-terraform`, `download-artifact` del `plan.tfplan`, `configure-aws-credentials` con `role-to-assume` apuntando a `arn:aws:iam::000000000000:role/terraform-apply-prod`, `terraform init`, `terraform apply plan.tfplan` **sin** `-auto-approve`.
5. **`.github/workflows/tf-drift.yml`**:
   - `on: schedule` con un `cron`.
   - Job con step que corre `terraform plan -refresh-only -detailed-exitcode` y un step condicional `if: steps.<id>.outputs.exitcode == '2'` que abre un issue.
6. **`trust-policies/plan.json`** y **`trust-policies/apply.json`**:
   - Ambos JSON válidos.
   - `Version: "2012-10-17"`, `Effect: Allow`, `Action: sts:AssumeRoleWithWebIdentity`.
   - `Principal.Federated` terminando en `/token.actions.githubusercontent.com`.
   - `aud = sts.amazonaws.com`.
   - `plan.json`: `sub` contiene `:pull_request` (o `:ref:refs/pull/`) — nunca `:environment:production`.
   - `apply.json`: `sub` contiene `:environment:production` — nunca `:pull_request` ni wildcard al final.
7. **`docs/pipeline.md`** (≥ 3 párrafos) mencionando: `plan.tfplan`, `TOCTOU`, `environment`, `OIDC`, `refresh-only`.

Usa cuentas y repos *placeholder*: `000000000000`, `MyOrg/MyRepo`.

### 5.3 Validar

```bash
bash tests/validate.sh /tmp/tf-cicd
# opcional:
MODE=live bash tests/validate.sh /tmp/tf-cicd
```

### 5.4 Pistas

- `permissions: {}` top-level en YAML se escribe literalmente así (mapping vacío).
- La acción oficial para descargar artefactos cross-workflow más usada es `dawidd6/action-download-artifact`; también vale `actions/download-artifact` si disparas desde un `workflow_run`.
- El step de drift que abre issue puede usar `actions/github-script`.
- Si duplicas `role-to-assume` apuntando al mismo rol en los dos workflows, el validator lo marca como error (hay que diferenciar roles).

## 6. Resultado esperado

- 3 workflows parsean YAML.
- 2 trust policies parsean JSON y tienen el `sub` pinneado correctamente.
- `versions.tf` tiene `required_version`.
- `.terraform.lock.hcl` existe.
- `docs/pipeline.md` menciona los 5 términos requeridos.
- Validator imprime `RESULT: ALL CHECKS PASS`.

## 7. Criterios de aceptación

- [ ] `tf-plan.yml`: trigger `pull_request`, OIDC con rol `*-plan-*`, upload del artefacto `plan.tfplan`.
- [ ] `tf-apply.yml`: trigger `push` a `main`, `environment: production`, OIDC con rol `*-apply-*`, consume el artefacto, `terraform apply plan.tfplan` sin `-auto-approve`.
- [ ] `tf-drift.yml`: trigger `schedule`, step con `plan -refresh-only -detailed-exitcode`, step condicional `exitcode == '2'`.
- [ ] Los dos roles son distintos (ARN distinto en plan vs apply).
- [ ] Trust policies: `plan.json` pinneada a `:pull_request` o `:ref:refs/pull/`; `apply.json` pinneada a `:environment:production`.
- [ ] Sin `AKIA...`, `secrets.AWS_ACCESS_KEY_ID`, `secrets.AWS_SECRET_ACCESS_KEY`, `permissions: write-all` en ningún workflow.
- [ ] `versions.tf` con `required_version`; `.terraform.lock.hcl` presente.
- [ ] `docs/pipeline.md` menciona: `plan.tfplan`, `TOCTOU`, `environment`, `OIDC`, `refresh-only`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/tf-cicd
```

El validator:

1. Parsea los 3 YAMLs con `yaml.safe_load`.
2. Parsea los 2 JSON con `json.load`.
3. Verifica para cada workflow la lista de condiciones de arriba.
4. Verifica que `plan` y `apply` apuntan a ARNs IAM distintos.
5. Verifica trust policies con las mismas reglas que `gha-11-01` + la restricción de `sub` por workflow.
6. Verifica `versions.tf` y `.terraform.lock.hcl`.
7. En `MODE=live`: verifica `aws sts get-caller-identity`.

## 9. Preguntas de reflexión

1. ¿Por qué el rol de `plan` tiene permisos de solo lectura y el de `apply` de mutación? ¿Qué atacarías si fueran el mismo rol?
2. Si el `apply` recalculase el plan (en vez de consumir el `.tfplan` del artefacto), ¿qué ataque TOCTOU sería posible?
3. ¿Qué pasa si el `.tfplan` guardado se queda "stale" porque pasaron 48h desde el PR hasta el merge?
4. El job de drift *abre issue*, no aplica. ¿Por qué nunca "autoreconciliar"?
5. Si tu organización usa self-hosted runners compartidos entre repos, ¿qué dos cambios adicionales harías aquí?

## 10. Extensiones

- **E1** — Añade un step que corra `checkov` sobre `plan.tfplan` (ver `tf-12`) antes de subir el artefacto; si falla, el PR no mergea.
- **E2** — Replica la actividad para 3 ambientes (`dev`, `stg`, `prod`), cada uno con su rol IAM, su trust policy y su environment en GitHub, promoviendo el mismo `plan.tfplan` por ambiente (o regenerándolo por ambiente — justifica tu elección).
- **E3** — Reemplaza `hashicorp/setup-terraform` por `opentofu/setup-opentofu` y vuelve a correr el validator. ¿Qué checks del validator deberías actualizar?

## 11. Limpieza

```bash
rm -rf /tmp/tf-cicd
```

En `MODE=live` (si llegaste a crear roles reales):

```bash
aws iam delete-role --role-name terraform-plan-ro
aws iam delete-role --role-name terraform-apply-prod
# No borres el OIDC provider si otros repos lo usan.
```
