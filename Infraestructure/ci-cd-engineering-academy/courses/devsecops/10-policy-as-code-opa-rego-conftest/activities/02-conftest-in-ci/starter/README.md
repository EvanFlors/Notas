# Starter — sec-10-02-conftest-in-ci

No hay plantilla a copiar: todo lo escribes tú. Pasos:

1. Lee `../README.md` completo.
2. Prepara el árbol de directorios:
   ```bash
   mkdir -p /tmp/sec-10-02-conftest-ci/{inputs,policy/k8s,policy/terraform}
   cd /tmp/sec-10-02-conftest-ci
   ```
3. Crea los **dos fixtures** (`inputs/deployment.yaml` y `inputs/plan.json`), cada uno con **al menos una violación** (ver §5.2 del README). Puedes basarte en los ejemplos `01` y `02` del módulo.
4. Crea las **dos policies** (`policy/k8s/deployment.rego`, `policy/terraform/sg.rego`), cada una con `import rego.v1` + al menos **1** `deny` (ver §5.3).
5. Crea `run-conftest.sh` en la raíz con `set -eu`, SKIP gracioso si falta `conftest`, invocación con `--all-namespaces`, y propagación del exit code (ver §5.4). Hazlo ejecutable: `chmod +x run-conftest.sh`.
6. Ejecuta `./run-conftest.sh` localmente.
7. Valida:
   ```bash
   bash <ruta-repo>/courses/devsecops/10-policy-as-code-opa-rego-conftest/activities/02-conftest-in-ci/tests/validate.sh /tmp/sec-10-02-conftest-ci
   ```
8. Compara con `../solution/REFERENCE.md`.
