#!/usr/bin/env bash
# Structural validation for plat-05-01-model-capstone-in-catalog.
# Walks a directory tree, collects every catalog-info.yaml, and runs a
# Python+PyYAML inspector that enforces the module's structural minimums:
#   - counts per kind (>=3 Components, >=2 APIs, >=1 Resource, 1 System,
#     1 Domain, >=2 Groups)
#   - every Component has >=2 annotations
#   - every Component's owner (group:X) resolves to a declared Group
#   - every providesApis/consumesApis target resolves to a declared API
#   - every dependsOn target of 'resource:X' or 'component:X' resolves
#
# Note: we deliberately do NOT enable `set -o pipefail` because many checks
# use `... | grep -q ...` which can produce SIGPIPE (exit 141) when grep
# finds a match early. pipefail would spuriously mark those as failures.
#
# Does NOT grade semantic correctness — compare manually with
# solution/REFERENCE.md.

set -eu

BASE="${1:-/tmp/plat-05-catalog}"
echo "== Structural validation for $BASE =="

if [ ! -d "$BASE" ]; then
  echo "FAIL: $BASE does not exist. Create it and populate catalog-info.yaml files."
  exit 1
fi

# Soft dependency: python3 + pyyaml. SKIP gracefully if either is missing.
if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 is not available on PATH."
  echo "      Install python3 >= 3.9 and re-run."
  exit 0
fi
if ! python3 -c "import yaml" >/dev/null 2>&1; then
  echo "SKIP: python3 is available but PyYAML is not installed."
  echo "      Install it with:  pip3 install pyyaml"
  exit 0
fi

# Find candidate files; abort cleanly if none.
files_count=$(find "$BASE" -type f -name 'catalog-info.yaml' | wc -l | tr -d ' ')
if [ "$files_count" -eq 0 ]; then
  echo "FAIL: no catalog-info.yaml files found under $BASE."
  echo "      Expected at least one per Component, plus a central file for System/Domain/Groups/Resources."
  exit 1
fi

echo "  Found $files_count catalog-info.yaml file(s). Delegating to inspector..."
echo

python3 - "$BASE" <<'PY'
import glob
import os
import sys
import yaml

base = sys.argv[1]
pattern = os.path.join(base, "**", "catalog-info.yaml")
files = sorted(glob.glob(pattern, recursive=True))

errors: list[str] = []
oks: list[str] = []

# Collect every entity across every file.
by_kind: dict[str, dict[str, dict]] = {
    "Component": {}, "API": {}, "Resource": {},
    "System": {}, "Domain": {}, "Group": {}, "User": {}, "Location": {},
}

for path in files:
    try:
        docs = list(yaml.safe_load_all(open(path, "r")))
    except yaml.YAMLError as exc:
        errors.append(f"{path}: invalid YAML: {exc}")
        continue

    for i, doc in enumerate(docs):
        if doc is None:
            continue
        if not isinstance(doc, dict):
            errors.append(f"{path}[doc {i}]: top-level must be a mapping")
            continue
        kind = doc.get("kind")
        meta = doc.get("metadata") or {}
        name = meta.get("name")
        if not kind or not name:
            errors.append(f"{path}[doc {i}]: missing kind or metadata.name")
            continue
        if kind not in by_kind:
            errors.append(f"{path}[doc {i}]: unknown kind '{kind}'")
            continue
        if name in by_kind[kind]:
            errors.append(f"{path}[doc {i}]: duplicate {kind} name '{name}' "
                          f"(also in {by_kind[kind][name]['_path']})")
            continue
        doc["_path"] = path
        by_kind[kind][name] = doc

# Count checks.
required = {"Component": 3, "API": 2, "Resource": 1,
            "System": 1, "Domain": 1, "Group": 2}
for kind, minimum in required.items():
    got = len(by_kind[kind])
    if got >= minimum:
        oks.append(f"OK   {kind}: {got} (>= {minimum})")
    else:
        errors.append(f"FAIL {kind}: {got} (expected >= {minimum})")

# Resolve references.
groups = set(by_kind["Group"].keys())
apis = set(by_kind["API"].keys())
components = set(by_kind["Component"].keys())
resources = set(by_kind["Resource"].keys())

provides_total = 0
consumes_or_depends_total = 0

for name, comp in by_kind["Component"].items():
    spec = comp.get("spec") or {}
    meta = comp.get("metadata") or {}

    # 2+ annotations per Component.
    annotations = (meta.get("annotations") or {})
    if isinstance(annotations, dict) and len(annotations) >= 2:
        oks.append(f"OK   Component '{name}': {len(annotations)} annotations")
    else:
        n = len(annotations) if isinstance(annotations, dict) else 0
        errors.append(f"FAIL Component '{name}': {n} annotations (expected >= 2)")

    # Owner resolves to a declared Group.
    owner = spec.get("owner") or ""
    if isinstance(owner, str) and owner.startswith("group:"):
        gname = owner.split(":", 1)[1]
        if gname in groups:
            oks.append(f"OK   Component '{name}' owner '{owner}' resolves")
        else:
            errors.append(f"FAIL Component '{name}' owner '{owner}' not declared as a Group")
    else:
        errors.append(f"FAIL Component '{name}' owner must be 'group:...' (got '{owner}')")

    # providesApis targets resolve to declared APIs.
    for ap in (spec.get("providesApis") or []):
        provides_total += 1
        if ap not in apis:
            errors.append(f"FAIL Component '{name}' providesApis '{ap}' not declared as API")

    # consumesApis targets resolve to declared APIs.
    for ap in (spec.get("consumesApis") or []):
        consumes_or_depends_total += 1
        if ap not in apis:
            errors.append(f"FAIL Component '{name}' consumesApis '{ap}' not declared as API")

    # dependsOn targets of resource:X or component:X resolve.
    for dep in (spec.get("dependsOn") or []):
        consumes_or_depends_total += 1
        if isinstance(dep, str) and ":" in dep:
            dkind, dname = dep.split(":", 1)
            if dkind == "resource" and dname not in resources:
                errors.append(f"FAIL Component '{name}' dependsOn 'resource:{dname}' not declared")
            elif dkind == "component" and dname not in components:
                errors.append(f"FAIL Component '{name}' dependsOn 'component:{dname}' not declared")

# At least one Component declares providesApis.
if provides_total >= 1:
    oks.append(f"OK   at least 1 providesApis declared ({provides_total} total)")
else:
    errors.append("FAIL no Component declares providesApis to a declared API")

# At least one Component declares consumesApis or dependsOn (resolved).
if consumes_or_depends_total >= 1:
    oks.append(f"OK   at least 1 consumesApis/dependsOn declared ({consumes_or_depends_total} total)")
else:
    errors.append("FAIL no Component declares consumesApis nor dependsOn to a declared entity")

for line in oks:
    print(f"  {line}")
print()
for line in errors:
    print(f"  {line}")

print()
if errors:
    print(f"RESULT: {len(errors)} structural check(s) failed.")
    print("        (Semantic correctness is YOUR responsibility — compare with solution/REFERENCE.md.)")
    sys.exit(1)
print("OK: estructura valida. Compara tu arbol con solution/REFERENCE.md para autoevaluarte.")
sys.exit(0)
PY
