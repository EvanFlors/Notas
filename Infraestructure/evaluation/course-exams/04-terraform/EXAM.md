# Examen de certificación — Curso Terraform

- **Nivel:** intermedio-avanzado (`tf-06` a `tf-14`, apoyado en `tf-01` a `tf-05`).
- **Dimensiones evaluadas:** conceptual, operativa, arquitectónica (`dimensión = todas`).
- **Tipo:** sumativa.
- **Duración:** 90–120 minutos.
- **Entorno:** take-home o live con instructor; máquina local con Terraform ≥ 1.6 (u OpenTofu equivalente). **No se requiere ni se permite tocar cloud.**
- **Umbral de aprobación:** 70% ponderado del total.
- **Prosa en español, código y comandos en inglés.**

> **Reglas generales**
>
> - No uses IDs reales de cuenta/tenant/suscripción, ni tokens o keys (ni siquiera formato real tipo `AKIA...`).
> - El ejercicio operativo es nivel `terraform validate`: no se ejecuta `apply` ni se consultan APIs cloud.
> - Si una pregunta es ambigua, declara el supuesto que elegiste; se puntuará la coherencia.
> - Entrega todo lo producido en una carpeta y un `ADR.md` para la parte arquitectónica.

---

## 1. Matriz de competencias evaluadas

La matriz formal está en `competency-matrix.yaml`. Resumen:

| ID            | Competencia (verbo + resultado observable)                                                                        | Dimensión       | Peso |
|---------------|-------------------------------------------------------------------------------------------------------------------|-----------------|------|
| tf-c-06-01    | Diseñar módulos pequeños, cohesivos y versionados con contrato claro de inputs/outputs                            | arquitectónica  | 10   |
| tf-c-07-01    | Justificar `for_each` sobre `count` y refactorizar un `count` que reindexa                                        | conceptual      | 8    |
| tf-c-07-02    | Generar N recursos a partir de un mapa usando `for_each` y `dynamic` blocks                                       | operativa       | 10   |
| tf-c-08-01    | Elegir patrón de ambientes (workspaces vs directorios) y defender riesgos de cada uno                             | arquitectónica  | 8    |
| tf-c-09-01    | Aplicar `lifecycle` (`create_before_destroy`, `prevent_destroy`, `ignore_changes`) y `moved` sin recrear recursos | operativa       | 10   |
| tf-c-09-02    | Diagnosticar un plan que destruye un recurso y proponer corrección con `lifecycle`/`moved`                        | conceptual      | 8    |
| tf-c-10-01    | Explicar fases del plan (refresh + diff) y por qué `-target` y `-refresh=false` son escape hatches                | conceptual      | 7    |
| tf-c-11-01    | Diseñar splitting del state por bounded context y backend por ambiente                                            | arquitectónica  | 10   |
| tf-c-11-02    | Recuperar un lock colgado con criterio y sin corromper el state                                                   | conceptual      | 5    |
| tf-c-12-01    | Diferenciar análisis estático sobre HCL vs análisis sobre plan JSON y ubicarlos en el pipeline                    | conceptual      | 7    |
| tf-c-12-02    | Escribir `validation` blocks y referenciar policies externas en el stack                                          | operativa       | 5    |
| tf-c-13-01    | Justificar plan guardado + `apply` as-is y OIDC vs access keys en CI/CD                                           | conceptual      | 6    |
| tf-c-14-01    | Defender el contrato de un módulo "golden" ante trade-offs autonomía dev vs control                               | arquitectónica  | 6    |

**Total: 100 puntos. Umbral: 70.**

Distribución por dimensión: conceptual 41%, operativa 25%, arquitectónica 34%.

---

## 2. Preguntas conceptuales

Responde con enunciado breve, concreto y argumentado. **No se evalúan flags ni defaults memorizados**; se evalúa comprensión del *por qué*.

> **Peso total de esta sección: 41 puntos** (sumatoria de pesos individuales).

### P1 — `for_each` sobre `count` (6 pts) · `tf-c-07-01`

Tienes un recurso iterado con `count = length(var.users)` donde `var.users` es `list(string)`. Alguien inserta un usuario al inicio de la lista.

