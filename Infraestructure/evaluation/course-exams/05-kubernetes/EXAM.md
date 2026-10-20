# Examen de certificación — Kubernetes (intermedio-avanzado)

> Alcance: módulos `k8s-06` a `k8s-14` del `courses/kubernetes/ROADMAP.md`, con guiños a `k8s-15/16`.
> Nivel: intermedio-avanzado. Dimensiones: conceptual + operativa + arquitectónica.
> Duración total: **90–120 min**. Umbral de aprobación: **70%** del total ponderado.
> Entorno: cluster local **kind** (requisito) + editor + `kubectl`. Sin recursos cloud.

---

## 0. Instrucciones generales

- Responde en prosa en español; **código, YAML y comandos en inglés** tal cual.
- No pegues secretos reales. Si un ejercicio necesita credenciales, usa placeholders (`REPLACE_ME`) o `Secret` generado localmente con `kubectl create secret`.
- Si no sabes algo, dilo. Vale más una respuesta parcial honesta que una fabricada.
- Si el instructor evalúa en vivo, prepárate para **preguntas de seguimiento** (incluidas en la guía de corrección).
- Ponderación final:
  - Conceptual: **30 pts** (7 preguntas).
  - Operativo (kind): **40 pts**.
  - Arquitectónico (ADR): **30 pts**.
  - Umbral: **70 / 100**.

---

## 1. Matriz de competencias evaluadas

Ver `competency-matrix.yaml` (fuente de verdad para pesos y mapeo a módulos).

| ID | Competencia | Dimensión | Peso |
|----|-------------|-----------|------|
| K8S-C1 | Elegir workload controller correcto (Deploy/StatefulSet/DS/Job/CronJob) | conceptual | 8 |
| K8S-C2 | Diseñar NetworkPolicies default-deny + reglas explícitas | conceptual | 8 |
| K8S-C3 | Explicar `volumeBindingMode` en multi-AZ | conceptual | 6 |
| K8S-C4 | Diagnosticar OOMKill vs CPU throttling | conceptual | 8 |
| K8S-C5 | Probes startup/readiness/liveness y rollouts | conceptual | 8 |
| K8S-C6 | Auditar RBAC y proponer least privilege | conceptual | 6 |
| K8S-C7 | HPA/VPA/CA/Karpenter: elección y riesgos | conceptual | 6 |
| K8S-O1 | Deploy en `kind` con probes + PDB + rollout | operativa | 20 |
| K8S-O2 | NetworkPolicy default-deny validada en `kind` | operativa | 10 |
| K8S-A1 | ADR de plataforma K8s multi-equipo | arquitectónica | 20 |

Nota: los pesos conceptuales suman 50 en bruto, pero la sección aporta **30 pts al total**; se escala proporcionalmente (regla de tres).

---

## 2. Preguntas conceptuales (dimensión conceptual · 30 pts)

Responde cada una en 4–10 líneas. Prohibido copiar la pregunta como respuesta.

### P1 (K8S-C1 · 5 pts)

Tienes tres cargas: (a) un servicio HTTP sin estado con 20 réplicas, (b) un cluster de Postgres de 3 nodos con identidad estable y PVCs por réplica, (c) un agente que **debe correr exactamente una vez en cada nodo**, incluyendo nuevos nodos que entren por autoscaling.

- ¿Qué controller eliges para cada una y **por qué**?
- Para la (b), **¿qué pasaría si** la expones vía un `Service` tipo `ClusterIP` normal en lugar de un `headless Service`?

### P2 (K8S-C2 · 5 pts)

En un cluster sin NetworkPolicies, un pod comprometido del namespace `frontend` puede llamar a Postgres en `data`. Describe:

- Qué regla **mínima** aplicarías en `data` para cortar ese tráfico sin romper el acceso del `api` namespace.
- **¿Por qué** una `NetworkPolicy` que **solo** define reglas `ingress` **no basta** para evitar que un pod comprometido exfiltre a Internet?

### P3 (K8S-C3 · 4 pts)

En EKS multi-AZ, un equipo creó una `StorageClass` con `volumeBindingMode: Immediate` y ahora algunos Pods quedan `Pending` con "node(s) had volume node affinity conflict". Explica **la causa raíz** y **por qué** `WaitForFirstConsumer` hubiera evitado el problema. ¿En qué escenario `Immediate` **sí** es la elección correcta?

