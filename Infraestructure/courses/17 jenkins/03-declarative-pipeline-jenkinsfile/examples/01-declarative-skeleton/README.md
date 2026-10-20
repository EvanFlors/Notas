# Ejemplo 01 — Esqueleto Declarative

> Lectura y análisis. Fija en memoria los **bloques top-level** del Declarative Pipeline y el orden recomendado.

## 1. Qué muestra

El `Jenkinsfile` adjunto incluye todos los bloques que puedes encontrar en un pipeline declarative:

| Bloque | Rol |
|--------|-----|
| `agent any` | Dónde corre el pipeline (en este caso, cualquier executor). |
| `options { ... }` | Timeout, concurrencia, retención de builds, timestamps en logs. |
| `parameters { ... }` | Formulario para el usuario que lanza el build (`ENV`, `SKIP_TESTS`). |
| `environment { ... }` | Variables disponibles en todos los steps. |
| `triggers { ... }` | Qué dispara el pipeline (`pollSCM` cada 5 min en este caso). |
| `stages { stage { steps { ... } } }` | Las fases del pipeline. |
| `post { always/success/failure/changed }` | Qué hacer al terminar, pase lo que pase. |

## 2. Lectura clave

1. **El orden importa para la legibilidad**, no para el parser. `agent` siempre primero, `post` siempre al final. En medio: `options`, `parameters`, `environment`, `triggers`, `tools`, `stages`.
2. **`archiveArtifacts` y `junit` llevan `allowEmptyResults`/`allowEmptyArchive`** para que el stage no falle sólo porque un build sin tests no generó el XML.
3. **`when { not { expression { ... } } }`** demuestra que `when` acepta cualquier expresión Groovy. Útil pero peligroso: una expresión opaca es tan ilegible como un `if` suelto.
4. **`post { always }` no sustituye a `post { success/failure }`**. `always` corre siempre; los otros filtran según el resultado final.

## 3. Qué **no** muestra (y dónde se ve)

- Agent por `stage` (`agent none` + `agent` por stage) → ejemplo `02-parallel-stages`.
- Credenciales inyectadas con `withCredentials` → ejemplo `03-withcredentials-vault`.
- Gates manuales con `input` → actividad `02-add-manual-gate`.

## 4. Preguntas de autocomprobación

1. ¿Qué pasa si quitas `allowEmptyResults: true` del `junit` y el stage de test se salta por `SKIP_TESTS=true`?
2. ¿Por qué `buildDiscarder` es una `option` y no un `trigger`?
3. ¿Qué diferencia hay entre poner `environment { }` al nivel de `pipeline` vs al nivel de un `stage`?
4. Si el stage `Build` falla, ¿se ejecuta `post { success }`? ¿Y `post { changed }`?
