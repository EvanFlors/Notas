# k8s-06 — Teoría: StatefulSet, DaemonSet, Jobs y CronJobs

> Lección profunda del módulo. 12 secciones. Lee en orden; cada sección cita a la anterior.

---

## 1. Por qué no todo es un `Deployment`

Un `Deployment` + `ReplicaSet` modela una **flota intercambiable** de Pods: cualquier réplica puede atender cualquier request, nadie tiene identidad, nadie tiene estado en disco local persistente, y si una muere la reemplazas sin consecuencias. Es la abstracción correcta para microservicios *stateless*.

Pero hay cuatro escenarios donde ese modelo rompe:

1. **La réplica tiene identidad**: `postgres-0` es el primario; `postgres-1` y `postgres-2` son réplicas. Si cambias quién es quién, la aplicación cliente deja de funcionar o pierde consistencia.
2. **La réplica tiene disco propio**: cada Pod tiene su `data/` con un dataset distinto. No puedes "balancear" entre réplicas: `postgres-0.data` ≠ `postgres-1.data`.
3. **Necesitas un Pod en cada nodo**: un *log forwarder*, un *CNI agent*, un *node-exporter* de Prometheus. No "N" réplicas repartidas: exactamente una por nodo.
4. **El trabajo es finito**: una migración de DB que corre una vez; un reporte nocturno. No necesitas un Pod "siempre arriba" — necesitas uno que arranque, termine su trabajo y desaparezca (o se repita por horario).

Para cada escenario, Kubernetes tiene un controller específico:

| Escenario | Controller |
|-----------|------------|
| Flota intercambiable | `Deployment` (visto en k8s-03) |
| Identidad y disco por réplica | `StatefulSet` |
| Un Pod por nodo | `DaemonSet` |
| Trabajo que termina | `Job` |
| Trabajo recurrente por horario | `CronJob` |

Usar el controller equivocado no te da errores de compilación — te da bugs en producción que son difíciles de atribuir a la decisión original. Esta lección trata, sobre todo, de **cuándo** usar cuál y qué garantiza cada uno.

---

## 2. `StatefulSet` — identidad estable

Un `StatefulSet` (STS) te garantiza, para una serie `N` de réplicas, lo siguiente:

- **Nombres ordenados**: `<name>-0`, `<name>-1`, …, `<name>-(N-1)`. No cambian. Si borras `postgres-1`, el controller crea otro **con el mismo nombre**, no con un nombre al azar.
- **Hostname estable**: el Pod se llama `<name>-<ordinal>` dentro de su propio DNS namespace. `hostname -f` desde dentro del Pod devuelve `postgres-0.postgres.default.svc.cluster.local`.
- **PVC estable**: si declaras `volumeClaimTemplates`, el controller crea un PVC por réplica, llamado `<template>-<name>-<ordinal>` (p. ej. `data-postgres-0`). Ese PVC *sobrevive* al Pod y se re-monta al re-crearse.
- **Orden determinista** de inicio y de parada (por default): `-0` arranca primero y debe estar `Ready` antes de crear `-1`. Al eliminar, se borran en orden inverso (`-(N-1)` → `-0`).

Manifiesto mínimo:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: pg          # headless — necesario, ver §9
spec:
  clusterIP: None
  selector:
    app: pg
  ports:
    - port: 5432
      name: postgres
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: pg
spec:
  serviceName: pg   # debe coincidir con el headless service
  replicas: 1
  selector:
    matchLabels: { app: pg }
  template:
    metadata:
      labels: { app: pg }
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          env:
            - { name: POSTGRES_PASSWORD, value: "devpass" }   # NO en prod — ver §12
            - { name: PGDATA, value: /var/lib/postgresql/data/pgdata }
          volumeMounts:
            - { name: data, mountPath: /var/lib/postgresql/data }
  volumeClaimTemplates:
    - metadata: { name: data }
      spec:
        accessModes: ["ReadWriteOnce"]
        resources: { requests: { storage: 1Gi } }
