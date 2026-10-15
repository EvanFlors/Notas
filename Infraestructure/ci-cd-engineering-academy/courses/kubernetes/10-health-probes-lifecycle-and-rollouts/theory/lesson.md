# Lección: Health probes, lifecycle y rollouts

> **ID:** `k8s-10-health-probes-lifecycle-and-rollouts` · **Nivel:** intermedio · **Duración:** 4 h
> **Prerrequisitos:** `k8s-03-pods-deployments-replicasets`.

---

## 1. Introducción intuitiva

Cuando dices "quiero que mi app esté disponible", en Kubernetes estás diciendo tres cosas distintas que las personas tienden a confundir:

1. **"Ya terminó de arrancar"** — el proceso bind al puerto, cargó el modelo, aplicó migraciones.
2. **"Está listo para recibir tráfico ahora"** — es diferente del punto 1: puede estar arrancado y temporalmente degradado (DB cayó, cola llena) y querer *dejar* de recibir tráfico sin morir.
3. **"Sigue vivo, no se colgó irrecuperablemente"** — el proceso no está en un deadlock, no entró en un bucle infinito, no se trabó esperando un lock que no vuelve.

K8s expone estas tres preguntas como tres **probes** distintas. Confundirlas — en particular, poner lógica de "estoy saludable aguas abajo" en `livenessProbe` — es una de las formas más eficientes conocidas de **amplificar incidentes**: un pico de latencia en Postgres se convierte en una cadena de restarts que a su vez genera más carga sobre Postgres.

El segundo gran tema del módulo es la **terminación**. En papel suena trivial: "borras el Pod, K8s lo apaga". En realidad hay una ventana de carrera entre tres cosas que ocurren **en paralelo**: tu proceso recibiendo `SIGTERM`, los endpoints siendo removidos del Service, y los balancers externos (si los hay) actualizando sus pools. Si no diseñas para esa ventana, cada rolling update pierde una fracción de requests — generalmente invisible en gráficos agregados y perfectamente visible para el usuario que lo recibió como 502.

El tercer tema es el **rolling update** en sí: `maxSurge`, `maxUnavailable`, su interacción con `PodDisruptionBudget`, y qué resuelve (y qué no) el `RollingUpdate` default comparado con blue/green y canary.

---

## 2. Fundamentos

### 2.1 Dónde se ejecuta la probe

Las probes las ejecuta el **kubelet del nodo** donde corre el Pod — no el `apiserver`, no el control plane. Consecuencias:

- Si el nodo está bajo presión de CPU (ruido de vecinos, DaemonSets caros), el kubelet tarda más en ejecutar la probe → `timeoutSeconds` empieza a disparar falsos positivos → `livenessProbe` empieza a matar Pods sanos.
- Las probes HTTP salen de la IP del nodo hacia la IP del Pod en la red del CNI. Normalmente son locales (mismo nodo) y rapidísimas, pero si configuras `host: X` apuntando a otro servicio estás introduciendo una dependencia de red externa en tu salud — mal diseño.

### 2.2 Las tres probes son tres primitivas distintas

| Probe | Pregunta | Qué hace K8s si falla |
|-------|----------|-----------------------|
| `startupProbe` | ¿terminó de arrancar? | Reinicia el contenedor. **Suspende** las otras dos hasta pasar por primera vez. |
| `readinessProbe` | ¿puede recibir tráfico? | **Quita** el Pod de los `Endpoints` del Service. No mata nada. |
| `livenessProbe` | ¿sigue vivo? | **Reinicia** el contenedor. |

Esta es la tabla más importante del módulo. Reléela.

Los dos errores canónicos son:
- Usar `livenessProbe` como "verifica que todo mi stack esté sano" (incluye DB, caché, servicios externos). Resultado: restarts en cascada.
- Usar solo `readinessProbe` y asumir que resuelve también los cuelgues. Resultado: Pods vivos pero inútiles que ocupan slot sin nunca volver a ready.

### 2.3 Mecanismos: HTTP, TCP, exec, gRPC

```yaml
# httpGet — el más común
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
    scheme: HTTP          # o HTTPS
    httpHeaders:
      - name: X-Probe
        value: kubelet
```

Un status `>= 200 && < 400` cuenta como éxito. Cualquier otro, o un timeout, cuenta como fallo.

```yaml
# tcpSocket — para servicios no-HTTP
readinessProbe:
  tcpSocket:
    port: 5432
```

