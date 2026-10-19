# Ejemplo 02 — Parallel stages y agent por stage

> Lectura y análisis. Enseña a partir checks baratos en paralelo y a usar `agent none` + `agent` por `stage` sin romper el flujo de archivos entre fases.

## 1. Qué muestra

- **`agent none`** al nivel de pipeline + **`agent` por `stage`** (cada stage declara su contenedor o label).
- **`stash` / `unstash`** para compartir el checkout entre stages que corren en workspaces distintos.
- **`parallel { }`** con tres sub-stages (lint, typecheck, SBOM) y **`failFast true`** para cortar los demás si uno falla.
- **`when { beforeAgent true; branch 'main' }`** para evitar levantar el agent Docker en PRs que nunca van a construir imagen.
- **`post { always { junit ... } }`** publicando los resultados aunque el stage falle.

## 2. Lectura clave

1. **El `stash` desde `Checkout` es obligatorio** cuando cada stage usa un agent distinto. Sin él, los stages paralelos no verían el código.
2. **`failFast true`** aborta los sibling stages del `parallel` en cuanto uno falla. Útil para bajar coste de CI, peligroso si uno de los sibling genera un artefacto que necesitas aunque los demás fallen.
3. **`beforeAgent true`** evalúa el `when` **antes** de levantar el agent. Para contenedores de 500 MB que tardan 30 s en pullear, la diferencia es brutal en PRs masivas.
4. **`npm ci` en cada stage paralelo** es redundante. En un proyecto real, se baja a Shared Library o se cachea `node_modules` con `stash` tras el primer `npm ci`.

## 3. Qué **no** muestra (y dónde se ve)

- Credenciales inyectadas (p. ej. para hacer `docker push`) → ejemplo `03-withcredentials-vault`.
- Gates manuales previos al push → actividad `02-add-manual-gate`.
- Agents efímeros en Kubernetes (`agent { kubernetes { yaml ... } }`) → `jk-05`.

## 4. Preguntas de autocomprobación

1. Si quitas `failFast true`, ¿cambia el **resultado final** del build cuando uno de los sibling falla?
2. ¿Por qué `beforeAgent true` sólo tiene sentido cuando el `when` depende de **branch** o **expression** sin estado, y no cuando depende de un `environment` que se calcula en `stages` anteriores?
3. Si el stage `Checkout` usa `label 'linux'` y `Lint` usa `docker { image 'node:20-alpine' }`, ¿comparten workspace? Si no lo comparten, ¿qué mecanismo rellena esa laguna?
4. ¿Qué hace exactamente `archiveArtifacts fingerprint: true`?
