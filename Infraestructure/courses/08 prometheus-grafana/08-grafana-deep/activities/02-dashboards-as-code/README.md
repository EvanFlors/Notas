# obs-08-02 — Dashboards as code (grafonnet)

## 1. Identificación
- **ID:** `obs-08-02-dashboards-as-code`
- **Tecnología:** prometheus-grafana
- **Módulo:** `08-grafana-deep`
- **Dificultad:** intermediate
- **Duración estimada:** 120 min
- **Tipo:** independent

## 2. Contexto
JSON exportado de Grafana es verboso, frágil ante merges y repetitivo cuando tienes 50 servicios con el mismo patrón RED. En esta actividad conviertes un dashboard JSON a **jsonnet** (estilo grafonnet) y generas el JSON por build. El dashboard se vuelve una **función** parametrizable: añadir un nuevo servicio es pasar un argumento.

Esta actividad es **independiente**: no revelamos el jsonnet terminado — tú diseñas la forma. La `solution/` contiene **una** forma posible como referencia (no la mires antes de intentarlo).

## 3. Objetivos
- Un archivo `dashboard.jsonnet` que define el dashboard de forma composable.
- Un archivo `rendered.json` producido por `jsonnet dashboard.jsonnet > rendered.json`.
- Invariantes preservados: `uid` fijo, 6 paneles (`timeseries`, `stat`, `gauge`, `heatmap`, `table`, `state-timeline`) y 2 variables (`query` + `custom`).

## 4. Prerrequisitos
- `jsonnet` (go-jsonnet o C++). Instala con `brew install jsonnet` o `go install github.com/google/go-jsonnet/cmd/jsonnet@latest`.
- `jq`, `bash`.
- Opcional: Grafana corriendo para publicar el `rendered.json` por provisioning (no requerido para la validación).

## 5. Instrucciones

1. En `starter/` tienes:
   - `source-dashboard.json` — el dashboard JSON "de referencia" (equivale a la solución de la actividad 01).
   - `Makefile` — target `render` que ejecuta `jsonnet dashboard.jsonnet > rendered.json`.
2. Crea `dashboard.jsonnet` desde cero. Pistas:
   - Define una función `panel(id, title, type, expr, gridPos, extras={})`.
   - Define una función `dashboard(uid, title, panels, variables)`.
   - La función principal del archivo devuelve el objeto raíz del dashboard.
3. Ejecuta:
   ```bash
   cd starter/
   make render
   ```
   Esto produce `rendered.json`.
4. Valida:
   ```bash
   bash ../tests/validate.sh
   ```
5. (Opcional) Copia `rendered.json` a un provisioning path y comprueba el badge *Provisioned*.

## 6. Resultado esperado
- `starter/dashboard.jsonnet` — tu diseño en jsonnet.
- `starter/rendered.json` — JSON generado.
- `validate.sh` → `RESULT: OK`.

## 7. Criterios de aceptación
- `dashboard.jsonnet` **existe** y es jsonnet válido (parsea con `jsonnet`).
- `rendered.json` **existe**, es JSON válido, con `uid`, 6 paneles de los tipos requeridos y 2 variables.
- El código jsonnet es **DRY**: no hay 6 bloques literales idénticos — usa funciones o comprehensions.

## 8. Validación
```bash
cd starter/
make render
cd ..
bash tests/validate.sh
```
Si `jsonnet` no está instalado, el validador aborta con instrucciones; no hay runtime check.

## 9. Preguntas de reflexión
- ¿Qué ventaja tiene definir `panel()` como función vs copiar JSON?
- ¿Cómo generarías 20 dashboards (uno por servicio) con el mismo patrón?
- ¿Por qué el `rendered.json` también se versiona (en vez de generarlo on-the-fly)?
- ¿Qué rol juega `grizzly` sobre `grafonnet`?

## 10. Extensiones
- Parametriza el dashboard por `service`: `function(service) dashboard(uid=service+'-red', ...)`.
- Añade una `libsonnet` compartida con constantes (colores, intervalos).
- Añade una regla de alerting Grafana como jsonnet y renderízala al mismo YAML.

## 11. Limpieza
```bash
cd starter/
make clean   # borra rendered.json
```
No hay servicios que detener (todo es offline salvo el provisioning opcional).
