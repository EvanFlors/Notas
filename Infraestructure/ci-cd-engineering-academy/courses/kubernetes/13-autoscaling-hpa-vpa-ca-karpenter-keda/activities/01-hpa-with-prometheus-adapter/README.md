# k8s-13-01 — HPA con metrics-server (prepa para Prometheus Adapter)

## 1. Identificación

- **ID:** `k8s-13-01-hpa-with-prometheus-adapter`
- **Tecnología:** `kubernetes`
- **Módulo:** `13-autoscaling-hpa-vpa-ca-karpenter-keda`
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** guided-lab

## 2. Contexto

HPA sobre custom metrics vía Prometheus Adapter requiere un stack completo (Prometheus Operator + prometheus-adapter) que se escapa del scope de un lab local. Pero el **patrón** y el **90 % de los problemas** son los mismos del HPA sobre CPU con `metrics-server`: *requests* bien puestos, cadena de métricas sana, `behavior` razonable.

Esta actividad hace **la mitad reproducible en kind** (HPA + metrics-server + carga sintética) y te deja el *manifest* del adapter como lectura/aplicación opcional contra un cluster con Prometheus.

Al terminar, tendrás un HPA que escaló de 1 a varias réplicas bajo carga, verificable automáticamente.

## 3. Objetivos

- Instalar `metrics-server` en kind con el patch para kubelet autofirmado.
- Verificar que `kubectl top` responde.
- Desplegar un workload con `requests.cpu` definidos.
- Crear un HPA v2 con `behavior` razonable.
- Generar carga sintética con `kubectl run busybox`.
- Observar la cadena *métrica → desired → scale* en `kubectl describe hpa`.
- Validar automáticamente que `.status.currentReplicas > 1`.
- Leer el `ConfigMap` de referencia de Prometheus Adapter y explicar la regla.

## 4. Prerrequisitos

- Conocimientos: módulos `k8s-01` a `k8s-09`.
- Software:
  - `docker` o `podman` con backend Linux.
  - `kind` ≥ 0.22.
  - `kubectl` ≥ 1.28.
- Dependencias: acceso a Internet para `registry.k8s.io/metrics-server` y `registry.k8s.io/hpa-example`.
- Variables de entorno: ninguna.
- Permisos / cuentas: ninguna (todo local).
- Infraestructura: cluster kind efímero (`/tmp/k8s-13-01`).
- **Costos potenciales:** cero.

## 5. Instrucciones

### 5.1 Crear el cluster kind

```bash
export BASE_DIR=/tmp/k8s-13-01
mkdir -p "$BASE_DIR"
cp -r starter/* "$BASE_DIR"/
cd "$BASE_DIR"

kind create cluster --name k8s-13-01 --config kind-config.yaml
kubectl cluster-info --context kind-k8s-13-01
```

### 5.2 Instalar metrics-server y aplicarle el patch de kind

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# kind usa un kubelet con cert autofirmado → metrics-server necesita --kubelet-insecure-tls
kubectl patch -n kube-system deploy metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

kubectl -n kube-system rollout status deploy metrics-server --timeout=180s
```

Verifica (puede tardar ~30 s en servir datos):

```bash
kubectl top nodes
kubectl top pods -A
```

Si `top` imprime `Metrics not available yet`, espera 30 s y repite. Si tras 2 min sigue fallando, mira `kubectl -n kube-system logs deploy/metrics-server`.

### 5.3 Desplegar el workload y el HPA

```bash
kubectl apply -f workload.yaml
kubectl apply -f hpa.yaml
kubectl get hpa web
```

Durante los primeros 60 s el HPA aparecerá con `TARGETS: <unknown>/50%` — es normal mientras metrics-server llena la primera ventana.

### 5.4 Generar carga

En otra terminal:

```bash
kubectl run -i --tty --rm load \
  --image=busybox:1.36 --restart=Never -- \
  sh -c 'while true; do wget -q -O- http://web.default.svc.cluster.local/; done'
```

Déjalo correr **al menos 2 min**. Observa en paralelo:

```bash
watch -n 5 'kubectl get hpa web; echo; kubectl get pods -l app=web'
kubectl describe hpa web
```

Esperas ver:

- `TARGETS` subir sobre el 50 %.
- `REPLICAS` subir de 1 a ≥ 2 (típicamente 3–6 en kind).
- Eventos `SuccessfulRescale` en el describe.

### 5.5 Validar

```bash
cd "$BASE_DIR"
bash tests/validate.sh
```

Debe decir `RESULT: OK — HPA scaled to N replicas (N > 1)`.

### 5.6 Lectura adicional (no reproducible aquí)

Lee `reference/prometheus-adapter-rule.yaml`. Explica en 3 frases:

- Qué métrica Prometheus se usa (`seriesQuery`).
- Qué nombre K8s se le da (`name.as`).
- Qué `metricsQuery` se ejecuta y por qué `rate(...)` es necesario (counter → gauge por segundo).

## 6. Resultado esperado

- Cluster kind `k8s-13-01` con metrics-server funcional.
- Deployment `web` escalado a ≥ 2 réplicas.
- `kubectl describe hpa web` muestra métrica current > target y eventos `SuccessfulRescale`.
- Validador `tests/validate.sh` termina con exit 0.

## 7. Criterios de aceptación

- **Funcionalidad:** HPA escaló por encima de 1 réplica bajo carga.
- **Calidad:** `requests.cpu` definido en el container; `behavior.scaleDown` configurado.
- **Reproducibilidad:** todo desde manifests versionados en `starter/`.
- **Limpieza:** `tests/validate.sh` reporta OK, y la sección 11 deja el entorno limpio.

## 8. Validación

```bash
bash tests/validate.sh
```

El script revisa que:

1. El cluster existe y responde.
2. El Deployment `web` tiene al menos 2 Pods `Ready`.
3. El HPA `web` existe y su `.status.currentReplicas > 1`.

## 9. Preguntas de reflexión

1. ¿Por qué `metrics-server` necesita `--kubelet-insecure-tls` en kind y no en EKS?
2. Si quitas `requests.cpu` del container, ¿por qué el HPA deja de funcionar? ¿Qué mensaje aparece en `kubectl describe hpa`?
3. ¿Qué pasaría si pusieras `targetAverageUtilization: 10`? Explica en términos de la fórmula del §2 de la lección.
4. ¿Por qué `scaleDown.stabilizationWindowSeconds: 120` es un valor conservador? ¿Qué métrica te haría elegir 60 vs 600?
5. Describe cómo cambiaría la cadena si en lugar de CPU el HPA mirara `http_requests_per_second`. ¿Qué pieza adicional necesitas instalar?

## 10. Extensiones

1. Añade un **segundo** `metric` al HPA (memoria `AverageValue`) y provoca escalado por memoria con un stress-ng pod.
2. Modifica `behavior.scaleUp` para que suba más despacio (`Percent: 25, periodSeconds: 60`) y mide el impacto en latencia bajo carga.
3. Instala VPA en modo `Off` y lee la recomendación para `web` tras 10 min de carga. ¿Coincide con lo que pusiste?

## 11. Limpieza

```bash
kind delete cluster --name k8s-13-01
rm -rf /tmp/k8s-13-01
```

Verifica:

```bash
kind get clusters
# No debe listar k8s-13-01
```
