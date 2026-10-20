# obs-05 — Exporters y relabeling

## Identificación
- **ID:** `obs-05-exporters-and-relabeling`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `obs-02-install-local-stack-and-first-scrape`, `obs-03-metric-types-and-naming`

## Objetivo
Aprovechar el ecosistema de **exporters** para traer métricas de sistemas que no se pueden instrumentar directamente, y usar **relabel_configs** / **metric_relabel_configs** para normalizar, filtrar y controlar la cardinalidad de las series *antes* y *después* del scrape.

## Temas y subtemas

- Exporters comunes
  - `node_exporter` (hardware y OS: CPU, disco, red, filesystem, loadavg).
  - `cAdvisor` (métricas de contenedores; integrado en kubelet).
  - `blackbox_exporter` (probes activos HTTP/HTTPS/TCP/ICMP/DNS).
  - `mysqld_exporter`, `postgres_exporter`, `redis_exporter`.
  - `nginx-prometheus-exporter`, `snmp_exporter`, `cloudwatch_exporter`.
- Writing a custom exporter (resumen)
  - Librerías oficiales (`client_golang`, `prometheus_client` Python).
  - Patrón "collector": implementar `Describe()` + `Collect()`.
  - Cuándo escribir uno (no existe, o el existente agrega labels tóxicas).
- Pipeline de un target: `SD` → `relabel_configs` → `scrape` → `metric_relabel_configs` → `TSDB`.
- `relabel_configs` (aplicado **antes** del scrape)
  - Keys: `source_labels`, `separator`, `regex`, `target_label`, `replacement`, `modulus`, `action`.
  - Acciones: `replace`, `keep`, `drop`, `labelmap`, `labeldrop`, `labelkeep`, `hashmod`, `lowercase`, `uppercase`.
  - Labels mágicos: `__address__`, `__scheme__`, `__metrics_path__`, `__param_<name>`, `__meta_*`, `__tmp_*`.
- `metric_relabel_configs` (aplicado **después** del scrape, antes de persistir)
  - Último recurso para drop por cardinalidad (`__name__` como `source_labels`).
  - No puede influir en qué se scrapea, solo en qué se guarda.
- Pipeline de Blackbox: Prometheus → `/probe?target=X&module=Y` → exporter → target → métricas sintéticas (`probe_success`, `probe_duration_seconds`, `probe_http_status_code`).

## Conceptos internos (fundamentos)

- **Relabel es "programación con regex sobre labels"**. Es el único momento donde se puede filtrar, renombrar o descartar targets/métricas **antes** de que entren a la TSDB. Todo lo que no se filtra aquí se paga en RAM y en cost de query.
- `__meta_*` labels existen **solo** durante la fase relabel y desaparecen al persistir. Son el canal entre service discovery y configuración.
- `metric_relabel_configs` es la **red de seguridad**: cuando un deploy introduce una métrica nueva de alta cardinalidad y no se puede desplegar el fix a la app en el momento, se dropea en el scraper.
- Cada exporter diseñado por otro equipo tiene sus propias decisiones de labels; la responsabilidad del operador es homogenizarlas (p. ej. llamar `instance` a lo mismo en todos los jobs).

## Competencias

- **Conceptual**: diferenciar `relabel_configs` de `metric_relabel_configs`; explicar por qué `labelmap` es idiomático con K8s SD.
- **Operativa**: desplegar y scrapear `node_exporter`, `blackbox_exporter`, `postgres_exporter`; aplicar reglas de relabel para normalizar e identificar la métrica ruidosa.
- **Arquitectónica**: diseñar una convención de labels (jobs, teams, envs) consistente a nivel de plataforma; definir cuándo escribir un exporter custom vs reutilizar uno existente.

## Ejemplos

- [`examples/01-node-exporter-scrape`](examples/01-node-exporter-scrape) — stack mínimo Prometheus + node_exporter con tres queries de verificación.
- [`examples/02-blackbox-probe`](examples/02-blackbox-probe) — probe HTTP/HTTPS con relabel que mueve `__param_target` a label `instance`.
- [`examples/03-relabel-tidy-labels`](examples/03-relabel-tidy-labels) — compara dos `prometheus.yml`: con y sin relabel, muestra la diferencia en labels y cardinalidad.

## Actividades

- [`activities/01-add-postgres-exporter`](activities/01-add-postgres-exporter) — **guided-lab**: agregar `postgres_exporter` al stack y verificar métricas `pg_up`, `pg_stat_database_xact_commit`.
- [`activities/02-relabel-dedup-labels`](activities/02-relabel-dedup-labels) — **independent**: dadas tres métricas duplicadas por labels redundantes y una métrica ruidosa, escribir las reglas de relabel que las dejan limpias.

## Entregables

- `prometheus.yml` con **3+ jobs** (al menos `node`, `blackbox`, `postgres`) usando relabel.
- Documento corto (`decisions.md` dentro de cada actividad) justificando cada regla de relabel.
- Métrica ruidosa dropeada vía `metric_relabel_configs` con comentario explicando por qué.

## Criterios de evaluación

- **Conceptual**: ante un `/metrics` dado, identificar la métrica más ruidosa por cardinalidad y proponer `metric_relabel_configs` que la dropee sin romper los dashboards.
- **Operativa**: `curl -s localhost:9090/api/v1/targets` muestra los jobs en `health=up`; la query `count by (__name__)({job="..."}, )` baja tras aplicar relabel.
- **Arquitectónica**: justificar por qué una convención `env`/`team`/`service` como labels obligatorios reduce complejidad en Grafana y Alertmanager.

## Recursos

Ver [`resources/links.md`](resources/links.md).