**(a)** ¿Qué va a mostrar `terraform plan` y por qué?
**(b)** ¿Qué cambia si pasas a `for_each` sobre un `map(object)` indexado por el username?
**(c)** ¿Hay algún caso donde `count` sea *preferible* a `for_each`? Da un ejemplo o justifica que no.

### P2 — Workspaces para separar `prod` (5 pts) · `tf-c-08-01`

Un compañero propone: "usemos `terraform workspace new prod` sobre el mismo backend que `dev` y `stg`, así reutilizamos el pipeline". Enumera **al menos tres** riesgos específicos y concretos (no genéricos tipo "menos seguro"), y propone cuándo *sí* son adecuados los workspaces.

### P3 — `prevent_destroy` vs `ignore_changes` vs `moved` (6 pts) · `tf-c-09-02`

Para cada uno, en una línea:

- Qué problema resuelve.
- Qué problema **no** resuelve.
- Un escenario donde usarlo sería un error.

Luego: te muestran un `plan` que marca `-/+ destroy and then create replacement` sobre una base de datos en `prod` porque se renombró el recurso en el código. ¿Cuál de los tres aplicas? ¿Por qué los otros dos no?

### P4 — `-target` y `-refresh=false` (7 pts) · `tf-c-10-01`

**(a)** Describe las dos fases principales de un `terraform plan` normal, en orden, en no más de 4 líneas.
**(b)** Explica por qué `-target` fragmenta el grafo y qué garantía pierdes al usarlo.
**(c)** ¿En qué caso `-refresh-only` es la operación correcta y no `-target`?

### P5 — Lock colgado (5 pts) · `tf-c-11-02`

Un `apply` murió en medio (SIGKILL del runner). El lock queda tomado en DynamoDB. Un compañero propone correr `terraform force-unlock <ID>` de inmediato.

**(a)** ¿Qué debes verificar *antes* de hacerlo?
**(b)** ¿Qué puede corromperse si lo haces mientras otra sesión sigue viva?
**(c)** ¿Qué diferencia hay con un lock nativo S3 en términos operativos?

### P6 — Checkov vs Rego sobre plan JSON (6 pts) · `tf-c-12-01`

**(a)** Da un ejemplo de regla que **solo** se puede expresar bien sobre el plan JSON y **no** sobre el HCL fuente. Explica por qué.
**(b)** Da un ejemplo de regla que es más barata y confiable en análisis estático de HCL.
**(c)** Decide dónde ponés cada tipo en un pipeline PR → merge → apply y por qué.

### P7 — Plan guardado + OIDC en CI/CD (6 pts) · `tf-c-13-01`

**(a)** ¿Por qué el plan guardado (`-out=plan.tfplan`) se aplica tal cual en merge en vez de volver a planear? Nombra el riesgo que se evita.
**(b)** ¿Por qué OIDC desde el runner al cloud es preferible a inyectar access keys como secret? Da al menos dos razones que no sean "más moderno".
**(c)** ¿Qué sigue siendo riesgoso incluso con OIDC si el runner es self-hosted compartido?

---

## 3. Ejercicio operativo

Carpeta: [`operative/`](operative/).

- **Peso: 25 puntos.** Distribución en §5.
- Nivel `terraform validate`. Sin `apply`, sin cloud, sin credenciales.
- El enunciado completo y los comandos de validación están en `operative/README.md`.
- Entrega: los 4 archivos `.tf` corregidos y el bloque `# NOTAS` al final de `main.tf` con las tres explicaciones solicitadas.

**Resumen de lo que se pide:**

1. Hacer que `terraform fmt`, `terraform init -backend=false`, `terraform validate` terminen limpio.
2. Refactor `count` → `for_each` sobre `map(object)`.
3. `moved` block para preservar identidad tras rename.
4. `validation` block en `variable "environment"` (dev/stg/prod).
5. `lifecycle { prevent_destroy = true }` donde corresponde.
6. Corregir `sensitive` en los `output` (uno falta, otro sobra).
7. `required_providers` con pinning `~>`.

---

## 4. Ejercicio arquitectónico

Archivo: [`architectural/scenario.md`](architectural/scenario.md).

- **Peso: 34 puntos.** Distribución en §5.
- Entrega: un `ADR.md` que resuelve los 7 puntos del escenario con alternativas descartadas, consecuencias, diagrama y triggers de revisión.

