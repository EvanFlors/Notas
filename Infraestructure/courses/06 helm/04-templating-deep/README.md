# helm-04 — Templating en profundidad

## Identificación

- **ID:** `helm-04-templating-deep`
- **Nivel:** intermedio
- **Duración estimada:** 5 h
- **Prerrequisitos:** `helm-03-chart-anatomy` (chart propio funcional con `Chart.yaml`, `values.yaml`, `templates/`).

## Objetivo

Dominar Go templates aplicados a YAML con seguridad: escribir templates idiomáticos sin caer en "yaml hell", refactorizar duplicación a `_helpers.tpl` siguiendo las convenciones estándar de Helm, y diagnosticar errores de render a partir del output y el template.

## Temas y subtemas

1. **Sintaxis Go templates** — delimitadores `{{ }}`, control de whitespace con `-`, pipelines `|`, comentarios `{{/* ... */}}`.
2. **Objetos built-in** — `.Values`, `.Chart`, `.Release`, `.Files`, `.Capabilities`, `.Template`.
3. **Funciones built-in y Sprig** — `default`, `required`, `quote`, `toYaml`, `nindent`, `indent`, `tpl`, `include`, `tuple`, `list`, `len`, `b64enc`, `sha256sum`, `trimSuffix`, `trunc`.
4. **Control de flujo** — `if/else if/else`, `with` (y su cambio de scope), `range` (sobre listas y mapas), `break`/`continue`.
5. **Scoping** — qué es `.`, cuándo cambia, uso de `$` para raíz, variables `$name := ...`.
6. **Named templates** — `define`, `template` (acción, no se puede pipear), `include` (función, sí se puede pipear a `nindent`, `trim`, etc.) y por qué `include` suele preferirse.
7. **`_helpers.tpl`** — nombres estándar (`<chart>.fullname`, `<chart>.labels`, `<chart>.selectorLabels`, `<chart>.serviceAccountName`), chart name truncation a 63 chars (DNS label), `.Chart.Name`/`.Release.Name` combinados.
8. **Errores comunes** — indentación (lista vs mapa anidado), `null` vs ausencia, `nindent` olvidado, comillas en strings numéricos ("1" vs 1), uso de `with` ocultando el root.
9. **`helm template --debug`** — render local sin cluster, resolución de errores de parse vs runtime.
10. **`helm lint`** — qué cubre y qué no (estilo + estructura; no detecta semántica de K8s).
11. **`required "msg" .Values.x`** — falla al render si falta; fundamental para evitar surprises en producción.
12. **`tpl`** — renderizar strings de values como templates (p. ej. annotations dinámicas desde `values.yaml`).

## Conceptos internos (fundamentos)

- **`template` vs `include`.** `template` es una acción del lenguaje: emite output pero no retorna un valor; por tanto no se puede componer con pipelines (`template ... | nindent 4` es un error de parse). `include` es una función que *retorna* el string renderizado, encajando en pipelines. Esto es la razón por la que `_helpers.tpl` casi siempre se consume con `include`.
- **`required` corta el render.** Es la forma correcta de hacer "campos obligatorios" en el contrato de un chart. Sin él, un `.Values.x` ausente simplemente renderiza vacío o `<no value>` y K8s falla aguas abajo con un error poco informativo.
- **Scoping con `with`.** `with .Values.image` cambia `.` dentro del bloque, dejando el root inaccesible salvo por `$`. Es una fuente clásica de bugs: dentro de un `with`, `.Release.Name` ya no existe — hay que escribir `$.Release.Name`.
- **Indentación y YAML.** El rendering es textual; Helm no sabe YAML. `toYaml .Values.foo | nindent 4` produce un bloque alineado a 4 espacios con newline al inicio. `indent` NO antepone newline; `nindent` SÍ. Confundirlos es el bug #1 de principiantes.
- **`tpl` para strings-con-template-dentro.** Permite que un consumidor del chart ponga `{{ .Release.Name }}` dentro de un value y se interpole en render. Útil para anotaciones por entorno.

## Competencias

- **Conceptual.** Explicar la diferencia entre `template` e `include`; cuándo usar `required` vs `default`; por qué `nindent` existe.
- **Operativa.** Escribir un `_helpers.tpl` idiomático; refactorizar duplicación de labels/selectors; depurar errores de render con `--debug`.
- **Arquitectónica.** Diseñar el "contrato" de values para que el chart sea robusto a inputs incompletos y claro para quien lo consume.

## Ejemplos

- [`examples/01-sprig-essentials/`](examples/01-sprig-essentials/README.md) — las 7 funciones que vas a usar cada día.
- [`examples/02-include-vs-template-and-nindent/`](examples/02-include-vs-template-and-nindent/README.md) — la diferencia crítica demostrada con render real.
- [`examples/03-required-and-default/`](examples/03-required-and-default/README.md) — contratos robustos sin surpresas en producción.

## Actividades

- [`activities/01-refactor-template-with-helpers/`](activities/01-refactor-template-with-helpers/README.md) — guided-lab: extraer labels, selectorLabels, fullname y serviceAccountName a `_helpers.tpl`.
- [`activities/02-fix-broken-indent/`](activities/02-fix-broken-indent/README.md) — independent debug: starter con 3 bugs plantados (indentación, scoping, `template` vs `include`). Fíxalos hasta que `helm template` pase.

## Entregables

- `_helpers.tpl` propio con nombres estándar: `<chart>.fullname`, `<chart>.labels`, `<chart>.selectorLabels`, `<chart>.serviceAccountName`.
- Dos charts terminados (uno refactorizado, uno debuggeado) que renderizan limpios con `helm template`.
- Notas personales con el "cheat sheet" de 7 funciones Sprig que usarás a diario.

## Criterios de evaluación

- **Conceptual.** Dado un template y su output de `helm template --debug`, señalar la causa raíz de un error (indentación, scoping, o uso incorrecto de `template`/`include`).
- **Operativa.** Un chart cuyo `helm template` + `helm lint` pasan sin warnings, con labels renderizadas correctamente en todos los recursos.
- **Arquitectónica.** `_helpers.tpl` reutilizable: cada helper tiene una sola responsabilidad y no depende de valores que podrían faltar sin `default` o `required`.

## Recursos

Ver [`resources/links.md`](resources/links.md) para documentación oficial, Sprig docs, best practices y utilidades de debugging.
