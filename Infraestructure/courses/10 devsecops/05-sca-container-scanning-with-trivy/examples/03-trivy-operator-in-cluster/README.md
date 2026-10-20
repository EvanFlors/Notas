# Ejemplo 03 — Trivy Operator en Kubernetes

> Lectura y análisis. Si tienes `kind` y `helm` locales y quieres probarlo, los pasos ejecutables están al final; **no es obligatorio** para pasar las actividades.

## 1. Problema que resuelve el Operator

En CI escaneas en el **build**. En el cluster corren imágenes **ya construidas hace días o semanas**. Mientras tanto el NVD / GHSA publican CVEs nuevas contra paquetes que ya están corriendo en prod. CI atrapa en build; el **Operator atrapa en runtime**.

Preguntas que responde:

> "¿Qué workloads en prod corren una imagen con una CVE publicada **hoy**?"
> "¿Qué pods tienen un misconfig de PodSpec (p. ej. `privileged: true`) ahora mismo?"
> "¿Qué secretos están filtrados en imágenes corriendo en el cluster?"

CI no responde ninguna. El Operator sí.

## 2. Qué instala el Helm chart

Nombre del chart: `aqua/trivy-operator`. Namespace recomendado: `trivy-system`.

Componentes principales:

- **Deployment `trivy-operator`**: el controlador. Watchea Workloads (Deployment, StatefulSet, DaemonSet, CronJob, Pod).
- **Deployment `trivy-operator-trivy-server`** (opcional): instancia centralizada de Trivy en modo server, para no bajar la DB en cada scan job.
- **ConfigMap `trivy-operator-trivy-config`**: policy de severidad, timeout, scanners habilitados.
- **CRDs** (todas en `aquasecurity.github.io/v1alpha1`):
  - `VulnerabilityReport` — un report por `container` × `workload`.
  - `ConfigAuditReport` — misconfigs del PodSpec según policies (Appshield, Rego).
  - `ExposedSecretReport` — secretos detectados en layers de la imagen.
  - `RbacAssessmentReport` — permisos RBAC excesivos.
  - `ClusterSbomReport` — SBOM del cluster entero.
  - `KubeBenchReport` (opcional) — CIS Kubernetes Benchmark.

## 3. Flujo interno (lo que hace el Operator cada ciclo)

```
   Workload creado/actualizado
            │
            ▼
   Operator detecta via watch
            │
            ▼
   Lanza un Job efimero por container
   (imagen aquasec/trivy:X.Y.Z)
            │
            ▼
   El Job escanea la imagen (vuln + config + secret)
            │
            ▼
   Resultado -> CRD <...>Report en el mismo namespace
            │
            ▼
   Operator borra el Job (opcional, keep-jobs=false)
```

Cadencia por defecto: cada 24 h **o** al cambiar el workload **o** al cambiar la Trivy DB. Configurable.

## 4. Lectura rápida de los reports

```bash
# Todas las vulns del cluster
kubectl get vulnerabilityreports -A

# Las CRITICAL en el namespace default
kubectl get vulnerabilityreports -n default \
  -o json | jq '
  .items[]
  | select(.report.summary.criticalCount > 0)
  | { workload: .metadata.ownerReferences[0].name,
      critical: .report.summary.criticalCount,
      high:     .report.summary.highCount }
'

# Que workloads tienen misconfig HIGH o CRITICAL
kubectl get configauditreports -A -o json | jq '
  .items[]
  | select(.report.summary.criticalCount > 0 or .report.summary.highCount > 0)
  | .metadata.name
'

# El SBOM del cluster (CycloneDX)
kubectl get clustersbomreports -o yaml
```

Esos tres `jq` son el 80 % del uso diario. Un dashboard Grafana o un exporter Prometheus (`trivy-operator` expone `/metrics`) convierte eso en SLOs del tipo "% de workloads sin `CRITICAL`".

## 5. Policies para `ConfigAuditReport`

El Operator trae un set de **built-in checks** (Appshield policies, Rego). Los más comunes:

| Check | Qué audita |
|-------|------------|
| `KSV001` | Container ejecutando como root (`runAsUser: 0`) |
| `KSV003` | `allowPrivilegeEscalation: true` |
| `KSV017` | Container `privileged: true` |
| `KSV020` | `hostPID: true` |
| `KSV029` | Container sin `runAsNonRoot: true` |
| `KSV104` | `seccompProfile` no definido |

Se extienden con policies custom en Rego (ver `sec-10` del roadmap).

## 6. Para probarlo (opcional)

Si tienes `kind`, `helm` y `kubectl`:

```bash
# 1. kind cluster efímero
kind create cluster --name sec05-trivy-op

# 2. helm repo
helm repo add aqua https://aquasecurity.github.io/helm-charts/
helm repo update

# 3. Instalar el Operator (pin de version del chart)
helm install trivy-operator aqua/trivy-operator \
  --namespace trivy-system \
  --create-namespace \
  --version 0.24.1 \
  --set="trivy.ignoreUnfixed=true"

# 4. Esperar a que el controller este listo
kubectl -n trivy-system rollout status deploy/trivy-operator --timeout=120s

# 5. Desplegar algo deliberadamente vulnerable
kubectl run badpod --image=alpine:3.14 -- sleep 1h

# 6. Esperar unos segundos y leer los reports
kubectl get vulnerabilityreports -A

# Cleanup
kind delete cluster --name sec05-trivy-op
```

**No corras esto si no tienes `kind` ya instalado** — la actividad `01` no lo requiere.

## 7. Qué queda en manos del cluster y qué sigue en CI

| Ámbito | CI (`trivy image`) | Cluster (`trivy-operator`) |
|--------|--------------------|----------------------------|
| Cuándo | En cada build | Continuo (daily reconcile + on-change) |
| Gate | Bloquea merge | Alerta / dashboard (no bloquea sin extra tooling) |
| Visibilidad | Un log de job | Reports persistentes queryables |
| Enforcement | Sí (merge gate) | No, por diseño — necesitas admisión (Kyverno/VAP) para bloquear |
| Blind spot | No ve lo que ya está en prod si cambia la DB | No ve lo que **nunca** llegó al cluster (p. ej. feature branch builds) |

Las dos capas son **complementarias**. Si solo tienes una, elige CI (gate accionable). Si tienes ambas, el ciclo "detect en runtime → ticket → fix en PR → gate CI → deploy" se cierra.

## 8. Preguntas de reflexión

1. Si el Operator detecta un `CRITICAL` nuevo en una imagen que lleva 3 meses en prod, ¿qué proceso debería dispararse? ¿Quién lo recibe?
2. ¿Por qué el Operator no bloquea deployments por defecto? ¿Qué pasaría si lo hiciera?
3. Si el cluster tiene 500 workloads, ¿cuántos Jobs lanza el Operator en un reconcile completo? ¿Qué configurarías para no saturar?
4. ¿Qué aporta `RbacAssessmentReport` por encima de `ConfigAuditReport`? ¿Cuándo lo usarías?
5. Si tienes **Prometheus + Grafana** instalados (curso `prometheus-grafana`), ¿qué métricas de `trivy-operator /metrics` convertirías en SLO?
