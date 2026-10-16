# obs-12 — Prometheus Operator & kube-prometheus-stack

## Identificación

- **ID:** `obs-12-prometheus-operator-and-kube-prometheus-stack`
- **Curso:** `prometheus-grafana`
- **Nivel:** avanzado
- **Duración estimada:** 5 h
- **Prerrequisitos:** `obs-06-recording-and-alerting-rules`, `obs-09-service-discovery-and-relabeling`, `k8s-14-operators-and-crds` (CRDs y patrón Operator), curso `helm` (al menos chart install/values/upgrade).

## Objetivo

**Operar observabilidad en Kubernetes con el camino "default" moderno.** Instalar y mantener `kube-prometheus-stack` (KPS), modelar scrapes y reglas como CRDs (`ServiceMonitor`, `PodMonitor`, `Probe`, `ScrapeConfig`, `PrometheusRule`, `AlertmanagerConfig`), entender por qué el Operator "ve" o no tus recursos, integrarlo con GitOps (Argo CD + dashboards como ConfigMap) y hacer upgrades seguros.

## Alcance

Este módulo cubre:

- **Prometheus Operator** como *controller* que traduce CRDs → `prometheus.yml` + secret montado.
- **kube-prometheus-stack** (chart Helm) como paquete integrado: Operator + Prometheus + Alertmanager + Grafana + `node-exporter` + `kube-state-metrics` + dashboards y alerts del **`kubernetes-mixin`**.
- CRDs principales: `Prometheus`, `Alertmanager`, `ThanosRuler`, `ServiceMonitor`, `PodMonitor`, `Probe`, `ScrapeConfig` (GA desde Operator v0.65+), `PrometheusRule`, `AlertmanagerConfig`.
- El tema que más duele en producción: **selectors y labels**. Por qué `release: kps` o `prometheus.selector.matchLabels` deciden si tu `ServiceMonitor` aparece o se queda invisible.
- **GitOps**: Argo CD aplica los CRs y las ConfigMap de dashboards (`grafana_dashboard=1`).
- **Multi-tenant**: un `Prometheus` por tenant via `serviceMonitorSelector` + `namespaceSelector`.
- **Upgrade seguro** del stack (CRDs no se actualizan por `helm upgrade`).

Lo que **no** cubre:

