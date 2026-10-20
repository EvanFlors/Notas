# tf-09 — Providers avanzados y lifecycle

## Identificación

- **ID:** `tf-09-providers-deep-and-lifecycle`
- **Curso:** `terraform`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `tf-03-resources-data-sources-and-references`, `tf-05-state-basics`.

## Objetivo

Configurar **providers con precisión** (alias, múltiples regiones, versiones) y **controlar el ciclo de vida** de cada recurso para evitar destrucciones accidentales, refactorizar sin recrear infraestructura y adoptar recursos existentes sin tocar la consola. Al terminar, deberías poder leer un `terraform plan` destructivo en producción y proponer la corrección exacta en HCL — con `lifecycle`, con `moved`, con `import` o con `removed` — justificando el por qué de cada una.

## Alcance

Este módulo cubre:

- **Configuración fina de providers**: bloque `provider`, `required_providers`, `alias` para multi-región / multi-cuenta, cómo un recurso referencia un provider aliasado (`provider = aws.us_east_1`).
- **Meta-arguments de `lifecycle`**:
  - `create_before_destroy` — evita downtime al reemplazar un recurso.
  - `prevent_destroy` — rechaza cualquier plan que proponga destruir el recurso.
  - `ignore_changes` — ignora drift en atributos específicos (tags inyectados, auto-scaling, etc.).
  - `replace_triggered_by` — fuerza reemplazo cuando cambia otro recurso.
- **`provisioner`**: `local-exec`, `remote-exec`, `file`, `connection`, `self`; por qué son **último recurso** y qué alternativas preferir.
- **Reemplazos manuales**: `terraform taint` **deprecado** → `terraform apply -replace=<addr>`.
- **Refactoring sin recrear**:
  - `moved {}` block — renombrar o mover recursos sin destroy+create.
  - `import {}` block (TF 1.5+) — adoptar recursos existentes en HCL (vs comando `terraform import`).
  - `removed {}` block (TF 1.7+) — quitar un recurso del state sin destruirlo en la nube.

Lo que **no** cubre (se verá después):

