# Qué pasa cuando el deploy es rechazado por branch policy

Cuando un workflow intenta usar `environment: prod` desde una ref que **no** matchea `deployment_branch_policy`:

1. GitHub crea el `deployment` record.
2. Evalúa la branch policy antes de reviewers.
3. Marca `deployment_status.state = rejected`.
4. El job queda en estado `failure` en la UI.
5. **No** se asigna runner. **No** se consumen minutos.

Mensaje típico en UI:

```
This branch is not allowed to deploy to prod due to deployment protection rules.
```

Mensaje típico vía `gh api`:

```json
{
  "state": "failure",
  "description": "Branch not allowed to deploy to this environment"
}
```

## Diagnóstico rápido

- `gh api repos/$O/$R/environments/prod` — mira el valor de `deployment_branch_policy`.
- `gh api repos/$O/$R/environments/prod/deployment-branch-policies` — lista los patrones.
- Si `custom_branch_policies: true` y no hay patrones listados, **nada** puede desplegar. Fix: añade al menos uno.
