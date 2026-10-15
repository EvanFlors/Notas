# tf-07 — Expresiones, `for_each`, `count` y bloques `dynamic`

## Identificación

- **ID:** `tf-07-expressions-for_each-count-dynamic`
- **Curso:** `terraform`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `tf-04-variables-outputs-locals`, `tf-06-modules`.

## Objetivo

Dominar las **expresiones de HCL** (operadores, funciones, comprehensions, splats, condicionales), los **meta-arguments de iteración** (`count` y `for_each`) y los **bloques `dynamic`**, con criterio suficiente para generar N recursos a partir de un dato externo (YAML/JSON) **sin convertir el HCL en código enredado**. Al terminar deberías poder justificar por qué `for_each` casi siempre gana sobre `count`, y refactorizar un stack roto por reindexación.

## Alcance

Este módulo cubre:

- Expresiones: operadores aritméticos, lógicos y de comparación; condicionales (`a ? b : c`); splat (`[*]`); `for` expressions (list y map comprehensions).
- Funciones esenciales: `concat`, `merge`, `lookup`, `try`, `coalesce`, `jsonencode`, `templatefile`, `yamldecode`, `tomap`, `toset`.
- `count` vs `for_each`: semántica, direccionamiento, cuándo falla cada uno.
- Bloques `dynamic` para generar sub-bloques repetidos (ingress rules, tags, listeners).
- `terraform console` como laboratorio interactivo de expresiones.
- Generación de un set de recursos desde un YAML de entrada (patrón "data-driven infra").

Lo que **no** cubre (se verá después):

