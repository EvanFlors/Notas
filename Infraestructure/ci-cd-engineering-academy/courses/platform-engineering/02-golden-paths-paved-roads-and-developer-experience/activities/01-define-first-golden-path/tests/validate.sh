#!/usr/bin/env bash
# Structural validation for plat-02-01-define-first-golden-path.
# Checks that CANVAS.md exists and contains the 8 required sections,
# numeric DX metrics, long tail, owner, antipatterns and canonical path vocabulary.
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/plat-02-golden-path}"
DOC="$BASE/CANVAS.md"
fail=0

echo "== Structural validation for $BASE =="

if [ ! -f "$DOC" ]; then
  echo "FAIL: $DOC does not exist. Student must produce it."
  exit 1
fi

# Required 8 sections (by number).
required_sections=(
  "Caso de uso"
  "Usuarios"
  "Alcance"
  "Criterios"
  "M[ée]tricas"
  "Long tail|Long-tail"
  "Owner"
  "Riesgos|Antipatterns"
)

idx=1
for pattern in "${required_sections[@]}"; do
  if grep -qiE "^#+ *${idx}\. *(${pattern})" "$DOC"; then
    echo "  OK   section ${idx} present"
  else
    echo "  FAIL section ${idx} ('${pattern}') missing or not numbered"
    fail=$((fail+1))
  fi
  idx=$((idx+1))
done

# Must mention Python microservice (case use focus).
if grep -qiE 'python' "$DOC"; then
  echo "  OK   mentions Python"
else
  echo "  FAIL does not mention Python"
  fail=$((fail+1))
fi

# Must mention microservicio / microservice.
if grep -qiE 'microservic'  "$DOC"; then
  echo "  OK   mentions microservicio/microservice"
else
  echo "  FAIL does not mention microservicio"
  fail=$((fail+1))
fi

# Must list at least 3 DX metrics tokens.
metrics_found=0
for m in "time-to-production" "time to production" "ttp" "time-to-first-commit" \
         "nps" "adopci[óo]n" "adoption" "error rate" "tasa de error" "mttr" \
         "lead time" "deploy frequency"; do
  if grep -qiE "$m" "$DOC"; then
    metrics_found=$((metrics_found+1))
  fi
done
if [ "$metrics_found" -ge 3 ]; then
  echo "  OK   names at least 3 DX metrics ($metrics_found found)"
else
  echo "  FAIL names only $metrics_found DX metrics (expected >=3)"
  fail=$((fail+1))
fi

# Metrics section must include at least one numeric target (% or < N or digit).
if grep -qiE '([0-9]+ *%|p50|< *[0-9]|>=? *[0-9]|&ge;|&lt;)' "$DOC"; then
  echo "  OK   metrics include numeric targets"
else
  echo "  FAIL metrics without numeric targets"
  fail=$((fail+1))
fi

# Must mention long tail posture vocabulary.
if grep -qiE 'opci[óo]n b|option b|mandato|no soportad|fuera de scope|fuera-de-scope|off[- ]?road' "$DOC"; then
  echo "  OK   long tail posture named"
else
  echo "  FAIL long tail posture not named"
  fail=$((fail+1))
fi

# Must mention at least 2 scope items (CI, observabilidad, catalog, helm, scaffolding, gitops).
scope_hits=0
for s in "scaffolding" "ci\b" "observabilidad" "observability" "cat[áa]logo" "catalog" \
         "helm" "gitops" "argo" "chart" "prometheus" "otel" "opentelemetry"; do
  if grep -qiE "$s" "$DOC"; then
    scope_hits=$((scope_hits+1))
  fi
done
if [ "$scope_hits" -ge 3 ]; then
  echo "  OK   scope lists at least 3 canonical pieces ($scope_hits found)"
else
  echo "  FAIL scope lists only $scope_hits canonical pieces (expected >=3)"
  fail=$((fail+1))
fi

# Owner must be a concrete person (name + role) or at least rol/DRI/Lead marker.
if grep -qiE 'owner.*(:|-).*(lead|dri|platform|ingenier|engineer|sre|arquitect)' "$DOC"; then
  echo "  OK   owner section names role / DRI"
else
  echo "  FAIL owner section without role/DRI"
  fail=$((fail+1))
fi

# Must mention versionado/semver and deprecation.
if grep -qiE 'semver|versionad|versioning' "$DOC"; then
  echo "  OK   mentions versioning / SemVer"
else
  echo "  FAIL does not mention versioning / SemVer"
  fail=$((fail+1))
fi
if grep -qiE 'deprecat' "$DOC"; then
  echo "  OK   mentions deprecation policy"
else
  echo "  FAIL does not mention deprecation policy"
  fail=$((fail+1))
fi

# Risks section must enumerate at least 3 numbered or bulleted items.
risks_count=$(awk '/^#+ *8\./,0' "$DOC" | grep -cE '^[[:space:]]*([0-9]+\.|[-*]) ' || true)
if [ "$risks_count" -ge 3 ]; then
  echo "  OK   risks section lists at least 3 items ($risks_count found)"
else
  echo "  FAIL risks section lists only $risks_count items (expected >=3)"
  fail=$((fail+1))
fi

# Must mention at least one antipattern keyword.
if grep -qiE 'golden cage|en papel|mandato prematuro|m[ée]trica [úu]nica|long tail despreciad|sin owner|golden path universal|antipattern'  "$DOC"; then
  echo "  OK   names at least one antipattern"
else
  echo "  FAIL no antipattern named"
  fail=$((fail+1))
fi

echo
if [ "$fail" -gt 0 ]; then
  echo "RESULT: $fail structural check(s) failed."
  echo "        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)"
  exit 1
fi
echo "OK: estructura valida. Compara CANVAS.md con solution/REFERENCE.md para autoevaluarte."
exit 0
