# Ejemplo 02 — `include` vs `template` y por qué `nindent` lo cambia todo

## Concepto que demuestra

La diferencia crítica entre la **acción** `template` (no se puede pipear) y la **función** `include` (sí se puede pipear), y por qué `include ... | nindent N` es el idiom moderno para componer con `_helpers.tpl`.

## Contexto

Dos recursos (`Deployment` y `Service`) consumen el mismo helper `app.labels`. En el chart se muestran los tres patrones posibles:

1. `template "app.labels" .` → funciona pero el helper tiene que hardcodear la indentación.
2. `template "app.labels" . | nindent 4` → **error de parse**: `template` es una acción, no una función.
3. `include "app.labels" . | nindent 4` → forma preferida: helper limpio, caller decide la indentación.

## Prerrequisitos

- Helm 3+. Testeado con Helm v4.3.1.

## Ejecución

```bash
cp -r files /tmp/include-vs-template
cd /tmp/include-vs-template

# 1. Render correcto (usa 'include | nindent 4')
helm template demo .

# 2. Forzar el patrón roto: descomenta el bloque BROKEN en templates/service.yaml
#    (o aplica el patch descrito al final del README). Observa:
#      Error: parse error ... function "template" not defined
#    Mensaje engañoso: el error no es que falte la función, es que 'template'
#    es una ACCIÓN y por tanto no puede aparecer en un pipeline.
```

## Resultado esperado

Render de 3 recursos:

- `Deployment` con labels indentadas correctamente a 4 espacios bajo `metadata.labels`.
- `Service` con labels igualmente indentadas.
- Un `ConfigMap` que ilustra `include` aplicado también a `sha256sum`:
  `annotations.checksum/config: <64 hex>`.

## Interpretación

- `template "name" .` emite output al stream del render. No retorna nada en el sentido de pipeline.
- `include "name" .` **retorna** el output como string, por tanto encaja en pipelines.
- Como `_helpers.tpl` se consume desde múltiples sitios con contextos de indentación distintos, la única forma mantenible de escribirlo es **sin** indentación interna y aplicando `nindent` en el call site.

Esto es también la razón por la que el patrón `checksum/config` solo funciona con `include`:

```yaml
annotations:
  checksum/config: {{ include "app.configmap" . | sha256sum }}
```

Con `template` sería imposible, porque no puedes pipear su output a `sha256sum`.

## Errores frecuentes

- Mezclar `template` + pipeline → error de parse críptico.
- Usar `include` olvidando el `nindent` → bloque pegado o mal alineado.
- Hardcodear indentación dentro del `define` → el helper deja de ser reutilizable en otros contextos de indentación.

## Limpieza

```bash
rm -rf /tmp/include-vs-template
```