```

Puntos clave que **no son obvios**:

- `serviceName` **no es cosmético**: es lo que ancla el DNS por Pod. Si está mal, los Pods no son resolvibles por su nombre.
- `volumeClaimTemplates` **no es un `volume` normal**: el controller instancia *un PVC por réplica*. No vuelvas a verlo como "un volume compartido".
- Si borras el STS, los PVC siguen ahí (ver §8). Es intencional. Si realmente quieres destruirlos, hazlo tú.

---

## 3. Orden de inicio y de parada

Por default, `podManagementPolicy: OrderedReady`:

- **Scale up** de 0 → N: el controller crea `-0`, espera a que esté `Ready`, luego `-1`, luego `-2`. Si `-0` nunca llega a `Ready`, nunca aparece `-1`.
- **Scale down** de N → 0: el controller borra `-(N-1)` primero, espera a que termine, luego `-(N-2)`, etc.
- **Update rolling** (ver §4): va de ordinal mayor a menor.

Alternativa: `podManagementPolicy: Parallel`. Útil para apps *stateful* donde las réplicas son independientes entre sí (p. ej., shards que no requieren bootstrap ordenado). Los Pods se crean/borran todos a la vez. Postgres primario/réplica **no es** este caso.

¿Por qué importa el orden? Dos razones:

1. **Bootstrap**: muchas DBs esperan "el nodo 0 inicializa el cluster; los demás se unen apuntándolo". Si todos arrancan a la vez, race.
2. **Shutdown seguro**: si `-0` es el primario, quieres que las réplicas se vayan primero.

---

## 4. `updateStrategy`

Dos modos:

- **`RollingUpdate`** (default): el controller actualiza Pods **de mayor ordinal a menor**. Es decir, `-2` primero, luego `-1`, luego `-0`. Lo contrario al orden de creación.
- **`OnDelete`**: el controller **no toca** los Pods. Tú los borras cuando quieras y, al re-crearse, usan la nueva spec.

Con `RollingUpdate` tienes además `partition: K`: solo se actualizan Pods con ordinal `>= K`. Útil para *canary* manual en un STS (dejas `-0` sin tocar hasta validar que `-1` y `-2` funcionan).

```yaml
updateStrategy:
  type: RollingUpdate
  rollingUpdate:
    partition: 1   # solo actualiza -1, -2, ...; deja -0 con la vieja spec
