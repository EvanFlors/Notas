# Progress dashboard

Scanner + renderer de progreso del estudiante a lo largo de los 17 cursos y las 15 etapas del capstone. Solo stdlib — sin PyYAML, sin pandas, sin dependencias externas. Un único script.

## Qué hace

Recorre:

- `courses/*/*/activities/*/activity.yaml`
- `projects/capstone/stages/*/activities/*/activity.yaml`

y produce un reporte Markdown con:

- Resumen global (totales, minutos estimados, % completado).
- Breakdown **por curso**, **por nivel** (`beginner | intermediate | advanced`) y **por dimensión** (`conceptual | operativa | arquitectonica`, inferida desde el campo `type`).
- Breakdown de las 15 etapas del capstone.
- Sección **DORA-style sobre el trabajo del estudiante**: usa `git log` sobre cada `activity.yaml` para estimar lead time, throughput semanal y bottlenecks (cursos con mayor lead time medio). Si todavía no hay actividades `completed`, imprime las fórmulas en vez de los números.

## Uso

Desde la raíz del repo:

```bash
python3 evaluation/progress-dashboard/compute_dashboard.py
```

A archivo (por ejemplo para commitear un snapshot semanal):

```bash
python3 evaluation/progress-dashboard/compute_dashboard.py \
    --out evaluation/progress-dashboard/sample-output.md
```

Contra otro clon del repo:

```bash
python3 evaluation/progress-dashboard/compute_dashboard.py --repo /ruta/al/repo
```

Sin argumentos el script asume que su propia ubicación está dos niveles por debajo de la raíz (`<repo>/evaluation/progress-dashboard/compute_dashboard.py`).

## Cómo lee el estado

El script parsea `activity.yaml` con un mini-parser YAML (solo escalares y listas en el nivel raíz; es lo que necesita). Valores reconocidos para `status`:

- `not-started` (default si no aparece o no se reconoce)
- `in-progress`
- `blocked`
- `completed`

Para avanzar el dashboard, el estudiante edita el campo `status:` en el `activity.yaml` correspondiente al terminar / empezar una actividad. El dashboard no modifica nada.

## Mapeo `type` → dimensión

| `type` en `activity.yaml` | Dimensión |
|---------------------------|-----------|
| `guided-lab`, `independent`, `debug`, `scenario` | `operativa` |
| `architecture`, `mini-project` | `arquitectonica` |
| `demo` | `conceptual` |

Si se agregan nuevos tipos, actualizar `TYPE_TO_DIMENSION` en `compute_dashboard.py`.

## DORA-style — método

Requiere que el repo esté bajo control git. Para cada actividad con `status: completed`:

- **Lead time** = `max(commit_times) - min(commit_times)` sobre el historial del `activity.yaml` (uses `git log --follow`). Es una aproximación: no mide el tiempo real que el estudiante trabajó, solo cuánto tiempo pasó entre la primera edición y la última.
- **Throughput** = conteo de completadas por semana ISO (usando el timestamp del último commit).
- **Bottlenecks** = top 5 cursos por lead time medio.

Mientras no haya ninguna `completed`, la sección imprime las fórmulas en vez de los números. Esto es intencional: evita mostrar métricas falsas.

## Sample output

Ver [`sample-output.md`](sample-output.md) para una ejecución real contra este repo en su estado actual (todas las actividades en `not-started`).

## Formato del output

El script emite Markdown puro, pensado para:

- Pegarse en el portafolio (`metrics/dashboard.md`).
- Commitearse en el repo del estudiante para tener historial.
- Renderizarse en GitHub sin extensiones.

Las barras de progreso usan `#` y `-` en bloques de ancho fijo para que se vean iguales en light/dark/mono.
