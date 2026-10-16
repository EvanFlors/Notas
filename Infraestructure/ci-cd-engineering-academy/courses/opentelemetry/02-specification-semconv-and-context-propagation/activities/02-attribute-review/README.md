# otel-02-02 — Attribute review

## 1. Identificación

- **ID:** `otel-02-02-attribute-review`
- **Tecnología:** `opentelemetry`
- **Módulo:** `02-specification-semconv-and-context-propagation`
- **Dificultad:** beginner
- **Duración estimada:** 40 min
- **Tipo:** independent

## 2. Contexto

Un equipo propone una lista de 15 atributos para instrumentar un servicio `checkout-api`. Vienen mezclados: algunos son Resource, otros son semconv estándar, otros son custom razonables, y **unos cuantos son horrores** (PII en claro, alta cardinalidad, nombres mal escritos).

Tu misión es revisar la lista como lo haría la **plataforma de observabilidad** antes de dar luz verde.

## 3. Objetivos

- Clasificar cada atributo propuesto en una de 4 categorías: `RESOURCE`, `SEMCONV`, `CUSTOM_OK`, `REJECT`.
- Para cada `REJECT`, explicar la razón (PII, cardinalidad, naming, redundante con otro).
- Producir una lista final limpia que irá al runbook del servicio.

## 4. Prerrequisitos

- Haber leído `theory/lesson.md`, secciones 4, 5, 8 y 11.
- `python3`. **SKIP si falta.**
- `bash`, `grep`.

## 5. Instrucciones

1. **Genera la propuesta**:

   ```bash
   cd "$(git rev-parse --show-toplevel)/courses/opentelemetry/02-specification-semconv-and-context-propagation/activities/02-attribute-review"
   bash starter/build-proposal.sh
   ```

   Esto crea `/tmp/otel-02-02-review/proposal.md` con los 15 atributos y una plantilla `review.md` para tu respuesta.

2. **Lee `proposal.md`** y edita `/tmp/otel-02-02-review/review.md`:

   - Para cada atributo, añade una línea de la forma: `<name>: <RESOURCE|SEMCONV|CUSTOM_OK|REJECT> — <razón breve>`.
   - Al final, añade una sección **"Final clean list"** con los atributos que sobreviven.

3. **Valida**:

   ```bash
   bash tests/validate.sh
   ```

**No consultes `solution/`** hasta haber producido tu review.

## 6. Resultado esperado

- `/tmp/otel-02-02-review/review.md` existe y pasa `tests/validate.sh`.
- Cada uno de los 15 atributos tiene veredicto.
- Los 4-5 atributos "venenosos" quedan marcados `REJECT` con razón explícita.

## 7. Criterios de aceptación

- `tests/validate.sh` exit 0 con `RESULT: OK`.
- Al menos 4 atributos marcados `REJECT`.
- Al menos 2 atributos clasificados como `RESOURCE` correctamente.

## 8. Validación

```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Qué proceso tendrías en tu organización para que esta revisión no dependa de "una persona con criterio"? ¿Un linter? ¿Un review en PR?
2. ¿Qué pasaría si `userEmail` sigue en span attributes y acabas exportándolo a un backend SaaS? ¿Es sólo un problema técnico o legal?
3. ¿Cómo detectarías *post facto* que entró un atributo high-cardinality a producción (síntoma)?
4. ¿Cuál sería tu convención para prefijar atributos custom de tu organización?

## 10. Extensiones

- Escribe la configuración de un **`attributes` processor** del Collector que elimine los atributos `REJECT` como última red de seguridad.
- Proponé una regla CI que grepee strings prohibidos (`email`, `ssn`, `password`) en los PRs que tocan código de instrumentación.

## 11. Limpieza

```bash
rm -rf /tmp/otel-02-02-review
```
