# Lección — Instalación del stack local y primer scrape

## 1. Punto de partida: por qué empezamos con docker-compose

El stack de observabilidad "canónico" tiene al menos tres piezas incluso en modo laboratorio: un **servidor Prometheus** que scrapea y almacena, un **target** que expone métricas (en este módulo `node_exporter`) y una **UI de usuarios** (Grafana). Montar eso con binarios sueltos funciona, pero no es reproducible: cada estudiante termina con rutas, puertos y versiones distintas. `docker compose` resuelve el problema con **un solo archivo versionable** (`compose.yaml`), DNS interno entre servicios por nombre y aislamiento de red por proyecto.

La duda legítima — "¿por qué no instalar los binarios directamente?" — tiene una respuesta operativa: en producción nadie corre Prometheus desnudo en una VM; corre como contenedor (K8s, ECS, Nomad). El `prometheus.yml` del compose local es el **mismo artefacto** que termina como `ConfigMap` en Kubernetes. Aprender con contenedores es, además, aprender el formato que se usará en producción.

## 2. Imágenes oficiales y versionado

| Componente | Imagen oficial | Puerto por defecto |
|---|---|---|
| Prometheus | `prom/prometheus` | 9090 |
| Grafana | `grafana/grafana` | 3000 |
| node_exporter | `prom/node-exporter` | 9100 |
| Alertmanager (módulos futuros) | `prom/alertmanager` | 9093 |

**Fijar la versión (`:v2.54.1`, `:11.2.0`) nunca es opcional** en material que debe reproducirse: `latest` cambia de semana en semana. En este módulo usamos *tags* mayor.menor concretos para que el laboratorio compile dentro de un año igual que hoy.

## 3. `prometheus.yml` mínimo útil

```yaml
global:
  scrape_interval: 15s        # cada cuánto Prometheus pregunta a los targets
  evaluation_interval: 15s    # cada cuánto evalúa reglas (recording / alerting)

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node"
    static_configs:
      - targets: ["node-exporter:9100"]
```

Tres observaciones:

1. **`global`** define *defaults*; cada `scrape_config` puede sobrescribir `scrape_interval` para targets lentos o caros.
2. El `job_name` termina como *label* `job="..."` en **cada métrica** producida por ese scrape. Elegirlo bien es parte del diseño.
3. El `targets:` del segundo job no es `localhost:9100`, es `node-exporter:9100`. Dentro del `compose.yaml` el **DNS del proyecto** resuelve cada servicio por su nombre.

### `scrape_interval` no es "cada cuánto Grafana refresca"

Es la frecuencia con la que Prometheus pega al endpoint. Si pones `1s` sobre 500 targets con 2000 series cada uno, acabas de añadir **1M writes/s** a la TSDB. Para labs, `15s` es sano; para producción, `15s–60s` es lo común y rara vez `5s`.

## 4. El endpoint `/metrics`

Un target expone métricas en texto plano por HTTP. Ejemplo recortado del `node_exporter`:

```text
# HELP node_cpu_seconds_total Seconds the CPUs spent in each mode.
# TYPE node_cpu_seconds_total counter
node_cpu_seconds_total{cpu="0",mode="idle"} 83241.12
node_cpu_seconds_total{cpu="0",mode="user"} 1912.33
node_cpu_seconds_total{cpu="0",mode="system"} 423.90

# HELP node_memory_MemAvailable_bytes Memory available in bytes.
# TYPE node_memory_MemAvailable_bytes gauge
node_memory_MemAvailable_bytes 1.4876672e+09
```

Reglas del formato *exposition*:

- Una línea por muestra: `metric_name{label1="v1",label2="v2"} VALUE [TIMESTAMP]`.
- `# HELP` es documentación legible; `# TYPE` es `counter|gauge|histogram|summary|untyped`.
- Es **grep-able**. "Mi app no reporta esta métrica" se depura con `curl -s http://app:8080/metrics | grep http_requests_total`.