### P4 (K8S-C4 · 5 pts)

Dos síntomas:

- (a) El pod reinicia con `Reason: OOMKilled` y `ExitCode: 137`.
- (b) El pod no reinicia pero sus latencias p99 suben a 5× cuando hay carga, y `container_cpu_cfs_throttled_periods_total` crece.

Para cada caso: **¿qué parámetro ajustas y por qué**? **¿Qué pasaría si** solo subes `limits` sin tocar `requests` en el caso (b) en un nodo lleno?

### P5 (K8S-C5 · 5 pts)

Un equipo define `livenessProbe: httpGet /health`, y `/health` hace `SELECT 1` contra Postgres. Durante un incidente de red, **todos** los Pods del Deployment entran en `CrashLoopBackOff` a la vez.

- Explica **por qué** este patrón es un anti-patrón.
- **¿Cuándo** usarías `startupProbe` en vez de aumentar `initialDelaySeconds` del `livenessProbe`?
- ¿Qué garantiza `readinessProbe` que `livenessProbe` **no** garantiza?

### P6 (K8S-C6 · 3 pts)

Encuentras este binding en producción:

```yaml
kind: ClusterRoleBinding
metadata: { name: ci-deployer }
roleRef: { kind: ClusterRole, name: cluster-admin, apiGroup: rbac.authorization.k8s.io }
subjects:
  - kind: ServiceAccount
    name: ci
    namespace: ci
```

¿Qué está mal? Propón el **esqueleto** (sin escribirlo entero) de un `Role` + `RoleBinding` de mínimo privilegio asumiendo que el pipeline solo despliega `Deployment` y `Service` en los namespaces `app-dev` y `app-staging`.

### P7 (K8S-C7 · 3 pts)

Un equipo activa **HPA sobre CPU** y **VPA en modo `Auto`** sobre la misma Deployment, apuntando a la misma métrica. Explica **qué sale mal** y propón una configuración coherente. Luego, diferencia **cuándo** usarías **Cluster Autoscaler** vs **Karpenter**.

---

## 3. Ejercicio operativo (dimensión operativa · 40 pts)

Materiales de inicio: `operative/` (ver README allí).
Entorno obligatorio: **cluster local kind** (no cloud).

Resumen: desplegarás una app HTTP (`hashicorp/http-echo` como stand-in de FastAPI, sin build) con:

1. `Deployment` de 3 réplicas con probes `startup/readiness/liveness` correctamente diferenciadas.
2. `Service` ClusterIP + `NetworkPolicy` que implemente **default-deny** en el namespace + regla explícita que permita tráfico **solo** desde un pod cliente etiquetado `role=client`.
3. `PodDisruptionBudget` con `minAvailable: 2`.
4. Un **rolling update** cambiando el `-text` del contenedor y demostrando **cero errores** desde el pod cliente durante el rollout.

Validación: ejecuta el script `operative/validate.sh`. Debe salir con exit code 0. Entregables detallados en `operative/README.md`.

Peso dentro de la sección operativa:

- Deployment correcto + probes diferenciadas: **12 pts** (K8S-O1).
- PDB + rolling update sin errores observados: **8 pts** (K8S-O1).
- NetworkPolicy default-deny + regla explícita validada: **10 pts** (K8S-O2).
- Manifiestos limpios (labels/selector coherentes, resource requests, no `latest`, no `hostPath`): **10 pts** (K8S-O1).

---

## 4. Ejercicio arquitectónico (dimensión arquitectónica · 30 pts)

Lee `architectural/scenario.md`. Produce un ADR siguiendo la plantilla en ese documento.

Peso:

- Diseño coherente con requisitos y restricciones: 10 pts.
- Trade-offs explícitos (al menos 3, con alternativa descartada y razón): 8 pts.
- Riesgos + mitigaciones + plan de reversión: 7 pts.
- Decisión defendible (incluye lo que **no** harás y por qué): 5 pts.

---

## 5. Rúbrica

### 5.1 Rúbrica — Preguntas conceptuales (aplica a cada P)

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|----------|------------------|------------|----------------|-------------|
| Correctness | Respuesta incorrecta o inventada | Idea correcta, detalles errados | Correcta y precisa | Correcta + contraejemplo o matiz útil |
| Razonamiento | Afirmación sin "por qué" | Justifica a nivel superficial | Justifica con mecanismo real (reconciler, kube-proxy, scheduler...) | Justifica + predice qué cambia si cambia una restricción |
| Precisión técnica | Términos mezclados (Pod/Deployment, limits/requests) | Términos correctos mayoría | Términos correctos + distingue conceptos próximos | Mismo + referencia a comportamiento documentado |

