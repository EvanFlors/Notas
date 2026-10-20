#!/usr/bin/env bash
# check-jcasc.sh — validación estructural de un jenkins.yaml (JCasC).
# No requiere Jenkins. Usa python3+pyyaml para parsear.
#
# Uso:  bash check-jcasc.sh path/to/jenkins.yaml
#
# Reglas verificadas (ver EXAM.md § OP-task-2):
#   J1  YAML parseable.
#   J2  jenkins.securityRealm existe y NO es 'unsecured'.
#   J3  jenkins.authorizationStrategy es roleBased | projectMatrix (prohibidos
#       loggedInUsersCanDoAnything, unsecured).
#   J4  jenkins.remotingSecurity.enabled == true.
#   J5  credentials: existe y NO contiene valores literales obvios de secreto.
#   J6  unclassified.globalLibraries declara 'platform-lib' con defaultVersion
#       pinneada (no 'master'/'main').
#   J7  jobs: define al menos un pipelineJob o multibranchPipelineJob.

set -u

FILE="${1:-}"
if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "ERROR: pasa el path al jenkins.yaml como primer argumento." >&2
  exit 2
fi

python3 - "$FILE" <<'PY'
import re
import sys

try:
    import yaml
except Exception:
    print("ERROR: pyyaml no está instalado. Ejecuta: pip3 install pyyaml", file=sys.stderr)
    sys.exit(2)

path = sys.argv[1]
pass_n = 0
fail_n = 0

def check(name, ok, hint=""):
    global pass_n, fail_n
    if ok:
        print(f"PASS  {name}")
        pass_n += 1
    else:
        print(f"FAIL  {name}  -- {hint}")
        fail_n += 1

# J1 parseable
try:
    with open(path) as f:
        raw = f.read()
    data = yaml.safe_load(raw) or {}
    check("J1 YAML parseable", True)
except Exception as e:
    check("J1 YAML parseable", False, f"error: {e}")
    print("\nResultado: 0 pass, 1 fail")
    sys.exit(1)

jenkins = (data.get("jenkins") or {}) if isinstance(data, dict) else {}

# J2 securityRealm presente y no unsecured
sr = jenkins.get("securityRealm")
sr_ok = sr is not None and sr != "unsecured" and (
    isinstance(sr, dict) or isinstance(sr, str)
)
if isinstance(sr, dict) and "local" in sr:
    local = sr.get("local") or {}
    users = local.get("users") or []
    sr_ok = sr_ok and len(users) >= 1
check("J2 jenkins.securityRealm declarado (no 'unsecured')", bool(sr_ok),
      "Define securityRealm (local con usuarios declarados, ldap, oic, o saml).")

# J3 authorizationStrategy
az = jenkins.get("authorizationStrategy")
az_ok = False
az_kind = None
if isinstance(az, dict):
    for k in az.keys():
        az_kind = k
        if k in ("roleBased", "projectMatrix"):
            az_ok = True
            break
elif isinstance(az, str):
    az_kind = az
check("J3 authorizationStrategy roleBased | projectMatrix",
      bool(az_ok),
      f"authorizationStrategy actual: {az_kind!r}. "
      "Prohibido loggedInUsersCanDoAnything o unsecured.")

# J4 remotingSecurity enabled
rs = jenkins.get("remotingSecurity") or {}
check("J4 jenkins.remotingSecurity.enabled: true",
      bool(rs.get("enabled") is True),
      "Añade jenkins.remotingSecurity.enabled: true.")

# J5 credentials sin literales
creds = data.get("credentials")
leaked = []
suspect_keys = {"secret", "password", "token", "privateKeySource", "privateKey", "apiKey"}
def walk(node, path="credentials"):
    if isinstance(node, dict):
        for k, v in node.items():
            if k in suspect_keys and isinstance(v, str):
                if not re.search(r"\$\{[^}]+\}", v) and v.strip() not in ("", "CHANGEME"):
                    # ¿parece un literal real? (más de 6 chars y sin placeholder)
                    if len(v) >= 6 and not v.startswith("${"):
                        leaked.append(f"{path}.{k} = {v[:12]}...")
            walk(v, f"{path}.{k}")
    elif isinstance(node, list):
        for i, item in enumerate(node):
            walk(item, f"{path}[{i}]")
if creds is not None:
    walk(creds)
check("J5 credentials sin valores literales (usar ${VAR} o placeholders)",
      creds is not None and not leaked,
      f"Credenciales declaradas: {creds is not None}. Literales detectados: {leaked or 'ninguno'}.")

# J6 globalLibraries pinneada
unclassified = data.get("unclassified") or {}
gl = (unclassified.get("globalLibraries") or {}).get("libraries") or []
gl_ok = False
reason = "No se encontró 'platform-lib' en unclassified.globalLibraries.libraries"
for lib in gl:
    if (lib or {}).get("name") == "platform-lib":
        dv = lib.get("defaultVersion", "")
        if dv and dv not in ("master", "main"):
            gl_ok = True
            reason = ""
        else:
            reason = f"platform-lib.defaultVersion = {dv!r} (debe ser un tag/sha, no master/main)."
        break
check("J6 globalLibraries.platform-lib pinneada por tag/sha", gl_ok, reason)

# J7 jobs seed
jobs = data.get("jobs") or []
has_seed = False
for j in jobs:
    if isinstance(j, dict) and "script" in j:
        has_seed = True
        break
    if isinstance(j, dict) and any(k in j for k in ("pipelineJob", "multibranchPipelineJob")):
        has_seed = True
        break
# jobs puede venir como lista de dicts con 'script:' (Job DSL) o referencias
check("J7 jobs: con pipelineJob/multibranchPipelineJob/script seed",
      bool(has_seed),
      "Añade al menos un job seed en 'jobs:' (Job DSL script o pipelineJob).")

print(f"\nResultado: {pass_n} pass, {fail_n} fail")
sys.exit(0 if fail_n == 0 else 1)
PY
