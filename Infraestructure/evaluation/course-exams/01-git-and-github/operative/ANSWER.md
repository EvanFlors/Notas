# Ejercicio operativo — Hoja de respuesta del candidato

> Rellena esta plantilla y entrégala junto con el repo `/tmp/exam-op` ya rebasado.

## 1. Procedimiento ejecutado

Describe en 5–10 líneas qué hiciste (comandos, orden del todo-file, decisiones). Si usaste un `solve.sh`, pégalo aquí o referencia su path.

```text
<tu procedimiento aquí>
```

## 2. ¿Por qué importa el orden en el todo-file de `rebase -i`?

Explica, con tus palabras, qué pasaría si pusieras un `fixup` *antes* de su `pick` target en este ejercicio. Describe el modo de falla concreto (qué commit terminaría con qué contenido).

```text
<tu respuesta aquí>
```

## 3. `fixup` vs. `squash`

¿Cuál es la diferencia funcional? ¿En qué escenario preferirías cada uno?

```text
<tu respuesta aquí>
```

## 4. Política de push público

Si esta rama ya estuviera pusheada y revisada por otros, ¿harías `push --force`, `push --force-with-lease`, o abandonarías el rebase? Justifica contra la regla "no reescribas historia pública" y describe el modo de falla que `--force-with-lease` evita y `--force` no.

```text
<tu respuesta aquí>
```

## 5. (Opcional, puntúa Experto) `solve.sh` reproducible

Si incluiste un `solve.sh` que automatiza el rebase con `GIT_SEQUENCE_EDITOR`, pégalo aquí o referencia su path. Explica brevemente por qué esto es útil (CI, demos, repetibilidad).
