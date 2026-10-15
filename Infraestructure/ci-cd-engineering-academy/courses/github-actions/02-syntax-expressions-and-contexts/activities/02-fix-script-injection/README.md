# Actividad 02 — Fix script injection

## 1. Identificación

- **ID:** `gha-02-02-fix-script-injection`
- **Tecnología:** `github-actions`
- **Módulo:** `02-syntax-expressions-and-contexts`
- **Dificultad:** beginner
- **Duración estimada:** 30–45 min
- **Tipo:** independent

## 2. Contexto

Un repo tiene un workflow que corre en cada PR y "saluda" al contribuidor imprimiendo el título del PR y el nombre de la rama de origen. Funciona bien… hasta que alguien abre un PR con un título especial. Esta es la **evaluación oficial del módulo**: tienes que detectar la vulnerabilidad y arreglarla.

No miras `solution/` hasta tener tu arreglo validando.

## 3. Objetivos

Al terminar:
- Identificas **todas** las interpolaciones inseguras del starter.
- Aplicas el patrón `env:` + `"$VAR"` en cada caso.
- Pasas el validador, que incluye un **detector grep** y checks de que los steps aún imprimen la información esperada.
- Puedes explicar por escrito la vulnerabilidad y los dos arreglos (env var vs `actions/github-script`).

## 4. Prerrequisitos

- `gha-02-01` completado.
- Haber leído la sección 10 de `theory/lesson.md` y el ejemplo `examples/03-safe-vs-unsafe-interpolation/`.
- Git y `python3`.
- `actionlint` recomendado pero no obligatorio.
- Costo: $0.

## 5. Instrucciones

### 5.1 Preparar

```bash
MODE=local bash starter/bootstrap.sh /tmp/gha-02-02
```

Esto deja en `/tmp/gha-02-02/local/.github/workflows/greet.yml` el **workflow vulnerable** tal cual se encontró en el "repo real" (ficticio).

### 5.2 Encuentra la vulnerabilidad

Abre `greet.yml` y busca los `${{ ... }}` dentro de bloques `run:`. Pregúntate: *¿este valor viene del autor del PR?* Si la respuesta es sí o "podría", es injection.

Guía:

- `github.event.pull_request.title` — **sí**, controlado por el autor.
- `github.event.pull_request.head.ref` — **sí**, nombre de rama controlable (incluso con `;` y backticks).
- `github.event.pull_request.body` — **sí**.
- `github.sha` — no, es un SHA calculado por GitHub.
- `github.repository` — no, es el nombre del repo (constante).

### 5.3 Arregla

Para **cada** interpolación insegura:

1. Mueve el valor a un `env:` del step (clave con `UPPER_SNAKE_CASE`).
2. Consúmelo en `run:` como `"$VAR"` entre **comillas dobles**.
3. Si vas a imprimirlo con `printf '%s\n'` mejor aún.

No cambies la **estructura** del workflow ni los nombres de steps.

### 5.4 Verifica

```bash
MODE=local bash tests/validate.sh /tmp/gha-02-02
```

Debe pasar. Si falla, el reporte dice qué línea sigue siendo insegura.

### 5.5 Entregable escrito

En `/tmp/gha-02-02/local/EXPLANATION.md`, escribe (puede ser bullets, no es un ensayo):

1. Un payload de título de PR que explotaría el starter.
2. Por qué GitHub permite esta expansión (modelo de ejecución).
3. Los dos arreglos canónicos (env var + `actions/github-script`) con un snippet mínimo de cada uno.
4. Qué otro campo del evento sería atacable y cómo lo trataríamos.

El validador exige que exista este archivo y tenga al menos 20 líneas no vacías.

## 6. Resultado esperado

- `greet.yml` sin ninguna ocurrencia de `${{ github.event.*.title|body|head.ref|head.label|comment.body|head_commit.message }}` dentro de un bloque `run:`.
- Cada valor movido a `env:` del step y referenciado como `"$VAR"`.
- `EXPLANATION.md` presente.
- `actionlint` (si disponible) sin errores.

## 7. Criterios de aceptación

- [ ] Detector no encuentra interpolaciones peligrosas en bloques `run:`.
- [ ] Los steps siguen funcionando (verificado por checks estructurales: el `name:` y el `id:` se preservan).
- [ ] Al menos un step usa un `env:` nuevo con una variable derivada de `github.event.pull_request.*`.
- [ ] `EXPLANATION.md` existe con ≥ 20 líneas no vacías.
- [ ] YAML válido.

## 8. Validación

```bash
MODE=local bash tests/validate.sh /tmp/gha-02-02
```

## 9. Preguntas de reflexión

1. Si tu equipo mantiene 40 workflows, ¿cómo escalarías la detección? Pistas: `actionlint` como pre-commit, action de org required, scan periódico.
2. ¿Qué ventajas tiene `actions/github-script` sobre el patrón env var cuando el valor es un **JSON anidado** (p. ej. labels del PR)?
3. ¿Qué cambia si el workflow usa `pull_request_target` en vez de `pull_request`? ¿Por qué el riesgo es mucho mayor?
4. GitHub podría **auto-escapar** las interpolaciones peligrosas. ¿Por qué no lo hace? Pista: hay varios shells, varias actions, el escape depende del consumidor.
5. ¿Cómo detectarías el mismo patrón pero dentro del `script:` de `actions/github-script`?

## 10. Extensiones (opcional)

- **E1** — Rehaz el workflow usando **`actions/github-script`** en lugar de env vars. Compara readability.
- **E2** — Añade `permissions: contents: read` a nivel workflow (principio de mínimo privilegio).
- **E3** — Añade un step inicial que valide con regex que `github.event.pull_request.head.ref` solo contiene `[A-Za-z0-9/_-]` y falle si no, usando `actions/github-script`.
- **E4** — Integra `actionlint` como step del propio workflow (self-lint).

## 11. Limpieza

```bash
rm -rf /tmp/gha-02-02
```
