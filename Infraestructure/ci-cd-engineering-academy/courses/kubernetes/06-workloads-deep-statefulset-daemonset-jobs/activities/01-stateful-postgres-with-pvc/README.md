# k8s-06-01 — Postgres via `StatefulSet` con PVC (guided-lab)

## 1. Identificación

- **ID:** `k8s-06-01-stateful-postgres-with-pvc`
- **Tecnología:** kubernetes
- **Módulo:** `06-workloads-deep-statefulset-daemonset-jobs`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

El objetivo es *dejar de pensar* un `StatefulSet` como "un Deployment con disco" y empezar a verlo como lo que es: **identidad + PVC + DNS por Pod**. Para eso vas a levantar un Postgres mínimo, insertar un dato, borrar el Pod, y demostrar que *vuelve con el dato*. También vas a comprobar, con tus ojos, que borrar el `StatefulSet` **no borra** los `PersistentVolumeClaim` — y por qué eso es un rasgo intencional de K8s, no un bug.

El validador comprueba el estado del cluster, no la historia: debe existir el STS, el headless `Service`, al menos un PVC `data-pg-0` *Bound*, el Pod `pg-0` listo, y una tabla `t` con la fila `hola k8s-06` creada por ti.

## 3. Objetivos

Al terminar deberías poder:

- Escribir un `StatefulSet` + headless `Service` + `volumeClaimTemplates` sin consultar.
- Explicar por qué el `serviceName` del STS *debe* apuntar al headless Service.
- Demostrar que `kubectl delete pod pg-0` **no** destruye los datos.
- Explicar qué pasa (y qué no) al `kubectl delete statefulset pg`.

## 4. Prerrequisitos

- Cluster local `kind` corriendo (nombre libre).
  ```bash
  kind create cluster --name k8s-06
  ```
- `kubectl` apuntando al cluster: `kubectl config current-context` debe mostrar `kind-k8s-06`.
- `StorageClass` default: en `kind` ya existe `standard` con `rancher.io/local-path`. Verifica:
  ```bash
  kubectl get storageclass
  ```
- `psql` client NO es necesario localmente — se usa el `psql` del propio contenedor Postgres.
- Sin costo (todo local).

## 5. Instrucciones

Trabaja en `/tmp/k8s-06-01/`. Crea el directorio:

```bash
mkdir -p /tmp/k8s-06-01 && cd /tmp/k8s-06-01
```

### Paso 1 — manifest

Copia el `starter/postgres.yaml` a `/tmp/k8s-06-01/postgres.yaml` y abrelo. Está **incompleto** a propósito. Debes:

1. Añadir `clusterIP: None` al `Service` (sin esto, no es headless y no hay DNS por Pod).
2. En el `StatefulSet`, poner `serviceName: pg` (debe coincidir con el nombre del Service).
3. Verificar que `volumeClaimTemplates` existe con `name: data` y `storage: 1Gi`.

> No cambies los nombres (`pg` para el Service y el STS). El validador los busca por nombre.

### Paso 2 — aplicar

```bash
kubectl apply -f /tmp/k8s-06-01/postgres.yaml
kubectl rollout status statefulset/pg --timeout=180s
```

### Paso 3 — verificar DNS por Pod

```bash
kubectl run -i --rm --restart=Never dnsprobe --image=busybox:1.36 -- \
  nslookup pg-0.pg.default.svc.cluster.local
```

Debe devolver una IP. Si falla, revisa `clusterIP: None` y `serviceName: pg`.

### Paso 4 — crear tabla y fila

```bash
kubectl exec pg-0 -- psql -U postgres -d demo -c \
  "CREATE TABLE IF NOT EXISTS t (id serial primary key, msg text);"
kubectl exec pg-0 -- psql -U postgres -d demo -c \
  "INSERT INTO t(msg) VALUES ('hola k8s-06');"
kubectl exec pg-0 -- psql -U postgres -d demo -c "SELECT * FROM t;"
```

### Paso 5 — matar el Pod y demostrar persistencia

```bash
kubectl delete pod pg-0
kubectl rollout status statefulset/pg --timeout=120s
kubectl exec pg-0 -- psql -U postgres -d demo -c "SELECT * FROM t;"
# La fila 'hola k8s-06' DEBE seguir ahí.
```

### Paso 6 — escribir un ADR corto

En `/tmp/k8s-06-01/adr.md` escribe 3-5 bullets justificando si operarías Postgres en K8s (así, con `StatefulSet` a pelo) para:

- Una **startup** de 5 ingenieros en AWS.
- Un **banco** con equipo DBA interno.
- Un **cluster edge** sin acceso a managed services.

El validador solo comprueba que el archivo existe y menciona `StatefulSet`.

### Paso 7 — validar

```bash
bash /ruta/al/repo/courses/kubernetes/06-workloads-deep-statefulset-daemonset-jobs/activities/01-stateful-postgres-with-pvc/tests/validate.sh
```

Imprime `RESULT: PASS` cuando todo está en su sitio.

## 6. Resultado esperado

- `kubectl get sts pg` muestra `READY 1/1`.
- `kubectl get svc pg -o jsonpath='{.spec.clusterIP}'` devuelve `None`.
- `kubectl get pvc data-pg-0 -o jsonpath='{.status.phase}'` devuelve `Bound`.
- `nslookup pg-0.pg.default.svc.cluster.local` resuelve.
- `SELECT * FROM t` devuelve la fila `hola k8s-06` **también después de** `kubectl delete pod pg-0`.
- `/tmp/k8s-06-01/adr.md` existe.

## 7. Criterios de aceptación

- `tests/validate.sh` imprime `RESULT: PASS`.
- `Service pg` es headless (`clusterIP: None`).
- El `StatefulSet` referencia el headless con `serviceName: pg`.
- `data-pg-0` está `Bound`.
- El validador se ejecuta **antes de limpiar**; después de limpiar, falla (es intencional).

## 8. Validación

```bash
bash courses/kubernetes/06-workloads-deep-statefulset-daemonset-jobs/activities/01-stateful-postgres-with-pvc/tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Por qué `kubectl delete pod pg-0` *no* pierde los datos, mientras que `docker rm -f pg` *sí* los perdería (si fuera un contenedor Docker con volumen anónimo)?
2. Escala a 2 réplicas con `kubectl scale sts pg --replicas=2`. ¿`pg-1` tiene los mismos datos que `pg-0`? ¿Por qué?
3. ¿Qué pasa si cambias `clusterIP: None` por `ClusterIP` normal y haces `nslookup pg-0.pg...`?
4. Borras el STS con `kubectl delete sts pg`. ¿Perdiste los datos? ¿Cómo recuperas en 2 comandos?
5. ¿Qué 5 cosas te faltan para que esto sea apto para producción?

## 10. Extensiones

- Escala a 3 réplicas y haz un `kubectl get pvc` — observa cómo aparecen `data-pg-1`, `data-pg-2`.
- Añade `persistentVolumeClaimRetentionPolicy.whenScaled: Delete` y escala de 3 → 1. ¿Qué PVC se borran?
- Configura un `readinessProbe` con `pg_isready` y mide cuánto cambia el tiempo hasta `Ready`.

## 11. Limpieza

```bash
kubectl delete statefulset pg --ignore-not-found
kubectl delete pvc -l app=pg --ignore-not-found
kubectl delete svc pg --ignore-not-found
rm -rf /tmp/k8s-06-01
```
