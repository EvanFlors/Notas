#!/usr/bin/env bash
# Reference solution: writes a complete ADR to /tmp/adr-identity/ADR.md.
set -eu
DEST="${1:-/tmp/adr-identity}"
if [ ! -d "$DEST" ]; then
  echo "Run starter/build-scratch.sh first ($DEST missing)" >&2; exit 1
fi

cat > "$DEST/ADR.md" <<'EOF'
# ADR: Identity for the PR-labeling / deploy-status / S3-upload bot

- **Status:** accepted
- **Date:** 2026-01-15
- **Deciders:** platform-sre team

## Context

Operamos una org GitHub Enterprise con ~40 repos. Un bot debe cubrir tres
responsabilidades que mezclan **actuar sobre GitHub** (etiquetar PRs,
actualizar comentarios con el estado de deploy) y **actuar sobre AWS**
(subir artefactos a S3 tras merge). Compliance exige que ninguna credencial
dure más de 90 días, que la rotación sea trazable extremo a extremo, y que
el audit log cubra las acciones cross-org. Hoy existe un PAT classic
compartido en Vault — es exactamente el antipatrón que queremos retirar.

## Decision

Adoptamos una **composición** de dos identidades:

1. **GitHub App** (`pr-labeler-and-status-bot`) instalada en la org para
   todos los repos en scope. Permisos: `pull_requests: write`,
   `issues: write`, `metadata: read`, `checks: read`. Autenticación via
   JWT firmado con RSA privada almacenada en Vault; el workflow obtiene
   un **installation token de 1 h** en runtime.
2. **OIDC federation** desde GitHub Actions hacia un role IAM
   `gha-upload-artifacts-prod` en AWS. El trust policy restringe
   `sub` a `repo:example-org/<repo>:environment:production`, de forma que
   sólo workflows ejecutándose en el environment aprobado pueden asumirlo.
   Credenciales de 15 min, sin secretos long-lived.

PATs quedan prohibidos para esta automatización.

## Consequences

### Positive

- **TTL mínimo**: installation token 1 h, STS 15 min. Un leak cualquiera
  caduca antes del próximo café.
- **Blast radius reducido**: permisos declarados por manifiesto de la App;
  OIDC restringido por `sub` por repo y environment.
- **Auditabilidad real**: las acciones de la App se atribuyen a su slug
  (no a un humano), y los `AssumeRoleWithWebIdentity` quedan en CloudTrail
  con `role-session-name` que lleva `run_id`.
- **Operabilidad**: rotar la App implica rotar su RSA key (una vez), no
  40 secrets duplicados.

### Negative

- Setup inicial de la App (manifest + webhook URL + private key en Vault)
  es más caro que generar un PAT. **Mitigación**: template reproducible
  en IaC + runbook corto.
- Debug de permisos de App puede ser frustrante al principio. **Mitigación**:
  log explícito del endpoint fallido + tabla de permisos vs endpoints.

## Alternatives considered

### PAT classic

Rejected: scopes demasiado amplios, duración ilimitada, atado a un humano
(cuando se va, se filtra con él), y es exactamente lo que el compliance
quiere matar.

### PAT fine-grained

Rejected para producción: aunque los scopes son granulares, siguen atados
a un usuario, con máximo 1 año de duración. Lo seguimos permitiendo para
scripts personales de developers, documentado aparte. Why not aquí: el
bot productivo no debe depender de la cuenta de nadie.

### Shared IAM access key stored in Vault

Discarded: credencial estática que viaja por secrets de Actions. Rompe
el requisito de "no credential > 90 days" salvo rotación agresiva que
nadie va a sostener en el tiempo. OIDC lo reemplaza sin pérdidas.

### GitHub App emitiendo credenciales de AWS

Discarded por complejidad innecesaria: OIDC resuelve el mismo problema
sin reinventar un broker.

## Compliance mapping

| Requirement | How this decision satisfies it |
|-------------|--------------------------------|
| No credentials > 90 days | Installation token 1 h; AWS STS 15 min; RSA key rotable por operación |
| Auditable rotation | Rotación de la RSA key queda en Vault audit log + GitHub App events; rotación del OIDC provider thumbprint cambia en IaC con PR trazable |
| Cross-org audit log | GitHub Enterprise audit log cubre acciones de la App; CloudTrail cubre uso del role; ambos se exportan al SIEM corporativo |

## Follow-ups

- (sre) Automatizar rotación trimestral de la RSA key de la App (Q+1).
- (sre) Añadir alerta en SIEM si `AssumeRoleWithWebIdentity` del role llega
  desde un `sub` distinto al permitido (defensa en profundidad).
- (platform) Deprecate del PAT classic actual: notice 30 días,
  revocación forzada tras.
EOF

echo "OK: ADR written to $DEST/ADR.md"
