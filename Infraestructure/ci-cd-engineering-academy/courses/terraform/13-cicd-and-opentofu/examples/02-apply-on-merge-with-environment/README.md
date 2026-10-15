# Ejemplo 02 — Merge: apply desde el artefacto plan, gated por environment

Workflow que, al mergear a `main`, descarga el `plan.tfplan` que generó el PR aprobado y lo aplica tal cual. El job está gated por `environment: production` con *required reviewers*.

## Archivos

- [`.github/workflows/tf-apply.yml`](.github/workflows/tf-apply.yml) — workflow completo.

## Puntos clave

- **OIDC** con un rol **de mutación** (`terraform-apply-prod`) distinto del rol de plan.
  - Trust policy pinneada a `sub = repo:MyOrg/MyRepo:environment:production`. Si alguien intenta aplicar fuera del environment, AWS rechaza el assume.
- `environment: production` en el job → requiere aprobación humana desde la UI de GitHub.
- Descarga el artefacto `tfplan-<PR>` producido por el workflow de PR (ver `examples/01`) con `actions/download-artifact` + `github-script` para resolver el número de PR a partir del commit mergeado.
- `terraform apply plan.tfplan` **sin** `-auto-approve` adicional (el `.tfplan` ya está "aprobado" por el revisor humano en el gate del environment).
- Si entre PR aprobado y merge pasó demasiado tiempo (p. ej. > 1 h) o alguien tocó la consola, el apply falla con `Error: Saved plan is stale` — comportamiento deseado: forzar un nuevo plan.

## Flujo end-to-end

```
PR abierto ─► workflow tf-plan.yml ─► artefacto tfplan-123
   │
   │ review approved + merged
   ▼
push a main ─► workflow tf-apply.yml ─► espera reviewer del environment
   │                                      ▼
   │                                 download tfplan-123
   │                                 OIDC assume prod role
   │                                 terraform apply tfplan-123
```

## Qué NO hace

- No recalcula el plan. Esa es exactamente la propiedad que buscamos (TOCTOU).
- No sabe aplicar un hotfix sin pasar por un PR. Si lo necesitas, dispara el workflow con `workflow_dispatch` y acepta que el revisor del environment es tu única barrera.
- No gestiona rollback automático. Rollback de infra = otro PR con el cambio inverso.
