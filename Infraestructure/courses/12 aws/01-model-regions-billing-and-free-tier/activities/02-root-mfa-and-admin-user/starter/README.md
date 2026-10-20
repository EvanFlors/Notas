# Starter — aws-01-02-root-mfa-and-admin-user

## Pasos

```bash
mkdir -p /tmp/aws-01-root-mfa
cd /tmp/aws-01-root-mfa
touch ADR-001-root-blindado.md CHECKLIST.md
```

## Esqueleto `ADR-001-root-blindado.md`

```markdown
# ADR 001 — Blindaje del root y creacion del admin no-root

## Status
Accepted — 2026-10-16

## Context
Cuenta nueva 123456789012. Sin MFA, sin admin, sin budget. Riesgos: ...

## Decision
1. MFA en root (TOTP).
2. Admin humano via <IAM Identity Center | IAM user>.
3. Cero access keys en root.
4. Budget con alerta.

## Alternatives considered
- A: no MFA (riesgo X)
- B: access keys en root (anti-patron)
- C: IAM user vs Identity Center

## Consequences
- Positivas: ...
- Negativas: ...

## Vectores de ataque mitigados
1. Credential stuffing contra email root.
2. Phishing del password root.
3. Dump publico del password manager comprometido.

## Blast radius: root comprometido sin MFA
- Attacker crea access keys ilimitadas y las lleva a su infra.
- ...
```

## Esqueleto `CHECKLIST.md`

```markdown
# Checklist de blindaje de root

Ejecutado por: Alice Example
Fecha: 2026-10-16
Cuenta objetivo: 123456789012

- [x] MFA activado en root (TOTP, seed guardado offline)
- [x] Access keys de root inexistentes / borradas
- [x] IAM access to Billing habilitado
- [x] Budget 20 USD/mes creado con alerta email
- [x] Admin humano no-root creado con MFA
- [x] Sesion de root cerrada
- [x] CloudTrail multi-region activo

## Evidencia (simulada)

` ` `json
{
    "Account": "123456789012",
    "Arn": "arn:aws:sts::123456789012:assumed-role/AWSReservedSSO_AdministratorAccess_xxxx/alice"
}
` ` `
```
