# Service Discovery en Prometheus — Lección

> 12 secciones. Prerrequisito: haber hecho `obs-05` (exporters y relabel).

---

## 1. Por qué existe el service discovery

Prometheus funciona con **modelo pull**: alguien tiene que decirle qué URLs raspar. Las opciones son dos:

1. **Mantener una lista a mano** (`static_configs`): cómodo con 2–3 targets, insostenible con 50.
2. **Dejar que Prometheus descubra**: le damos *una fuente de verdad* (API de Kubernetes, API de EC2, un archivo JSON, un endpoint HTTP), y Prometheus la consulta periódicamente para producir la lista de targets.

El segundo modo es **service discovery (SD)**. SD no decide *qué* scrapear: produce un universo de **targets potenciales** anotados con metadatos (`__meta_*`). Después, los `relabel_configs` filtran y transforman ese universo.

**La distinción es crítica**: si un cluster tiene 1 000 pods, Kubernetes SD genera 1 000 targets potenciales. Sin un relabel que *keep* por anotación o label, se generan 1 000 scrapes por `scrape_interval` — y la mitad fallarán porque no todos los pods exponen `/metrics`.

---

## 2. `static_configs` — el baseline

```yaml
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['host-a:9100', 'host-b:9100']
        labels:
          env: prod
```

Útil para:
- El propio Prometheus (`localhost:9090`).
- 2–3 exporters en una máquina.
- Pruebas locales.

Mal uso: inventario de servicios cambiantes. Cada cambio requiere editar YAML, hacer PR, reload. Es lo que SD vino a resolver.

---

## 3. `file_sd_configs` — SD "a dos pasos"

```yaml
scrape_configs:
  - job_name: 'from-file'
    file_sd_configs:
      - files:
          - '/etc/prometheus/targets/*.json'
        refresh_interval: 30s
```

El archivo (JSON o YAML) tiene forma:

```json
[
  { "targets": ["app-1:8080", "app-2:8080"], "labels": { "env": "staging", "team": "payments" } }
]
```

Prometheus relee el archivo cada `refresh_interval` (o cuando `inotify` detecta cambio). No requiere reload.

**Cuándo usarlo**: cuando ya tienes tooling (CMDB, Ansible, Terraform) que puede generar el JSON. Es la bisagra entre inventario externo y Prometheus sin inventar un SD custom.

---

## 4. Kubernetes SD — el caso dominante

```yaml
scrape_configs:
  - job_name: 'k8s-pods'
    kubernetes_sd_configs:
      - role: pod
```

El `role` define *qué objeto* se descubre:

| role            | genera un target por…                                                  |
|-----------------|-------------------------------------------------------------------------|
| `pod`           | cada contenedor con un puerto declarado                                 |
| `service`       | cada puerto declarado en el `Service` (vía ClusterIP)                   |
| `endpoints`     | cada endpoint listado por el `Endpoints` detrás de un Service           |
| `endpointslice` | igual pero vía `EndpointSlice` (recomendado en clusters modernos)       |
| `node`          | cada `Node` (típicamente para kubelet, cAdvisor)                        |
| `ingress`       | cada regla de `Ingress` (para blackbox probing)                         |

Cada target llega con decenas de labels `__meta_kubernetes_*`:

- `__meta_kubernetes_namespace`
- `__meta_kubernetes_pod_name`
- `__meta_kubernetes_pod_container_name`
- `__meta_kubernetes_pod_container_port_name`
- `__meta_kubernetes_pod_annotation_<ANNOT>` (puntos y guiones a `_`)
- `__meta_kubernetes_pod_label_<LABEL>`
- `__meta_kubernetes_pod_node_name`
- `__meta_kubernetes_pod_ready`
- `__meta_kubernetes_pod_phase`

Son los insumos del relabel.

---

## 5. El patrón canónico: filtrar por annotation

```yaml
scrape_configs:
  - job_name: 'k8s-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      # 1. keep solo pods con prometheus.io/scrape=true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: "true"
      # 2. permitir sobreescribir el path con prometheus.io/path
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      # 3. permitir sobreescribir el puerto con prometheus.io/port
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      # 4. labels útiles
      - source_labels: [__meta_kubernetes_namespace]
        target_label: namespace
      - source_labels: [__meta_kubernetes_pod_name]
        target_label: pod
```

**Por qué es robusto**: cada equipo *opta por entrar* al scrape vía anotación en su manifest; nadie edita el `prometheus.yml` central. Un pod nuevo se vuelve observable sin desplegar Prometheus.

---

## 6. Diferencia target potencial vs scrapeado

- **Target potencial**: lo que SD devuelve (todos los pods).
- **Target descartado**: `action: drop` o `keep` con regex no-match → desaparece.
- **Target activo**: pasa el relabel → aparece en `/targets` con estado `UP` o `DOWN`.
- **Target `UP`**: pasa relabel y el scrape HTTP responde 200.
- **Target `DOWN`**: pasa relabel pero el scrape falla (conexión, 404, timeout).

El flujo mental para debug: ¿SD lo generó? → ¿relabel lo dejó pasar? → ¿el endpoint responde? → ¿la respuesta parsea?

La página `/service-discovery` muestra los targets *potenciales* con todos sus `__meta_*`; `/targets` muestra sólo los que sobrevivieron.

