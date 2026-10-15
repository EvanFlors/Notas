# k8s-10-01 — Arreglar restarts en cascada por `livenessProbe` mal diseñada

## 1. Identificación

- **ID:** `k8s-10-01-fix-cascading-restarts`
- **Tecnología:** kubernetes
- **Módulo:** `10-health-probes-lifecycle-and-rollouts`
- **Dificultad:** intermediate
- **Duración estimada:** 60 min
- **Tipo:** debug (independiente)

## 2. Contexto

Heredas un microservicio llamado `orders-api` que vive en Kubernetes. Depende de una base de datos Postgres. En condiciones normales todo va bien. Cuando Postgres tiene **cualquier** pico de latencia (un backup nocturno, un lock, un `VACUUM`), empiezan a aparecer alarmas en cadena:

- `CrashLoopBackOff` en varios Pods a la vez.
- La capacidad del Deployment se desploma.
- Postgres recibe aún más carga (los Pods que arrancan abren conexiones nuevas).
- El incidente se autoamplifica. SRE termina `kubectl scale deployment/orders-api --replicas=0` para romper el ciclo.

Tienes el manifiesto en `starter/deployment.yaml`. Léelo, identifica el anti-patrón, y arréglalo. El validador comprobará la forma final de las probes — no te importa correrlo contra un cluster real para esta actividad (aunque puedes hacerlo).

## 3. Objetivos

Al terminar deberías poder:

- Explicar en una frase por qué una `livenessProbe` que depende de una dependencia aguas abajo convierte latencia en restarts.
- Reescribir las probes de un Deployment: `livenessProbe` barata y local, `readinessProbe` que sí verifica dependencias.
- Defender tus `periodSeconds`/`failureThreshold` elegidos.

## 4. Prerrequisitos

- Haber leído la lección (`theory/lesson.md`), especialmente la sección 3.
- Un editor para YAML.
- Opcional (para probar de verdad): un cluster local kind/k3d y `kubectl`.
- Sin costo. Sin secretos.

## 5. Instrucciones

Trabaja en `/tmp/k8s-10-01/`:

```bash
mkdir -p /tmp/k8s-10-01
cp starter/deployment.yaml /tmp/k8s-10-01/deployment.yaml
cd /tmp/k8s-10-01
```

### Paso 1 — leer y entender qué está mal

Abre `deployment.yaml`. La app expone **tres** endpoints HTTP:

- `GET /` → página principal. **Ejecuta una query a Postgres** para listar últimos pedidos.
- `GET /healthz` → responde `200 OK` con un string estático. **No toca nada externo.**
- `GET /readyz` → responde `200` si el pool a Postgres está sano, `503` si no.

Mira la sección `livenessProbe` del manifiesto. ¿Qué endpoint usa?

### Paso 2 — razona el fallo

Si Postgres tarda 2 s en responder y la liveness tiene `timeoutSeconds: 1`:
- Cada probe falla.
- Con `failureThreshold: 3` y `periodSeconds: 10`, en 30 s el kubelet mata el contenedor.
- El Pod reinicia. Durante el arranque, no toma tráfico.
- Los Pods restantes absorben la carga → más conexiones a Postgres → más latencia.
- La siguiente ronda de probes falla también. Varios Pods caen en cascada.

Esto es exactamente lo que ves en los logs del incidente real.

### Paso 3 — arregla el manifiesto

Edita `deployment.yaml` para que:

1. **`livenessProbe`** use `/healthz` (barato, local). Debe usar `httpGet` sobre el puerto `http`. Debe ser tolerante: `periodSeconds >= 10`, `failureThreshold >= 3`.
2. **`readinessProbe`** use `/readyz` (verifica DB). Debe usar `httpGet` sobre el puerto `http`. Debe ser razonablemente reactiva: `periodSeconds` entre 2 y 10, `failureThreshold` entre 2 y 4.
3. Añade (nueva) una **`startupProbe`** que use `/healthz` y permita hasta 60 s de arranque (`failureThreshold * periodSeconds >= 60`).

No cambies nada más (nombre, imagen, puertos, labels).

### Paso 4 — valida

```bash
bash tests/validate.sh
```

El validador lee `/tmp/k8s-10-01/deployment.yaml` y comprueba la nueva forma de las probes.

### Paso 5 (opcional) — pruébalo contra un cluster

Si tienes kind levantado:

```bash
kubectl apply -f /tmp/k8s-10-01/deployment.yaml
kubectl rollout status deployment/orders-api --timeout=60s
# (no funcionará realmente porque la imagen es ficticia, pero verás los campos aceptados)
```

## 6. Resultado esperado

- `/tmp/k8s-10-01/deployment.yaml` con tres probes bien separadas.
- `bash tests/validate.sh` termina con exit 0 y reporte `0 fallos`.

## 7. Criterios de aceptación

- `livenessProbe.httpGet.path` apunta a `/healthz`.
- `readinessProbe.httpGet.path` apunta a `/readyz`.
- `startupProbe` existe y apunta a `/healthz` con una ventana >= 60 s.
- `livenessProbe` **no** apunta a `/`.
- Tiempos razonables (como los especificados en el paso 3).

## 8. Validación

```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Por qué `readinessProbe` falla sin matar al Pod resuelve el problema de amplificación?
2. ¿Qué pasaría si tu `/readyz` fuera también costoso (ej. 3 queries pesadas)? ¿Qué `periodSeconds` elegirías?
3. Si tu app tiene conexiones persistentes (gRPC, websockets), ¿basta con esta corrección o necesitas también cambiar algo en terminación? Lee la sección 6 de la lección.
4. ¿Cuándo tiene sentido NO poner `livenessProbe` en absoluto?

## 10. Extensiones

- Añade `preStop: sleep 10` + `terminationGracePeriodSeconds: 40` y argumenta por qué.
- Añade un `PodDisruptionBudget` con `minAvailable: 2` suponiendo `replicas: 3`.
- Convierte las probes a `grpc` imaginando que la app es gRPC en vez de HTTP.

## 11. Limpieza

```bash
# Si aplicaste en un cluster:
kubectl delete -f /tmp/k8s-10-01/deployment.yaml --ignore-not-found
rm -rf /tmp/k8s-10-01
```
