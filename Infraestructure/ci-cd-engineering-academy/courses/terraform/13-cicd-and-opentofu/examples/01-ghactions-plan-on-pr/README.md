# Ejemplo 01 — PR: fmt + validate + plan comentado

Workflow que, en cada PR a `main` que toca `terraform/**`, corre `fmt -check`, `validate`, `plan -out=plan.tfplan`, sube el plan como artefacto y lo pega en el PR como comentario *sticky*.

## Archivos

- [`.github/workflows/tf-plan.yml`](.github/workflows/tf-plan.yml) — workflow completo.

## Puntos clave

- **OIDC** con un rol **read-only** (`terraform-plan-ro`). El plan nunca necesita permisos de mutación.
- `permissions: {}` top-level; solo el job eleva `id-token: write` + `contents: read` + `pull-requests: write`.
- Trust policy del rol (en IAM) pinneada a `sub = repo:MyOrg/MyRepo:pull_request` para que solo los PRs del repo puedan asumirlo.
- El plan se guarda como `plan.tfplan` **binario** y se sube como artefacto; el workflow de apply lo descarga tal cual (ver `examples/02`).
- `terraform show -no-color plan.tfplan` convierte el binario a texto para el comentario.
- La acción `marocchino/sticky-pull-request-comment` actualiza el mismo comentario en lugar de crear uno nuevo por push.

## Cómo usarlo

1. Copiar `.github/workflows/tf-plan.yml` a tu repo.
2. Ajustar `role-to-assume`, `aws-region`, y la ruta `working-directory` del stack.
3. En AWS: crear el OIDC provider (si no existe) y el rol `terraform-plan-ro` con permisos de solo lectura sobre los servicios que tu TF describe (p. ej. `ReadOnlyAccess` de AWS más permisos específicos de read sobre S3/DynamoDB del backend).
4. En GitHub: marcar el check `terraform-plan` como *required* en branch protection de `main`.

## Qué NO hace

- No aplica nada. El `apply` vive en el workflow de merge (ver `examples/02`).
- No valida políticas (eso es `tf-12` + Checkov/OPA).
- No detecta drift (eso es un job programado aparte).