Puntaje de la pregunta = redondeo al cuarto más cercano del promedio de criterios, escalado al peso de la pregunta.

### 5.2 Rúbrica — Ejercicio operativo (K8S-O1 + K8S-O2)

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|----------|------------------|------------|----------------|-------------|
| Correctness (manifiestos aplican, pods Ready) | No aplica o pods no Ready | Aplica con warnings | Aplica limpio, pods Ready | Mismo + idempotente, sin edición manual |
| Probes diferenciadas | Una sola probe o todas iguales | Las tres existen pero misma ruta/semántica | Tres probes con semántica distinta justificable | Mismo + `startupProbe` protege arranque lento |
| NetworkPolicy | No existe o permite todo | Default-deny sin reglas explícitas (rompe app) | Default-deny + regla por podSelector/puerto | Mismo + egress DNS explícito + validación con pod no autorizado |
| Rollout sin downtime | Hay 5xx/connection refused del cliente | Pocos errores durante switch | 0 errores con `maxUnavailable: 0` o PDB coherente | Mismo + evidencia (logs del cliente adjuntos) |
| Seguridad básica | `latest`, `hostPath`, root, `privileged` | Falta uno de: requests, non-root | Imagen pineada, non-root, requests presentes | Mismo + `readOnlyRootFilesystem` + `capabilities: drop: [ALL]` |
| Validación | `validate.sh` falla | Falla parcial | `validate.sh` ok | ok + estudiante corrió también un test manual propio |

Peso total 40 pts; cada criterio pesa igual (≈6.6 pts, máximo 3 por criterio × 2 ≈ 40 escalado).

### 5.3 Rúbrica — Ejercicio arquitectónico (K8S-A1)

| Criterio | Insuficiente (0) | Básico (1) | Competente (2) | Experto (3) |
|----------|------------------|------------|----------------|-------------|
| Comprensión del escenario | Ignora requisitos clave | Cubre la mayoría | Cubre todos | Mismo + identifica requisito faltante y lo pregunta |
| Trade-offs | Solo propone una opción | Compara 2 superficialmente | Compara 2–3 con pros/contras concretos | Mismo + condiciones bajo las que cambiaría |
| Riesgos y mitigaciones | No menciona | Lista genérica (sin mitigación) | Riesgos específicos del diseño + mitigación | Mismo + plan de reversión y métricas de alerta |
| Decisión defendible | Decisión arbitraria | Decisión sin "qué no hago" | Explícita + "no haré X porque Y" | Mismo + define el punto en que reconsideraría |
| Alineación con restricciones | Rompe alguna restricción explícita | Las cumple mínimamente | Todas con holgura | Mismo + muestra cómo la decisión escala si cambian |

---

## 6. Guía de corrección (instructor-only)

### 6.1 Respuestas modelo — Conceptuales

**P1** (K8S-C1):

- (a) `Deployment` — stateless, replicable, rolling update nativo.
- (b) `StatefulSet` — identidad estable (`pg-0`, `pg-1`), orden de arranque/parada, PVCs por réplica vía `volumeClaimTemplates`. Postgres necesita identidad para replicación lógica/física y para no reusar un PVC equivocado.
- (c) `DaemonSet` — garantiza un pod por nodo y añade uno automáticamente al escalar.
- *What-if headless:* un `ClusterIP` normal da un **VIP** y balancea entre réplicas; el cliente no puede dirigirse al **`pg-0`** específicamente, lo que rompe clientes que necesitan hablar con el primary o un replica concreto. Headless (`clusterIP: None`) devuelve A-records por pod y es lo que StatefulSet asume.
- Puntos clave que deben aparecer: "identidad estable", "orden", "PVC por réplica", "DNS por pod".
- Parcial: menciona StatefulSet pero no explica identidad → 2 pts de 3 en Razonamiento.

**P2** (K8S-C2):

