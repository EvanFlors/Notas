# Lección: Testing y Policy-as-Code en Terraform

> **ID:** `tf-12-testing-and-policy-as-code` · **Nivel:** avanzado · **Duración:** 5 h
> **Prerrequisitos:** `tf-06`, `tf-10`.

---

## 1. Introducción intuitiva

Imagina un equipo con 40 developers que escriben Terraform. En seis meses han enviado 300 PRs. Dos de esos PRs crearon buckets S3 **públicos**. Uno porque alguien olvidó `block_public_acls = true`; otro porque alguien hardcodeó `acl = "public-read"` creyendo que era "necesario para que el frontend lo leyera". Nadie lo vio en code review. El plan parecía normal — "crea un bucket, listo". Un auditor externo lo encontró tres meses después.

Este es el problema que resuelve este módulo. Cuando el único control es *la revisión humana* de un `plan` en texto, errores de seguridad sistemáticos **pasan**. La solución no es "revisar mejor" — es **codificar la política** y hacer que el pipeline la aplique en todos los PRs, siempre, antes del `apply`.

Validar Terraform tiene **capas**, y entender la diferencia entre ellas es la mitad del aprendizaje:

1. **Sintaxis** — ¿compila el HCL? (`terraform validate`).
2. **Estilo** — ¿sigue convenciones? (`terraform fmt`, `tflint`).
3. **Misconfig estática** — ¿este HCL tiene patrones conocidos como inseguros? (**Checkov**, **Trivy**, **Terrascan**).
4. **Policy sobre el plan** — ¿lo que el plan va a *ejecutar realmente* viola nuestra política? (**OPA/Rego** + **Conftest**, **Sentinel**).
5. **Tests de comportamiento** — ¿el módulo, cuando se instancia con tales inputs, produce tales outputs? (`terraform test`, **Terratest**).

Las capas 3 y 4 parecen lo mismo. **No lo son.** La 3 lee el HCL fuente; la 4 lee el plan JSON, que es el *resultado real* después de resolver `for_each`, `locals`, módulos remotos, data sources y defaults de provider. El plan es un *oracle* mucho más fuerte.

---

## 2. Fundamentos

### 2.1 La taxonomía de validaciones

```
┌─────────────────────────────────────────────────────────────┐
│  Capa                 │ Entrada           │ Herramienta     │
├───────────────────────┼───────────────────┼─────────────────┤
│ 1. Sintaxis           │ *.tf              │ terraform validate
│ 2. Estilo             │ *.tf              │ fmt, tflint     │
│ 3. Misconfig HCL      │ *.tf              │ checkov, trivy  │
│ 4. Policy sobre plan  │ plan.tfplan.json  │ OPA/conftest    │
│ 5. Comportamiento     │ módulo + inputs   │ terraform test  │
│                       │ (plan o apply)    │ terratest       │
└───────────────────────────────────────────────────────────────┘
```

Cada capa **ve** cosas distintas. La capa 3 no sabe qué atributos tendrá el bucket si el nombre viene de `data.aws_region.current.name` — ve el HCL. La capa 4 sí: cuando Terraform calcula el plan, ya resolvió esos valores.

### 2.2 ¿Por qué el plan JSON es tan potente?

`terraform plan -out=plan.tfplan` produce un binario con el diff completo. `terraform show -json plan.tfplan` lo serializa a JSON con dos secciones clave:

- `planned_values.root_module` — qué recursos existirán **después** del apply, con sus atributos ya resueltos.
- `resource_changes[]` — cada acción (`create`, `update`, `delete`, `no-op`), con `before` y `after`.

Rego puede caminar ese árbol:

```rego
deny[msg] {
  r := input.resource_changes[_]
  r.type == "aws_s3_bucket"
  r.change.after.acl == "public-read"
  msg := sprintf("bucket %s is public (acl=public-read)", [r.address])
}
```

Esta regla **no se puede escribir en checkov** sin perder recall, porque checkov lee el HCL. Si el `acl` viene de una variable con default `"private"` pero el stack lo override a `"public-read"` en `prod.tfvars`, checkov no lo verá. El plan sí.

