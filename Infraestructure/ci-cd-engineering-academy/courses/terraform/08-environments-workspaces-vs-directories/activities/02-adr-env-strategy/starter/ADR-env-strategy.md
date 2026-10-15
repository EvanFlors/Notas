# ADR-00X — Estrategia de ambientes para Terraform (Shoply)

> Plantilla. Rellena cada sección. Las secciones con "TODO" son obligatorias.

## 1. Estado

TODO: `propuesto | aceptado | reemplazado por ADR-NNN`.

## 2. Fecha

TODO: `YYYY-MM-DD`.

## 3. Autores

TODO: nombres o roles.

## 4. Contexto

TODO: describe el estado actual de la infra IaC de Shoply en 1-2 párrafos.

- Repos: ...
- Ambientes y cómo están implementados hoy: ...
- Pipeline: ...
- Incidentes relevantes: ...

## 5. Riesgos del status quo

TODO: enumera **al menos 3 riesgos concretos** del esquema actual. Para cada uno:
nombre breve, descripción de una línea, impacto esperado si se materializa.

- Riesgo 1 — ...
- Riesgo 2 — ...
- Riesgo 3 — ...

## 6. Decisión

TODO: **UNA línea** empezando por `**Decisión:**` seguida de la elección.

Ejemplo de forma (no copies el contenido):

> **Decisión:** adoptar el patrón "directorios separados por ambiente con módulos locales compartidos" como primer paso; migrar en 6 meses a módulos versionados por git tag.

Luego, en párrafos cortos, justifica por qué.

## 7. Alternativas consideradas

TODO: enumera **al menos 2 alternativas descartadas**, cada una con:

- Nombre.
- En qué consistiría.
- Por qué la descartas (criterio concreto, no "no me gusta").

## 8. Consecuencias

TODO: lista positivas y negativas de la decisión.

- Positivas: ...
- Negativas / costo de la decisión: ...

## 9. Plan de migración

TODO: pasos ordenados, sin "big bang". **Al menos 3 pasos**. Para cada paso: qué se hace, cómo validar que salió bien, cómo revertir si falla.

1. Paso ...
2. Paso ...
3. Paso ...