- `NetworkPolicy` en `data` con `podSelector` matcheando Postgres y `ingress` desde `namespaceSelector: {kubernetes.io/metadata.name: api}` + `ports: [{port: 5432}]`. Nada más.
- *Por qué solo ingress no basta:* una `NetworkPolicy` que define **solo** `policyTypes: [Ingress]` deja el egress en modo "allow-all" (por default K8s permite todo hasta que una policy aplique a esa dirección). Para evitar exfiltración necesitas también una policy `Egress` (o default-deny egress + whitelist a DNS y servicios internos).
- Red flag si contesta: "basta con denegar ingress porque el atacante no puede recibir respuestas" → confunde modelo (fallo de concepto).

**P3** (K8S-C3):

- Con `Immediate`, el PV se aprovisiona en una AZ **antes** de que el scheduler decida en qué nodo correr el pod. Si el scheduler elige nodo en otra AZ, el pod no puede montar el volumen → `volume node affinity conflict`.
- `WaitForFirstConsumer` difiere la creación del PV hasta que el pod sea scheduled; así el provisioner elige la misma AZ.
- `Immediate` tiene sentido con storage **de verdad RWX cross-AZ** (ej. EFS, FSx), donde el PV no está atado a una AZ.

**P4** (K8S-C4):

- (a) OOMKill → la app excedió el `memory limit`. Acciones: subir `limits.memory` basado en RSS observado, revisar leak, considerar heap tuning. **No basta con subir requests**: el kill lo dispara el limit.
- (b) CPU throttling → `cpu limit` muy bajo. Acciones: subir `limits.cpu` **o quitarlo** si la app es ciudadana responsable. `requests` solo ayudan al scheduler, no afectan throttling.
- *What-if subir solo `limits` sin tocar `requests` en nodo lleno:* el scheduler ya metió el pod en un nodo con "cupo" según `requests`; subir solo `limits` deja al pod competir por CPU con otros y el throttling puede persistir — pero sobre todo, en memoria aumentas el riesgo de OOM del nodo (overcommit) porque la suma de `limits` puede superar la capacidad.

**P5** (K8S-C5):

- Anti-patrón: `liveness` depende de dependencia externa (Postgres). Si Postgres cae o la red falla, **todos** los pods fallan la probe y K8s los mata → `CrashLoopBackOff` sincrónico. La app "sana" se destruye por un problema externo. `liveness` debe medir solo "este proceso está vivo y responde".
- `startupProbe` cuando el arranque es largo (migraciones, warmup, carga de modelo) y no quieres acoplar la paciencia del arranque con la del liveness en estado normal.
- `readinessProbe` saca el pod del `Service` endpoints (deja de recibir tráfico) **sin matarlo**; `liveness` no afecta tráfico, mata al pod.

**P6** (K8S-C6):

- `cluster-admin` para un pipeline es violación brutal de least privilege; además es `ClusterRoleBinding` → todos los namespaces.
- Solución: `Role` namespaced con verbs `get, list, create, update, patch, delete` sobre `deployments.apps`, `services`, `configmaps` en `app-dev` y `app-staging`. Dos `RoleBinding` (uno por namespace). SA en namespace `ci` con `OIDC`/token projection.
- Debe mencionar: separar por namespace, verbs mínimos, no `*`, no `secrets` salvo necesidad justificada.

**P7** (K8S-C7):

- HPA cambia `replicas` leyendo CPU; VPA en `Auto` cambia `requests/limits` de los pods vivos (reinicio). Si ambos leen CPU, se pelean: VPA sube requests → HPA cree que hay más headroom → menos escalado horizontal; o VPA baja requests y HPA escala en vertical artificial. Resultado: oscilación.
- Config coherente: HPA sobre CPU y VPA en `Off`/`Initial` para solo recomendar, **o** VPA en `Auto` sobre memoria mientras HPA mira CPU/custom metric. Nunca ambos sobre la misma métrica en `Auto`.
- CA vs Karpenter: CA opera sobre **Node Groups/ASGs preexistentes**, reactivo a `Pending` Pods, provisioning uniforme. Karpenter es scheduler-aware, elige el tipo de instancia óptima por pod y consolida nodos subusados; mejor en workloads heterogéneos y bursty. CA sigue vigente donde no hay Karpenter (GKE Autopilot) o se quiere simplicidad y pools fijos.

### 6.2 Guía — Ejercicio operativo

Solución de referencia: `operative/solution/` (no distribuir al estudiante; usar para comparar).
Script de validación: `operative/validate.sh` chequea:

