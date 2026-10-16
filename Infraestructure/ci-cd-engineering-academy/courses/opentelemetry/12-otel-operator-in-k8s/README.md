# otel-12-otel-operator-in-k8s — OpenTelemetry Operator en Kubernetes

## Identificación
- **ID:** `otel-12-otel-operator-in-k8s`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `otel-09-collector-deployment-patterns`, `k8s-14-operators-and-crds`

## Objetivo

Operar OpenTelemetry en Kubernetes por el **camino declarativo**: usar el **OTel Operator** y sus CRs (`OpenTelemetryCollector`, `Instrumentation`) para desplegar Collectors en los distintos modos (deployment, daemonset, sidecar, statefulset), inyectar SDKs automáticamente en Pods marcados con annotations, scrapear Prometheus de forma distribuida con **Target Allocator**, y enriquecer telemetría con **k8sattributes**.

## Temas y subtemas

1. **OpenTelemetry Operator** — qué es, por qué existe (vs instalar Collector "a mano" con Helm), dependencias (cert-manager para los webhooks).
2. **CR `OpenTelemetryCollector`** y sus **modes**:
   - `deployment` — Collector "gateway" central con N réplicas.
   - `daemonset` — Collector "agent" por nodo (receivers locales: `hostmetrics`, `filelog` del nodo).
   - `sidecar` — Collector como container al lado del Pod (inyectado vía annotation `sidecar.opentelemetry.io/inject`).
   - `statefulset` — Collector con identidad estable (tail sampling, Target Allocator, cualquier processor stateful).
3. **CR `Instrumentation`** — auto-inject del SDK:
   - Annotations `instrumentation.opentelemetry.io/inject-python=true` (y `-java`, `-nodejs`, `-dotnet`, `-go`).
   - Qué hace el mutating webhook: añade un initContainer que copia el SDK + settea `OTEL_*` env vars + `PYTHONPATH`.
   - Config shared (resource attrs, propagators, sampler, endpoint OTLP).
4. **Target Allocator** — scrape de Prometheus distribuido:
   - Collector `statefulset` + sidecar `targetallocator`.
   - Distribución consistente de targets entre réplicas (consistent hashing / least-weighted).
   - Integración con **Prometheus Operator** (`PodMonitor`, `ServiceMonitor`) vía `allocationStrategy` y `prometheusCR.enabled`.
5. **Receivers "k8s-native"**:
   - `k8sobjects` — watch de recursos K8s (Events, Deployments) como logs/eventos.
   - `k8s_cluster` — métricas de inventario del cluster.
   - `kubeletstats` — métricas por node/pod desde el kubelet local.
6. **Processor `k8sattributes`** — enriquecimiento automático:
   - Extrae `k8s.pod.name`, `k8s.namespace.name`, `k8s.node.name`, labels, annotations desde el API server.
   - RBAC mínimo (ClusterRole con `get`/`list`/`watch` de pods, namespaces, nodes).
7. **Upgrade del Operator** y de los Collectors que gestiona (`spec.image`, imagen por default del Operator, autoReconcile, matriz de versiones).
8. **Operator vs Helm "manual"** — cuándo cada camino, blast radius, debugabilidad, GitOps.

## Conceptos internos (fundamentos)

- El Operator es un **controller** más (ver `k8s-14`): reconcilia `OpenTelemetryCollector` → `ConfigMap` + `Deployment`/`DaemonSet`/`StatefulSet` + `Service` + `ServiceAccount` + RBAC.
- El **webhook mutating** del CR `Instrumentation` es la pieza clave del zero-code: necesita TLS (de ahí **cert-manager**).
- El **Target Allocator** resuelve un problema real: con N réplicas de Collector y M targets Prometheus, sin un allocator cada réplica scrape los mismos targets (duplica métricas) o se requiere particionamiento manual.
- `k8sattributes` funciona por **IP del Pod**: el processor correlaciona la IP source del OTLP con el Pod que lo envió (de ahí que necesite `watch` de pods).
- La diferencia con Helm es filosófica: Helm **renderiza** YAML una vez (upgrade = re-render + apply); el Operator **reconcilia continuamente** — si alguien edita el Deployment generado, el Operator lo revierte.

## Competencias

- **Conceptual:** explicar qué habilita cada *mode* del CR `OpenTelemetryCollector` y cuándo elegir cada uno.
- **Operativa:** instalar el Operator, aplicar un `OpenTelemetryCollector` + `Instrumentation`, verificar la inyección del SDK y el flujo OTLP end-to-end.
- **Arquitectónica:** decidir Operator vs Helm; diseñar un stack con DaemonSet (agent) + StatefulSet (gateway con Target Allocator) + Instrumentation.

## Ejemplos

- `examples/01-operator-install-and-collector-cr/` — instalar cert-manager + OTel Operator en kind y aplicar un `OpenTelemetryCollector` de modo `deployment`.
- `examples/02-instrumentation-python-auto-inject/` — `Instrumentation` CR + Pod Python con annotation; observar el initContainer y las env vars inyectadas.
- `examples/03-k8sattributes-enrichment/` — Collector con receiver `otlp` + processor `k8sattributes` + exporter `debug`; ver atributos `k8s.*` adjuntados automáticamente.

## Actividades

- `activities/01-full-otel-stack-via-operator/` (guided-lab) — stack completo: cert-manager + Operator + DaemonSet agent + Deployment gateway + Instrumentation Python + k8sattributes, con tráfico de prueba.
- `activities/02-upgrade-collector-cr/` (independent) — ejercitar el ciclo de upgrade del `OpenTelemetryCollector` (cambio de imagen, cambio de config, rollout) y comparar vs upgrade Helm.

## Entregables

- Stack OTel completo corriendo en kind, instalado declarativamente.
- Captura de un trace Python auto-inyectado con atributos `k8s.*` presentes.
- ADR corto `OPERATOR_VS_HELM.md` con la decisión justificada para un contexto dado.

## Criterios de evaluación

- **CRs correctos:** `OpenTelemetryCollector` + `Instrumentation` validados por el webhook, Pods generados, config renderizada en ConfigMap.
- **Inyección verificada:** Pod anotado tiene initContainer `opentelemetry-auto-instrumentation` y env vars `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_SERVICE_NAME`, etc.
- **k8sattributes funciona:** telemetría exportada incluye `k8s.pod.name`, `k8s.namespace.name` sin que la app los setee.
- **Upgrade limpio:** cambio de imagen del CR dispara rollout observable (nuevos ReplicaSet / rolling update).

## Recursos

Ver `resources/links.md`.
