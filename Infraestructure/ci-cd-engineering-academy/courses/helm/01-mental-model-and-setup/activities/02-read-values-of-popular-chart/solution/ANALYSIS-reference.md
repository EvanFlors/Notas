# ANALYSIS (reference) - values.yaml de 3 charts populares

> Autoevaluacion. **No** es la respuesta unica - es *una* respuesta correcta y profesional. Las versiones exactas cambiaran.

## Chart 1: `ingress-nginx/ingress-nginx`

- Chart version: 4.10.0
- App version:   1.10.0 (nginx-ingress-controller)
- Repo: `https://kubernetes.github.io/ingress-nginx`

### Valores destacados

| Valor | Tipo | Default | Para que sirve | Lo tocarias? |
|-------|------|---------|----------------|--------------|
| `controller.replicaCount` | int | `1` | N replicas del Deployment del controller | **Si** (prod: 3+ con PDB) |
| `controller.service.type` | string | `LoadBalancer` | Tipo del Service que expone el controller | Depende: bare-metal -> `NodePort` o `ClusterIP` + MetalLB |
| `controller.autoscaling.enabled` | bool | `false` | Crear un HPA para el controller | **Si** en prod (minReplicas=3, maxReplicas=11 por default) |
| `controller.metrics.enabled` | bool | `false` | Exponer metricas Prometheus | **Si** si usas Prometheus Operator |
| `controller.resources.requests.cpu` | string | `100m` | CPU request del controller | **Si** - ajustar al tamano del cluster |
| `controller.admissionWebhooks.enabled` | bool | `true` | Habilitar admission webhook (valida Ingress) | Normalmente **no** - dejar `true` |
| `defaultBackend.enabled` | bool | `false` | Levantar un backend por defecto para 404 | Depende del caso |

### Observaciones

Convenciones muy estandar (`image.repository`, `image.tag`, `resources`, `nodeSelector`, `tolerations`). El `values.yaml` tiene ~900 lineas y esta dividido por top-level: `controller`, `defaultBackend`, `rbac`, `tcp`, `udp`. El chart es un **monolito funcional** del controller.

---

## Chart 2: `jetstack/cert-manager`

- Chart version: v1.14.4
- App version:   v1.14.4
- Repo: `https://charts.jetstack.io`

### Valores destacados

| Valor | Tipo | Default | Para que sirve | Lo tocarias? |
|-------|------|---------|----------------|--------------|
| `installCRDs` | bool | `false` | Instalar las CRDs del operador via templates | **Si**, poner `true` si no las instalas aparte |
| `replicaCount` | int | `1` | Replicas del Pod principal de cert-manager | **Si** en prod (2 con HA) |
| `webhook.replicaCount` | int | `1` | Replicas del webhook de admission | **Si** en prod (2) |
| `cainjector.replicaCount` | int | `1` | Replicas del cainjector | **Si** en prod (2) |
| `prometheus.enabled` | bool | `true` | Exponer metricas Prometheus | Dejar `true` si usas Prom |
| `global.leaderElection.namespace` | string | `kube-system` | Namespace del leader election | Raramente |
| `extraArgs` | list | `[]` | Flags adicionales al binario | **Si** si necesitas tweaks |

### Observaciones

- La API esta mas plana que ingress-nginx (menos jerarquia profunda).
- Separa `webhook` y `cainjector` como top-level - refleja que cert-manager son **tres Deployments** coordinados.
- `installCRDs: false` por default es un gotcha famoso: si no las instalas aparte, el chart no funciona.

---

## Chart 3: `prometheus-community/kube-prometheus-stack`

- Chart version: 58.0.0
- App version:   v0.72.0 (prometheus-operator)
- Repo: `https://prometheus-community.github.io/helm-charts`

### Valores destacados

