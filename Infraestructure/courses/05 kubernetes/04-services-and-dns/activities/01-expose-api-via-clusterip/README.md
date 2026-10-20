# k8s-04-01 — Exponer una API vía ClusterIP y consumirla por DNS

## 1. Identificación

- **ID:** `k8s-04-01-expose-api-via-clusterip`
- **Tecnología:** kubernetes
- **Módulo:** `04-services-and-dns`
- **Dificultad:** beginner
- **Duración estimada:** 45 min
- **Tipo:** guided-lab

## 2. Contexto

Toda app en Kubernetes empieza igual: un `Deployment` corre N Pods y necesitas que otros workloads le hablen por un nombre estable, no por IPs efímeras. El contrato que une un Service con un Deployment es **solo labels**; cuando funciona a la primera parece magia y cuando falla parece imposible. En esta actividad lo haces funcionar, lo lees con `kubectl describe` y lo pruebas desde un Pod cliente.

## 3. Objetivos

- Crear un `Deployment` de 3 réplicas con labels explícitas.
- Crear un `Service` tipo `ClusterIP` que seleccione esos Pods.
- Verificar que `endpoints` lista las 3 IPs y que `curl` desde un Pod cliente devuelve HTTP 200.
- Resolver el Service por **nombre corto** y por **FQDN** y observar la diferencia.

## 4. Prerrequisitos

- `kind` ≥ 0.20, `kubectl` ≥ 1.28, Docker daemon arriba.
- 2 GB libres de RAM para el nodo kind.
- Sin costo.

## 5. Instrucciones

Trabaja en `/tmp/k8s-04-01/`.

### Paso 1 — Preparar cluster

```bash
mkdir -p /tmp/k8s-04-01 && cd /tmp/k8s-04-01

kind delete cluster --name k8s04-act1 >/dev/null 2>&1 || true
kind create cluster --name k8s04-act1 --wait 90s
kubectl config use-context kind-k8s04-act1
kubectl get nodes
```

### Paso 2 — Crear Deployment y Service

Crea `/tmp/k8s-04-01/manifest.yaml` con **un Deployment de 3 réplicas** y **un ClusterIP Service** llamado `webapi` que las exponga en el `port: 80` → `targetPort: 80`.

Requisitos del grader:

- El Deployment se llama **`webapi`** y usa imagen **`nginx:alpine`**.
- Los Pods llevan la label **`app: webapi`**.
- El Service se llama **`webapi`**, es tipo **`ClusterIP`** y su `selector` es `app: webapi`.
- El Service escucha en **`port: 80`** y apunta a **`targetPort: 80`**.
- Todo en el namespace **`default`**.

Aplica y espera:

```bash
kubectl apply -f manifest.yaml
kubectl rollout status deploy/webapi --timeout=90s
```

### Paso 3 — Verificar que endpoints no está vacío

```bash
kubectl get svc webapi
kubectl get endpoints webapi
#   Debe listar 3 IP:80.

kubectl describe svc webapi | grep -E 'Selector|Endpoints'
```

### Paso 4 — Consumir el Service desde un Pod cliente

```bash
# Pod cliente efímero (verifica nombre corto, mismo namespace).
kubectl run tmp --image=curlimages/curl:8.9.1 --rm -i --restart=Never --quiet -- \
  curl -sS -o /dev/null -w "short: HTTP %{http_code}\n" http://webapi

# Pod cliente efímero (verifica FQDN).
kubectl run tmp --image=curlimages/curl:8.9.1 --rm -i --restart=Never --quiet -- \
  curl -sS -o /dev/null -w "fqdn:  HTTP %{http_code}\n" http://webapi.default.svc.cluster.local
```

Ambos deben imprimir `HTTP 200`.

### Paso 5 — Validar

```bash
bash courses/kubernetes/04-services-and-dns/activities/01-expose-api-via-clusterip/tests/validate.sh
```

## 6. Resultado esperado

- `kubectl get svc webapi` muestra tipo `ClusterIP` y un `CLUSTER-IP` no vacío.
- `kubectl get endpoints webapi` lista **3** `IP:80`.
- `curl http://webapi` desde un Pod en `default` → `HTTP 200`.
- `curl http://webapi.default.svc.cluster.local` desde ese mismo Pod → `HTTP 200`.
- El validador imprime `RESULT: PASS`.

## 7. Criterios de aceptación

- `Service` tipo `ClusterIP`, no NodePort/LoadBalancer.
- `endpoints` con exactamente 3 backends.
- Resolución por FQDN funciona.
- No usas IP del Pod en ningún lado (siempre nombre DNS).

## 8. Validación

```bash
bash courses/kubernetes/04-services-and-dns/activities/01-expose-api-via-clusterip/tests/validate.sh
```

## 9. Preguntas de reflexión

1. Si bajas `replicas` a 1, ¿`endpoints` queda con 1 IP? ¿Cuánto tarda en reflejarlo?
2. ¿Qué pasa si cambias `targetPort: 80` a `targetPort: 8080` en el Service? ¿`endpoints` cambia? ¿Qué pasa con `curl`?
3. Si eliminas el Deployment pero no el Service, ¿qué muestra `kubectl get endpoints webapi`?
4. ¿Qué diferencia hay operacionalmente entre usar `webapi` y `webapi.default.svc.cluster.local` desde un Pod en `default`?

## 10. Extensiones

- Cambia la imagen a `httpd:2.4-alpine` sin tocar el Service y verifica que sigue respondiendo.
- Añade `sessionAffinity: ClientIP` y mide con `for i in 1..10; curl` desde el mismo Pod cliente si todas las requests caen en el mismo backend.
- Reduce `replicas` a 0 y lee `kubectl describe svc webapi`: ¿qué dice `Endpoints`?

## 11. Limpieza

```bash
kind delete cluster --name k8s04-act1
rm -rf /tmp/k8s-04-01
```
