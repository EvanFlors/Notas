# Ejemplo 03 — Multiprocess mode

Cuando gunicorn/uwsgi corren con N workers, cada worker tiene su propio `REGISTRY`. Prometheus scrapea un worker al azar → ves solo 1/N del tráfico. La solución: modo multiproceso, donde cada worker persiste contadores en archivos `.db` y el handler de `/metrics` los une.

## Requisitos

- `pip install fastapi uvicorn gunicorn prometheus_client`
- Variable `PROMETHEUS_MULTIPROC_DIR` apuntando a un directorio local vacío.

## Correr

```bash
cd $(dirname "$0")
bash run.sh
```

Internamente:
1. Crea `PROMETHEUS_MULTIPROC_DIR` limpio.
2. Lanza gunicorn con 2 workers Uvicorn.
3. Pega varios `GET /hit` → ejecutados por workers distintos.
4. Scrape `/metrics` → `mp_requests_total` suma todos los hits.

## Qué observar

- `mp_requests_total{endpoint="/hit"}` suma contribuciones de los dos workers (y crece con cada hit).
- `mp_worker_pid_info` suma 1 por pid vivo (gracias a `multiprocess_mode="livesum"` el label `pid` se agrega y acaba como un total global).
- Los default collectors (process/GC) *no* se agregan automáticamente: en multiproceso hay que diseñarlos aparte.

## Cuidado

- `PROMETHEUS_MULTIPROC_DIR` **no debe estar en NFS**; usa `/tmp` o un volumen local.
- Limpiar el directorio al arrancar (hay archivos huérfanos de corridas previas).
- `child_exit` en `gunicorn.conf.py` llama `mark_process_dead(pid)` para purgar.