1. Namespace `exam` existe.
2. `Deployment/http-echo` tiene 3 pods Ready.
3. Los pods tienen las 3 probes definidas (`kubectl get deploy -o jsonpath` sobre `startupProbe`, `readinessProbe`, `livenessProbe`).
4. `NetworkPolicy` default-deny existe + policy explícita permite al pod `role=client`.
5. Un pod `role=unauth` **no** puede conectar al Service (timeout).
6. El pod `role=client` **sí** puede conectar y obtiene 200.
7. PDB `minAvailable: 2` existe para el deployment.

Errores comunes:

- Olvidan `policyTypes: [Ingress, Egress]` y dejan egress abierto → señal de "no entendió el modelo aditivo".
- Usan `livenessProbe` idéntica a `readinessProbe` → punto 2 de rúbrica a 1.
- Usan `imagePullPolicy: Always` + `:latest` → 0 en Seguridad básica.
- Ponen `hostPath` para "logs" → red flag; descartar sección Seguridad.
- Pasan validación pero sus manifiestos incluyen `cluster-admin` RoleBinding "por si acaso" → red flag arquitectónico (restar en limpieza).

Red flags que **invalidan** el ejercicio (no suma puntos aunque `validate.sh` pase):

- `Secret` con credencial real pegada en el manifiesto.
- `privileged: true`, `hostNetwork: true` o `hostPID: true` sin justificación.
- `ClusterRoleBinding` a `cluster-admin` para el SA de la app.
- `curl | bash` en un init script sin pin de versión ni checksum.

### 6.3 Guía — Ejercicio arquitectónico

Esperado: ADR en formato Michael Nygard (Contexto, Decisión, Consecuencias, Alternativas, Estado).
Debe decidir sobre al menos: control plane managed vs self-hosted, policy engine (Kyverno vs Gatekeeper vs ValidatingAdmissionPolicy), estrategia DR (Velero + etcd snapshot + región), multi-tenant (namespace isolation vs vcluster vs multi-cluster), ingress (ingress-nginx vs Gateway API).

Señales de "respondió sin entender":

- Elige service mesh "porque sí" sin requisito de mTLS/traffic shaping (contradice `k8s-18`).
- Copia la decisión de un blog famoso sin adaptarla a las restricciones del escenario (presupuesto, tamaño del equipo, SLO).
- No menciona upgrades ni skew policy pese a hablar de "producción".

### 6.4 Preguntas de seguimiento (evaluación en vivo)

- P1: "Si te dicen que (b) Postgres debe tolerar la caída de **todo** un nodo sin pérdida de escrituras, ¿qué cambia en tu diseño?" (busca: replicación, PDB, antiAffinity, operador de Postgres).
- P2: "Si tu CNI es Flannel y no implementa NetworkPolicy, ¿qué haces?" (busca: cambiar CNI a Calico/Cilium, o aceptar que no hay enforcement).
- P4: "Muéstrame cómo medirías el RSS real antes de proponer el nuevo limit" (busca: `kubectl top`, `container_memory_working_set_bytes`, perfilado).
- P5: "¿Qué pasa si pones `preStop: sleep 30` sin ajustar `terminationGracePeriodSeconds`?" (busca: el pod puede ser SIGKILLed antes de terminar).
- Operativo: "Si tengo que escalar a 50 réplicas, ¿tu PDB sigue siendo correcto?" (busca: usar `maxUnavailable` como porcentaje).
- ADR: "Dame la **primera** cosa que recortarías si el presupuesto se corta a la mitad y por qué."

### 6.5 Red flags transversales

- Hardcodear secretos en manifiestos entregados.
- Usar `kubectl --kubeconfig` apuntando a un cluster que no es `kind` (p. ej. prod del empleador).
- Deshabilitar RBAC o usar `--insecure-skip-tls-verify` para "que funcione".
- Pegar comandos `curl ... | sudo bash` desde fuentes no verificadas en el ADR como solución.

---

## 7. Cálculo del puntaje final

```
score_total = score_conceptual (0..30)
            + score_operativo  (0..40)
            + score_arq        (0..30)

aprobado = score_total >= 70
```

Si el estudiante aprueba el total pero obtiene **< 50%** en cualquiera de las tres secciones, el instructor debe marcar "aprobado condicional" y asignar remediación específica a esa dimensión.
