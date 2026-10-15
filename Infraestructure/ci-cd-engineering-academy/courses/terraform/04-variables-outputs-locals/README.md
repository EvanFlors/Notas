# tf-04 — Variables, outputs y locals

## Identificación

- **ID:** `tf-04-variables-outputs-locals`
- **Curso:** `terraform`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `tf-02-setup-hcl-first-provider`. Recomendado haber completado `tf-03-resources-data-sources-and-references` (reutilizaremos conceptualmente su stack).

## Objetivo

Parametrizar código Terraform para que el **mismo stack** pueda desplegarse a múltiples ambientes sin tocar `.tf`, y exponer resultados estables hacia el operador y hacia otros stacks mediante `output`. Al terminar deberías poder: declarar `variable` con tipos ricos y `validation`, resolver mentalmente la **jerarquía de precedence** de valores, derivar expresiones intermedias con `locals`, y explicar por qué `sensitive = true` **no es gestión de secretos**.

## Alcance

Este módulo cubre:

- Bloque `variable`: `type` (string, number, bool, list, map, set, object, tuple), `default`, `description`, `nullable`, `sensitive`, `validation`.
- Precedence de valores: `-var` / `-var-file` / `TF_VAR_*` / `terraform.tfvars` / `*.auto.tfvars` / defaults.
- Bloque `locals`: expresiones derivadas y DRY.
- Bloque `output`: `description`, `sensitive`, consumo entre stacks (`terraform output -json`, `terraform_remote_state`).
- Qué significa realmente `sensitive`: oculta en CLI, **sigue en claro en el state**.
- Por qué los secretos reales no viven como variables de TF (van a sistemas de secretos: Vault, Secrets Manager, SOPS, etc., y se referencian con `data`).

Lo que **no** cubre (se verá después):

- `for_each`, `count`, `dynamic`, funciones avanzadas → `tf-07`.
- Encapsulación en módulos reutilizables → `tf-06`.
- State remoto, encriptación at-rest, locking → `tf-11`.
- Policy-as-code sobre variables → `tf-12`.

## Materiales

- **`theory/lesson.md`** — lección en 12 secciones.
- **`examples/`**:
  - `01-typed-variables-with-validation/` — `variable` con `type`, `default`, `description`, `validation`.
  - `02-outputs-and-sensitive/` — outputs con `sensitive`; demuestra que el valor sigue en claro en `terraform.tfstate`.
- **`activities/`**:
  - `01-parameterize-the-stack/` (guided-lab) — toma un stack local (tls self-signed cert + random pet name + local_file) y parametrízalo por ambiente (`dev`, `prod`). El validador prueba la precedence lanzando `plan` con `-var`, `-var-file` y `TF_VAR_*`.
  - `02-why-sensitive-is-not-secret-management/` (análisis / independiente) — demuestra con un `grep` sobre `terraform.tfstate` que `sensitive = true` oculta el valor en la CLI pero **no** en el state. Escribe un `ANALYSIS.md` con la demostración y propone la mitigación correcta.
- **`resources/links.md`** — documentación oficial.

## Temas y subtemas

1. Variables de entrada
   - Bloque `variable "x" { ... }` y nombrado por convención (`snake_case`).
   - `type`: primitivos (`string`, `number`, `bool`) y colecciones (`list(T)`, `set(T)`, `map(T)`, `object({...})`, `tuple([...])`).
   - `default`, `description`, `nullable`, `sensitive`.
   - `validation { condition / error_message }` — fallar temprano con mensaje accionable.
2. Precedence de valores (de menor a mayor prioridad)
   1. `default` del bloque `variable`.
   2. Archivo `terraform.tfvars` (y `terraform.tfvars.json`).
   3. Archivos `*.auto.tfvars` (y `*.auto.tfvars.json`) en orden lexicográfico.
   4. Variables de entorno `TF_VAR_<name>`.
   5. Flags en CLI: `-var 'x=...'` y `-var-file=... ` (en el orden en que aparecen).
3. Locals
   - `locals { ... }` para expresiones derivadas, nombres canónicos y evitar repetición.
   - Qué no son los locals (no son variables de entrada; no se parametrizan desde fuera).
