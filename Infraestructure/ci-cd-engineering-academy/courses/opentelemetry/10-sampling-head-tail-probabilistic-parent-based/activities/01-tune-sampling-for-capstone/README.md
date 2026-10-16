# otel-10-01 — Afinar sampling para el capstone

## 1. Identificación
- **ID:** `otel-10-01-tune-sampling-for-capstone`
- **Tecnología:** opentelemetry
- **Módulo:** 10-sampling-head-tail-probabilistic-parent-based
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** guided-lab

## 2. Contexto

Operas el pipeline de observabilidad del capstone. Hoy el SDK muestrea al 100% (`AlwaysOn`) y la factura del backend crece lineal con el tráfico. El equipo de SRE pide:

- Visibilidad **completa de errores** (no se puede perder un solo trace fallido).
- Visibilidad **completa de requests lentos** (> 500 ms).
- Baseline estadístico del 10% sobre el resto.
- Memoria del Collector controlada (no explotar en los peaks de tráfico).

Debes configurar el **gateway Collector** con `tail_sampling` adecuado y verificar que la salida respeta esos criterios con una carga sintética.

## 3. Objetivos

- Configurar `tail_sampling` processor con policies `status_code`, `latency`, `probabilistic`.
- Dimensionar `decision_wait` y `num_traces` para una carga de 300 traces mixtos.
- Verificar automáticamente que el output contiene 100% de errores, 100% de slow y ~10% de fast ok.
- Explicar por qué `batch` va **después** de `tail_sampling`.

## 4. Prerrequisitos

- Haber corrido `examples/02-tail-sampling-errors-plus-latency` al menos una vez.
- Docker con permisos para `docker run`.
- Python 3.10+ con pip.
- Puerto `14317` libre (OTLP gRPC del lab).
- Costo: 0 (local).

## 5. Instrucciones

1. `cd starter/`
2. Lee `collector-config.yaml` — está **incompleto a propósito**. Faltan tres cosas:
   - La policy `errors-100` (debe muestrear 100% de spans `ERROR`).
   - La policy `probabilistic` (10% baseline).
   - El processor `batch` en el pipeline **después** de `tail_sampling`.
3. Edita el archivo y añade lo faltante. No cambies el orden de `tail_sampling` (debe ir antes de `batch`).
4. Lanza el stack:
   ```bash
   ./run-lab.sh
   ```
   El script levanta el Collector, instala Python deps, emite carga sintética (150 fast ok + 100 slow ok + 50 errores) y escribe la salida en `/tmp/otel10-01/out.json`.
5. Valida con:
   ```bash
   bash tests/validate.sh
   ```
6. Si falla, revisa qué conteo no está en rango e itera.

## 6. Resultado esperado

- Archivo `/tmp/otel10-01/out.json` existe y pesa > 0 bytes.
- `errors=50` (100% de los 50 errores emitidos).
- `slow>=90` (al menos 90% de los 100 slow, tolerancia por timing).
- `3 <= fast <= 40` (10% de los 150 fast ok con margen estadístico).
- `tests/validate.sh` termina con exit 0 y último mensaje `OK`.

## 7. Criterios de aceptación

- La configuración incluye las tres policies pedidas.
- `batch` aparece después de `tail_sampling` en el pipeline.
- `decision_wait` entre 3 s y 15 s (razonable para la carga del lab).
- Alumno puede explicar oralmente qué pasa si `batch` va **antes**.

## 8. Validación

```bash
bash tests/validate.sh /tmp/otel10-01
```

Verifica rangos sobre `out.json` sin reinstalar el stack.

## 9. Preguntas de reflexión

1. ¿Por qué `batch` debe ir después de `tail_sampling`? ¿Qué pasa si invertimos el orden?
2. Si `decision_wait=1s`, ¿qué traces se perderían?
3. ¿Qué cambia si duplicas el throughput? ¿`num_traces` basta?
4. Si quisieras garantizar un **máximo** de 500 traces/s exportados (budget duro), ¿qué policy añades?
5. ¿Cómo cambiaría la configuración si tuvieras **dos** instancias de gateway Collector?

## 10. Extensiones

- Añade `rate_limiting` capping a 200 spans/s. Observa qué se descarta en el peak.
- Añade `string_attribute` que capture 100% de `http.route == /checkout`.
- Reemplaza `probabilistic` por `composite` con pesos ponderados (ERRORS 60%, LATENCY 30%, RANDOM 10%).

## 11. Limpieza

```bash
docker rm -f otel10-01-collector 2>/dev/null
rm -rf /tmp/otel10-01 /tmp/otel10-01-venv
```

El script `run-lab.sh` también incluye `trap cleanup EXIT` que ejecuta esto al terminar.