El formato OpenMetrics es su descendiente estandarizado (CNCF); Prometheus lo acepta como entrada vía `Content-Type` y es compatible hacia atrás con el formato clásico.

## 5. UI de Prometheus: lo mínimo que hay que saber

| Ruta | Para qué |
|---|---|
| `/graph` | Consola PromQL ad-hoc (tab *Table* para instant, *Graph* para range). |
| `/targets` | Estado por target: `UP|DOWN`, última hora de scrape, duración, último error. **Primer sitio al que ir cuando "no veo mi métrica"**. |
| `/alerts` | Reglas de alerta cargadas (en este módulo, vacío). |
| `/rules` | Reglas de recording cargadas. |
| `/status/config` | El `prometheus.yml` tal como Prometheus lo tiene cargado — útil para confirmar que un `reload` tomó efecto. |
| `/status/tsdb` | Tamaño del head block, series activas, chunks, top-10 metrics por serie. |
| `/service-discovery` | Qué targets descubrió cada SD *antes* de relabel y por qué unos quedaron fuera. |

Esta UI está pensada para operadores. **No se le enseña al usuario final**: Grafana es la UI de usuario.

## 6. Grafana inicial

Al arrancar Grafana por primera vez, `admin/admin` es el password temporal (que fuerza cambio al login). Para demos locales ese "cambio" es ruido; se desactiva con la env var `GF_SECURITY_ADMIN_PASSWORD=admin` + `GF_AUTH_DISABLE_LOGIN_FORM=false`. **Para producción jamás** se dejan credenciales por defecto.

Flujo manual (lo que haríamos la primera vez para entender el concepto):

1. Login `admin/admin`.
2. *Connections → Data sources → Add new → Prometheus*. URL: `http://prometheus:9090` (el nombre del servicio en el compose).
3. *Save & test* → "Data source is working".
4. *Explore* → query `up` → *Run query*. Tres filas, una por target, valor `1`.
5. *Dashboards → New → Add visualization → Prometheus → query `rate(node_cpu_seconds_total{mode="idle"}[1m])`*. Guardar.

Lo que acabamos de hacer es manual y por lo tanto **efímero**: `docker compose down -v` destruye el volumen de Grafana y nos devuelve a cero. Es solo pedagógico. El siguiente paso es declararlo.

## 7. Provisioning de Grafana

Grafana lee al arrancar los directorios `/etc/grafana/provisioning/{datasources,dashboards,alerting,notifiers,plugins}`. Lo que esté allí **se materializa como configuración gestionada**: no se puede borrar desde la UI, y se re-aplica en cada reinicio.

Esquema del provisioning que usaremos:

```
grafana/
├── provisioning/
│   ├── datasources/
│   │   └── datasource.yml     # describe el DS Prometheus
│   └── dashboards/
│       └── dashboards.yml     # provider: "lee JSON desde /var/lib/grafana/dashboards"
└── dashboards/
    └── node-basic.json        # el dashboard en sí
```

Lo que un `docker-compose.yaml` monta como volúmenes:

```yaml
volumes:
  - ./grafana/provisioning:/etc/grafana/provisioning:ro
  - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
```

El `:ro` es intencional: Grafana no debe reescribir estos archivos — son el *source of truth*. Si el usuario edita el dashboard en la UI y guarda, Grafana le ofrece *Save as copy* o le avisa que es *provisioned*.

## 8. `node_exporter` como "primer target real"

`node_exporter` expone cerca de 1500 series en un host típico: CPU por core y por modo, memoria, filesystems, red, loadavg, procesos, interrupts, etc. Es **el exporter más usado del ecosistema** y la referencia para entender cómo luce un `/metrics` de verdad.

