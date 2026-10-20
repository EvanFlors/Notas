# Actividad 01 — Añadir VictoriaMetrics como long-term store

## 1. Identificación

- **ID:** `obs-11-01-add-vm-as-long-term-store`
- **Tecnología:** `prometheus-grafana`
- **Módulo:** `obs-11-scale-and-long-term-storage`
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Tienes un Prometheus local scrapeando un `node_exporter`. Tu organización pide **90 días de retención** para dashboards históricos y queries de rango largo. Prometheus single-node sólo da 15 d prácticos. Vas a añadir **VictoriaMetrics single** como long-term store vía `remote_write`, dejando a Prometheus con una retención corta (2 h) para `/graph` live y a VM con la retención larga.

Este patrón es la base del stack del capstone cuando no justifica Thanos/Mimir.

## 3. Objetivos

Al terminar:
- Levantas un stack de 3 contenedores (`prometheus`, `victoriametrics`, `node-exporter`) con `docker compose`.
- Configuras `remote_write` en `prometheus.yml` apuntando a VM.
- Añades un `write_relabel_configs` que descarta `go_*` y `process_*` (reduce coste).
- Verificas con `curl` que VM responde la misma serie `up` que Prometheus (`/api/v1/query`).
- Verificas que `prometheus_remote_storage_samples_dropped_total` es 0.

## 4. Prerrequisitos

- Docker ≥ 20 y Docker Compose plugin.
- Puertos libres: 9090, 8428, 9100.
- Haber leído `theory/lesson.md` secciones 5 y 8.

**Costos**: ninguno (local).

## 5. Instrucciones

### 5.1 Preparar

Copia los archivos semilla:

```bash
bash starter/bootstrap.sh /tmp/obs11-vm
cd /tmp/obs11-vm
ls
# docker-compose.yml  prometheus.yml
```

El `prometheus.yml` **ya tiene scrape** de node_exporter y de sí mismo, pero **le falta la sección `remote_write`**. Debes añadirla.

### 5.2 Añadir `remote_write`

Edita `prometheus.yml` y añade al final:

```yaml
remote_write:
  - url: http://victoriametrics:8428/api/v1/write
    queue_config:
      capacity: 10000
      max_shards: 30
      max_samples_per_send: 2000
      batch_send_deadline: 5s
    write_relabel_configs:
      - source_labels: [__name__]
        regex: '(go_|process_).*'
        action: drop
```

### 5.3 Levantar el stack

```bash
docker compose up -d
docker compose ps
```

Espera ~20 s (dos scrape intervals).

### 5.4 Verificar que llegan muestras a VM

```bash
# Prometheus debe responder up
curl -s 'http://localhost:9090/api/v1/query?query=up' | head -c 300

# VM debe responder la misma serie
curl -s 'http://localhost:8428/api/v1/query?query=up' | head -c 300
```

Ambos endpoints devuelven JSON con `"status":"success"` y al menos una serie.

### 5.5 Verificar salud de `remote_write`

```bash
curl -s 'http://localhost:9090/api/v1/query?query=prometheus_remote_storage_samples_dropped_total' \
  | head -c 300
# el valor del summary debe ser 0 (o ausente si todavía no se ha generado la métrica)
```

### 5.6 Validar

```bash
bash tests/validate.sh /tmp/obs11-vm
```

Debe pasar con `RESULT: 4/4 OK`.

## 6. Resultado esperado

- Contenedores `obs11-prom`, `obs11-vm`, `obs11-node` en estado `running`.
- `/api/v1/query?query=up` responde `success` **en ambos** `:9090` y `:8428`.
- `prometheus.yml` contiene una sección `remote_write` apuntando a VM.
- `write_relabel_configs` drop de `go_*|process_*` activo.

## 7. Criterios de aceptación

- [ ] Funcionalidad: VM recibe y sirve series scrapeadas por Prometheus.
- [ ] Calidad: `write_relabel_configs` filtra ruido documentado.
- [ ] Reproducibilidad: `tests/validate.sh` pasa 4/4.
- [ ] Comprensión: puedes explicar qué ocurre si bajas VM 5 min y la subes de nuevo.

## 8. Validación

```bash
bash tests/validate.sh /tmp/obs11-vm
```

Chequea:
1. Directorio base existe con `docker-compose.yml` y `prometheus.yml`.
2. `prometheus.yml` contiene `remote_write` y `url: http://victoriametrics:8428/api/v1/write`.
3. (Si Docker está disponible y los contenedores arriba) Prometheus responde `/api/v1/query?query=up`.
4. (Si Docker está disponible y los contenedores arriba) VM responde `/api/v1/query?query=up`.

Si Docker no está disponible o los contenedores no están levantados, los pasos 3-4 se marcan como `SKIP` (no fallan).

## 9. Preguntas de reflexión

1. ¿Qué pasa si VM está caída durante 10 min y la cola de `remote_write` se desborda? ¿Cómo lo detectas?
2. ¿Por qué dejamos Prometheus con sólo 2 h de retención local? ¿Qué perderías si la bajaras a 15 min?
3. ¿Qué diferencia operacional tendría usar `vmagent` en lugar de Prometheus como "scraper + remote_write"?
4. Si Grafana apunta a Prometheus como datasource, ¿por qué una query de 60 d puede devolver "no data"? ¿Qué cambiar?
5. ¿Qué métricas más añadirías al drop de `write_relabel_configs` tras una semana de datos? ¿Cómo lo decidirías?

## 10. Extensiones (opcional)

- **E1** — Añade `vmagent` en reemplazo de Prometheus para el scrape y compara `RAM in use` entre ambos.
- **E2** — Enciende Grafana en el compose y añade dos data sources: Prometheus (`:9090`) y VictoriaMetrics (`:8428`). Haz el mismo dashboard contra ambos.
- **E3** — Configura `retentionPeriod=30d` en VM y verifica con `curl 'http://localhost:8428/api/v1/status/tsdb'`.
- **E4** — Para VM 2 min, deja Prometheus corriendo, vuelve a levantarla. Observa `prometheus_remote_storage_samples_pending` subir y bajar.

## 11. Limpieza

```bash
cd /tmp/obs11-vm
docker compose down -v
rm -rf /tmp/obs11-vm
```
