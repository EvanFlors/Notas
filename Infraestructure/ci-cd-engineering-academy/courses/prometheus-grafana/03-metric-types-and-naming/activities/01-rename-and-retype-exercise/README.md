# obs-03-01 — Rename & retype exercise (guided-lab)

## 1. Identificación
- **ID:** `obs-03-01-rename-and-retype-exercise`
- **Tecnología:** prometheus-grafana
- **Módulo:** `03-metric-types-and-naming`
- **Dificultad:** beginner
- **Duración estimada:** 45 min
- **Tipo:** guided-lab

## 2. Contexto
Heredas un `/metrics` escrito por alguien que no leyó la convención. Es tu primer ejercicio operativo: toma el fichero `starter/metrics_bad.txt`, identifica qué está mal (nombres, unidades, tipos, sufijos) y reescríbelo bien en `/tmp/obs03-01/metrics_fixed.txt`.

## 3. Objetivos
- Aplicar la convención `<namespace>_<subsystem>_<name>_<unit>`.
- Añadir el sufijo correcto (`_total`, `_bytes`, `_seconds`, `_ratio`).
- Corregir el `# TYPE` cuando el sufijo original mentía (`_total` en algo no monótono, etc.).
- Promover `summary` → `histogram` cuando sea razonable.

## 4. Prerrequisitos
- Haber leído `theory/lesson.md` (secciones 3-10).
- Herramientas: `bash`, `grep`, `mkdir`, `cp`. No hay dependencias externas ni costes.

## 5. Instrucciones

Paso a paso:

```bash
# 1) Prepara el scratch
mkdir -p /tmp/obs03-01
cp starter/metrics_bad.txt /tmp/obs03-01/metrics_fixed.txt

# 2) Edita /tmp/obs03-01/metrics_fixed.txt aplicando la convención.
#    Pistas por métrica (sigue el orden del fichero):
#    - 'httpRequests' → http_requests_total (counter)
#    - 'request_latency_ms' → http_request_duration_seconds (histogram, en segundos)
#    - 'memory_used_mb' → process_memory_used_bytes (gauge, bytes)
#    - 'cpu_usage_percent' → process_cpu_usage_ratio (gauge, 0..1)
#    - 'active_connections_total' → active_connections (gauge, sin _total)
#    - 'queue_size_total' → queue_size (gauge)
#    - 'disk_free_gb' → node_filesystem_free_bytes (gauge, bytes)
#    - El summary de duración → histogram con buckets

# 3) Ejecuta el validador
bash tests/validate.sh
```

Si el validador falla, lee el mensaje y corrige. Cada check es independiente.

## 6. Resultado esperado
- Fichero `/tmp/obs03-01/metrics_fixed.txt` con las métricas renombradas y re-tipadas.
- `tests/validate.sh` imprime `RESULT: 8/8 checks OK` y sale con código 0.

## 7. Criterios de aceptación
- Todas las métricas usan `snake_case`.
- Counters terminan en `_total` y tienen `# TYPE X counter`.
- Unidades canónicas: `_bytes`, `_seconds`, `_ratio`. Nada de `_ms`, `_mb`, `_percent`.
- Gauges no llevan `_total`.
- El summary se ha convertido a histogram con al menos `_bucket{le="..."}`, `_count`, `_sum`.

## 8. Validación

```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexión
- ¿Por qué `cpu_usage_ratio` (0..1) y no `cpu_usage_percent` (0..100)?
- ¿Qué pasa en una query PromQL si un gauge se declaró como counter?
- ¿Por qué `summary` cross-target es un bug? ¿Qué garantía pierdes al "agregarlo"?

## 10. Extensiones
- Añade `# HELP` descriptivos (al menos para 3 métricas).
- Añade una métrica `app_build_info{version="...", commit="..."} 1` para explorar el patrón `_info`.

## 11. Limpieza

```bash
rm -rf /tmp/obs03-01
```