Solo verifica que el puerto acepte una conexión TCP. **No valida el protocolo**: un Postgres bloqueado en recovery acepta TCP y responde error a cualquier query — tcpSocket dice "ready" cuando no lo está. Útil como *liveness* mínima, pobre como *readiness* real.

```yaml
# exec — para apps sin endpoint HTTP de salud
livenessProbe:
  exec:
    command: ["pgrep", "-f", "myd"]
```

Cada intento cuesta un `fork + execve` dentro del contenedor. Barato, pero no gratis — evita comandos de 1–2 s en probes de `periodSeconds: 1`.

```yaml
# grpc — K8s >= 1.24, GA en 1.27
livenessProbe:
  grpc:
    port: 9090
    service: ""           # vacío = chequeo de salud del servidor completo
```

Usa el estándar `grpc.health.v1.Health/Check`. Si tu servidor gRPC no implementa el proto estándar de health, esto no funciona.

### 2.4 Parámetros temporales

```yaml
readinessProbe:
  httpGet: { path: /ready, port: 8080 }
  initialDelaySeconds: 0        # cuánto esperar tras arrancar antes del primer intento
  periodSeconds: 10             # cada cuánto
  timeoutSeconds: 1             # cuánto esperar respuesta
  successThreshold: 1           # intentos ok seguidos para marcar sano (readiness puede > 1)
  failureThreshold: 3           # intentos fallidos seguidos para marcar enfermo
```

**La ecuación que debes memorizar** para `livenessProbe`:

```
tiempo máximo de un cuelgue antes de reinicio
  = initialDelaySeconds + periodSeconds × failureThreshold
```

Con `initialDelay=0, period=10, failureThreshold=3`: 30 s después de colgarse, el kubelet mata al contenedor.

**`successThreshold` solo puede ser > 1 en `readinessProbe`.** Las otras lo forzarán a 1. (Tiene sentido: no reinicias un contenedor hasta que falle N veces; no lo marcas vivo tras "éxito parcial").

---

## 3. El anti-patrón "liveness que pega a la DB"

Este es el patrón específico que la actividad `01-fix-cascading-restarts` reproduce y arregla.

Imagina una app FastAPI/Flask/Express con esta configuración:

```yaml
livenessProbe:
  httpGet:
    path: /                 # ← la home page
    port: 8080
```

Y `/` ejecuta `SELECT 1 FROM users LIMIT 1` para "verificar que el stack esté sano". A velocidad normal, la query tarda 2 ms y la probe pasa en 10 ms. Todo bien.

Ahora, un día cualquiera, Postgres tiene un pico de latencia: un backup, un lock largo, un vecino ruidoso. Las queries empiezan a tardar 1.5 s. La probe tiene `timeoutSeconds: 1`. **Todas las probes empiezan a fallar.** Con `failureThreshold: 3` y `periodSeconds: 10`, en 30 s cada Pod es matado y reiniciado.

Qué pasa entonces:

1. Un Pod reinicia. Durante 20–40 s mientras arranca (migraciones, warmup) no toma tráfico.
2. La capacidad del Deployment baja de N a N-1.
3. Los N-1 Pods restantes absorben el tráfico extra. La carga por Pod sube.
4. Cada Pod abre más conexiones a Postgres. **La latencia de Postgres sube más.**
5. La probe ahora falla con más razón. **Varios Pods** empiezan a fallar simultáneamente.
6. K8s los reinicia. La capacidad baja a N-K.
7. Postgres se desploma por conexiones. Nadie responde.

Esto es un **incidente amplificado por la plataforma**. La causa raíz fue "latencia en DB". Un sistema sin probes mal diseñadas hubiera degradado en latencia pero servido tráfico. Con la probe mal diseñada, se cayó entero.

**El arreglo correcto:**

```yaml
livenessProbe:
  httpGet:
    path: /healthz         # endpoint barato: devuelve 200 OK si el proceso corre
    port: 8080
  periodSeconds: 10
  timeoutSeconds: 1
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /readyz          # verifica DB, caché, dependencias
    port: 8080
  periodSeconds: 5
  timeoutSeconds: 2
  failureThreshold: 3
```

Qué cambia:

- `/healthz` solo prueba que el proceso está vivo. Nunca falla por latencia de DB.
- `/readyz` sí verifica dependencias. Cuando DB está lenta, `readinessProbe` falla, el kubelet **quita el Pod de los Endpoints**, el Service deja de mandarle tráfico. **El Pod sigue vivo.** Cuando DB vuelve a estar sana, `/readyz` responde 200 de nuevo, el Pod vuelve a Endpoints.
- No hay restart. No hay pérdida de capacidad. El sistema degrada pero no se amplifica.

