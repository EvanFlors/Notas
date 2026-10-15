# k8s-10 — Health probes, lifecycle y rollouts

## Identificación

- **ID:** `k8s-10-health-probes-lifecycle-and-rollouts`
- **Curso:** `kubernetes`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `k8s-03-pods-deployments-replicasets`. Un cluster local (kind o k3d) funcional del módulo `k8s-02`.

## Objetivo

Señalar correctamente el **ciclo de vida de un Pod** para lograr rollouts seguros y sin downtime. Al terminar deberías saber instrumentar las tres probes (`startup`, `readiness`, `liveness`) sin provocar restarts en cascada, drenar un Pod con `preStop` + `terminationGracePeriodSeconds`, y tunear `maxSurge`/`maxUnavailable` para un rolling update que respete un `PodDisruptionBudget`.

## Alcance

Este módulo cubre:

- Las tres probes de un contenedor (**startupProbe**, **readinessProbe**, **livenessProbe**) y los cuatro mecanismos (`httpGet`, `tcpSocket`, `exec`, `grpc`).
- Por qué una `livenessProbe` **mal diseñada** amplifica incidentes: restarts en cascada bajo latencia de dependencias.
- `readinessGates` (señales externas que participan en la readiness del Pod).
- Terminación limpia: señal `SIGTERM`, hook `preStop`, `terminationGracePeriodSeconds`, `SIGKILL` como *backstop*.
- Rolling updates: `strategy.rollingUpdate.maxSurge` y `maxUnavailable`, interacción con **PodDisruptionBudget**.
- Blue/green y canary como *referencia* (herramientas específicas — Argo Rollouts, Flagger — se cubren en el curso de **argo-cd**).

Lo que **no** cubre:

- Argo Rollouts, Flagger, análisis automatizado de métricas → curso `argo-cd` / `progressive-delivery`.
- Autoscaling (`HPA`/`VPA`/`KEDA`) → módulo `k8s-13`.
- Service Mesh (Istio, Linkerd, mTLS) → módulo `k8s-15` y curso de observabilidad.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`**:
  - `01-three-probes/` — un Deployment con las tres probes bien separadas: `startup` cubre arranque lento, `readiness` quita el Pod del Service bajo degradación, `liveness` solo mata al proceso realmente colgado.
  - `02-prestop-drain/` — `preStop` con `sleep` + `terminationGracePeriodSeconds` para que los `kube-proxy` y balancers externos dejen de mandar tráfico antes de que el proceso cierre.
  - `03-rolling-update-tuning/` — un Deployment con `maxSurge: 1`, `maxUnavailable: 0` y PDB, observado paso a paso con `kubectl rollout status`.
- **`activities/`**:
  - `01-fix-cascading-restarts/` (**debug independiente**) — una app cuya `livenessProbe` apunta a `/` (una ruta que consulta la base de datos). Bajo pico de latencia en la DB, la probe falla → el Pod reinicia → aumenta la presión sobre la DB → siguiente Pod reinicia. El estudiante debe mover la verificación de dependencias a `readinessProbe` y dejar `liveness` como un `/healthz` barato que solo prueba que el proceso está vivo.
  - `02-zero-downtime-deploy/` (**guided-lab**) — rollout de dos versiones consecutivas instrumentando `preStop`, `terminationGracePeriodSeconds`, probes y `maxUnavailable: 0`, comprobando que un *loop* de `curl` nunca ve 5xx.
- **`resources/links.md`** — docs oficiales, KEPs y lecturas.

## Temas y subtemas

1. Las tres probes y por qué son tres
   - `startupProbe` — "¿ya terminó de arrancar?"
   - `readinessProbe` — "¿puede recibir tráfico ahora?"
   - `livenessProbe` — "¿sigue vivo o debo reiniciarlo?"
2. Mecanismos de probe
   - `httpGet` (status < 400 = sano).
   - `tcpSocket` (apertura TCP = sano; no valida nada del protocolo).
   - `exec` (comando con exit 0 = sano; costo: fork por intento).
   - `grpc` (desde K8s 1.24; usa `grpc.health.v1`).
3. Parámetros temporales
   - `initialDelaySeconds`, `periodSeconds`, `timeoutSeconds`, `successThreshold`, `failureThreshold`.
   - La ecuación: *tiempo máximo antes de reiniciar* = `initialDelay + periodSeconds × failureThreshold`.
4. El anti-patrón "liveness que pega a la DB"
   - Por qué `GET /` como liveness, si `/` toca Postgres, convierte latencia de DB en reinicios.
   - Restart = pérdida de capacidad = más carga sobre el resto = más latencia = más restarts.
5. `readinessGates`
   - Cómo un controller externo puede marcar un Pod como no-ready sin tocar la probe (patrón de LB managed).
6. Terminación de un Pod
   - Qué hace exactamente `kubectl delete pod`: `preStop` + `SIGTERM` **en paralelo** con la remoción de endpoints.
   - La ventana de carrera: `kube-proxy` tarda en actualizar iptables; LB externo puede tardar segundos más.
   - `terminationGracePeriodSeconds`: contador que termina en `SIGKILL`.
7. `preStop` y draining
   - `preStop: exec sleep 10` como truco canónico para absorber la ventana de carrera.
   - Draining a nivel de app vs. draining a nivel de red.
8. Rolling update
   - `strategy.rollingUpdate.maxSurge` (cuántos Pods extra por encima de `replicas`).
   - `maxUnavailable` (cuántos pueden faltar en el peor momento).
   - `revisionHistoryLimit`, `progressDeadlineSeconds`.
9. Interacción con PDB
   - `PodDisruptionBudget` protege ante **disruption voluntaria** (drains, upgrades, el rollout mismo).
   - `minAvailable` vs `maxUnavailable` en el PDB.
10. Blue/green y canary (referencia)
    - Qué resuelven que `RollingUpdate` no (atomicidad del switch, análisis métrico, rollback instantáneo).
    - Dónde se implementan: **Argo Rollouts**, **Flagger** (cubiertos en curso `argo-cd`).
11. Rollback
    - `kubectl rollout undo`, `history`, `pause/resume`.
    - Qué guarda realmente K8s (los ReplicaSets anteriores) y por qué `revisionHistoryLimit=10` es un buen default.
12. Checklist de rollout seguro.

## Conceptos internos (fundamentos)

- Las probes las ejecuta el **kubelet** del nodo, no el `apiserver`. Si el nodo tiene presión de CPU, las probes se ralentizan y el `timeoutSeconds` empieza a disparar falsos positivos.
- `readinessProbe` **no** mata al Pod. Solo lo quita de los `Endpoints`/`EndpointSlice` del Service. El Pod sigue vivo y, si vuelve a reportarse ready, vuelve a recibir tráfico — es la primitiva correcta para "dependencia aguas abajo degradada".
- `livenessProbe` **sí** mata al Pod (el kubelet reinicia el contenedor). Es la primitiva para "el proceso se colgó irrecuperablemente". Toda probe de liveness debe ser **barata y local** (no debe tocar red externa ni DB).
- `startupProbe`, si existe, **suspende** las otras dos hasta que pasa por primera vez. Resuelve el problema histórico de los apps lentos (JVM, migraciones) donde subir `initialDelaySeconds` de `liveness` ensuciaba también `readiness`.
- Terminación: cuando se borra un Pod, el `apiserver` lo marca con `deletionTimestamp` y notifica a dos partes **en paralelo**: (a) el `kubelet` del nodo que corre `preStop` y luego manda `SIGTERM`; (b) los controllers de Service/Endpoints que lo quitan de los endpoints — pero `kube-proxy` tarda ms–segundos en reprogramar iptables, y balancers externos (ELB/NLB/GLB) tardan **segundos**. Sin un `preStop sleep` o un drain a nivel app, hay una ventana en que el Pod ya cerró el listener pero todavía recibe tráfico → conexiones rechazadas.
- `SIGKILL` **no es la señal esperada**: es un *backstop* a los `terminationGracePeriodSeconds` (default 30 s). Si tu app está diseñada para apagarse en 30 s, nunca lo verá; si no lo está, verás resets, datos no flusheados y conexiones half-closed.
- `maxSurge: 25%` y `maxUnavailable: 25%` son los **defaults de Deployment** — razonables para la mayoría, incorrectos para apps críticas donde `maxUnavailable: 0` es obligatorio.

## Competencias

- **Conceptual** — explicar por qué una probe es *liveness* y no *readiness* (o viceversa). Explicar la ventana de carrera entre borrado de endpoint y cierre de proceso.
- **Operativa** — instrumentar las tres probes correctamente, con `startupProbe` para apps lentos; añadir `preStop` + `terminationGracePeriodSeconds` acorde al tiempo real de cierre; medir downtime real con un cliente externo.
- **Arquitectónica** — decidir cuándo `RollingUpdate` basta y cuándo hace falta blue/green o canary. Diseñar la terminación de un servicio con conexiones de larga duración (gRPC, websockets).

## Ejemplos

- [`examples/01-three-probes/`](examples/01-three-probes/) — las tres probes bien separadas en un mismo Deployment.
- [`examples/02-prestop-drain/`](examples/02-prestop-drain/) — `preStop` + `terminationGracePeriodSeconds` demostrado contra un load generator.
- [`examples/03-rolling-update-tuning/`](examples/03-rolling-update-tuning/) — `maxSurge`/`maxUnavailable` tuneados con PDB.

## Actividades

- [`activities/01-fix-cascading-restarts/`](activities/01-fix-cascading-restarts/) — debug independiente: una app cae en loop de restarts por una liveness mal diseñada; arréglala.
- [`activities/02-zero-downtime-deploy/`](activities/02-zero-downtime-deploy/) — guided-lab: rollout de dos versiones sin un solo 5xx observado.

## Entregables

- Un Deployment del capstone con las tres probes correctamente instrumentadas.
- Un `preStop` + `terminationGracePeriodSeconds` demostrablemente alineados con el tiempo real de cierre de la app.
- Un rollout observado con `kubectl rollout status` + `kubectl get pods -w` + un `curl` loop externo que no ve 5xx.
- Un breve ADR (3–5 bullets) justificando los valores elegidos de `maxSurge`, `maxUnavailable`, PDB `minAvailable`, y `terminationGracePeriodSeconds`.

## Criterios de evaluación

- **Conceptual** — explicar en 2–3 frases por qué `livenessProbe: httpGet /` apuntando a una ruta que consulta la DB es un anti-patrón. Explicar qué pasa, segundo a segundo, cuando `kubectl delete pod` se ejecuta.
- **Operativa** — dado un manifiesto con probes incorrectas, corregirlo y defender cada cambio.
- **Arquitectónica** — diseñar la estrategia de rollout de un servicio con 20 conexiones gRPC permanentes por Pod.

## Recursos

Ver [`resources/links.md`](resources/links.md).