---

## 5. Rúbrica

### 5.1 Preguntas conceptuales (§2) — 41 puntos

Para cada pregunta se aplica esta rúbrica genérica, ponderada por su peso individual (ver §2):

| Criterio                 | Insuficiente (0)                          | Básico (1)                                                   | Competente (2)                                                                   | Experto (3)                                                                                  |
|--------------------------|-------------------------------------------|--------------------------------------------------------------|----------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------|
| Corrección técnica       | Afirma algo falso o irrelevante.          | Idea general correcta pero con imprecisiones.                | Correcta y precisa en todos los puntos pedidos.                                  | Correcta, precisa y menciona un matiz no exigido (p. ej. caso borde).                        |
| Razonamiento (*por qué*) | Lista hechos sin causa.                   | Da una causa superficial ("es más seguro").                  | Explica el mecanismo (qué garantiza el diseño, qué no).                          | Explica el mecanismo y contrasta con alternativas descartadas.                               |
| Ajuste al enunciado      | Responde otra cosa.                       | Responde parcial.                                            | Responde todas las sub-preguntas.                                                | Además, propone una pregunta adicional pertinente o detecta un supuesto implícito.           |

- Puntuación por pregunta = (promedio de los 3 criterios / 3) × peso.
- Nota orientativa para corrector: dos correctores independientes deben llegar al mismo puntaje ±1 por pregunta.

### 5.2 Ejercicio operativo (§3) — 25 puntos

| Criterio                                | Peso | Insuficiente (0)                                                                 | Básico (1)                                                 | Competente (2)                                                             | Experto (3)                                                                                                   |
|-----------------------------------------|------|----------------------------------------------------------------------------------|------------------------------------------------------------|----------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| `terraform validate` limpio             | 5    | No valida.                                                                       | Valida con warnings relevantes ignorados.                  | Valida limpio.                                                             | Valida limpio y además pasa `terraform fmt -check` sin cambios.                                               |
| Refactor `count` → `for_each`           | 5    | Lo deja en `count` o rompe el stack.                                             | Usa `for_each` sobre lista con `toset()` sin razonar.      | `for_each` sobre `map(object)` con clave estable (`username`).             | Además documenta en `# NOTAS` el caso donde `count` reindexa y por qué `for_each` lo evita.                   |
| `moved` block correcto                  | 3    | Falta o apunta mal.                                                              | Está pero sin comentario.                                  | Está, correcto y con `from`/`to` precisos.                                 | Además explica por qué `moved` es preferible a `terraform state mv` en PR revisable.                          |
| `validation` + tipado de variables      | 3    | Sin validation ni tipos.                                                         | Tipos declarados, sin validation.                          | Tipos declarados y validation para `environment` ∈ {dev,stg,prod}.         | Además mensaje de `error_message` claro y accionable.                                                         |
| `lifecycle { prevent_destroy = true }`  | 3    | Ausente o puesto en recurso equivocado.                                          | En `tls_private_key.ca` sin explicación.                   | En `tls_private_key.ca` con comentario de cuándo removerlo.                | Además explícito trade-off (bloquea destroy legítimos, requiere PR para removerlo).                           |
| `sensitive` correcto en outputs         | 3    | Deja la fuga de `private_key_pem` o marca todo `sensitive`.                      | Corrige uno de los dos.                                    | Corrige ambos.                                                             | Además explica en `# NOTAS` que `sensitive` oculta en CLI pero el state queda en claro.                       |
| `required_providers` y pinning          | 3    | Ausente.                                                                         | Declarado sin version.                                     | Declarado con `~> X.Y` por provider.                                       | Además incluye `required_version` coherente con las features usadas (p. ej. `moved` requiere ≥ 1.1).          |

Umbral de aprobación de este ejercicio: **18 / 25**.

### 5.3 Ejercicio arquitectónico (§4) — 34 puntos