- Internals del grafo y del algoritmo de plan → `tf-10`.
- Backends remotos y locking → `tf-11`.
- Policy-as-code sobre plan JSON → `tf-12`.
- Platform patterns, imports masivos, drift continuo → `tf-14`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`**:
  - `01-create-before-destroy-lb/` — un recurso con nombre único que, cambiado "en caliente", romperia; `create_before_destroy` + nombre derivado lo arreglan.
  - `02-ignore-tags-managed-elsewhere/` — `ignore_changes` sobre `content` de un `local_file` que otro sistema modifica fuera de banda.
  - `03-moved-block-refactor/` — renombrar un recurso con `moved {}` y comparar plan antes/después.
- **`activities/`**:
  - `01-rename-resource-with-moved/` (guided-lab) — refactorizar un stack real sin recrear recursos.
  - `02-import-block-vs-cli/` (independent) — adoptar un recurso creado fuera de Terraform usando `import {}` blocks.
- **`resources/links.md`** — documentación oficial y lecturas complementarias.

## Temas y subtemas

1. **Providers a fondo**
   - `required_providers` + versión + `source`.
   - Bloque `provider` con `alias`.
   - Un recurso que elige provider con `provider = aws.sa_east_1`.
   - Multi-cuenta / multi-región sin crear workspaces.
2. **`lifecycle` meta-arguments**
   - `create_before_destroy = true` — mecánica y colisiones de unicidad.
   - `prevent_destroy = true` — barrera dura; no se desactiva por error.
   - `ignore_changes = [tags, content]` — qué significa cada forma.
   - `replace_triggered_by = [resource.other]` — relaciones de "si tú cambias, yo me reemplazo".
3. **Reemplazo manual**
   - `terraform taint` deprecado; usar `terraform apply -replace=<addr>`.
   - Cuándo tiene sentido forzar un reemplazo (ej.: pool de instancias "sucias").
4. **`provisioner`**
   - `local-exec`, `remote-exec`, `file`, `connection`.
   - `when = destroy` — único uso que a veces sí vale la pena.
   - Por qué los provisioners son **último recurso** (no son idempotentes, no participan del plan, se pierden si cambias el provider).
5. **Refactor con `moved` blocks**
   - Caso: renombrar `local_file.old` → `local_file.new`.
   - Caso: mover un recurso entre módulos (`module.a.aws_s3_bucket.x` → `module.b.aws_s3_bucket.x`).
   - `moved` vs `terraform state mv`.
6. **Adopción con `import` blocks**
   - `import { to = ..., id = "..." }` en HCL (TF ≥ 1.5).
   - `terraform plan -generate-config-out=generated.tf`.
   - `import` block vs comando `terraform import` (procedural, no versionado).
7. **Baja controlada con `removed` blocks** (TF ≥ 1.7)
   - Sacar un recurso del state sin destruirlo (equivale a `terraform state rm` versionado).
   - `removed { lifecycle { destroy = false } }` como contrato explícito en HCL.
8. **Lectura de un plan destructivo**
   - Símbolos del plan (`+`, `-`, `~`, `-/+`, `+/-`).
   - Diagnóstico: ¿por qué TF quiere reemplazar? (atributo `ForceNew`, cambio de provider, cambio de módulo, rename).
   - Flujo de decisión: ¿`lifecycle`? ¿`moved`? ¿`import`? ¿`removed`?

## Conceptos internos (fundamentos)

- Un **provider con `alias`** es, operacionalmente, otra instancia del plugin con otra configuración (otra región, otra credencial). El state registra el recurso contra ese alias; cambiar el alias de un recurso ya creado implica, por default, destroy+create (y a veces hay que recurrir a `moved`).
- `create_before_destroy = true` **invierte el orden** del plan para ese recurso: TF primero crea el reemplazo, luego destruye el viejo. Esto solo es viable si el recurso no tiene restricciones de **unicidad global** (nombres, puertos, hostnames); si colisiona, el `create` falla y el `destroy` no se ejecuta — queda en un estado "half-way" que hay que revisar.
- `ignore_changes` opera sobre **atributos específicos del state**: TF sigue leyendo el valor real desde la API en el refresh, lo guarda en el state para no perder la trazabilidad, pero **no genera diff** contra el HCL para esos atributos. No "borra" el drift; lo ignora activamente.
- `prevent_destroy` se evalúa al **generar el plan**: cualquier operación `-` sobre ese recurso aborta `terraform plan` con un error. No protege contra `terraform state rm` + `terraform destroy` posterior (eso borra la referencia primero), ni contra borrado manual desde la consola.
- Un **`provisioner`** se ejecuta en `apply` **después** de que el provider reporta el recurso como creado. No participa del plan — no sabes de antemano qué va a pasar. Si falla, el recurso queda "tainted" (se destruirá y recreará al siguiente apply) y pierdes idempotencia.
- `moved {}` es puramente una **operación sobre el state**: le dice a TF "lo que antes se llamaba A ahora se llama B, no destruyas nada". No cambia infraestructura; es el equivalente versionado de `terraform state mv`.
- `import {}` convierte **adopción de recursos en código**: queda en Git como constancia histórica de cómo entró ese recurso al state. El comando `terraform import` hace lo mismo pero no deja huella en los archivos `.tf` — solo en el state.
- `removed {}` resuelve un problema concreto: "quiero quitar este recurso del código, pero NO quiero destruirlo en la nube" (porque otro equipo lo gestiona ahora, por ejemplo). Antes se hacía con `terraform state rm` procedural; `removed` lo deja declarativo.

## Competencias

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar la diferencia entre `moved`, `import` y `removed` blocks, y cuándo usar cada uno. Explicar por qué `create_before_destroy` requiere pensar la unicidad del recurso. Explicar por qué `provisioner` es siempre el último recurso. |
| Operativa | Renombrar un recurso en HCL sin producir destroy+create. Adoptar un recurso creado por fuera usando `import {}`. Diagnosticar un plan que destruye un recurso de producción y proponer la corrección exacta. |
| Arquitectónica | Diseñar una convención de `lifecycle` para recursos de producción (qué `prevent_destroy`, qué `ignore_changes` por defecto). Decidir cuándo introducir `removed` vs mantener el recurso en el código. |

## Entregables

- Un **refactor** de un stack real: renombrar al menos un recurso usando `moved {}` sin producir destroy+create. Evidencia: `terraform plan` final con `No changes.`
- Un **script de adopción** usando `import {}` blocks que lleve un recurso no gestionado al state, con el HCL correspondiente versionado en Git.
- Los dos `tests/validate.sh` de las actividades deben pasar.

## Criterios de evaluación

- Dado un plan que muestra `-/+ destroy and then create replacement` sobre un recurso crítico, **identificar la causa raíz** (atributo `ForceNew`, rename, cambio de provider) y proponer la corrección (`lifecycle`, `moved`, `import` o `removed`) con justificación.
- Capacidad de **argumentar en contra** del uso de `prevent_destroy = true` como mecanismo único de protección (no sustituye a políticas IAM, backups ni policy-as-code).
- Capacidad de **rechazar** un uso de `provisioner "remote-exec"` cuando existe una alternativa declarativa (user-data, cloud-init, módulo del provider).

## Secuencia recomendada

1. Lee `theory/lesson.md` completo.
2. Reproduce `examples/01-create-before-destroy-lb/` y observa el reordenamiento del plan.
3. Reproduce `examples/02-ignore-tags-managed-elsewhere/` modificando el archivo "a mano" entre `apply`s.
4. Reproduce `examples/03-moved-block-refactor/` comparando el plan antes y después del bloque `moved`.
5. Haz `activities/01-rename-resource-with-moved/`.
6. Haz `activities/02-import-block-vs-cli/`.
7. Responde las preguntas de evaluación de la lección sin consultar.

## Siguiente

→ `tf-10-internals-graph-and-plan-algorithm`: pasamos de "cómo controlo el plan" a "cómo lo construye TF por dentro" (grafo, refresh, diff atributo por atributo).