### 2.3 ¿Por qué existe entonces checkov?

Porque es **rápido** y detecta la mayoría de errores comunes sin necesidad de credenciales cloud ni de hacer `init` con backend remoto. Checkov corre contra HCL puro — ideal como primer gate en PR, local, barato. OPA sobre el plan es más caro (requiere `init` + `plan`) pero más preciso. **Las dos cosas se usan juntas, no una u otra.**

### 2.4 `terraform test` nativo (≥ 1.6)

Antes de 1.6 el único testing serio era **Terratest** (framework Go). En 1.6 HashiCorp añadió `terraform test` nativo, con archivos `*.tftest.hcl`:

```hcl
run "basic" {
  command = plan             # 'plan' o 'apply'
  variables { name = "demo" }

  assert {
    condition     = aws_s3_bucket.this.bucket == "demo"
    error_message = "bucket name mismatch"
  }
}
```

- `command = plan` evalúa sin desplegar — perfecto para módulos con providers "caros".
- `command = apply` despliega *de verdad* contra el provider configurado — ideal con providers locales (`null`, `random`, `docker`, `tls`) o con cloud sandbox.
- Las aserciones son expresiones HCL — se pueden usar funciones y operadores.
- Varios bloques `run` encadenan: el estado de uno es la entrada del siguiente.

Terratest sigue vigente para pruebas end-to-end más complejas (parallelismo, retries, aserciones imperativas) pero `terraform test` cubre el 80 % con 0 líneas de Go.

### 2.5 Policy-as-Code: OPA/Rego vs Sentinel

- **OPA (Open Policy Agent)** — proyecto CNCF; lenguaje **Rego**; agnóstico; open source. Se integra vía **Conftest** para evaluar JSON/YAML (incluido el plan JSON).
- **Sentinel** — propietario de HashiCorp, integrado en **Terraform Cloud / Enterprise**. Lenguaje propio con lógica similar pero sintaxis distinta; soporta `advisory`, `soft-mandatory`, `hard-mandatory`.
- **Trade-off**: Sentinel está mejor integrado con TFC/TFE (hooks pre-plan, pre-apply nativos); OPA es portable (mismo motor que usas en Kubernetes, en Envoy, en microservicios).

Para la mayoría de organizaciones open-source, **OPA + Conftest** es la elección pragmática.

---

## 3. Historia breve

- **2016** — Aparece **Terratest** (Gruntwork), primera forma estandarizada de testear módulos.
- **2017** — **InSpec** y **Serverspec** se usan como testing "post-apply" (verifican el estado real contra expectativas).
- **2018** — **tflint** (Kazuhiro Suzuki) gana tracción como linter de reglas de provider.
- **2019** — **Checkov** (Bridgecrew, luego Palo Alto) nace como scanner de misconfig IaC con reglas CIS.
- **2019** — **OPA** se gradúa en CNCF; **Conftest** permite usar Rego contra manifiestos arbitrarios.
- **2019** — **Terrascan** (Accurics, luego Tenable) con enfoque policy-as-code.
- **2021** — **Trivy** (Aqua) añade `trivy config` cubriendo IaC además de contenedores.
- **2023** — Terraform **1.6** incorpora `terraform test` nativo como experimental-stable.
- **2024+** — `terraform test` madura; OpenTofu lo soporta compatible desde el fork.

---

## 4. Problemas que resuelve

- **Prevenir misconfig de seguridad** (buckets públicos, SGs 0.0.0.0/0, IAM `*`) antes de aplicar.
- **Enforcement de políticas organizacionales** (tagging obligatorio, regiones permitidas, familias de instancias permitidas).
- **Regresión funcional** en módulos — garantizar que cambios internos no rompen contratos de output.
- **Confianza en code review**: el reviewer humano ya no es el único control.
- **Costo** — bloquear tipos de instancia prohibidamente caros antes del apply.

---