```

---

## 5. `DaemonSet` — un Pod por nodo

Un `DaemonSet` (DS) te garantiza que **cada nodo** que satisfaga el selector tenga **un** Pod del DS. Casos canónicos:

- **Log collectors**: fluent-bit, Vector, promtail — leen `/var/log/containers/*` del nodo.
- **CNI agents**: Calico-node, cilium-agent — programan el *data plane* de red del nodo.
- **Node exporters**: prometheus/node-exporter — exponen métricas del host.
- **Storage**: Longhorn, OpenEBS — gestionan discos locales.
- **Security**: Falco — syscalls vía eBPF.

Manifiesto mínimo:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-logger
spec:
  selector:
    matchLabels: { app: node-logger }
  template:
    metadata:
      labels: { app: node-logger }
    spec:
      tolerations:
        - operator: Exists    # tolera cualquier taint — incluido el del control plane
      containers:
        - name: logger
          image: busybox:1.36
          command: ["sh","-c","while true; do date; sleep 10; done"]
```

Puntos clave:

- Un DS **no tiene `replicas`**; el "número" viene de la cantidad de nodos.
- Para incluir el control plane (en clusters que lo taintean), necesitas tolerations explícitas.
- `nodeSelector` + `affinity` te permiten restringir a un subset de nodos (p. ej., solo nodos GPU).
- Si añades un nodo al cluster, el DS controller detecta el evento y crea el Pod automáticamente.
- `updateStrategy` del DS: `RollingUpdate` (default) con `maxUnavailable` (default 1) o `OnDelete`.

---

## 6. `Job` — trabajo que termina

Un `Job` ejecuta Pods hasta que `completions` de ellos terminen con éxito (exit 0). Casos: migraciones de schema, reportes, procesamiento batch de un archivo, backups.

Manifiesto mínimo:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: migrate
spec:
  completions: 1          # cuántos Pods deben completar con éxito
  parallelism: 1          # cuántos pueden correr simultáneamente
  backoffLimit: 3         # cuántos fallos del Pod aguanta antes de rendirse
  activeDeadlineSeconds: 600
  ttlSecondsAfterFinished: 300   # auto-GC del Job 5 min después de terminar
  template:
    spec:
      restartPolicy: OnFailure    # OnFailure | Never (NO Always en Job)
      containers:
        - name: migrator
          image: migrate/migrate:v4
          args: ["-source","file:///migrations","-database","postgres://...","up"]
```

Puntos clave:

- `completions` **vs** `parallelism`: puedes querer `completions: 100, parallelism: 10` → 100 ejecuciones exitosas en lotes de 10 simultáneos.
- `restartPolicy: Always` **no es válido** en un Pod de Job. Debe ser `OnFailure` o `Never`.
  - `OnFailure`: el kubelet reinicia el contenedor dentro del mismo Pod.
  - `Never`: el Job controller crea un **nuevo Pod** por cada reintento.
- `backoffLimit` cuenta reintentos; una vez excedido, el Job se marca como `Failed`.
- `activeDeadlineSeconds` es un deadline hard: el Job se mata al cumplirse, hayan terminado o no los Pods.
- `ttlSecondsAfterFinished` evita que te queden Jobs completados eternamente en `kubectl get jobs`.

---

## 7. Indexed Jobs y patrones comunes

### Indexed Jobs

Con `completionMode: Indexed`, cada Pod del Job recibe un **índice** único entre `0` y `completions - 1`, expuesto como:

- Variable de entorno `JOB_COMPLETION_INDEX`.
- Sufijo del hostname: `<job>-<index>-<hash>`.

Útil para **particionado estático de trabajo**: tienes 50 archivos; haces `completions: 50, parallelism: 10`, cada Pod procesa `files[JOB_COMPLETION_INDEX]`.

```yaml
spec:
  completions: 50
  parallelism: 10
  completionMode: Indexed
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: shard
          image: ...
          command: ["process", "--shard", "$(JOB_COMPLETION_INDEX)"]
```

### Worker queue

Para trabajo **dinámico** (no sabes cuántos ítems hay), el patrón es: Job con `parallelism: N`, cada Pod corre un loop `pop_from_queue → process → ack`. Cuando la cola queda vacía, cada Pod termina con exit 0. `completions` se deja sin fijar (o igual a `parallelism`).

### Leader election

No es un *Job*, pero merece mención aquí porque es cómo "N réplicas, pero solo una actúa" se resuelve en K8s: un `coordination.k8s.io/Lease` con tu identidad; quien obtiene el lease es el líder; renueva periódicamente; si se cae, otro lo adquiere. Lo usan controllers (kube-controller-manager se replica así en HA) y operadores. Lo verás en profundidad en `k8s-14`.

---

## 8. PVC lifecycle en `StatefulSet`

Esta es la sección que más gente aprende *después* de perder datos. Lée con calma:

**Default conservador**: eliminar un `StatefulSet` **no borra** sus `PersistentVolumeClaim`. Escalar hacia abajo tampoco los borra. Son los datos — K8s asume que si los querías *de verdad* los borrarías explícitamente.

```bash
kubectl delete statefulset postgres
# Resultado: Pods desaparecen; PVC `data-postgres-0`, `data-postgres-1`, ... siguen vivos.
kubectl get pvc            # ahí están
```

Esto significa:

- **Recreas el STS** y los PVC se re-asocian: `postgres-0` encuentra su `data-postgres-0` original y sus datos están ahí.
- **No lo recreas y quieres limpiar**: `kubectl delete pvc -l app=postgres` (y verifica el `reclaimPolicy` del `StorageClass` — si es `Delete`, también se borrarán los PV reales en el cloud).

Desde K8s 1.27 (GA 1.32) existe `persistentVolumeClaimRetentionPolicy` para afinarlo:

```yaml
spec:
  persistentVolumeClaimRetentionPolicy:
    whenDeleted: Retain | Delete
    whenScaled:  Retain | Delete
```

Mantén `Retain` para producción salvo que tengas una muy buena razón.

---

## 9. Headless `Service` y DNS por Pod

Un `Service` normal te da un **VIP** (`clusterIP`) y balancea entre los Pods seleccionados. Para un `StatefulSet` eso **no sirve**: necesitas direccionar réplicas específicas (`postgres-0` para el primario, `postgres-1` como réplica, etc.).

La solución: un **headless Service**, con `clusterIP: None`. Hace dos cosas:

1. **No** asigna VIP.
2. CoreDNS publica un `A record` **por Pod** del `StatefulSet`:
   - `postgres-0.pg.default.svc.cluster.local` → IP del Pod `postgres-0`.
   - `postgres-1.pg.default.svc.cluster.local` → IP del Pod `postgres-1`.

Esto es lo que permite que tu cliente diga "conéctame al primario, que es `postgres-0`" sin tener que descubrirlo dinámicamente. El `serviceName` del `StatefulSet` **debe** apuntar a este headless.

Pequeña trampa frecuente: la gente crea el STS y un `ClusterIP` Service normal (como para un Deployment). Funciona a medias — el service balancea, pero no hay DNS por Pod. Añade el headless.

---

## 10. `CronJob` — trabajo recurrente

Un `CronJob` crea `Job`s en una **programación**. Es la primitiva nativa de K8s para "cada hora", "cada noche", "cada 5 minutos".

Manifiesto mínimo:

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: cleanup
spec:
  schedule: "*/5 * * * *"       # cada 5 min — EN UTC por default
  timeZone: "Europe/Madrid"      # (opcional; GA desde 1.27)
  concurrencyPolicy: Forbid      # Allow | Forbid | Replace
  startingDeadlineSeconds: 60    # si no pudo arrancarse en 60 s, "missed"
  successfulJobsHistoryLimit: 3  # cuántos Jobs completados conservar
  failedJobsHistoryLimit: 1
  suspend: false
  jobTemplate:
    spec:
      backoffLimit: 2
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: cleanup
              image: busybox:1.36
              command: ["sh","-c","echo cleanup at $(date)"]
