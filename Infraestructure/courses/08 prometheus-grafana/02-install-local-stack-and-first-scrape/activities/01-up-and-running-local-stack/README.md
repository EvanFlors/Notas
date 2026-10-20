# obs-02-01 — Up and running: stack local Prometheus + Grafana + node_exporter

## 1. Identificación
- **ID:** `obs-02-01-up-and-running-local-stack`
- **Tecnología:** prometheus-grafana
- **Módulo:** 02-install-local-stack-and-first-scrape
- **Dificultad:** beginner
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

Primera actividad práctica del curso. Vas a levantar el stack mínimo de observabilidad local con `docker compose`, confirmar que los targets están siendo scrapeados y hacer tu primera consulta PromQL. Al final, el validador verifica el estado del stack sin intervención.

## 3. Objetivos
- Levantar el stack con `docker compose up -d` y comprobar health de los tres servicios.
- Confirmar en `/targets` que los jobs `prometheus` y `node` están `UP`.
- Ejecutar al menos la query `up` en `/graph` y leer el resultado.
- Diagnosticar un target `DOWN` provocado a propósito.

## 4. Prerrequisitos
- Docker Engine o Docker Desktop con `docker compose` v2 (`docker compose version` debe mostrar `v2.x`).
- Puertos libres en el host: `9090`, `3000`, `9100`.
- `curl` y `bash` disponibles.
- Costos: ninguno (todo local).

## 5. Instrucciones

El `starter/` contiene un `compose.yaml` y un `prometheus/prometheus.yml` **a los que les falta un detalle**. Antes de arrancar:

1. Copia el starter a `/tmp` para no ensuciar el repo:
   ```
   rm -rf /tmp/obs-02-01 && mkdir -p /tmp/obs-02-01
   cp -R starter/. /tmp/obs-02-01/
   cd /tmp/obs-02-01
   ```
2. Abre `prometheus/prometheus.yml`. Vas a notar que falta un job: `node-exporter` no está siendo scrapeado. **Añádelo** con `job_name: "node"` apuntando a `node-exporter:9100` dentro del `compose.yaml`.
3. Levanta el stack:
   ```
   docker compose up -d
   docker compose ps
   ```
4. Verifica health manualmente:
   ```
   curl -fsS http://localhost:9090/-/healthy
   curl -fsS http://localhost:3000/api/health
   curl -fsS http://localhost:9100/metrics | head -3
   ```
5. Abre `http://localhost:9090/targets`. Deberías ver los **dos** jobs en `UP`. Si `node` no aparece, el paso 2 no está completo.
6. Ejecuta la query `up` en `http://localhost:9090/graph`. Observa cuántas series devuelve y qué valores.
7. **Diagnóstico de target DOWN**: para el stack con `docker compose stop node-exporter`. Espera 15s y refresca `/targets`. Lee el error textual en la columna *Last Error* y anota en tu cuaderno qué dice. Vuelve a arrancarlo con `docker compose start node-exporter`.
8. Corre el validador desde el repo:
   ```
   bash activities/01-up-and-running-local-stack/tests/validate.sh
   ```

## 6. Resultado esperado

- `docker compose ps` muestra `prometheus`, `grafana`, `node-exporter` en estado `running` / `Up`.
- `curl http://localhost:9090/api/v1/targets` lista 2 targets con `health: up`.
- `curl 'http://localhost:9090/api/v1/query?query=up'` devuelve `status: success` con 2 series y `value[1] == "1"`.
- `curl http://localhost:3000/api/health` devuelve `database: ok`.

## 7. Criterios de aceptación

- **Funcionalidad:** validador verde (`RESULT: N/N checks OK`).
- **Reproducibilidad:** `docker compose down -v && docker compose up -d` deja el mismo estado.
- **Observabilidad del fallo:** sabes dónde ir (`/targets` → *Last Error*) cuando algo no es scrapeado.

## 8. Validación

```
bash activities/01-up-and-running-local-stack/tests/validate.sh
```

Variables de entorno respetadas por el validador:

- `BASE_DIR` (default `/tmp/obs-02-01`): directorio donde se corrió el stack.
- `USE_SOLUTION=1`: en lugar de usar `BASE_DIR`, el validador arranca el stack desde `solution/` en un project name aislado.

## 9. Preguntas de reflexión
- ¿Por qué `targets: ["node-exporter:9100"]` y no `targets: ["localhost:9100"]`?
- Si cambias `scrape_interval` a `1s`, ¿qué efectos observas en `/status/tsdb`?
- Cuando pararás `node-exporter`, ¿cuál fue el texto exacto de *Last Error*? ¿Qué otro error habrías visto si en vez de parar el contenedor hubieras cambiado el puerto en el `prometheus.yml`?

## 10. Extensiones
- Añade un tercer target: tu propia máquina ejecutando `node_exporter` como binario (fuera de Docker). Pista: `host.docker.internal:9100` desde el contenedor Prometheus en Docker Desktop.
- Haz `curl -X POST http://localhost:9090/-/reload` después de editar `prometheus.yml` y confirma que el cambio aplicó sin reiniciar el contenedor (requiere `--web.enable-lifecycle`, ya está en el compose).

## 11. Limpieza

```
cd /tmp/obs-02-01
docker compose down -v
cd -
rm -rf /tmp/obs-02-01
```
