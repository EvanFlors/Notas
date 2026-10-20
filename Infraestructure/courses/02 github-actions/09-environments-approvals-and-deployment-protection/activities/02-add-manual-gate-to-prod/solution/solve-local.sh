#!/usr/bin/env bash
# Reference solution for gha-09-02-add-manual-gate-to-prod in MODE=local.
set -euo pipefail

BASE="${1:-/tmp/gha09-manual-gate}"
HERE="$(cd "$(dirname "$0")" && pwd)"

MODE=local bash "$HERE/../starter/bootstrap.sh" "$BASE"

# Workflow intentionally untouched.

cat > "$BASE/environment-prod.yaml" <<'EOF'
name: prod
wait_timer: 10
prevent_self_review: true
reviewers:
  - type: Team
    slug: release-managers
  - type: Team
    slug: platform-sre
  - type: User
    login: on-call-lead
deployment_branch_policy:
  protected_branches: false
  custom_branch_policies: true
  patterns:
    - refs/heads/main
    - refs/heads/hotfix/*
EOF

cat > "$BASE/DECISION.md" <<'EOF'
# Decision — approvals policy para `prod`

Reviewers son dos **teams** (`release-managers`, `platform-sre`) y un fallback
individual (`on-call-lead`). Usar teams nos protege contra vacaciones y rotación
de personas: a lo largo del tiempo el equipo cambia, el team persiste.

`prevent_self_review: true` evita que el autor del commit se auto-apruebe
(rubber stamp). Esto es especialmente importante con bots como Dependabot o
`release-please` que podrían figurar como `github.actor`.

Dos teams en lugar de uno porque el bus factor con un solo team pequeño sigue
siendo frágil durante incidentes multi-equipo. Añadir un tercer reviewer humano
sería contraproducente: aumentaría la fatiga sin reducir riesgo material.

`wait_timer: 10` da espacio para cancelar un deploy equivocado observando el
PR mergeado, los dashboards de pre-deploy y las alertas de síntesis. No es
"revisión" automática — es un cool-off humano.

Branch policy `custom_branch_policies: true` con `refs/heads/main` y
`refs/heads/hotfix/*`. Lo primero cubre el flujo normal; lo segundo deja la
puerta abierta a los hotfix urgentes sin tener que relajar la policy en caliente.

**On-call 3am del sábado**: la persona on-call pertenece a `platform-sre`;
puede aprobar su propio hotfix siempre que no sea quien hizo el commit
(`prevent_self_review`). Si lo escribió ella, otro miembro del team on-call
(secundario de PagerDuty) aprueba. El wait_timer de 10 minutos es aceptable
para incidencias no-Sev-1; para Sev-1 lo asumimos conscientemente.

Lo que queda fuera (y por qué): no usamos *custom protection rules* via Apps
porque no tenemos la infraestructura para operar la App. El día que
necesitemos "no desplegar durante ventana PCI" lo añadiremos.
EOF

echo
echo "== Solution written to $BASE =="
echo "Running validator (MODE=local):"
echo
bash "$HERE/../tests/validate.sh" "$BASE"
