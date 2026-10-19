# Ejemplo 01 — `workflow:` top-level: evitar pipelines duplicados en MR

> Lectura y análisis. Sin ejecución. Objetivo: ver un `workflow:` que resuelve el problema clásico "doble pipeline en MR" y filtra por fuente.

## 1. El problema

Sin `workflow:`, un commit a una branch con MR abierto dispara **dos pipelines**:

- Uno por el push a la branch (`$CI_PIPELINE_SOURCE == "push"`).
- Otro por el update del MR (`$CI_PIPELINE_SOURCE == "merge_request_event"`).

Mismo commit, mismo trabajo, el doble de minutos de runner y notificaciones duplicadas.

## 2. La solución

```yaml
workflow:
  name: "pipeline for $CI_COMMIT_REF_NAME"
  rules:
    # 1) MR pipelines: siempre correr.
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"

    # 2) Default branch: siempre correr (push a main / tag en main).
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

    # 3) Branch con MR abierto: NO correr pipeline de push (lo cubre el del MR).
    - if: $CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS
      when: never

    # 4) Fallback: branches sin MR, correr.
    - if: $CI_COMMIT_BRANCH

    # 5) Tags: correr siempre.
    - if: $CI_COMMIT_TAG

build:
  stage: build
  script: echo "build $CI_COMMIT_SHORT_SHA"

test:
  stage: test
  script: echo "test"
```

## 3. Lectura

1. La regla #3 es la que corta el "doble pipeline": si existe un MR abierto, el pipeline de la **branch** se descarta (`when: never`) porque el MR ya ejecutará las mismas pruebas sobre el mismo commit.
2. Las reglas son **evaluadas de arriba abajo** y gana la primera que matchea. Por eso #1 y #2 van antes del `when: never`.
3. `workflow:` **no** necesita saber qué jobs existen. Si decide que no hay pipeline, ningún `rules:` por job se evalúa.

## 4. Diagnóstico

- Si ves "pipelines fantasma" después de merger a `main`, revisa que `$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH` esté arriba.
- Si un push ya no dispara nada en una feature branch con MR cerrado, revisa `$CI_OPEN_MERGE_REQUESTS` (no debería valer true si el MR está cerrado).
- Para debuggear qué variable vale qué, añade un `job: echo-vars` con `script: env | sort | grep ^CI_`.

## 5. Ejercicio de lectura

¿Qué pasa en estos escenarios?

| Evento | Pipeline creado | Por qué |
|--------|-----------------|---------|
| Push a `feature/x` sin MR | SÍ (regla 4) | Branch sin MR abierto → fallback. |
| Push a `feature/x` con MR abierto | NO (regla 3) | Hay MR; el pipeline de MR cubre el commit. |
| Create MR desde `feature/x` | SÍ (regla 1) | `merge_request_event`. |
| Merge a `main` | SÍ (regla 2) | push a default branch. |
| Tag `v1.0.0` | SÍ (regla 5) | `$CI_COMMIT_TAG` presente. |

En `gl-05` se verá cómo factorizar este `workflow:` como `include:` reutilizable para toda la org.
