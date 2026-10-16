# obs-02 — Install local stack and first scrape

## Identificación
- **ID:** `obs-02-install-local-stack-and-first-scrape`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `obs-01-observability-pillars-and-pull-model`, curso **docker** (≥ `dkr-08-compose-for-development`).

## Objetivo
Levantar un stack local de observabilidad con **Prometheus + Grafana + node_exporter** usando `docker compose` y verificar el primer *scrape* end-to-end: targets `UP`, consulta PromQL en la UI de Prometheus y primer panel en Grafana (incluyendo datasource y dashboard **provisionados** declarativamente).

## Temas y subtemas
1. Binarios e imágenes oficiales (`prom/prometheus`, `grafana/grafana`, `prom/node-exporter`).
2. `prometheus.yml` mínimo: bloque `global` (`scrape_interval`, `evaluation_interval`), bloque `scrape_configs` (`job_name`, `static_configs.targets`).
3. El endpoint `/metrics`: formato texto *exposition*; línea `# HELP`, línea `# TYPE`, muestra `metric_name{label="value"} 123`.
4. UI de Prometheus:
   - `/graph` — ad-hoc PromQL.
   - `/targets` — estado de cada scrape (`UP` / `DOWN` + último error).
   - `/alerts` — reglas de alerta cargadas (vacío en este módulo).
   - `/status/config` — `prometheus.yml` renderizado.
   - `/status/tsdb` — stats de la TSDB (series, blocks, head size).
5. Grafana inicial: login `admin/admin`, cambio de password, añadir Prometheus como data source por URL `http://prometheus:9090`.
6. Primer panel: query `up`, panel *stat*; query `rate(node_cpu_seconds_total{mode="idle"}[1m])`, panel *time series*.
7. **Provisioning** de Grafana por YAML en `/etc/grafana/provisioning/{datasources,dashboards}` → nada de "clicks" en producción.
8. `node_exporter` como primer target real; qué expone (`node_cpu_seconds_total`, `node_memory_MemAvailable_bytes`, `node_filesystem_*`, etc.).

## Conceptos internos (fundamentos)
- **Pull simétrico**: Prometheus solo necesita alcanzar HTTP del target; en Compose eso significa resolver el servicio por nombre DNS del proyecto.
- **Formato texto intencionalmente simple**: `curl -s http://target/metrics | grep foo` es un workflow de debugging real; nada binario.
- **UI de Prometheus = *development only***: existe para operadores y para debugging, no para usuarios finales. Grafana es la UI de usuarios.
- **Provisioning > clics**: lo manual se pierde con el próximo `docker compose down -v`; lo declarativo vive en Git y se reproduce.

## Competencias
- **Conceptual:** explicar cómo Prometheus descubre y scrapea un target, y por qué el `/metrics` del target debe hablar texto *exposition*.
- **Operativa:** levantar el stack con `docker compose up`, abrir `/targets`, provisionar un datasource y un dashboard sin tocar la UI.
- **Arquitectónica:** diferenciar "stack de desarrollo" (una sola máquina, un `compose.yaml`) de los componentes que persistirán sin cambios estructurales al pasar a Kubernetes (`prometheus.yml`, `datasources.yaml`, `dashboards.yaml`, los JSON de dashboards).

## Ejemplos
- [`examples/01-compose-prom-grafana-node`](examples/01-compose-prom-grafana-node/) — stack mínimo Prometheus + Grafana + node_exporter.
- [`examples/02-grafana-provisioning`](examples/02-grafana-provisioning/) — datasources y dashboards declarativos.
- [`examples/03-first-dashboard-panel`](examples/03-first-dashboard-panel/) — primer dashboard JSON con un panel de CPU idle.

## Actividades
- [`activities/01-up-and-running-local-stack`](activities/01-up-and-running-local-stack/) — *guided-lab*: levantar el stack, verificar `/targets`, ejecutar una PromQL.
- [`activities/02-provision-grafana-declaratively`](activities/02-provision-grafana-declaratively/) — *independent*: completar `provisioning/` para que al arrancar ya exista datasource y un dashboard.

## Entregables
- Stack local reproducible: `docker compose up -d` → Prometheus en `:9090`, Grafana en `:3000`, node_exporter en `:9100`.
- Grafana con datasource Prometheus y un dashboard provisionado declarativamente.
- Capturas de `/targets` mostrando los tres jobs `UP`.

## Criterios de evaluación
- **Conceptual:** describir el ciclo "scrape → store → query" en 3 líneas; distinguir `scrape_interval` de `evaluation_interval`.
- **Operativa:** diagnosticar un `target DOWN` leyendo el "Last error" en `/targets` (ej. `connect: connection refused`, `dial tcp: lookup`).
- **Arquitectónica:** justificar por qué todo lo demostrado aquí ya está diseñado para portarse a Kubernetes sin cambios de concepto (el `prometheus.yml` muta a ConfigMap/`ServiceMonitor`, el dashboard JSON a ConfigMap con la label `grafana_dashboard=1`).

## Recursos
Ver [`resources/links.md`](resources/links.md).
