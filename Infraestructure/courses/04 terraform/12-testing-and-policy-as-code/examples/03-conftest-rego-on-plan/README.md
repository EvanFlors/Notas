# Ejemplo 03 — Conftest + Rego sobre `terraform show -json`

## Concepto que demuestra

Cómo evaluar **el plan JSON** (no el HCL) con una policy Rego. Esto captura violaciones que los scanners estáticos no ven, porque trabaja sobre atributos **ya resueltos** por Terraform.

## Prerrequisitos

- `terraform` ≥ 1.6 (opcional en este ejemplo: ya se incluye un `plan.json` precomputado).
- `conftest` ≥ 0.46.

## Archivos

- `main.tf` — stack con una regla SG que abre SSH al mundo (ingress 0.0.0.0/0:22).
- `policy/sg.rego` — regla Rego que **deniega** ese caso.
- `plan.json` — plan JSON de ejemplo *ya generado* para ejecutar sin provider real.

## Ejecución (dos caminos)

### A. Usando el `plan.json` incluido (sin terraform)

```bash
cd examples/03-conftest-rego-on-plan
conftest test --policy policy/ plan.json
```

Esperado: 1 violación.

### B. Regenerar el plan tú mismo (requiere terraform init contra AWS)

```bash
terraform init
terraform plan -out=plan.tfplan
terraform show -json plan.tfplan > plan.json
conftest test --policy policy/ plan.json
```

## Qué debes observar

Salida típica de conftest:

```
FAIL - plan.json - terraform.aws.sg - SG rule aws_security_group_rule.ssh_world opens SSH to 0.0.0.0/0

1 test, 0 passed, 0 warnings, 1 failure
```

## Lectura clave: la estructura del plan

En `plan.json`:

```json
"resource_changes": [
  {
    "address": "aws_security_group_rule.ssh_world",
    "type": "aws_security_group_rule",
    "change": {
      "actions": ["create"],
      "after": {
        "type": "ingress",
        "from_port": 22,
        "to_port": 22,
        "cidr_blocks": ["0.0.0.0/0"]
      }
    }
  }
]
```

La regla Rego hace *walk* por `input.resource_changes[_]` y evalúa cada candidato.

## Limpieza

```bash
rm -rf .terraform .terraform.lock.hcl plan.tfplan
# NO borres plan.json: es parte del ejemplo.
```