| Criterio                               | Peso | Insuficiente (0)                                       | Básico (1)                                           | Competente (2)                                                   | Experto (3)                                                                                              |
|----------------------------------------|------|--------------------------------------------------------|------------------------------------------------------|------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| Fundamento (razona, no recita)         | 8    | Lista decisiones sin por qué.                          | Justifica solo las "obvias".                         | Justifica todas con mecanismo explícito.                         | Además nombra qué evidencia haría cambiar la decisión.                                                   |
| Ajuste al contexto (50 µs, reg., 4+12) | 7    | Diseño genérico que ignora el contexto.                | Reconoce el contexto en una o dos decisiones.        | El diseño cambia visiblemente por el contexto en 4+ decisiones.  | Además dimensiona (p. ej. "6–8 states por ambiente", no "varios states").                                |
| Trade-offs explícitos                  | 7    | No menciona alternativas descartadas.                  | Alternativas listadas sin por qué descartarlas.      | Al menos 1 alternativa descartada por decisión crítica.          | Además indica bajo qué cambio en el contexto la descartada ganaría.                                      |
| Operabilidad (día 2)                   | 6    | No habla de drift, locks, upgrades, bootstrap.         | Menciona uno de estos.                               | Cubre drift + locks + upgrades de providers/módulos.             | Además incluye SLA/alerta y runbook en una línea cada uno.                                               |
| Gobernanza y aprobación en `prod`      | 6    | "El equipo de plataforma aprueba todo" o similar.      | Describe aprobadores sin trazabilidad.               | Define quién aprueba qué por capa, con trazabilidad.             | Además distingue aprobación de policy automática (OPA/Sentinel) de aprobación humana y cuándo cada una. |

Umbral de aprobación de este ejercicio: **24 / 34**.

### 5.4 Ponderación global

- Conceptual: 41
- Operativo: 25
- Arquitectónico: 34
- **Total: 100.** **Umbral general: 70.**
- Para aprobar hay que, además del total ≥ 70, no reprobar ningún ejercicio por debajo de su umbral individual (§5.2 y §5.3).

---

## 6. Guía de corrección (instructor-only)

> No distribuir junto con el examen al candidato.

### 6.1 Respuestas modelo — conceptual

**P1 (for_each vs count).**
Modelo: (a) Reindexa todos los índices > 0: destroy+create en cascada porque `count.index` es la identidad del recurso. (b) Con `for_each` sobre `{ for u in var.users : u.username => u }`, la identidad es la clave; insertar un usuario es un add puro, los demás quedan intactos. (c) `count = var.enabled ? 1 : 0` para "toggle" de recurso único es un uso legítimo de `count` donde `for_each` sería ceremonia.
Puntos clave: identidad por índice vs por clave; "no-op" tras insert; toggle como caso válido de `count`.
Parcial aceptable: solo (a) y (b) sin (c) → 2/3 criterios.
Red flag: afirmar que `for_each` requiere `toset()` siempre (no es cierto para mapas).

**P2 (workspaces para prod).**
Modelo (riesgos): (1) mismo backend y bucket → una policy IAM mal escrita o un `force-unlock` indebido afecta prod. (2) mismas credenciales en el runner → cualquier compromiso cruza ambientes. (3) `terraform workspace select` es un flag humano fácil de equivocar; no hay separación física. (4) outputs se cruzan en el mismo state file (no es cierto por workspace, pero sí comparten bucket y lock table). (5) imposibilidad de aplicar policies IAM por "ambiente" sobre el backend.
Cuándo sí: feature environments efímeros creados y destruidos por CI, mismo nivel de criticidad.
Parcial: 2 riesgos genéricos → 1/3.
Red flag: "los workspaces son equivalentes a terraform cloud" (no lo son).

**P3 (prevent_destroy vs ignore_changes vs moved).**
Modelo:
- `prevent_destroy`: evita *destroy* explícito; no evita cambios in-place; no evita que el proveedor fuerce `ForceNew`. Error: usarlo en recursos efímeros (bloquea cleanup legítimo).
- `ignore_changes`: ignora drift en atributos específicos; no reconcilia (el drift queda); no cambia la identidad. Error: ponerlo en `all` cuando el problema es un atributo.
- `moved`: preserva identidad del recurso en el state tras rename/refactor; no cambia el recurso real; no sirve para cambiar tipo de recurso.
Caso del rename en prod → `moved`. Los otros dos no cambian la identidad y por tanto no evitan el replace.
Red flag: proponer `terraform state mv` por CLI sobre prod sin PR revisable.