4. Outputs
   - `output "x" { value, description, sensitive }`.
   - `terraform output`, `terraform output -json`, `terraform output -raw x`.
   - Consumo entre stacks: `terraform_remote_state` data source.
5. Qué significa `sensitive`
   - Oculta en CLI (`<sensitive>` en plans, apply e `output`).
   - **No** cifra el state. El valor queda en `terraform.tfstate` en texto plano.
   - Patrón correcto para secretos reales: Vault / Secrets Manager / SSM / SOPS + `data` source.

## Conceptos internos (fundamentos)

- Las variables de Terraform son **inputs del root module**: viven en el espacio del stack, no en el del provider. El provider nunca ve "la variable"; ve el valor interpolado.
- `sensitive = true` es un **marcador de propagación**: si una expresión usa un valor sensitive, el resultado también lo es, y Terraform rechaza mostrarlo en la salida de `plan`/`apply`/`output` salvo que uses `-raw` o `-json`. Es defensa contra el *shoulder-surfing* y los logs de CI; **no** es cifrado.
- El state es la fuente de verdad operacional de Terraform. Para hacer `plan` necesita saber qué valor exacto tiene cada atributo computado; por eso el state guarda los valores en claro. Cifrar los valores sensitive requeriría una llave accesible al proceso TF — lo que esa llave protege ya no es el valor, es la llave. Por eso la mitigación correcta es: **no pongas secretos en variables**; léelos de un sistema de secretos con un `data` source, y protege el state al nivel del backend (acceso + encriptación at-rest).
- `validation` corre en el momento de resolver las variables, **antes** de construir el grafo. Un error de `validation` detiene el `plan` con tu mensaje — es tu única defensa en profundidad contra inputs absurdos antes de llamar al provider.
- La precedence tiene una regla sutil: dentro del mismo archivo de tfvars, el último valor gana; entre niveles distintos, el nivel más alto gana. CLI (`-var`) siempre gana a `TF_VAR_*`.

## Competencias

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Enumerar los 5 niveles de precedence y resolver un caso donde conviven dos; explicar por qué `sensitive` no es gestión de secretos; justificar cuándo usar `local` y cuándo `variable`. |
| Operativa | Declarar variables con tipos ricos y `validation`; estructurar `terraform.tfvars` por ambiente (`dev.tfvars`, `prod.tfvars`); extraer un output con `-raw` y consumirlo desde un script. |
| Arquitectónica | Definir el contrato de variables de un stack (qué se parametriza, qué no); decidir qué sale como `output` para consumo entre stacks; definir dónde viven los secretos (no en variables de TF). |

## Entregables

- Stack adaptado de `tf-03` (local-only: `tls`, `local`, `random`) **parametrizado por ambiente** con `dev.tfvars` y `prod.tfvars`.
- `ANALYSIS.md` demostrando con `grep` sobre `terraform.tfstate` que `sensitive = true` no protege el valor en el state, y proponiendo la mitigación correcta.
- Los dos `tests/validate.sh` deben pasar.

## Criterios de evaluación

- **Precedence**: explicar sin notas el orden `default → terraform.tfvars → *.auto.tfvars → TF_VAR_* → -var/-var-file`, y resolver un caso con conflicto entre dos niveles.
- **Validación temprana**: justificar por qué una validación en el bloque `variable` es preferible a validar en una expresión posterior.
- **Límite de `sensitive`**: explicar en una frase por qué `sensitive = true` **no** sustituye a un secret manager, y qué patrón usar para secretos reales.
- **Diseño del contrato**: dado un stack, decidir qué parametrizar (ambiente, región, tamaños) y qué dejar codificado (invariantes de arquitectura).

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-typed-variables-with-validation/` — pon atención en los errores que lanzan las `validation`.
3. Reproduce `examples/02-outputs-and-sensitive/` — ejecuta el `grep` al final y entiende qué viste.
4. Haz `activities/01-parameterize-the-stack/`.
5. Haz `activities/02-why-sensitive-is-not-secret-management/`.
6. Responde las preguntas de evaluación de la lección sin consultar.

## Siguiente

→ `tf-05-state-basics`: el state como artefacto operacional de primer orden; cómo moverse por él sin romper cosas.