Esta diferencia — matar vs. desenchufar — es toda la lección del módulo si solo te llevas una idea.

---

## 4. `startupProbe` y por qué existe

Antes de K8s 1.16 solo había `liveness` y `readiness`. Problema: un app Spring Boot con 60 s de arranque obligaba a poner `initialDelaySeconds: 90` en `livenessProbe` para no matarlo durante el arranque. Pero ese mismo `initialDelay` se aplicaba a toda la vida del Pod: si el proceso se colgaba, tardabas 90 s en empezar a chequearlo.

`startupProbe` resuelve esto. Cuando existe, **las otras dos probes están suspendidas** hasta que `startup` pasa por primera vez. Entonces el kubelet las "activa" y nunca más vuelve a ejecutar `startup`.

```yaml
startupProbe:
  httpGet: { path: /healthz, port: 8080 }
  failureThreshold: 30     # hasta 30 intentos
  periodSeconds: 10        # cada 10 s = 300 s de ventana de arranque total

livenessProbe:
  httpGet: { path: /healthz, port: 8080 }
  periodSeconds: 10
  failureThreshold: 3      # 30 s de cuelgue → reinicio (ya no afectado por el arranque)
```

Regla práctica: si el p99 de tu tiempo de arranque es > 20 s, usa `startupProbe`.

---

## 5. `readinessGates`

Caso de uso: tienes un **Load Balancer gestionado** (AWS ALB con AWS LB Controller, GCP ILB) que registra los Pods como targets. El Pod puede estar `Ready` según sus probes, pero el ALB **aún no lo ha registrado** — y mandar tráfico fallaría.

`readinessGates` permite a un controller externo publicar su propia señal:

```yaml
spec:
  readinessGates:
    - conditionType: target-health.alb.ingress.k8s.aws/my-targetgroup
```

Para que el Pod cuente como ready, deben ser `True` **todas** las probes **y** todas las condiciones listadas en `readinessGates`. El ALB controller, cuando el target queda healthy en el ALB, publica esa condición en el Pod. Si no, se queda `NotReady` aunque la app esté perfecta.

Esto evita el síntoma clásico de "los primeros 10 s de cada Pod devuelven 502 porque el ALB aún no sabe que existe".

---

## 6. Qué pasa exactamente cuando se borra un Pod

Esta es la segunda tabla más importante del módulo. `kubectl delete pod X` dispara **cinco cosas** que ocurren en paralelo (no en secuencia):

```
t=0: apiserver marca el Pod con deletionTimestamp.

  ├── (A) EndpointSlice controller remueve el Pod de los endpoints del Service.
  │       └── kube-proxy en cada nodo detecta el cambio y reprograma iptables/IPVS.
  │           └── latencia típica: 100 ms – 2 s por nodo.
  │
  ├── (B) El Ingress controller / LB externo detecta el cambio y deregistra el target.
  │       └── latencia típica: 2 s – 30 s según LB.
  │
  └── (C) El kubelet del nodo ejecuta:
          1. preStop hook (si existe), bloqueante.
          2. Al terminar preStop, envía SIGTERM al PID 1 del contenedor.
          3. Arranca el contador terminationGracePeriodSeconds (default 30 s).
          4. Si el proceso termina antes → ok.
          5. Si no → SIGKILL, remueve el Pod.
```

El punto doloroso es que (A), (B) y (C) corren **en paralelo**. Nada garantiza que (A) y (B) hayan terminado antes de que (C) mate al proceso. Si tu app recibe `SIGTERM` y cierra inmediatamente el listener, hay una ventana en que:

- Tu proceso ya no acepta nuevas conexiones.
- `kube-proxy` aún tiene reglas que apuntan a tu Pod.
- Nuevas requests llegan y reciben `connection refused` → 502 aguas arriba.

**El truco canónico** es un `preStop` con `sleep`:

```yaml
lifecycle:
  preStop:
    exec:
      command: ["sh", "-c", "sleep 10"]
terminationGracePeriodSeconds: 40
```

Qué logra:

1. Cuando llega la señal de terminación, el kubelet corre `sleep 10` **antes** de mandar `SIGTERM`.
2. Durante esos 10 s el proceso **sigue sirviendo tráfico normalmente** — pero los endpoints ya fueron removidos y `kube-proxy` ya se actualizó.
3. A los 10 s se manda `SIGTERM`. Ahora el proceso puede cerrar listener sin pérdida: nadie debería mandarle tráfico nuevo.
4. El proceso tiene `terminationGracePeriodSeconds - preStop_duration = 30 s` para cerrar limpio.

