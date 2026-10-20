# Actividad 02 — Plantilla de entrevista DX

## 1. Identificación

- **ID:** `plat-02-02-dx-interview-template`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-02-golden-paths-paved-roads-and-developer-experience`
- **Dificultad:** beginner
- **Duración estimada:** 40–55 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Vas a hacer **5 entrevistas DX** la próxima semana con developers de equipos stream-aligned del capstone, para capturar el *por qué* detrás de la telemetría del scaffolder y los resultados del último survey. Necesitas una **plantilla reutilizable** que:

- Dure 30–45 min reales (no 90).
- Produzca notas comparables entre entrevistas.
- Evite preguntas *leading* ("¿te gusta la plataforma?") y *yes/no*.
- Deje la puerta abierta a seguimientos.
- Encaje con la triangulación entrevistas + survey + telemetría (ver `theory/lesson.md` §9).

Tu entregable es un documento Markdown. **No** entrevistas realmente — diseñas la herramienta.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Estructurar la plantilla en **5 bloques** (rapport, contexto, viaje concreto, preguntas abiertas, cierre).
- Formular **al menos 6 preguntas abiertas** útiles (no leading, no yes/no).
- Definir **método de muestreo** (quiénes, cuántos, con qué sesgo evitado).
- Definir **cadencia** y **responsable**.
- Articular **cómo se cruza** con telemetría y survey.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (especialmente §9).
- Haber recorrido `examples/03-dx-metrics-samples/`.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/plat-02-dx-interview
cd /tmp/plat-02-dx-interview
```

Puedes usar otro directorio, pero pásalo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `TEMPLATE.md` con 5 bloques

Secciones **obligatorias** (el validador las comprueba por título):

1. `## 1. Metadatos` — duración, participante, entrevistador, fecha, consentimiento de notas.
2. `## 2. Rapport` — 2–3 preguntas blandas de 2–3 min para romper el hielo.
3. `## 3. Contexto` — equipo, rol, antigüedad, servicios recientes creados o tocados por el participante.
4. `## 4. Preguntas` — el bloque principal. Mínimo **6 preguntas abiertas** numeradas.
5. `## 5. Cierre` — compromisos del entrevistador, próximos pasos, canal de seguimiento.

Además, incluye una sección `## 6. Método` con:

- **Muestreo:** cómo eliges a los 5 developers. Mencionar al menos un **sesgo evitado** (p. ej. "no solo los que levantan la mano").
- **Cadencia:** cada cuánto se repite (trimestral / semestral).
- **Responsable:** persona concreta del platform team (DRI).
- **Triangulación:** cómo cruzas los hallazgos con **telemetría** y **survey**.

### 5.3 Reglas sobre las preguntas (sección 4)

- Al menos **6 preguntas**, numeradas (`1.`, `2.`, ...).
- **Prohibido** empezar con "¿Te gusta...?" o similar leading.
- Al menos **2 preguntas** deben pedir un **viaje concreto reciente** ("cuéntame tu último scaffolding/deploy/incidente...").
- Al menos **1 pregunta** debe explorar el **long tail** ("¿has tenido que salirte del golden path? ¿por qué?").
- Al menos **1 pregunta** sobre **documentación / soporte**.
- Al menos **1 pregunta** sobre **qué quitarías** del path (fricción percibida).

### 5.4 Entregable

```
/tmp/plat-02-dx-interview/TEMPLATE.md
```

## 6. Resultado esperado

- `TEMPLATE.md` existe y es coherente.
- Las 6 secciones (5 bloques + Método) están presentes.
- Al menos 6 preguntas abiertas numeradas.
- Muestreo, cadencia y responsable definidos.
- Triangulación con telemetría + survey mencionada.
- `bash tests/validate.sh /tmp/plat-02-dx-interview` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: preguntas abiertas, no leading, no yes/no.
- **Reproducibilidad**: cualquier integrante del platform team puede usar la plantilla sin modificarla.
- **Mantenibilidad**: Markdown válido.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-02-dx-interview
```

El validador comprueba **estructura**, no semántica. Compara tu plantilla con `solution/TEMPLATE.md` después para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Por qué una pregunta sobre *un viaje concreto reciente* vale más que una pregunta sobre *la plataforma en general*?
2. ¿Qué sesgos introduce elegir a los 5 developers por "los que levantan la mano"?
3. ¿Cómo evitas que la entrevista se convierta en un *venting* sin acciones?
4. ¿Qué pasa si todos los entrevistados dicen "todo bien"? ¿Cómo lo interpretas?
5. ¿Cómo decides cuándo **dejar de hacer** entrevistas (saturación) y pasar a solo survey + telemetría?

## 10. Extensiones

- Añade un **anexo con un rubric de notas** (categorías: fricción, delight, bloqueos, deseos).
- Añade un **guión del entrevistador** (frases exactas) para los primeros 3 minutos.
- Define una **política de anonimización** antes de compartir hallazgos.

## 11. Limpieza

```bash
rm -rf /tmp/plat-02-dx-interview
```

No hay procesos ni contenedores que detener.
