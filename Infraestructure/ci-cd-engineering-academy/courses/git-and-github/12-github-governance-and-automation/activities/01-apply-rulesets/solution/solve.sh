#!/usr/bin/env bash
# Reference solution: populate ruleset-main.json and DECISION.md.
set -eu

DEST="${1:-/tmp/apply-rulesets}"
if [ ! -d "$DEST" ]; then
  echo "Run starter/build-scratch.sh first: scratch dir $DEST missing" >&2
  exit 1
fi

cat > "$DEST/ruleset-main.json" <<'EOF'
{
  "name": "protect-main",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "required_linear_history" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": true,
        "required_review_thread_resolution": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "ci/build", "integration_id": null },
          { "context": "ci/test",  "integration_id": null }
        ]
      }
    }
  ],
  "bypass_actors": []
}
EOF

cat > "$DEST/DECISION.md" <<'EOF'
# Decisiones del ruleset `protect-main`

- **`bypass_actors: []`**: queremos que la ruleset sea auténtica — cualquier
  excepción pasa por un cambio en la propia ruleset, auditable en git y en
  audit log, no por una lista silenciosa de "admins que pueden saltarse".
- **`require_last_push_approval: true`**: evita que una approval previa
  "cubra" un cambio incorporado después. Sin esto, un atacante con write
  podría pushear cambios sensibles tras aprobación legítima.
- **`dismiss_stale_reviews_on_push: true`**: coherente con lo anterior; las
  approvals se evalúan contra el estado final mergeado, no uno viejo.
- **Status checks `ci/build` y `ci/test` estrictos**: la rama debe estar
  up-to-date respecto a main antes del merge; combinable con una merge
  queue si el throughput lo requiere.
- **`required_linear_history`**: facilita bisect y revert; el equipo acordó
  trunk-based con squash-merge, así que no perdemos nada.
- **No activamos `required_signatures` todavía** porque el onboarding de
  firmas aún no está cerrado; está planeado para la próxima iteración.
EOF

echo "OK: solved at $DEST"
