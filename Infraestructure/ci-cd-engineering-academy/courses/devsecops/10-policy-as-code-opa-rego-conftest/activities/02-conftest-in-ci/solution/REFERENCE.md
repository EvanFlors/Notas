# REFERENCE — sec-10-02-conftest-in-ci

> Modelo de referencia. **No es la única respuesta correcta** — es una contra la que compararte.

## `inputs/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:latest     # violación 1 (:latest)
          # resources no definido  # violación 2 (sin memory limit)
```

## `inputs/plan.json`

```json
{
  "format_version": "1.2",
  "terraform_version": "1.7.0",
  "planned_values": {
    "root_module": {
      "resources": [
        {
          "address": "aws_security_group.ssh_open",
          "type": "aws_security_group",
          "values": {
            "ingress": [
              {
                "from_port": 22,
                "to_port": 22,
                "protocol": "tcp",
                "cidr_blocks": ["0.0.0.0/0"]
              }
            ]
          }
        }
      ]
    }
  }
}
```

## `policy/k8s/deployment.rego`

```rego
package k8s.deployment

import rego.v1

deny contains msg if {
    input.kind == "Deployment"
    some c in input.spec.template.spec.containers
    endswith(c.image, ":latest")
    msg := sprintf("container %q in Deployment %q uses forbidden :latest tag",
                   [c.name, input.metadata.name])
}

deny contains msg if {
    input.kind == "Deployment"
    some c in input.spec.template.spec.containers
    not c.resources.limits.memory
    msg := sprintf("container %q in Deployment %q has no memory limit",
                   [c.name, input.metadata.name])
}
```

## `policy/terraform/sg.rego`

```rego
package terraform.sg

import rego.v1

deny contains msg if {
    some r in input.planned_values.root_module.resources
    r.type == "aws_security_group"
    some ing in r.values.ingress
    "0.0.0.0/0" in ing.cidr_blocks
    msg := sprintf("SG %q allows %d/%s from 0.0.0.0/0",
                   [r.address, ing.from_port, ing.protocol])
}
```

## `run-conftest.sh`

```bash
#!/usr/bin/env bash
# CI-equivalent wrapper. Runs Conftest over inputs/ with policies in policy/,
# exits 1 if any `deny` is produced, 0 otherwise.
#
# Note: we deliberately do NOT enable `set -o pipefail` because downstream
# compositions with `grep -q` or `head` can produce SIGPIPE (exit 141) that
# pipefail would spuriously treat as failures.
set -eu

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if ! command -v conftest >/dev/null 2>&1; then
    echo "SKIP: conftest not installed — install from https://www.conftest.dev/install/"
    echo "      Structural checks still valid; this wrapper simply has nothing to run."
    exit 0
fi

echo "== Running conftest test (all namespaces) =="
rc=0
conftest test --all-namespaces --policy policy/ inputs/*.yaml inputs/*.json || rc=$?

echo
echo "== Conftest wrapper done =="
if [ "$rc" -ne 0 ]; then
    echo "RESULT: policy violations found (exit $rc)."
    exit "$rc"
fi
echo "RESULT: no policy violations."
exit 0
```

Permisos:

```bash
chmod +x run-conftest.sh
```

## Ejecución esperada

```bash
$ ./run-conftest.sh
== Running conftest test (all namespaces) ==
FAIL - inputs/deployment.yaml - k8s.deployment - container "nginx" in Deployment "web" uses forbidden :latest tag
FAIL - inputs/deployment.yaml - k8s.deployment - container "nginx" in Deployment "web" has no memory limit
FAIL - inputs/plan.json - terraform.sg - SG "aws_security_group.ssh_open" allows 22/tcp from 0.0.0.0/0

3 tests, 0 passed, 0 warnings, 3 failures, 0 exceptions

== Conftest wrapper done ==
RESULT: policy violations found (exit 1).
$ echo $?
1
```

Si `conftest` **no** está instalado:

```bash
$ ./run-conftest.sh
SKIP: conftest not installed — install from https://www.conftest.dev/install/
      Structural checks still valid; this wrapper simply has nothing to run.
$ echo $?
0
```

## Notas de diseño

1. **`--all-namespaces`** es necesario porque tenemos `package k8s.deployment` **y** `package terraform.sg`. Sin este flag, Conftest solo evalúa `main` por defecto.
2. **No `set -o pipefail`** — ver comentario inline. Es el mismo motivo que `tests/validate.sh` lleva en todos los módulos.
3. **El SKIP gracioso con exit 0** permite que CI sin conftest no bloquee el pipeline. Alternativa estricta: `exit 2` ("missing tool"), que invita a provisionar la herramienta.
4. **Propagar el exit code real de conftest** (`rc=$?`) en vez de `exit 1` directo preserva información (p. ej. conftest también sale 2 ante errores de sintaxis Rego).
5. **Para producción real** se añadirían: `--output=sarif` (formato estándar para GitHub Code Scanning), reporte JUnit para test runners, y configuración de qué `warn` ignorar vía `.conftest.yaml`.
