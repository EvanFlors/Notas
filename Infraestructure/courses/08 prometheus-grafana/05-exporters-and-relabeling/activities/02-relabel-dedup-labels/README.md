# obs-05-02 — Relabel: dedup y limpieza

## 1. Identificación
- **ID:** `obs-05-02-relabel-dedup-labels`
- **Tecnología:** prometheus-grafana
- **Módulo:** `05-exporters-and-relabeling`
- **Dificultad:** intermediate
- **Duración estimada:** 75 min
- **Tipo:** independent

## 2. Contexto

Te heredan un `prometheus.yml` que scrapea `node_exporter` y `blackbox_exporter`, pero el equipo que lo escribió no usó convenciones de labels y dejó pasar métricas internas ruidosas. Tu tarea es **sin ver la solución** aplicar `relabel_configs` y `metric_relabel_configs` que normalicen el conjunto.

Este tipo de limpieza es la operación #1 cuando se adopta una política de plataforma de observabilidad: todos los jobs deben llevar `env`, `team` y `service`, y las métricas internas de los exporters que no se usan deben ir fuera para ahorrar RAM.

## 3. Objetivos

Al terminar, el stack debe cumplir:

1. **Toda** serie expuesta por Prometheus tiene labels `env="lab"` y `team="sre"`.
2. El job `node` tiene `instance="node1"` (no `node-exporter:9100`).
3. El job `blackbox` tiene `instance` igual a la **URL completa** del target probeado (no al host del exporter).
4. La métrica `promhttp_metric_handler_requests_total` no existe (dropeada).
5. La métrica `promhttp_metric_handler_requests_in_flight` no existe (dropeada).
6. `probe_success` sigue existiendo y vale `1` para al menos un target.

## 4. Prerrequisitos

- Docker + Docker Compose v2.
- Haber completado `obs-05-01-add-postgres-exporter` (o entender su setup).
- Puertos libres: 9090, 9100, 9115.

## 5. Instrucciones

```bash
cd activities/02-relabel-dedup-labels/starter
docker compose up -d
sleep 15
```

Explora el estado "sucio":

```bash
curl -s 'http://localhost:9090/api/v1/query?query=up' | less
curl -s 'http://localhost:9090/api/v1/label/__name__/values' | tr ',' '\n' | grep promhttp
```

Edita **solo** `prometheus.yml`. No modifiques `docker-compose.yml`. Recarga con:

```bash
curl -X POST http://localhost:9090/-/reload
```

o `docker compose restart prometheus`.

**No consultes `solution/` hasta haber intentado al menos 20 minutos.**

Valida tu progreso:

```bash
cd ..
bash tests/validate.sh
```

El validador imprime, por cada criterio, OK o FAIL con pista.

## 6. Resultado esperado

- `tests/validate.sh` exit 0 con 6/6 checks OK.
- `prometheus.yml` con comentarios explicando cada regla.
- Un archivo `decisions.md` corto justificando por qué se dropeó cada métrica.

## 7. Criterios de aceptación

- Reglas comentadas (qué, por qué).
- No se duplican reglas idénticas por cada job: si aplica a todos, se repite deliberadamente (Prometheus no soporta `defaults`) y se anota.
- `probe_success` sobrevive; el drop no fue indiscriminado.

## 8. Validación

```bash
bash tests/validate.sh
```

Falla gracefully si el stack no está arriba.

## 9. Preguntas de reflexión

- `env` y `team` ¿deberían ir en `external_labels` (global) o en cada job? ¿Qué cambia?
- Si otro equipo necesita las métricas `promhttp_*`, ¿cómo las re-habilitas sin afectar a otros tenants?
- Imagina un `/metrics` con 500 series donde 400 son `_bucket` de un histogram con `le` de 20 buckets × 5 pods × 4 paths. ¿Dropeas, re-tipas, o pre-agregas con recording rules?

## 10. Extensiones

1. Añade un tercer job (p. ej. `cadvisor`) y verifica que tu convención escala sin repeticiones feas (idealmente usar `external_labels`).
2. Mide con `prometheus_tsdb_head_series` el delta antes/después de tus reglas.
3. Convierte las reglas a un `scrape_configs:` generado por template (Jsonnet/Jinja).

## 11. Limpieza

```bash
cd starter
docker compose down -v
rm -rf /tmp/obs-05-02-* 2>/dev/null || true
```
