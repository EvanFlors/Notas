# Actividad 01 — Dibujar el ciclo `init → plan → apply → destroy`

## 1. Identificación

- **ID:** `tf-01-01-draw-the-cycle`
- **Tecnología:** `terraform`
- **Módulo:** `tf-01-mental-model-and-plan-apply`
- **Dificultad:** beginner
- **Duración estimada:** 40–60 min
- **Tipo:** independent

## 2. Contexto

Esta es la actividad **conceptual** del módulo. No requiere Terraform instalado, ni cuenta cloud, ni Linux: se puede completar en cualquier editor de texto.

Se trata de producir un **mapa anotado** que demuestra que entendiste el ciclo declarativo. Si no puedes dibujarlo con tus palabras, no lo entiendes todavía.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Dibujar el ciclo `init → plan → apply → destroy` como un diagrama ASCII.
- Para cada fase, decir **qué toca** y **qué no toca** (estado deseado / state / infra real).
- Nombrar los símbolos `+`, `-`, `~`, `-/+` y qué significa cada uno.
- Explicar qué pasa en `refresh` dentro del `plan`.
- Explicar por qué `init` tiene que ejecutarse al menos una vez antes del primer `plan`.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` completo (al menos §4 y §5).
- Haber recorrido `examples/01-declarative-vs-imperative-pseudocode/`.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/tf-01-cycle
cd /tmp/tf-01-cycle
```

(Puedes usar otro directorio si pasas la ruta a `validate.sh`; el default es `/tmp/tf-01-cycle`.)

### 5.2 Entregable: `MAP.md`

Produce un archivo `MAP.md` con **cuatro secciones** explícitas:

#### A. Los tres estados

Dibuja (ASCII) y explica brevemente los tres estados que Terraform coordina:

- **Estado deseado** (tus `.tf`, en Git).
- **State** (`.tfstate`, lo que Terraform cree que hay).
- **Infra real** (lo que realmente existe en el cloud/SaaS).

Para cada uno responde: **¿quién lo escribe? ¿quién lo lee? ¿dónde vive?**

#### B. El ciclo `init → plan → apply → destroy`

Dibuja un diagrama ASCII del ciclo. Para **cada** fase (`init`, `plan`, `apply`, `destroy`) escribe:

- **Qué hace** en términos de los tres estados de la sección A.
- **Qué toca** (lectura de API, escritura de API, lectura de disco, escritura de disco).
- **Qué NO toca** (importante: `init` no toca infra real, `plan` solo lee, …).

Dentro de **`plan`**, llama explícitamente la sub-fase **`refresh`** y di qué hace.

#### C. Los símbolos del plan

Lista **al menos cinco** símbolos/anotaciones que aparecen en el output de un plan:

- `+`
- `-`
- `~`
- `-/+`
- `<=` (data source read)
- `# forces replacement` (opcional, pero bonus)
- `(known after apply)` (opcional, pero bonus)

Para cada uno, una frase: qué significa y **quién decide** que aparezca (core vs provider).

#### D. Idempotencia y drift

En 3–5 frases cada uno:

- Qué es **idempotencia** aplicada a Terraform.
- Qué es **drift** y da un ejemplo concreto.

### 5.3 Preguntas obligatorias (al final de `MAP.md`)

Numera las respuestas **del 1 al 7**:

1. ¿Qué pasa en `init` que es necesario para que el `plan` pueda ejecutarse? Nombra al menos tres cosas.
2. Durante `plan`, ¿se llama a la API cloud? Si sí, ¿para qué? ¿Se escribe algo?
3. Un `apply` tarda 10 minutos y falla a la mitad. ¿Qué queda en la infra real? ¿Qué queda en el state? ¿Es "todo o nada"?
4. Explica el significado de `-/+` y da un ejemplo concreto (atributo + tipo de recurso) donde aparecería.
5. Un atributo del output del plan aparece como `(known after apply)`. ¿Por qué? ¿Cuándo se "sabrá"?
6. Describe un escenario de **drift**. ¿Qué muestra el próximo `plan`? ¿Qué pasa si corres `apply` sin leerlo?
7. ¿Por qué `destroy` es "un caso particular" de `plan + apply` y no una operación distinta?

### 5.4 Validar estructura

```bash
bash tests/validate.sh /tmp/tf-01-cycle
```

Chequea que `MAP.md` exista y contenga las cuatro secciones mínimas (A, B, C, D), los nombres de las fases, los símbolos del plan y las 7 respuestas numeradas. **No valida contenido semántico** — eso lo verificas contra `solution/MAP-reference.md`.

## 6. Resultado esperado

- Archivo `MAP.md` en `/tmp/tf-01-cycle/` con secciones A, B, C, D y 7 respuestas numeradas.
- `tests/validate.sh` pasa.
- Autocomparas con `solution/MAP-reference.md` para calibrar.

## 7. Criterios de aceptación

- [ ] Los tres estados (deseado, state, infra real) aparecen nombrados.
- [ ] Las cuatro fases (`init`, `plan`, `apply`, `destroy`) aparecen nombradas.
- [ ] `refresh` se menciona como sub-fase del `plan`.
- [ ] Los símbolos `+`, `-`, `~`, `-/+` aparecen explicados.
- [ ] "drift" e "idempotencia" aparecen con una definición propia.
- [ ] Las 7 preguntas respondidas (como `1.`, `2.`, ... al inicio de línea).

## 8. Validación

```bash
bash tests/validate.sh /tmp/tf-01-cycle
```

Estructural. **Semántica** la calibras tú con `solution/MAP-reference.md`.

## 9. Preguntas de reflexión

Más allá de las obligatorias:

1. Si Terraform *no* tuviera `refresh` y asumiera que el state es siempre correcto, ¿qué podría salir mal?
2. ¿Qué pasaría si dos personas corren `apply` al mismo tiempo sobre el mismo state (sin locking)?
3. ¿Por qué el **plan** no se puede eliminar y aplicar directamente en `apply`? ¿Qué perderías?

## 10. Extensiones (opcional)

- **E1** — Añade un diagrama alternativo donde el ciclo se corre desde CI (plan en PR, apply en merge). Marca dónde vive el state y dónde las credenciales.
- **E2** — Dibuja qué pasa si se corre `terraform plan -refresh=false`. ¿Qué deja de detectarse?
- **E3** — Lee `examples/02-plan-walkthrough-reading/` otra vez y, en un apartado nuevo de `MAP.md`, inventa un plan corto (3–4 recursos) con al menos un `~`, un `-/+` y un `+`.

## 11. Limpieza

```bash
rm -rf /tmp/tf-01-cycle
```