**P4 (-target y -refresh).**
Modelo: (a) 1. Refresh: lee estado real desde providers y actualiza el state en memoria; 2. Diff: compara estado deseado (código) con estado refrescado y produce `+/-/~`. (b) `-target` recorta el grafo a un subconjunto; pierdes la garantía de que el plan es la "verdad completa"; dependencias quedan inconsistentes. (c) Cuando hay drift conocido y querés reconciliar el state con la realidad sin ejecutar cambios en el código.
Red flag: decir que `-target` "es seguro si sabés lo que hacés" sin matizar.

**P5 (lock colgado).**
Modelo: (a) Verificar que ningún runner esté vivo (CI dashboard, procesos locales, logs). (b) Si otra sesión escribe mientras hacés unlock, el state puede quedar inconsistente (dos writers). (c) S3 native locking elimina la tabla aparte; semánticamente similar; operativamente, menos piezas que mantener.
Red flag: hacer `force-unlock` como primera medida sin verificar.

**P6 (checkov vs Rego sobre plan JSON).**
Modelo: (a) Reglas que dependen de *valores computados* (p. ej. IDs/ARNs resueltos, interpolación cruzada entre módulos, counts resueltos). Solo el plan JSON los resuelve. (b) Reglas de estilo/forma: ausencia de tags, naming, módulos deprecados. (c) Static en PR (barato, rápido, falla pronto); plan JSON policy en PR tras `plan` (más caro) y gating duro en merge. Apply queda para policies de último recurso (p. ej. Sentinel sobre runs).
Red flag: proponer correr Checkov sobre el plan JSON (no es su función).

**P7 (plan guardado + OIDC).**
Modelo: (a) Evita TOCTOU: entre que humano revisa el plan y se aprueba, el estado real podría cambiar; aplicar el plan guardado garantiza que lo aprobado = lo aplicado. (b) OIDC: credenciales efímeras (minutos), sin secret persistente que robar, auditoría por request, rotación "gratis". (c) En self-hosted compartido, el runner mismo es el perímetro: otro job puede leer el token activo, o el host puede ser pivot. Mitigar con runners efímeros y aislamiento.
Red flag: "OIDC es inseguro porque no hay password" (confusión conceptual).

### 6.2 Ejercicio operativo — pointer a solución

- `versions.tf`: `required_version = ">= 1.6"`, bloque `required_providers` con `random ~> 3.6`, `tls ~> 4.0`, `null ~> 3.2`, `local ~> 2.5` (las versions concretas pueden variar; se puntúa el pinning, no el número).
- `variables.tf`:
  - `variable "environment"` con `type = string` y `validation { condition = contains(["dev","stg","prod"], var.environment)  error_message = "environment must be one of: dev, stg, prod." }`.
  - `variable "users"` con `type = map(object({ role = string, email = string }))` y default coherente.
- `main.tf`:
  - `moved { from = random_pet.application  to = random_pet.app }`.
  - `null_resource "aws_null_users"` con `for_each = var.users` y `triggers = { username = each.key, role = each.value.role }`.
  - `tls_private_key.ca` con `lifecycle { prevent_destroy = true }` y comentario.
  - `null_resource "security_group_sim"` con `dynamic "ingress"` usando `for_each = { for r in var.ingress_rules : r.port => r }` y `content { ... ingress.value.port ... }` (iterator por defecto = nombre del bloque dynamic).
  - Eliminar o apuntar correctamente el `replace_triggered_by` en `broken_lifecycle` para que no fuerce replace cíclico.
- `outputs.tf`: `ca_private_key_pem` con `sensitive = true`; `name_prefix` sin `sensitive`.
- `# NOTAS` cubre: identidad estable con `for_each`; `prevent_destroy` evita destroy pero no in-place; `sensitive` oculta CLI pero no state.

### 6.3 Errores comunes y cómo puntuarlos