**Nota crítica**: `terminationGracePeriodSeconds` **incluye** el tiempo de `preStop`. Si tu `preStop` dura 10 s y pones `terminationGracePeriodSeconds: 10`, al proceso le quedan ~0 s antes de `SIGKILL`.

Draining a nivel de app es la alternativa superior cuando se puede: la app, al recibir `SIGTERM`, deja de aceptar conexiones nuevas pero termina las en vuelo, con un timeout propio. Combinada con `preStop sleep` para la ventana de red, es la solución completa.

---

## 7. `SIGTERM` → `SIGKILL`: el contrato

Resumido:

- `SIGTERM` es la **señal esperada**. Tu app debe diseñarse para apagarse en respuesta a ella.
- Tienes `terminationGracePeriodSeconds` segundos para cerrar. Default: **30**.
- Si no cerraste a tiempo, llega `SIGKILL` del kubelet. El kernel mata el proceso. No hay recuperación, no hay flush, no hay logs finales.

Qué debe hacer tu app en `SIGTERM`:

1. Dejar de aceptar nuevas conexiones (cerrar listener).
2. Dejar de poll-ear colas nuevas.
3. Terminar requests en vuelo con un timeout razonable (ej. 25 s si tu `terminationGracePeriodSeconds` es 30).
4. Flushear buffers, cerrar conexiones a DB, commitear offsets de Kafka.
5. Exit 0.

Anti-patrones comunes:

- `node app.js` que no instala handler de `SIGTERM`: Node por default termina inmediatamente al recibir la señal, dropeando conexiones en vuelo.
- `/bin/sh -c "python app.py"` como entrypoint: `sh` no reenvía señales a hijos. Tu Python nunca ve el `SIGTERM`. Mismo problema que PID 1 en Docker (ver curso `dkr-02`).

---

## 8. Rolling update: `maxSurge` y `maxUnavailable`

```yaml
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1              # cuántos Pods extra por encima de replicas se permiten
      maxUnavailable: 0        # cuántos pueden faltar en el peor momento
```

Interpretación:

- `maxSurge: 1` → durante el rollout puede haber hasta `replicas + 1 = 11` Pods.
- `maxUnavailable: 0` → siempre hay al menos `replicas - 0 = 10` Pods ready. **Cero pérdida de capacidad.**

Esta configuración (`maxSurge: 1, maxUnavailable: 0`) es la **más segura**: siempre tienes 100 % de capacidad disponible, el rollout avanza un Pod a la vez. Es más lento. Para apps críticas vale la pena.

Los **defaults** (`maxSurge: 25%, maxUnavailable: 25%`) son otra cosa: con 10 réplicas pueden desaparecer 2 Pods a la vez durante el rollout. Para la mayoría de servicios web eso es tolerable; para una API financiera no.

Ambos pueden ser absolutos (`1`, `2`) o porcentuales (`25%`). Al menos uno debe ser > 0 (si no, el rollout no puede progresar).

Otros campos relevantes:

- `revisionHistoryLimit: 10` (default) — cuántos ReplicaSets viejos se conservan para `rollout undo`.
- `progressDeadlineSeconds: 600` (default) — si el rollout no avanza en 10 min, se marca `Progressing=False` y, con GitOps, se puede autoabortar.
- `minReadySeconds: 0` — tiempo mínimo que un Pod nuevo debe estar ready antes de considerarse "disponible" por el rollout. Útil cuando la readiness probe pasa demasiado pronto.

---

## 9. Interacción con PodDisruptionBudget

`PDB` protege ante **disruption voluntaria**: drains (`kubectl drain`), upgrades de nodo, autoscaler bajando nodos, **y el rollout mismo**. No protege ante caídas accidentales (nodo que muere).

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web
spec:
  minAvailable: 8          # o maxUnavailable: 2
  selector:
    matchLabels:
      app: web
