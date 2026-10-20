# Recursos — sec-10

Referencias oficiales. **Verificar en Fase 4** del curso (sintaxis Rego ha evolucionado: `rego.v1` es la forma recomendada actual).

## OPA / Rego

- **Sitio oficial OPA**: `https://www.openpolicyagent.org/`
- **Documentación Rego**: `https://www.openpolicyagent.org/docs/latest/policy-language/`
- **Rego Playground** (prueba online): `https://play.openpolicyagent.org/`
- **`import rego.v1`** (modern syntax): `https://www.openpolicyagent.org/docs/latest/opa-1/`
- **Testing Rego** (`opa test`): `https://www.openpolicyagent.org/docs/latest/policy-testing/`
- **Built-ins**: `https://www.openpolicyagent.org/docs/latest/policy-reference/`

## Conftest

- **Repo + docs**: `https://www.conftest.dev/` y `https://github.com/open-policy-agent/conftest`
- **Install**: binarios en releases o `brew install conftest`.
- **Convenciones `deny` / `warn` / `violation`**: `https://www.conftest.dev/writing/`
- **`conftest verify`**: `https://www.conftest.dev/verify/`

## Casos de uso canónicos

- **K8s manifests**: `https://www.conftest.dev/examples/` (apartado kubernetes).
- **Terraform plan JSON**: generar con `terraform show -json plan.out`.
- **Dockerfile**: Conftest parser nativo.

## Alternativas / contexto

- **Checkov**: `https://www.checkov.io/`
- **tfsec**: `https://github.com/aquasecurity/tfsec`
- **Terrascan**: `https://runterrascan.io/`
- **Kyverno** (próximo módulo): `https://kyverno.io/`
- **OPA Gatekeeper**: `https://open-policy-agent.github.io/gatekeeper/`
- **HashiCorp Sentinel**: `https://www.hashicorp.com/sentinel`
- **Cedar (AWS)**: `https://www.cedarpolicy.com/`

## Lecturas recomendadas

- "Policy as Code: Fundamentals" — OPA blog (ver docs).
- CNCF whitepaper on Policy as Code (buscar "CNCF Policy WG").
- Styra blog (empresa detrás de OPA) — ejemplos reales de Rego: `https://www.styra.com/blog/`

## Instalación local (para los examples/activities)

- **OPA**: `brew install opa` (macOS) o descargar binario de `https://github.com/open-policy-agent/opa/releases`.
- **Conftest**: `brew install conftest` o descargar de `https://github.com/open-policy-agent/conftest/releases`.

Si no están instalados, los validadores de este módulo **saltan con gracia** y solo chequean estructura.

## Checklist de verificación requerida en Fase 4

- Versión mínima de OPA que soporta `import rego.v1` (actualmente ≥ 0.59).
- Comando `terraform show -json` sigue siendo el canonical para plans.
- Estado de `violation[{"msg": ..., "details": ...}]` en Gatekeeper vs `deny[msg]` en Conftest.
- Si Conftest ha añadido parsers nuevos (p. ej. CloudFormation nativo).
