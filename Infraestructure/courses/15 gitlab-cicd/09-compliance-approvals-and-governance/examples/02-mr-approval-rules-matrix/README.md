# Ejemplo 02 — Matriz de MR Approval Rules

> Lectura y análisis. Objetivo: ver un `approval-rules.yml` realista y entender qué significa cada regla cuando llega un MR.

## 1. El `approval-rules.yml`

```yaml
project: workloads/checkout
rules:
  - name: default-two-approvers
    applies_to_all_protected_branches: true
    approvals_required: 2
    reset_on_push: true
    prevent_author_approval: true
    prevent_committers_approval: true
    users_or_groups:
      - group: workloads/checkout-reviewers

  - name: codeowners-required
    applies_to_all_protected_branches: true
    code_owner_approval_required: true

  - name: security-high-findings
    applies_to_all_protected_branches: true
    report_type: vulnerability
    severity_levels: [high, critical]
    approvals_required: 1
    users_or_groups:
      - group: platform/security

  - name: release-branch-extra
    applies_to_branches: ["release/*"]
    approvals_required: 1
    users_or_groups:
      - group: platform/release-managers
```

## 2. Qué pasa con un MR concreto

### Caso A — MR trivial a `main` que toca `README.md`

- `default-two-approvers`: necesita 2 approvers del grupo `workloads/checkout-reviewers`. El autor **no** cuenta.
- `codeowners-required`: `README.md` no está en `CODEOWNERS` o cae en `*` → owner por default aprueba.
- `security-high-findings`: no se dispara (no hay findings).
- `release-branch-extra`: no aplica (target es `main`, no `release/*`).

**Total**: 2 approvers + 1 owner. Puede ser la misma gente si pertenece a ambos grupos.

### Caso B — MR a `main` que toca `/src/payments/charge.ts`

- `default-two-approvers`: 2 approvers.
- `codeowners-required`: owners de `/src/payments/` (digamos `@group/security @group/payments`) deben aprobar — al menos 1 de cada sección si tienen secciones separadas en `CODEOWNERS`.
- `security-high-findings`: si el pipeline detecta un `high` nuevo, además necesita 1 approver de `platform/security`.
- `release-branch-extra`: no aplica.

**Total**: 2 approvers + owners del path + opcionalmente 1 de security.

### Caso C — MR a `release/2026.10`

- `default-two-approvers`: 2 approvers.
- `codeowners-required`: según paths tocados.
- `security-high-findings`: si hay findings, security.
- `release-branch-extra`: **1 release manager** adicional.

## 3. Pitfalls comunes

- **Olvidar `prevent_author_approval`**: un developer que puede auto-aprobar su MR vacía el control.
- **Code Owners sin `code_owner_approval_required: true`**: el fichero `CODEOWNERS` sólo sirve de documentación — no bloquea el merge.
- **Security approvals sin `report_type: vulnerability`**: la regla no se activa aunque haya findings.
- **Reset on push desactivado**: alguien aprueba, el autor pushea un `rm -rf /` y mergea con las aprobaciones viejas.
- **Approvers = usuarios individuales en vez de grupos**: cuando ese usuario rota de equipo, nadie actualiza las rules y los MRs se bloquean.

## 4. Visualización mental

```
MR entra
   │
   ▼
┌─────────────────────────────────────────────┐
│  Pipeline corre (compliance + build + test) │
└───────────────┬─────────────────────────────┘
                │
                ▼
    ┌───────────────────────┐
    │ ¿pasó compliance?     │─ no ─▶ merge bloqueado por pipeline
    └──────────┬────────────┘
               │ sí
               ▼
    ┌───────────────────────┐
    │ ¿cumple approval rules│─ no ─▶ merge bloqueado por approvals
    └──────────┬────────────┘
               │ sí
               ▼
    ┌───────────────────────┐
    │ Maintainer hace merge │
    └───────────────────────┘
```

El pipeline y las approvals son **puertas en serie**: ambas deben estar verdes.