```

En conjunto con un `RollingUpdate` con `maxUnavailable: 0` y PDB `minAvailable: 8` para 10 réplicas: tu rollout avanzará de forma segura, y si alguien `drain`-ea un nodo durante el rollout, el drain **se bloqueará** hasta que haya al menos 8 Pods ready.

Reglas prácticas:
- `minAvailable` absoluto es más seguro que porcentual (porcentual redondea hacia abajo).
- Un PDB con `minAvailable: 100%` o `maxUnavailable: 0` es un *footgun*: bloquea cualquier operación voluntaria permanentemente.
- PDB **no** aplica si solo tienes 1 réplica. Diseña para 2+ si lo necesitas.

---

## 10. Blue/green y canary (referencia)

`RollingUpdate` tiene limitaciones:

- No es **atómico**: durante el rollout, el Service está respondiendo con mezcla de v1 y v2.
- No hay **análisis de métricas**: K8s no decide "la nueva versión tiene más errores, aborta". Solo mira probes.
- Rollback requiere `kubectl rollout undo` y toma otra ronda de rolling.

**Blue/green**: tienes dos Deployments completos (blue = v1, green = v2). Un Service apunta a uno. Al deployar v2, levantas green entero, lo pruebas internamente, y haces *switch* del selector del Service de una vez. Rollback = switch de vuelta, instantáneo.

**Canary**: expones v2 a un pequeño % de tráfico (5 %, 10 %, 25 %, 100 %) y mides errores/latencia en cada paso. Si una métrica se degrada, aborta.

Ninguna de las dos se implementa bien con primitivas puras de K8s: haría falta orquestar Services, selectors, y análisis métrico. **Herramientas específicas:**

- **Argo Rollouts** — reemplazo del controller de Deployment con `kind: Rollout` que soporta canary y blue/green nativos, con `AnalysisTemplate` para abortar según Prometheus.
- **Flagger** — operator de Flux que hace lo mismo integrado con service mesh (Istio, Linkerd, App Mesh).

Ambos se cubren en el curso **argo-cd** / módulo de progressive delivery. En este módulo basta con saber **qué resuelven** y **cuándo subir el nivel**.

Regla práctica: `RollingUpdate` basta si no tienes forma de medir "está peor" en 30 s con precisión. Si sí la tienes (SLO monitoreable, dashboards reales), canary paga el costo.

---

## 11. Rollback: `kubectl rollout undo`

Cada `kubectl apply` sobre un Deployment que cambie el `PodTemplateSpec` crea un nuevo **ReplicaSet** y escala el viejo a 0. Los viejos no se borran — se conservan según `revisionHistoryLimit` (default 10).

```bash
kubectl rollout history deployment/web
kubectl rollout history deployment/web --revision=3
kubectl rollout undo    deployment/web                 # vuelve a la revisión anterior
kubectl rollout undo    deployment/web --to-revision=3 # a una específica
```

`undo` crea un nuevo rollout (nuevo RS) con el template viejo. **No es** "revertir" en el sentido de git; es "deploy la versión vieja de nuevo", con sus propios maxSurge/maxUnavailable aplicables.

También útiles:

```bash
kubectl rollout status deployment/web                   # bloquea hasta terminar
kubectl rollout pause  deployment/web                   # congela el rollout
kubectl rollout resume deployment/web
```

`pause` sirve para hacer canary manual: aplicas la nueva versión, pausas inmediatamente, verificas que **los primeros Pods** se comportan bien, resume si ok.

---

## 12. Checklist de rollout seguro

Antes de considerar que un Deployment está listo para producción:

- [ ] `startupProbe` si el p99 de arranque > 20 s.
- [ ] `livenessProbe` apunta a un endpoint **barato y local** (no toca DB, no toca red externa).
- [ ] `readinessProbe` apunta a un endpoint que **sí** verifica dependencias necesarias.
- [ ] `periodSeconds` + `failureThreshold` de la liveness alineados con el peor cuelgue tolerable.
- [ ] `preStop` con `sleep` de 5–15 s **o** draining a nivel app robusto.
- [ ] `terminationGracePeriodSeconds` = `preStop` + tiempo real de cierre + margen.
- [ ] Tu app instala handler de `SIGTERM` **y lo prueba** (test que mande SIGTERM y verifique que exit 0 ocurrió en < gracePeriod).
- [ ] `strategy.rollingUpdate.maxUnavailable: 0` si es un servicio crítico.
- [ ] `PodDisruptionBudget` con `minAvailable` suficiente para absorber un drain durante el rollout.
- [ ] `revisionHistoryLimit` razonable (default 10 está bien; si guardas secretos grandes en manifests, baja).
- [ ] Un **cliente externo** midiendo errores durante el rollout (no puedes decir "sin downtime" sin medirlo).

Cuando los diez están, puedes hacer un rolling update en caliente de un servicio crítico sin suda. Cuando falta uno, es cuando aparece el postmortem.
