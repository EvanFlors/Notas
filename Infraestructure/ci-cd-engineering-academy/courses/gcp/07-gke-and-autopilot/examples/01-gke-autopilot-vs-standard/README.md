# Ejemplo 01 — GKE Autopilot vs Standard

> Lectura y análisis. Sin ejecución. Objetivo: fijar la **tabla mental** para elegir modo de GKE.

## 1. La tabla de referencia

| Dimensión | GKE Standard | GKE Autopilot |
|-----------|--------------|---------------|
| Modelo de nodes | Tú defines node pools, tipos, taints | Google provisiona; tú no ves nodes individuales |
| Facturación | Nodes 24×7 + control plane fee | Por pod/segundo (CPU, memoria, GPU *requested*) |
| Escalado de nodes | `cluster-autoscaler` managed (opt-in) | N/A — no hay nodes para el usuario |
| `hostNetwork` / `hostPID` / `hostIPC` | Permitidos | **Rechazados** en admisión |
| `hostPath` | Permitido | Rechazado (usar `emptyDir` o PVC) |
| `privileged: true` | Permitido | Rechazado |
| DaemonSets custom | Permitidos | Restringidos (solo los aprobados por Google) |
| Modificar `kube-system` | Permitido (bajo tu responsabilidad) | Prohibido |
| Upgrade de control plane | Auto según release channel | Auto según release channel (igual) |
| Upgrade de nodes | Auto opt-in o manual | Forzoso (dentro de maintenance window) |
| GPUs | Soportadas, drivers custom posibles | Soportadas, drivers managed |
| `Service type=LoadBalancer` | Soportado | Soportado |
| Ingress / Gateway API | Soportado | Soportado |
| PersistentVolume (Persistent Disk, Filestore) | Soportado | Soportado |
| StatefulSet | Soportado | Soportado |
| Private cluster | Opt-in | **Default** |
| Workload Identity Federation for GKE | Opt-in (muy recomendado) | **Obligatorio** |
| Shielded nodes | Opt-in | **Obligatorio** |
| Mejor para | Workloads "complejos", DaemonSets, sidecars custom, co-tenencia agresiva, GPUs raras | Aplicaciones "normales", batch esporádico, equipos sin SRE |

## 2. Ejemplos de workloads y modo recomendado

| Workload | Modo recomendado | Por qué |
|----------|-------------------|---------|
| API HTTP stateless con 3–10 pods de Python | **Autopilot** | Aplicación "normal", sin sidecars custom. |
| Jobs batch que suben a 500 pods por 10 min y bajan a 0 | **Autopilot** | Facturación por segundo gana. En Standard, mantener 500 nodes idle fuera de la ventana sería caro. |
| App con sidecar propio de observabilidad que exige `hostPath` para leer logs del host | **Standard** | Autopilot rechaza `hostPath`. |
| Entrenamiento ML con 8× A100 y driver NVIDIA custom | **Standard** | Más control sobre machine type y drivers. |
| Workload PCI-regulado donde el equipo quiere evidencia de que nadie opera los nodes | **Autopilot** | Google opera los nodes; menos superficie que auditar. |
| Service mesh "manual" con sidecar inyectado por el equipo (no Google-managed) | **Standard** | Autopilot restringe inyección de sidecars arbitrarios. |

## 3. Pricing en una línea

- **Standard**: pagas los nodes (p. ej. `e2-standard-4` ≈ 100 USD/mes/node) 24×7 + control plane fee.
- **Autopilot**: pagas los pods *requested*. Un pod con `cpu: 500m, memory: 512Mi` cuesta aproximadamente el equivalente de medio núcleo + medio Gi, con sobrecargo ~15 %. **No hay coste de nodes idle.**

El punto de equilibrio: si tus pods usan **más del 80 %** de los nodes de forma sostenida, Standard sale más barato. Si la utilización es baja o esporádica, Autopilot gana.

## 4. Qué NO cambia entre modos

- `kubectl` funciona igual.
- Los manifiestos de Deployment/Service/Ingress son los mismos (salvo que violen las restricciones de Autopilot).
- RBAC K8s, HPA, VPA, ConfigMaps, Secrets, Jobs, CronJobs: iguales.
- Workload Identity for GKE: funciona igual (y es forzoso en Autopilot, opcional en Standard).

## 5. Preguntas de autocomprobación

1. Un workload necesita `DaemonSet` para un agente antivirus corporativo. ¿Standard o Autopilot? ¿Por qué?
2. ¿En qué caso Standard es **más barato** que Autopilot para el mismo workload?
3. Si en Autopilot un pod declara `cpu: 100m, memory: 128Mi` pero la aplicación realmente usa 300 mCPU y 400 Mi, ¿qué pasa en facturación y qué pasa en el runtime?
4. ¿Puedes correr una app con `privileged: true` en Autopilot? ¿Y en Standard?
5. Un equipo quiere "GKE lo más parecido a Cloud Run posible". ¿Qué modo elegirían y por qué?