- Módulos reutilizables → `tf-06` (prerequisito).
- Patrones multi-ambiente, workspaces → `tf-08`.
- `moved`/`removed` para refactorings sin impacto → `tf-09`.
- Testing nativo de módulos → `tf-12`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`**:
  - `01-for_each-map-of-users/` — un `local_file` por usuario leyendo un map; demuestra claves estables.
  - `02-dynamic-ingress-rules/` — un bloque `dynamic` que expande N reglas desde una lista de objetos.
  - `03-count-to-for_each-migration/` — el mismo stack en dos versiones: `count` (que se rompe al reordenar) y `for_each` (que no).
- **`activities/`**:
  - `01-iam-users-from-yaml/` (guided-lab) — leer `users.yaml` con `yamldecode(file(...))` y crear un `local_file` por usuario.
  - `02-fix-count-reindex-drift/` (independent) — stack roto con `count`; eliminar el elemento del medio provoca destroy+create en cascada; refactorizar a `for_each` con `toset()`.
- **`resources/links.md`** — documentación oficial de expresiones y funciones.

## Temas y subtemas

1. **Expresiones**
   - Operadores (aritméticos, lógicos, comparación, concatenación de strings).
   - Interpolación `${}` y templates heredoc `<<EOT`.
   - Condicional ternario `cond ? a : b`.
   - Splat expression `lista[*].attr` y `lista[*]`.
2. **`for` expressions**
   - Lista: `[for x in lista : expr if cond]`.
   - Map: `{ for k, v in m : k => expr }`.
   - De lista a map (patrón para construir claves estables desde una lista de objetos).
3. **Funciones de uso diario**
   - Colecciones: `concat`, `merge`, `lookup`, `coalesce`, `compact`, `flatten`, `distinct`, `toset`, `tomap`, `keys`, `values`.
   - Seguras: `try`, `can`, `coalescelist`.
   - Encoding: `jsonencode`, `yamlencode`, `base64encode`.
   - Archivos: `file`, `fileexists`, `templatefile`, `yamldecode`, `jsondecode`.
4. **`count`**
   - Semántica: lista indexada por entero.
   - Direccionamiento: `resource.name[0]`, `resource.name[1]`.
   - El problema: eliminar un elemento del medio reindexa todo.
5. **`for_each`**
   - Semántica: map o set indexado por clave estable.
   - Direccionamiento: `resource.name["alice"]`.
   - Reorganizar la fuente no reasigna claves ⇒ plan vacío.
   - Restricción: la clave debe conocerse en plan time.
6. **`dynamic` blocks**
   - Para qué sirve: desdoblar un sub-bloque repetido en el schema de un recurso.
   - Qué **no** hace: no cambia el grafo, no crea recursos, solo expande syntax.
7. **`terraform console`**
   - REPL para probar expresiones sin aplicar.

## Conceptos internos (fundamentos)

- **`count` indexa por entero**. El grafo de Terraform ve `aws_user.this[0]`, `aws_user.this[1]`, etc. Si tu lista era `["alice","bob","carol"]` y borras `"bob"`, los índices se desplazan: lo que era `[2]="carol"` ahora es `[1]="carol"`. Terraform cree que `[1]` cambió de "bob" a "carol" y planea destroy+create. Esto es *la* trampa clásica del provider cloud: usuarios IAM, grupos, security groups se recrean sin motivo.
- **`for_each` indexa por clave estable**. El grafo ve `aws_user.this["alice"]`, `aws_user.this["bob"]`. Si eliminas `"bob"` del map, el único cambio del plan es `aws_user.this["bob"]` → destroy. "alice" y "carol" no se tocan.
- **`dynamic` es puramente sintáctico**. Expande sub-bloques repetidos (p. ej. N `ingress {}` dentro de un security group), pero el `security_group` sigue siendo un solo recurso con un solo ciclo de vida. No confundas iteración de **sub-bloques** (`dynamic`) con iteración de **recursos** (`count`/`for_each`).
- **`for_each` exige claves conocidas en plan time**. Si la clave viene de un atributo computado por otro recurso (p. ej. el ID de un VPC que aún no existe), Terraform no puede construir el map y falla con "cannot be determined until apply". Por eso las claves tienden a ser **nombres lógicos del humano** (ingresados por el estudiante), no IDs del provider.
- **Splat es azúcar sobre `for`**. `aws_user.this[*].arn` es equivalente a `[for u in aws_user.this : u.arn]`. Con `for_each`, splat devuelve una lista de valores en orden lexicográfico de clave (determinista).
- **`terraform console` NO consulta providers por ti**. Lee el state local y evalúa expresiones puras. Es ideal para pulir una expresión antes de meterla al código.

## Competencias

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué `for_each` casi siempre gana sobre `count` con un ejemplo donde `count` fuerza un destroy+create innecesario. Diferenciar iteración de recursos vs iteración de sub-bloques. |
| Operativa | Transformar una lista de objetos a un map con `for` para alimentar `for_each`. Escribir un `dynamic` block correctamente anidado. Usar `terraform console` para iterar sobre una expresión antes de meterla al código. |
| Arquitectónica | Diseñar la "superficie de datos" de un stack (YAML/JSON de entrada) para que el refactor y la expansión no obliguen a tocar HCL. |

## Entregables

- Stack de la **actividad 01** que lee un YAML y genera un `local_file` por usuario, con el YAML como única fuente de verdad.
- Refactor de la **actividad 02**: código `for_each` + evidencia (`terraform plan`) de que un cambio equivalente ya no provoca cascada.

## Criterios de evaluación

- Capaz de **justificar `for_each` sobre `count`** con un ejemplo concreto (no la frase memorizada: el ejemplo).
- Capaz de **construir un map a partir de una lista de objetos** con una `for` expression, eligiendo una clave estable del dominio.
- Capaz de **leer un `terraform plan`** y distinguir "reindex por `count`" de "cambio real".
- Capaz de **evitar la tentación** de meter `dynamic` en todas partes: solo donde se repite un sub-bloque.

## Secuencia recomendada

1. Lee `theory/lesson.md` completo. Abre `terraform console` en una terminal y prueba cada expresión que aparece.
2. Reproduce `examples/01-for_each-map-of-users/`.
3. Reproduce `examples/02-dynamic-ingress-rules/` (sin cloud: usamos `null_resource` para que el schema permita el patrón).
4. Reproduce `examples/03-count-to-for_each-migration/` prestando atención al diff de `terraform plan`.
5. Haz `activities/01-iam-users-from-yaml/`.
6. Haz `activities/02-fix-count-reindex-drift/`.
7. Responde las preguntas de evaluación.

## Siguiente

→ `tf-08-environments-workspaces-vs-directories`: cómo modelar dev/stg/prod sin acoplar código con datos ni abusar de `count`/`for_each` para "if por entorno".
