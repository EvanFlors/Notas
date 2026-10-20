# obs-03-02 — Cardinality smell test (independent)

## 1. Identificación
- **ID:** `obs-03-02-cardinality-smell-test`
- **Tecnología:** prometheus-grafana
- **Módulo:** `03-metric-types-and-naming`
- **Dificultad:** beginner
- **Duración estimada:** 60 min
- **Tipo:** independent

## 2. Contexto
Te pasan el `/metrics` de un servicio "en producción" que, con el tiempo, ha hecho crecer la TSDB mucho más de lo esperado. Alguien sospecha que hay labels con alta cardinalidad. Tu trabajo: **leer el fichero, señalar las métricas y labels problemáticas, y proponer una corrección**.

Es un ejercicio independiente: no te damos el camino, sólo el objetivo y las reglas.

## 3. Objetivos
- Identificar labels de alta cardinalidad (unbounded) en un `/metrics` dado.
- Explicar por qué cada label señalada es tóxica.
- Proponer corrección: dropear la label, moverla a exemplar/log, o acotarla.
- Entregar el análisis como `CARDINALITY-ANALYSIS.md` con una estructura precisa.

## 4. Prerrequisitos
- Haber leído `theory/lesson.md` (secciones 9 y 11 especialmente).
- Herramientas: `bash`, un editor de texto. No hay dependencias ni costes.

## 5. Instrucciones

```bash
# 1) Scratch dir
mkdir -p /tmp/obs03-02
cp starter/metrics.txt /tmp/obs03-02/metrics.txt

# 2) Lee el fichero y escribe tu análisis en:
#    /tmp/obs03-02/CARDINALITY-ANALYSIS.md
```

El fichero `CARDINALITY-ANALYSIS.md` **debe** tener exactamente estas secciones (headers de nivel 2), en orden:

```markdown
## Métricas analizadas
## Labels de alta cardinalidad
## Impacto estimado
## Propuesta de corrección
```

Qué va en cada sección (resumen):

- **Métricas analizadas**: lista de las métricas que aparecen en el fichero.
- **Labels de alta cardinalidad**: por cada label problemática: nombre, en qué métrica aparece, por qué es alta cardinalidad.
- **Impacto estimado**: una cuenta aproximada de "si cada label unbounded tuviera N valores, cuántas series genera".
- **Propuesta de corrección**: para cada label problemática, qué hacer (drop, mover a exemplar/log, acotar a enum, etc.).

No damos la solución. Si quieres validar la estructura (no el contenido), corre el validador.

## 6. Resultado esperado
- `/tmp/obs03-02/CARDINALITY-ANALYSIS.md` existe y tiene las 4 secciones requeridas.
- Mencionas al menos 3 labels sospechosas del `metrics.txt`.
- `tests/validate.sh` pasa (sólo valida **estructura**, no la calidad del análisis).

## 7. Criterios de aceptación
- Estructura del documento correcta (4 headers de nivel 2 exactos).
- Cada label señalada tiene justificación (una frase, no solo el nombre).
- La propuesta de corrección es accionable (no "mejorarlo", sino "dropear la label `request_id` con `metric_relabel_configs`").

## 8. Validación

```bash
bash tests/validate.sh
```

Un revisor humano (o tú mismo mañana) debería leer el markdown y poder reproducir las conclusiones sin más contexto.

## 9. Preguntas de reflexión
- ¿Por qué `user_id` como label siempre es un bug, incluso con "solo 1000 usuarios"?
- ¿Cómo diferencias una label legítima con "mucha" cardinalidad acotada (p. ej. `pod` en un cluster grande) de una tóxica unbounded (`request_id`)?
- Si el equipo que escribió este `/metrics` necesita de verdad ver qué pasó con un request concreto, ¿qué le propones en lugar de meter `request_id` como label?

## 10. Extensiones
- Reescribe `metrics.txt` eliminando las labels tóxicas y pégalo como `metrics_fixed.txt` adjunto al análisis.
- Investiga `metric_relabel_configs` (lo veremos en `obs-05`) y escribe el YAML que dropearía las labels detectadas en el momento del scrape.

## 11. Limpieza

```bash
rm -rf /tmp/obs03-02
```