- Instalación de Prometheus standalone sin Operator (ya en obs-04/05).
- Reglas de alerta SLO-based + burn-rate en profundidad (es `obs-14`; aquí se usa como consumidor).
- Thanos / Mimir / Cortex (se tocan en `obs-15`).
- Loki, Tempo, OTel Collector (otros módulos).

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`**:
  - `01-kps-via-helm/` — instalar `kube-prometheus-stack` con valores mínimos.
  - `02-servicemonitor-for-fastapi/` — endpoint `/metrics` en una app + `ServiceMonitor` que lo scrapea.
  - `03-dashboard-as-configmap/` — importar dashboards de Grafana como ConfigMap con la label `grafana_dashboard=1`.
- **`activities/`**:
  - `01-full-stack-in-kind/` — guided-lab: cluster kind + KPS + app con `/metrics` + ServiceMonitor + dashboard.
  - `02-add-slo-rules-via-crds/` — independent: escribir un `PrometheusRule` CRD con recording + alerting rules y un `AlertmanagerConfig` con ruta por severidad.
- **`resources/links.md`**.

## Temas y subtemas

1. Por qué Prometheus Operator existe (dolor de `prometheus.yml` manual en K8s).
2. Arquitectura del Operator: controller que observa CRDs → genera `prometheus.yml` → `Secret` → Pod Prometheus recarga.
3. `kube-prometheus-stack`: lo que trae y por qué es el "default" moderno.
4. CRDs de scrape: `ServiceMonitor`, `PodMonitor`, `Probe`, `ScrapeConfig`.
5. CRDs de reglas y routing: `PrometheusRule`, `AlertmanagerConfig`.
6. Selectors: el error #1 ("mi ServiceMonitor no es scrapeado").
7. `kubernetes-mixin`: dashboards y alertas que vienen "de serie".
8. Dashboards as code: ConfigMap con `grafana_dashboard=1` (`sidecar.dashboards`).
9. GitOps con Argo CD: aplicar CRs, patrones de carpeta, ignore de `CRDs`.
10. Multi-tenant: `prometheusSelector`, `serviceMonitorSelector`, `namespaceSelector`.
11. Upgrade seguro: `helm upgrade` **no** actualiza CRDs; `kubectl apply -f crds/`.
12. Troubleshooting operativo: `kubectl get prometheus -o yaml`, `/service-discovery`, `/targets`, "golden signals" del propio stack.

## Conceptos internos (fundamentos)

- El Operator es **declarativo por indirección**: tú describes *intención* (CRs), él genera *configuración* (YAML Prometheus).
- `ServiceMonitor` → `endpoints` (role=`endpoints` de K8s SD) → `targets`. `PodMonitor` → `pods` (role=`pod`). `Probe` → `blackbox_exporter`.
- `ScrapeConfig` (nuevo, promoted GA) permite escribir *cualquier* `scrape_config` nativo sin esperar a que el Operator lo abstraiga — útil para casos "exóticos" (EC2 SD, Consul SD).
- Los dashboards se cargan por un **sidecar** (`k8s-sidecar`) que mira ConfigMaps con la label `grafana_dashboard=1` y los deja en el filesystem de Grafana.
- `helm upgrade` **no** reaplica CRDs por diseño (podría destruir CRs existentes). Hay un paso aparte.

## Competencias

- **Conceptual** — Explicar cómo el Operator genera `prometheus.yml`. Distinguir `ServiceMonitor` vs `PodMonitor` vs `Probe` vs `ScrapeConfig`. Explicar por qué un ServiceMonitor correcto es ignorado si falta la label `release`.
- **Operativa** — Instalar y hacer upgrade de KPS; añadir ServiceMonitor para una app propia; cargar un dashboard como ConfigMap; crear PrometheusRule + AlertmanagerConfig; aplicar todo por Argo CD.
- **Arquitectónica** — Decidir monotenant vs multi-tenant (un Prometheus por equipo), decidir qué va a `PrometheusRule` vs a Grafana alerting, dimensionar retention vs costo.

## Ejemplos

- `examples/01-kps-via-helm/` — instalación mínima con `helm`.
- `examples/02-servicemonitor-for-fastapi/` — app FastAPI + Service + ServiceMonitor.
- `examples/03-dashboard-as-configmap/` — dashboard JSON como ConfigMap con label `grafana_dashboard=1`.

## Actividades

- `activities/01-full-stack-in-kind/` — guided-lab (120 min): cluster kind + KPS + app con `/metrics` + ServiceMonitor + dashboard importado + verificación.
- `activities/02-add-slo-rules-via-crds/` — independent (90 min): dado un escenario, escribir un `PrometheusRule` con recording + alerting y un `AlertmanagerConfig` con ruteo por severidad.

## Entregables

- Cluster kind con KPS instalado y verificable con `kubectl get prometheus,alertmanager,servicemonitor -A`.
- Un `ServiceMonitor` propio apareciendo en `/service-discovery` del Prometheus.
- Un dashboard propio visible en Grafana cargado desde ConfigMap.
- Un `PrometheusRule` con al menos una recording rule y una alerting rule bien formadas.
- Un `AlertmanagerConfig` que separa `critical` de `warning`.

## Criterios de evaluación

- `kubectl get crd | grep monitoring.coreos.com` devuelve ≥ 7 CRDs.
- Un `ServiceMonitor` creado por el estudiante aparece en el UI `/targets` del Prometheus como `UP`.
- La ConfigMap de dashboard tiene la label `grafana_dashboard=1` **y** el dashboard es visible en Grafana sin pasos manuales.
- El `PrometheusRule` pasa `promtool test rules` (opcional pero recomendado).
- El upgrade documentado explica el paso manual de CRDs.

## Recursos

Ver [`resources/links.md`](resources/links.md).

## Siguiente

→ `obs-13-logs-with-loki`: añadir logs al stack ya operativo.
