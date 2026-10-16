# obs-03 — Tipos de métricas y naming

## Identificación
- **ID:** `obs-03-metric-types-and-naming`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `obs-02-install-local-stack-and-first-scrape`

## Objetivo
Elegir el **tipo de métrica correcto** (counter, gauge, histogram, summary, native histogram) y **nombrarlo bien** (naming + labels con cardinalidad acotada) para que el modelo de datos de Prometheus sea útil, agregable y barato.

## Temas y subtemas
1. **Tipos de métricas**
   - `counter` — monótono creciente. Se consume con `rate()` / `increase()`.
   - `gauge` — sube y baja (temperatura, memoria usada, cola).
   - `histogram` — buckets acumulativos `_bucket{le="..."}` + `_count` + `_sum`. Cuantiles vía `histogram_quantile()` agregado cross-target.
   - `summary` — cuantiles pre-calculados por target. **No agregable** cross-target.
   - **Native histograms** — representación sparse, nueva, mucho más eficiente que buckets fijos.
2. **Naming**
   - Convención: `<namespace>_<subsystem>_<name>_<unit>`.
   - Nombre en singular, `snake_case`.
   - Sufijos de unidad obligatorios: `_total`, `_bytes`, `_seconds`, `_ratio`, `_info`.
3. **Labels**
   - Significado (dimensión) + cardinalidad (nº de valores posibles).
   - Reglas de cardinalidad: cada combinación única de labels = **1 serie** = coste de RAM.
4. **Las "3 cosas a medir"**
   - **RED** (Rate, Errors, Duration) para servicios HTTP.
   - **USE** (Utilization, Saturation, Errors) para recursos.

## Conceptos internos (fundamentos)
- Un `counter` nunca es "el valor absoluto que te interesa"; lo que importa es su **tasa** vía `rate()` en una ventana `[Nm]`.
- `histogram_quantile()` sobre un histogram agregado es correcto (suma de buckets es matemáticamente válida). Sobre un summary agregado es **inválido** (no se pueden sumar cuantiles).
- Cada label nueva **multiplica** la cardinalidad de la métrica. Un `user_id` como label puede llevar la TSDB a GB en minutos.
- Native histograms resuelven el trade-off "resolución vs coste" de los buckets fijos.

## Competencias
- **Conceptual:** diferenciar counter / gauge / histogram / summary / native histogram y explicar cuándo usar cada uno.
- **Operativa:** auditar un `/metrics` real, señalar métricas mal tipadas, nombres incorrectos y labels de alta cardinalidad.
- **Arquitectónica:** definir el "contrato RED" de un servicio y el "contrato USE" de un recurso, con naming que un tercero entienda sin leer código.

## Ejemplos
- [`examples/01-counter-vs-gauge-vs-histogram/`](examples/01-counter-vs-gauge-vs-histogram/) — tres métricas sencillas servidas por un mock `/metrics`.
- [`examples/02-red-vs-use-method/`](examples/02-red-vs-use-method/) — una tabla ejemplar del contrato RED para un servicio HTTP y USE para un disco.
- [`examples/03-naming-review/`](examples/03-naming-review/) — antes/después de nombres típicos.

## Actividades
- [`activities/01-rename-and-retype-exercise/`](activities/01-rename-and-retype-exercise/) — guided-lab: reescribir un `/metrics` con nombres y tipos correctos.
- [`activities/02-cardinality-smell-test/`](activities/02-cardinality-smell-test/) — independent: identificar labels de alta cardinalidad en un `/metrics` dado y proponer corrección.

## Entregables
- Cheat-sheet personal con naming (`<namespace>_<subsystem>_<name>_<unit>`), sufijos y mapa tipo → cuándo usarlo.
- `/metrics` reescrito del ejercicio 01.
- `CARDINALITY-ANALYSIS.md` del ejercicio 02.

## Criterios de evaluación
- **Conceptual:** elige el tipo correcto para 5 escenarios dados.
- **Operativa:** diagnostica métricas mal tipadas o nombradas en un `/metrics` dado y propone la corrección.
- **Arquitectónica:** justifica por qué `summary` casi nunca es la respuesta cuando hay más de 1 réplica del servicio.

## Recursos
- [`resources/links.md`](resources/links.md)