- **Pasar validate "comentando" el bloque dynamic**: 0 pts en ese criterio y descontar 1 pt global por evitar el problema en vez de resolverlo.
- **`for_each = toset(var.users)` con `users` list**: valida pero no es `map(object)`. Básico (1/3), no competente.
- **`moved` con `from`/`to` invertidos**: 0 pts en ese criterio; red flag por no entender la dirección del rename.
- **`prevent_destroy` en todos los recursos**: señal de "no entiende qué protege". Básico máximo.
- **Marcar todo `sensitive`**: idem. Básico máximo en `outputs`.
- **No tocar `broken_lifecycle`**: el `validate` igual pasa pero el plan sería un replace infinito. Documentarlo en `# NOTAS` cuenta como paliativo (Competente), corregirlo cuenta como Experto.

### 6.4 Señales de "respondió sin entender"

- Copió nombres literales del enunciado sin adaptar (p. ej. deja `aws_null_users` en vez de `null_resource.users` tras refactor).
- `validation` que acepta cualquier string ("longitud > 0").
- ADR arquitectónico que repite palabra por palabra términos del scenario sin aterrizarlos.
- Fragmentos HCL en el ADR que no compilarían (nombres de recursos inventados sin provider plausible).

### 6.5 Red flags que invalidan la entrega (puntuación 0 global)

- Secretos hardcodeados en cualquier archivo (tokens, access keys, aunque sean "falsos" con formato real).
- IDs reales de cuenta/tenant/suscripción en el ADR o en el stack.
- `terraform state rm` o `force-unlock` propuestos como primera respuesta en el ADR sin matizar.
- `cluster-admin` o roles tipo `*:*` en policies/ejemplos sin razón.
- `curl | bash` desde fuente no verificada en cualquier script o comentario.
- Proponer compartir credenciales cloud entre runners o entre ambientes.
- Entrega generada por LLM sin adaptación (indicio: nombres genéricos, decisiones contradictorias entre secciones).

### 6.6 Preguntas de seguimiento (si evaluación live)

Para distinguir memorización de comprensión; el instructor elige 2–3 según el perfil del candidato.

**Sobre P1/operativo (for_each):**
- "Si `var.users` fuera un `map` con 1000 entradas y quitamos una del medio, ¿cuál es el costo del plan?"
- "¿Qué pasa si dos claves distintas apuntan a objetos con el mismo `email`? ¿Es un problema de Terraform?"

**Sobre P3/operativo (lifecycle/moved):**
- "¿Cómo distingues en code review que un `moved` block es correcto sin ejecutar el plan?"
- "Si `prevent_destroy = true` bloquea un `apply` legítimo que ya pasó aprobación, ¿cuál es el workflow?"

**Sobre P4 (plan internals):**
- "Mostrás un `plan` con `~ update in-place` donde esperabas no-op. ¿Cómo descartás si es drift vs cambio de código?"
- "¿Qué información del `terraform show -json` usarías para una policy que detecte creación de recursos públicos?"

**Sobre P5 (locking):**
- "El `force-unlock` falló con 'lock still held by another process'. ¿Qué significa concretamente?"
- "¿Qué cambia en tu runbook si el backend es S3 native locking vs DynamoDB?"

**Sobre P7 / arquitectónico (CI/CD):**
- "El plan guardado tiene 7 días. ¿Lo aplicás o replaneás? ¿Qué política escribís?"
- "Un equipo pide poder hacer `apply` manual desde su laptop a `stg` para debuggear. ¿Qué permitís y qué no?"

**Sobre arquitectónico (state splitting):**
- "Un microservicio necesita atributos de otro state. ¿Terraform `remote_state` data source, outputs publicados a un bucket, service discovery? Elegí uno y defendelo."
- "Dos equipos quieren modificar el mismo módulo golden al mismo tiempo. ¿Cómo evitás que uno rompa al otro?"

---

## Instrucciones de entrega

1. Resuelve §2 en un `respuestas-conceptuales.md`.
2. Resuelve §3 editando los archivos en `operative/` y agregando el bloque `# NOTAS`.
3. Resuelve §4 en un `architectural/ADR.md`.
4. Comprime todo (o entrega el repo) con la estructura:

```
entrega-<tu-nombre>/
  respuestas-conceptuales.md
  operative/
    main.tf
    variables.tf
    outputs.tf
    versions.tf
  architectural/
    ADR.md
```

5. **No incluyas** archivos `ANALYSIS.md`, logs de `plan` reales, credenciales, ni `*.tfstate*`.