## 5. Casos de uso

- Pipeline PR: `fmt --check`, `validate`, `tflint`, `checkov`, `conftest` sobre plan comentado en el PR.
- Pipeline merge: `terraform test` (regresión de módulos), re-eval de policy sobre el plan definitivo.
- Pipeline apply: policy **hard-mandatory** (bloquea si denuncia); auditoría del plan aplicado.
- Pre-commit hook local: `fmt` + `validate` + `tflint` rápido para feedback <2s.
- Módulos "golden" en el registry interno: cada módulo trae su `tests/` nativo que corre en el CI del repo del módulo.

---

## 6. Arquitectura y flujo del pipeline

```
Developer                CI                       Policy
   │                      │                          │
   │  push PR             │                          │
   ├─────────────────────▶│                          │
   │                      │ fmt --check              │
   │                      │ validate                 │
   │                      │ tflint                   │
   │                      │ checkov                  │   capas 1-3
   │                      │                          │
   │                      │ init + plan -out=p       │
   │                      │ show -json p > plan.json │
   │                      │ conftest plan.json ─────▶│   capa 4
   │                      │                          │
   │                      │ terraform test           │   capa 5
   │                      │                          │
   │ ◀─── comment PR ─────┤                          │
   │                      │                          │
   │  merge               │                          │
   │                      │ init + plan              │
   │                      │ conftest (hard)          │
   │                      │ apply (approval)         │
   ▼                      ▼                          ▼
```

Puntos de diseño:

- El **plan** se calcula una vez por PR y se **guarda** (`-out=plan.tfplan`); todo lo demás opera sobre ese artefacto. Esto evita TOCTOU entre lo que se validó y lo que se aplicó (se profundiza en `tf-13`).
- Las policies corren **dos veces** en organizaciones estrictas: en PR (feedback rápido) y en merge/apply (gate final, con el plan definitivo contra `main`).

---

## 7. Internals: cómo lee cada herramienta

### 7.1 Checkov

Parsea HCL con un parser propio (`hcl2`), construye un árbol de recursos y evalúa reglas (Python). Cada regla es un `CheckClass` con `id` (`CKV_AWS_18`), `scan_resource_conf`, `missing_block_result`. No ejecuta Terraform.

**Limitación**: no resuelve `for_each`, no evalúa data sources, no sabe de defaults de provider. Si tu `acl` viene de un `locals`, lo intenta; si viene de un `data` resource, se rinde.

### 7.2 tflint

Linter con reglas **generales** (`terraform_required_providers`, `terraform_unused_declarations`) y **de provider** (plugins para AWS, GCP, Azure que validan atributos contra la API, p. ej. "este tipo de instancia no existe en esta región"). Corre después de `init` para tener los providers.

### 7.3 Conftest + OPA/Rego

Conftest es un wrapper CLI alrededor de OPA que acepta JSON/YAML y evalúa reglas en Rego. Para Terraform:

```bash
terraform plan -out=plan.tfplan
terraform show -json plan.tfplan > plan.json
conftest test --policy policy/ plan.json
```

Rego evalúa `deny[msg]` y `warn[msg]` por cada binding que haga `true`. Un `deny` no vacío → exit 1.

### 7.4 `terraform test`

Terraform core carga el archivo `*.tftest.hcl`, interpreta cada `run` como un *mini-apply* efímero (con su propio state temporal) y evalúa las aserciones. Al finalizar, destruye todo lo creado por los `run` con `command = apply`.

---

## 8. Reglas Rego típicas sobre un plan

**Prohibir ingress 0.0.0.0/0 en el puerto 22:**

```rego
package terraform.aws.sg

deny[msg] {
  r := input.resource_changes[_]
  r.type == "aws_security_group_rule"
  r.change.after.type == "ingress"
  r.change.after.from_port <= 22
  r.change.after.to_port >= 22
  "0.0.0.0/0" == r.change.after.cidr_blocks[_]
  msg := sprintf("SG rule %s opens SSH to 0.0.0.0/0", [r.address])
}
```