| Valor | Tipo | Default | Para que sirve | Lo tocarias? |
|-------|------|---------|----------------|--------------|
| `prometheus.enabled` | bool | `true` | Instalar Prometheus (el componente) | Casi siempre `true` |
| `grafana.enabled` | bool | `true` | Instalar Grafana embebido | Depende |
| `alertmanager.enabled` | bool | `true` | Instalar Alertmanager | Normalmente `true` |
| `prometheus.prometheusSpec.retention` | string | `10d` | Retencion de metricas en Prometheus local | **Si** - ajustar (30d / long-term storage) |
| `prometheus.prometheusSpec.resources.requests.memory` | string | sin default | Memory request de los Pods de Prometheus | **Si** siempre |
| `prometheus.prometheusSpec.storageSpec` | object | `{}` | PVCs para persistir metricas | **Si** en prod |
| `grafana.adminPassword` | string | `prom-operator` | Password admin de Grafana | **Si** - moverlo a Secret |

### Observaciones

- Es el `values.yaml` mas grande (~4000 lineas). Refleja que es un **umbrella chart**: integra `prometheus`, `grafana`, `alertmanager`, `prometheus-operator`, `kube-state-metrics`, `node-exporter` como subcharts.
- `prometheus.prometheusSpec.*` expone casi 1:1 el `Prometheus` CRD del Operator.
- Top-level flags `prometheus.enabled`, `grafana.enabled` permiten desactivar subcomponentes (condicional sobre dependencia; `helm-06`).

---

## Comparacion entre charts

| Dimension | ingress-nginx | cert-manager | kube-prometheus-stack |
|-----------|---------------|--------------|-----------------------|
| Lineas de `values.yaml` | ~900 | ~400 | ~4000 |
| Jerarquia | Profunda bajo `controller.` | Plana | Mixta |
| Pattern | Monolito single-controller | Multi-Deployment coordinados | Umbrella con subcharts condicionales |
| Convencion comun | `image.repository/tag`, `resources`, `nodeSelector` | igual | igual |
| Convencion divergente | `controller.replicaCount` | `replicaCount` + por componente | `prometheus.enabled` + `prometheusSpec.replicas` |

Observaciones:

- Las **convenciones comunes** son best practices Helm (`image.repository/tag`, `resources` requests/limits, `nodeSelector`/`tolerations`/`affinity`, `podSecurityContext`, `serviceAccount.create/name/annotations`, `rbac.create`).
- Las **divergencias** vienen del **modelo del software**: cert-manager tiene 3 Deployments, kube-prometheus-stack es umbrella.
- Mejor organizado (subjetivo): **cert-manager**. Mas honesto con la complejidad real: **kube-prometheus-stack**.

---

## Por que `values.yaml` ES la interfaz del chart

`values.yaml` es el **unico punto por donde el consumidor del chart puede influir** en el YAML que se renderiza y aplica. Es, en el sentido tecnico mas estricto, una **API publica**: tiene superficie, tiene contratos implicitos sobre tipos y semantica, y romperla rompe a usuarios downstream.

Implicaciones concretas:

1. **Versionado.** Anadir keys nuevas con defaults sensatos es compatible (minor bump). Renombrar o eliminar una key es un **breaking change** y requiere major bump + guia de migracion. El mismo rigor que una REST API o una libreria.
2. **Documentacion.** Comentar generosamente `values.yaml` **es** documentar la API. Charts maduros tienen bloques estilo godoc delante de cada key.
3. **Formalizacion con `values.schema.json`.** Un JSON Schema validado antes del rendering convierte la API de "informal con convenciones" a "formal con contrato ejecutable". Evita typos oscuros y permite auto-generar documentacion.
4. **Lectura obligatoria antes de instalar.** Si el consumidor no lee `values.yaml` antes de `helm install`, instala a ciegas y hereda defaults no pensados (p. ej. `controller.service.type: LoadBalancer` facturando dinero en el cloud).
5. **Diseno del chart como producto.** Un buen mantenedor piensa en `values.yaml` como un diseno de producto - que knobs expongo, cuales oculto, que defaults doy. Lo que *no* este en `values.yaml` no es ajustable; es decision intencional.

Cuando dos equipos comparten un chart, **lo que firman no son los templates - es `values.yaml`**. Los templates pueden cambiar completamente entre versiones; mientras la API sea compatible, los consumidores no se enteran.
