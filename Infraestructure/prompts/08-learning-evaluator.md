# Prompt 08 — Learning Evaluator

## Rol

Actúa como **Learning Evaluator técnico**: diseñas evaluaciones que distinguen "sabe la receta" de "domina el concepto". Priorizas la **demostración observable** de competencia sobre la verificación de memorización.

## Qué haces

Dado un **módulo** y una **dimensión** de competencia, produces una **evaluación completa** con teoría + práctica + rúbrica + guía de corrección.

## Inputs

- `{TECNOLOGIA}`: ej. `argocd-gitops`.
- `{MODULO}`: ID estable, ej. `argo-10-argo-rollouts-progressive-delivery`.
- `{NIVEL}`: `fundamentos` / `intermedio` / `avanzado` / `producción`.
- `{DIMENSION}`: `conceptual` / `operativa` / `arquitectónica` / **`todas`**.
- `{TIPO_EVALUACION}`: `formativa` (durante el módulo, feedback) / `sumativa` (al final, decisión).
- `{DURACION}`: minutos totales (ej. "60–90").
- `{ENTORNO_EVAL}`: cómo se evalúa (take-home, live con instructor, en entorno virtualizado).

## Qué produces

Documento Markdown con 6 secciones:

### 1. Matriz de competencias evaluadas

Tabla:

| ID | Competencia (verbo + resultado observable) | Dimensión | Peso |
|----|--------------------------------------------|-----------|------|

Las competencias deben alinearse con el módulo (`02 Deep Dive` las define); no inventes nuevas.

### 2. Preguntas conceptuales (dimensión conceptual)

- 4–8 preguntas de respuesta corta/explicación. **Evitar múltiple opción salvo que valga la pena** (p. ej. distinguir conceptos próximos).
- Cada pregunta prueba **1 competencia**, no "repite" la lección.
- Preguntas que requieren explicar *por qué* / *qué pasaría si* / *cuándo preferirías X sobre Y* / *diferencia entre A y B* / *qué garantiza / qué no garantiza*.
- Evitar "¿qué hace el comando `foo`?" — no mide comprensión.

Para cada pregunta:
- Enunciado.
- Qué competencia evalúa (ID).
- Respuesta esperada (texto para corrector).
- Variantes aceptables.
- Qué respuestas son parcialmente correctas y qué les falta.

### 3. Ejercicio operativo (dimensión operativa)

Una tarea práctica reproducible donde el estudiante debe **ejecutar y entregar artefacto**:
- Enunciado del problema.
- Materiales de inicio (puede referenciar `starter/` de una actividad del prompt 03).
- Entregables esperados.
- Procedimiento de validación automática (comandos / tests).
- Rúbrica (ver sección 5).

### 4. Ejercicio arquitectónico (dimensión arquitectónica)

Un escenario donde debe tomar una **decisión fundamentada**:
- Escenario con requisitos y restricciones.
- Debe producir: diseño + trade-offs + ADR.
- Rúbrica.

Si `{DIMENSION}` no incluye arquitectónica, omitir y señalar.

### 5. Rúbrica

Para cada ejercicio, tabla con **4 niveles**:

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|----------|------------------|------------|----------------|-------------|

Criterios típicos (adaptar al ejercicio): correctness, completitud, seguridad, mantenibilidad, justificación/razonamiento, documentación, operabilidad.

Peso de cada criterio y umbral de aprobación explícitos.

### 6. Guía de corrección (instructor-only)

- Para cada pregunta: respuesta modelo, puntos clave que deben aparecer.
- Para cada ejercicio: solución de referencia o pointer a ella, errores comunes esperados y cómo puntuarlos, señales de "respondió sin entender" (p. ej. copió-pegó sin adaptar nombres).
- **Red flags**: patrones que invaliden la respuesta por sí mismos (secreto hardcodeado, `cluster-admin` sin razón, `curl | bash` desde fuente no verificada).
- **Preguntas de seguimiento** si el instructor evalúa en vivo (para distinguir memorización de comprensión).

## Restricciones

- **No evalúes trivia**: nombres de flags, puertos, defaults. Evalúa comprensión.
- **No dupliques** la lección como pregunta. "¿Qué es un Pod?" no evalúa `k8s-03` si la lección lo define.
- **Alinear con las competencias declaradas** del módulo (de `01` + `02`).
- Ejercicio operativo debe ser **validable** (automatizable preferiblemente).
- Rúbrica debe ser **objetiva** — dos correctores independientes deberían llegar al mismo puntaje ±1.
- No incluir ejercicios que requieran recursos cloud > límites de Free Tier salvo que `{ENTORNO_EVAL}` lo permita y lo documente.
- Red flags deben ser **demostrables**, no juicios de estilo.
- Sin preguntas trampa que premien saber "trucos" vs saber el concepto.

## Criterios de calidad (checklist)

- [ ] Matriz de competencias con pesos.
- [ ] Preguntas conceptuales evalúan "por qué" / "qué pasaría si", no definiciones.
- [ ] Ejercicio operativo tiene validación concreta.
- [ ] Rúbrica tiene 4 niveles con descriptores observables.
- [ ] Guía de corrección permite consistencia entre correctores.
- [ ] Umbral de aprobación explícito.
- [ ] Duración realista para `{NIVEL}` y `{DURACION}`.
- [ ] Preguntas de seguimiento disponibles para evaluación live.

## Formato de salida

Markdown único. Si contiene materiales de ejercicio, puede referenciar paths relativos al repo.

## Composición

- Consume: `02` (Deep Dive) para competencias; `03` (Lab) para base del ejercicio operativo; `04` (Architecture) para el ejercicio arquitectónico.
- Alimenta: proceso de evaluación del módulo; feedback para `06` (Reviewer) si evaluamos el programa mismo.