---

## 7. EC2 SD (y otros cloud SD)

```yaml
scrape_configs:
  - job_name: 'ec2'
    ec2_sd_configs:
      - region: us-east-1
        port: 9100
    relabel_configs:
      - source_labels: [__meta_ec2_tag_monitoring]
        action: keep
        regex: "true"
      - source_labels: [__meta_ec2_tag_Name]
        target_label: instance
```

El patrón es idéntico al de K8s SD: SD devuelve todas las instancias; relabel filtra por tag. Mismos conceptos para **GCE SD** (`gce_sd_configs`, labels `__meta_gce_*`), **Azure SD** (`azure_sd_configs`, `__meta_azure_*`), **Consul SD** (`consul_sd_configs`, `__meta_consul_*`), **Nomad SD** (`nomad_sd_configs`, `__meta_nomad_*`).

Requiere credenciales (IAM role, service account) con permiso de *describe/list* sobre la fuente.

---

## 8. HTTP SD — el "SD custom" sin SDK

```yaml
scrape_configs:
  - job_name: 'from-http'
    http_sd_configs:
      - url: https://inventory.corp.internal/prom-targets
        refresh_interval: 30s
```

El endpoint devuelve JSON con la misma forma que `file_sd`:

```json
[ { "targets": ["app:8080"], "labels": { "team": "x" } } ]
```

Útil cuando la fuente de verdad es una app propia (IDP, Backstage, etc.) y no se quiere exportar a archivo plano ni montar volúmenes.

---

## 9. Jerarquía mental de alternativas

| Escenario                                    | SD recomendado                                 |
|----------------------------------------------|------------------------------------------------|
| Local / 1 target                             | `static_configs`                               |
| Inventario generado por tooling              | `file_sd_configs`                              |
| Kubernetes (manual, sin Operator)            | `kubernetes_sd_configs`                        |
| Kubernetes (producción, GitOps)              | **Prometheus Operator** (CRDs — ver `obs-12`)  |
| EC2 / GCE / Azure instance fleet             | cloud SD + relabel por tag                     |
| Consul / Nomad                               | SD nativo correspondiente                      |
| App propia como fuente de verdad             | `http_sd_configs`                              |

---

## 10. Por qué el Prometheus Operator "elimina" el `prometheus.yml`

Con el Operator, se dejan de escribir `scrape_configs` a mano. En su lugar se crean CRDs:

- `ServiceMonitor` — selecciona `Service` por labels, descubre endpoints detrás.
- `PodMonitor` — selecciona `Pod` por labels directamente.
- `Probe` — para blackbox probing.
- `ScrapeConfig` — escape hatch arbitrario (SD nativo).

El Operator *lee los CRDs y genera el `prometheus.yml`* como un `Secret`, que Prometheus monta. Sigue siendo Kubernetes SD + relabel por debajo — pero la autoría es declarativa, por equipo, y vive en el repo del servicio. Esto se cubre en profundidad en `obs-12`.

En este módulo hacemos K8s SD **a mano** precisamente para entender qué está generando el Operator por nosotros.

---

## 11. Diagnóstico de "mi pod no aparece"

Checklist ordenada de causas (de más común a menos):

1. **Falta la annotation**: `prometheus.io/scrape=true` no está en `spec.template.metadata.annotations` del Deployment. Verifica con `kubectl get pod -o yaml | grep -A3 annotations`.
2. **Annotation en el lugar equivocado**: la pusiste en el `Deployment` directamente, no en el `template.metadata`. Prometheus mira el pod, no el Deployment.
3. **Regex de keep incorrecta**: `regex: true` vs `regex: "true"` (sin comillas puede ser ambiguo). Mira el YAML cargado en `/status/config`.
4. **`role` incorrecto**: usas `role: service` pero el target es un pod suelto sin Service. O al revés.
5. **Puerto mal declarado**: `role: pod` necesita que el `container` tenga `ports: - name: metrics containerPort: 8000`. Sin `ports`, SD no genera target.
6. **RBAC**: el ServiceAccount del Prometheus no tiene permiso `list/watch` sobre `pods` en ese namespace. Mira los logs del pod Prometheus (`cannot list resource "pods"`).
7. **NetworkPolicy** bloquea el scrape pod→pod.
8. **El pod no está `Ready`**: Prometheus igualmente lo lista, pero el scrape dará `DOWN`.

Herramienta clave: `/service-discovery` muestra qué `__meta_*` llegan a cada target antes del relabel. Si tu pod no aparece ahí, es paso 5–6; si aparece ahí pero no en `/targets`, es paso 1–4.

---

## 12. Resumen y puente al siguiente módulo

- SD y relabel son dos fases: **SD descubre, relabel decide**.
- `static` solo para lo obvio; `file`/`http` SD como integración con tooling; cloud/K8s SD en entornos dinámicos.
- El patrón universal en K8s es *keep por annotation* `prometheus.io/scrape=true`.
- SD mal filtrado explota en número de scrapes; cada scrape cuesta CPU/RAM al Prometheus y bandwith al target.
- El Operator (obs-12) sube un nivel de abstracción pero sigue siendo esto por debajo.

Siguiente: `obs-07` — instrumentar la app Python para que *tenga* algo que scrapear.