Importante — **limitación en Docker Desktop (macOS/Windows)**: `node_exporter` dentro de un contenedor Linux solo "ve" el kernel de la VM que Docker Desktop ejecuta por debajo, no el macOS/Windows anfitrión. Lo que mide son métricas del VM-wrapper, no de tu laptop. Para fines didácticos es suficiente; para medir el host real en producción se instala el binario directamente en el nodo (o se usa un DaemonSet en K8s con `hostPID: true` + mounts del `/proc` y `/sys` del host).

## 9. Diagnóstico de un target `DOWN`

Lista corta por error típico en `/targets`:

| Error en la columna *Last Error* | Causa probable |
|---|---|
| `dial tcp: lookup node-exporter: no such host` | El nombre no está en la red del proyecto. ¿El servicio se llama distinto en `compose.yaml`? ¿Está en otra red? |
| `connect: connection refused` | El target está arriba pero no escucha en el puerto esperado. ¿Lo arrancamos en `--web.listen-address=:9100`? |
| `context deadline exceeded (Client.Timeout exceeded...)` | Scrape timeout; target lento o `scrape_timeout` demasiado agresivo. |
| `server returned HTTP status 404 Not Found` | El endpoint no es `/metrics`. Algunos exporters viven en `/actuator/prometheus` (Spring), `/stats/prometheus` (Envoy). Hay que pasar `metrics_path`. |
| `server returned HTTP status 401 Unauthorized` | Basic auth / token requerido; se configura con `basic_auth:` o `authorization:` en el scrape config. |

El workflow operativo real es: `/targets` → leer el error textual → reproducir con `curl` desde dentro de un contenedor en la misma red:

```
docker compose exec prometheus wget -qO- http://node-exporter:9100/metrics | head
```

Si eso funciona pero el scrape no, el problema no es de red: es del `prometheus.yml`.

## 10. Primera consulta útil

Al abrir `/graph` con el stack arriba, estas tres queries deben devolver datos:

| Query | Qué dice |
|---|---|
| `up` | Un 1 por cada target scrapeado con éxito, 0 si falló. Es la métrica más usada en alerting *básico* ("alerta si `up == 0` por 5m"). |
| `rate(node_cpu_seconds_total{mode="idle"}[1m])` | Fracción de segundos *idle* por core por segundo. Multiplicada por 100 y restada de 100 da uso de CPU %. |
| `node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}` | Fracción de disco libre en `/` por target. |

Si `up` devuelve vacío, el problema no es la query: es que ningún target está siendo scrapeado todavía.

## 11. El puente a Kubernetes

Lo que se construye en este módulo **se traslada 1:1** cuando lleguemos a `obs-12 Prometheus Operator`:

| Local (compose) | K8s con Operator |
|---|---|
| `prometheus.yml` como archivo montado | `Prometheus` CR + `ServiceMonitor` + `PodMonitor` (el Operator genera el yml) |
| `datasource.yml` provisionado | `GrafanaDatasource` CR o ConfigMap |
| `node-basic.json` provisionado | `ConfigMap` con label `grafana_dashboard=1` |
| `node_exporter` como servicio | `DaemonSet` del `kube-prometheus-stack` chart |

El objetivo pedagógico de este módulo es que el estudiante **se olvide de la UI de Grafana** para gestión de configuración: todo lo durable es un YAML/JSON en Git.

## 12. Checklist de salida del módulo

- [ ] `docker compose up -d` arranca Prometheus, Grafana y node_exporter.
- [ ] `curl -sf http://localhost:9090/-/healthy` responde `Prometheus Server is Healthy.`.
- [ ] `curl -sf http://localhost:3000/api/health` responde JSON con `"database":"ok"`.
- [ ] En `/targets` los tres jobs están `UP`.
- [ ] La query `up` devuelve 3 series con valor 1 en `/graph`.
- [ ] En Grafana el datasource "Prometheus" aparece **marcado como provisioned**.
- [ ] Un dashboard también provisioned carga un panel con datos reales.
- [ ] `docker compose down -v` deja la máquina limpia (`docker ps -a` y `docker volume ls` vacíos de rastros del proyecto).