```

### `concurrencyPolicy`

Esta es la decisión importante:

- **`Allow`** (default). Si el `Job` previo todavía corre cuando toca el siguiente, se lanzan **ambos**. Peligroso si el Job tarda a veces más que el intervalo (overlaps → carrera, duplicación, locks, corrupción).
- **`Forbid`**. Si el previo sigue corriendo, el nuevo **se salta**. Elección sensata para la mayoría de limpiezas y jobs idempotentes.
- **`Replace`**. Mata al previo y arranca el nuevo. Útil cuando el *más reciente* es el que importa (p. ej., re-sincronizar estado).

### `startingDeadlineSeconds`

Si el control plane estuvo caído o el scheduler no pudo arrancar el Job a tiempo, al volver intenta "ponerse al día". Sin `startingDeadlineSeconds`, podría lanzar muchas ejecuciones acumuladas. Con, por ejemplo, `60`, solo se lanza si está dentro de 60 s de su horario; si no, cuenta como *missed*.

### Zona horaria

**Por default se evalúa en UTC**. En clusters antiguos esto era inamovible; desde K8s 1.27 puedes poner `spec.timeZone: "Europe/Madrid"`. Si no lo pones, tu `0 2 * * *` ("a las 2 am") son las **2 am UTC** — no las de tu reloj.

### Historial

`successfulJobsHistoryLimit` y `failedJobsHistoryLimit` controlan cuántos Jobs completados/fallidos se dejan en el API. Por default conserva 3 éxitos y 1 fallo. Los jobs antiguos se borran, pero *sus Pods también* — si quieres logs forenses, exfíltralos antes.

---

## 11. Checklist: cuál controller usar

Preguntas que debes contestar antes de abrir el YAML:

1. **¿La carga termina alguna vez por sí sola?**
   - Sí, en una ejecución → `Job`.
   - Sí, cada X tiempo → `CronJob`.
   - No, es un proceso de servicio → sigue.
2. **¿Cada réplica necesita identidad y disco propio?**
   - Sí → `StatefulSet`.
   - No → sigue.
3. **¿Necesitas una copia por nodo del cluster?**
   - Sí → `DaemonSet`.
   - No → `Deployment`.

Y las trampas:

- *"Mi app es stateless pero usa Redis…"* — Redis va en un STS (u operador). Tu app sigue siendo un Deployment.
- *"Mi app necesita afinidad a un nodo…"* — eso no la convierte en DaemonSet. DS = una copia **por** nodo. Lo tuyo probablemente es `nodeSelector` + Deployment.
- *"Un script que debe correr al desplegar…"* — `Job`, no un `initContainer` en el Deployment (los initContainers corren **cada vez que el Pod arranca**).

---

## 12. StatefulSet no es un DBA

Esta es la sección honesta: Kubernetes te da los **mecanismos** para operar workloads con estado — identidad, PVC, scheduling ordenado. **No te da el conocimiento** para operarlos *bien*.

Para una base de datos "en serio" necesitas:

- **Backups** programados, verificados, con *restore drills* periódicos.
- **PITR** (Point-In-Time Recovery) si el RPO del negocio lo exige.
- **Failover** automático con *fencing* del primario viejo.
- **Upgrades mayores** sin pérdida de datos ni downtime (y rollback plan).
- **Tuning** de parámetros (`shared_buffers`, `max_connections`, autovacuum, WAL).
- **Monitoring** profundo (replication lag, bloat, long-running queries).

Nada de eso te lo da un `StatefulSet` solo. Opciones reales:

| Opción | Cuándo |
|--------|--------|
| **Servicio managed** (RDS, Cloud SQL, Azure DB) | Casi siempre. Es el *default* sano. |
| **Operador maduro** en K8s (CloudNativePG, Zalando, Percona) | Tienes razones fuertes para no usar managed (compliance, cloud sin esa opción, costes a gran escala) y gente para operar el operador. |
| **STS "a pelo"** | Dev/staging, tests, laboratorios, cargas donde "si se pierde no pasa nada". |

**En este módulo** aprendes a construirlo con `StatefulSet` **para entender el primitivo**, no para que ejecutes así tu Postgres de producción.

### Lectura final (y pregunta de evaluación)

Para tu capstone, decidirás si Postgres va en K8s o en RDS/Cloud SQL. Prepara 3-5 bullets justificando esa decisión. Factores a considerar: criticidad del dato, tamaño del equipo, existencia de managed en tu cloud, costes, requisitos de latencia y privacidad.

---

## Preguntas de evaluación

Responde sin consultar; luego valídate.

1. Explica por qué un `StatefulSet` necesita un headless `Service` y qué pasaría sin él.
2. ¿Cuál es la diferencia entre `OrderedReady` y `Parallel` en `podManagementPolicy`? Da un caso para cada uno.
3. Diseña un `CronJob` que corre un reporte cada noche y **nunca** debe solaparse si tarda más de 24 h. Enumera los campos clave.
4. Un compañero propone correr fluent-bit como `Deployment` con `replicas: 3` en un cluster de 10 nodos. ¿Qué le dices?
5. Borraste tu `StatefulSet` por error. ¿Perdiste los datos? ¿Por qué sí/no? ¿Cómo recuperas?
6. Diseña un `Job` que procesa 1000 archivos con 20 workers en paralelo, con tolerancia a 5 fallos.
7. Argumenta en 5 bullets si operarías Postgres en K8s para una fintech pequeña (10 ingenieros, equipo sin DBA, en AWS).
