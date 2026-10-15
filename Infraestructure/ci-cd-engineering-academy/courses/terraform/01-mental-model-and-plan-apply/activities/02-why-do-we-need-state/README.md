# Actividad 02 — ¿Por qué una herramienta declarativa necesita state?

## 1. Identificación

- **ID:** `tf-01-02-why-do-we-need-state`
- **Tecnología:** `terraform`
- **Módulo:** `tf-01-mental-model-and-plan-apply`
- **Dificultad:** beginner
- **Duración estimada:** 40–60 min
- **Tipo:** independent

## 2. Contexto

Esta es la **segunda actividad conceptual** del módulo, independiente de la primera. No requiere Terraform instalado ni cuenta cloud.

Produces un `WRITEUP.md` que argumenta — con tus palabras — por qué una herramienta declarativa de IaC **no puede** prescindir del state, qué pasaría sin él, y por qué `apply` por sí solo no detecta todo el drift. Esta es la pregunta de evaluación explícita del módulo.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Dar al menos **tres razones distintas** por las que una herramienta declarativa necesita state.
- Imaginar qué pasaría si Terraform fuera "stateless" (preguntara al cloud cada vez) y por qué no funciona.
- Explicar qué es **drift** y por qué `apply` sin `refresh` o sin plan previo no lo detecta todo.
- Argumentar por qué el state **nunca** va a Git y por qué debe vivir en un backend remoto con locking.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` completo (al menos §4.4, §4.6 y §9).
- Haber recorrido `examples/02-plan-walkthrough-reading/`.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/tf-01-state
cd /tmp/tf-01-state
```

(Puedes usar otro directorio si pasas la ruta a `validate.sh`; el default es `/tmp/tf-01-state`.)

### 5.2 Entregable: `WRITEUP.md`

Produce un archivo `WRITEUP.md` con **cuatro secciones** explícitas:

#### A. Tres razones por las que el state es necesario

Argumenta — en un párrafo cada una, con ejemplos concretos — por qué una herramienta declarativa de IaC necesita un state persistente. Como mínimo, aborda:

- El **mapeo** entre nombres en HCL y IDs en el cloud (`aws_instance.web` ↔ `i-0abc1234...`).
- Los **atributos computados** que solo existen tras crear (ID, ARN, IP, fingerprint).
- La **falta de listado barato o preciso** en muchas APIs (y la dificultad de distinguir "mis" recursos de los de otros).

Si quieres bonus, añade una cuarta razón: metadata interna (schema version de recursos, outputs sensibles, relaciones que el provider no re-deriva del `GET`).

#### B. El experimento mental "Terraform stateless"

Imagina una versión hipotética de Terraform **sin state**: en cada `plan`, lista todo lo que hay en el cloud y lo compara con tu HCL. En 4–6 frases, explica:

- Qué recursos sabrías *con certeza* que son "tuyos".
- Qué pasaría con atributos computados (ID generado al crear).
- Qué pasaría si tu HCL declara `resource "aws_instance" "web"` y en el cloud hay tres instancias — ¿cuál es "web"?
- Qué costo tiene (en API calls, en rate limits) listar todo en cada plan.

Conclusión en una frase: ¿funcionaría? ¿Por qué no?

#### C. Drift y por qué `apply` por sí solo no lo detecta todo

Explica, en 5–8 frases:

- Qué es drift (con tus palabras).
- Un ejemplo concreto que no sea del lesson.
- Por qué si corres `apply` con `-refresh=false` **no** detectas drift.
- Por qué si corres `apply` sin ejecutar un `plan` previo, puedes aplicar sobre un drift sin verlo.
- Por qué hay drift que Terraform **jamás** detecta (tags inyectados por SCPs; atributos no mapeados por el provider).

#### D. Consecuencias operativas del state

En lista (al menos **cuatro** ítems), con una frase cada uno, enumera consecuencias prácticas de que el state exista:

- Por qué nunca va a Git.
- Por qué debe vivir en backend remoto.
- Por qué debe tener locking.
- Por qué debe estar encriptado at-rest.
- (Bonus) Por qué conviene **dividirlo por bounded context**.

### 5.3 Preguntas obligatorias (al final de `WRITEUP.md`)

Numera las respuestas **del 1 al 7**:

1. Da **dos razones** por las que una herramienta declarativa de IaC no puede ser "stateless" en la práctica. (Al menos una debe ser *distinta* de "no sabemos qué recursos ya existen".)
2. ¿Qué es un **atributo computado**? Da dos ejemplos concretos (recurso + atributo).
3. Alguien borra el `.tfstate` por accidente. La infra sigue existiendo. ¿Qué pasa en el próximo `plan`? ¿Cómo se recupera?
4. Dos personas corren `terraform apply` al mismo tiempo sobre el mismo backend sin locking. Describe un escenario en el que el state queda corrupto.
5. ¿Por qué `terraform apply` sin un `plan` previo **podría** aplicar sobre drift sin que te enteres? ¿Cuándo *sí* lo detecta?
6. Enumera **tres tipos de drift** que Terraform **jamás** verá en un plan normal.
7. Un compañero propone: "metemos el `.tfstate` en el repo para que todos lo veamos". Dale **tres** razones para rechazarlo.

### 5.4 Validar estructura

```bash
bash tests/validate.sh /tmp/tf-01-state
```

Chequea que `WRITEUP.md` exista y contenga las cuatro secciones mínimas (A, B, C, D), términos clave (state, drift, locking, backend, mapeo, computado) y las 7 respuestas numeradas. **No valida contenido semántico** — eso lo verificas contra `solution/WRITEUP-reference.md`.

## 6. Resultado esperado

- Archivo `WRITEUP.md` en `/tmp/tf-01-state/` con secciones A, B, C, D y 7 respuestas numeradas.
- `tests/validate.sh` pasa.
- Autocomparas con `solution/WRITEUP-reference.md` para calibrar.

## 7. Criterios de aceptación

- [ ] Las cuatro secciones A/B/C/D aparecen explícitas.
- [ ] Se mencionan "state", "drift", "backend", "locking", "mapeo" y "computado".
- [ ] Hay al menos un ejemplo concreto de atributo computado.
- [ ] Las 7 preguntas respondidas (como `1.`, `2.`, ... al inicio de línea).

## 8. Validación

```bash
bash tests/validate.sh /tmp/tf-01-state
```

Estructural. **Semántica** la calibras tú con `solution/WRITEUP-reference.md`.

## 9. Preguntas de reflexión

Más allá de las obligatorias:

1. Pulumi, CDK, Crossplane también gestionan infra declarativa. Investiga brevemente dónde vive el "state" en cada uno. ¿Son equivalentes al `.tfstate`?
2. Si una API cloud expusiera "listá todos los recursos con tag `terraform:true` y devolveme su schema completo", ¿bastaría para que Terraform fuera stateless?
3. ¿Qué pasaría si Terraform guardara el state **dentro** de los propios recursos como tags/anotaciones? ¿Qué ganas, qué pierdes?

## 10. Extensiones (opcional)

- **E1** — Lee la [página oficial "State: Purpose"](https://developer.hashicorp.com/terraform/language/state/purpose) y añade al `WRITEUP.md` qué razones de las que ellos dan NO salieron en tu análisis.
- **E2** — Investiga el formato del `.tfstate` en v4 (JSON) y lista los campos top-level que verías. ¿Cuáles son metadata, cuáles contenido?
- **E3** — Elige un recurso que uses (p. ej. `aws_s3_bucket`) y lista 3 atributos computados que aparecerían como `(known after apply)` en un plan inicial.

## 11. Limpieza

```bash
rm -rf /tmp/tf-01-state
```