**Exigir tag `Owner` en todo recurso AWS:**

```rego
package terraform.aws.tagging

required := {"Owner", "Environment"}

deny[msg] {
  r := input.resource_changes[_]
  startswith(r.type, "aws_")
  r.change.actions[_] != "delete"
  missing := required - object.keys(r.change.after.tags)
  count(missing) > 0
  msg := sprintf("%s missing tags: %v", [r.address, missing])
}
```

### 8.1 Patrones comunes

- Un `package` por dominio (`sg`, `tagging`, `s3`, `iam`).
- Separar `deny` (bloquea) de `warn` (comenta pero no bloquea).
- Fixtures de plan JSON en el repo para probar las reglas sin plan en vivo.
- Tests **de las reglas** con `conftest verify` o Rego unit tests.

---

## 9. Diseño de gates por ambiente

No todos los controles aplican por igual. Un patrón razonable:

| Control                   | PR (dev) | merge→stg | apply→prod |
|---------------------------|----------|-----------|------------|
| fmt --check               | fail     | fail      | fail       |
| validate                  | fail     | fail      | fail       |
| tflint                    | warn     | fail      | fail       |
| checkov (CRITICAL)        | fail     | fail      | fail       |
| checkov (MEDIUM)          | warn     | warn      | fail       |
| Rego (hard-mandatory)     | fail     | fail      | fail       |
| Rego (advisory)           | warn     | warn      | warn       |
| terraform test            | fail     | fail      | fail       |
| costo estimado > $X       | warn     | warn      | fail       |

**Principio**: en dev prioriza *velocidad de iteración*; en prod prioriza *control*. Las policies "duras" (no S3 público, no IAM `*`, no 0.0.0.0/0:22) **siempre** bloquean.

---

## 10. Trade-offs y errores comunes

- **Falsos positivos de checkov** sin manejar → fatigue, el equipo deshabilita todo. Mitigación: `--skip-check` justificado por archivo + revisión periódica del skip-list.
- **Rego creado sin fixtures** → policies que nunca se probaron; cuando fallan en prod no se sabe si es la regla o el stack.
- **Mezclar `warn` y `deny`** mal → gente ignora los `warn` y los `deny` se vuelven ruido. Separar canales (comentario PR vs status check).
- **`terraform test` con `apply` contra prod** por error → *siempre* usar provider dedicado o `plan` para módulos con recursos caros.
- **No versionar las policies** junto al IaC → cambios de policy no son auditables. Trata `policy/` como código.

---

## 11. Mapa a OpenTofu

- `terraform fmt` / `validate` → `tofu fmt` / `validate` (compat).
- `terraform test` → OpenTofu lo soporta compatible desde v1.7+.
- tflint, checkov, conftest son **agnósticos**: leen HCL o plan JSON, no les importa el binario que lo produjo.
- Sentinel es **solo** TFC/TFE. Si considerás OpenTofu, OPA es el camino natural.

---

## 12. Preguntas de evaluación

Responde sin consultar docs:

1. Diferencia entre checkov y conftest+Rego sobre el plan. ¿Cuándo usarías cada uno?
2. ¿Por qué `terraform validate` **no** detecta que estás abriendo el puerto 22 al mundo?
3. ¿Qué pasa si un `*.tftest.hcl` tiene `command = apply` contra un provider AWS en una cuenta de prod y la pipeline lo corre?
4. Enumera 3 políticas que tú harías *hard-mandatory* en tu organización y 3 que harías *advisory*. Justifica.
5. ¿Por qué el plan JSON es un oracle más fuerte que el HCL para análisis de seguridad? Da un ejemplo concreto donde HCL diga una cosa y el plan diga otra.
6. ¿Cuándo justifica usar Terratest (Go) sobre `terraform test` nativo?
7. Diseña la tabla de gates para una org con 3 ambientes (dev/stg/prod) y 5 tipos de recurso (S3, SG, IAM, RDS, EKS). Marca qué validación aplica en cada celda y por qué.
