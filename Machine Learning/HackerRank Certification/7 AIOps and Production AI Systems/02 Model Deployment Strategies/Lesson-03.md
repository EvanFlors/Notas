# Docker for ML Model Deployment

## ¿Qué es?

Un **contenedor Docker** empaqueta tu modelo, código de serving, intérprete Python, librerías de sistema y dependencias en una imagen inmutable. La misma imagen se ejecuta idéntica en el laptop del dev, en staging y en producción. Es la respuesta al clásico *"funciona en mi máquina"*.

**Kubernetes (K8s)** orquesta esos contenedores a escala: los programa en nodos, los reinicia cuando fallan, escala el número de réplicas según carga, administra networking entre servicios y permite actualizaciones sin downtime.

### Containerización para ML

Un contenedor para serving ML típicamente contiene:

- Imagen base (python-slim, nvidia/cuda, nvcr.io/nvidia/pytorch).
- Librerías del sistema (libgomp, libglib, libgl para OpenCV, etc.).
- Dependencias Python con versiones pinneadas (`requirements.txt` o `pyproject.toml` + lockfile).
- Código de serving (FastAPI, vLLM, Triton config, etc.).
- **Opcional**: el modelo embebido. Alternativa: descargar al startup desde S3/GCS para mantener la imagen pequeña.

### Kubernetes para orquestación

- **Pod:** unidad mínima, 1-N contenedores con red y storage compartidos.
- **Deployment:** declara "quiero N replicas de este Pod"; maneja rolling updates y rollback.
- **Service:** IP y DNS estables delante de un conjunto de Pods ephemeros.
- **HPA (Horizontal Pod Autoscaler):** escala replicas según CPU, memoria o métricas custom.
- **ConfigMap / Secret:** inyecta configuración/credenciales al Pod sin reconstruir la imagen.
- **Namespace:** aislamiento lógico (staging vs prod).
- **Ingress / Gateway API:** entrada HTTP desde el exterior.
- **PersistentVolume:** storage persistente para caches de modelos o logs.

Complementos típicos en el stack:

- **Helm:** gestor de paquetes para K8s (plantillas + values).
- **Kustomize:** overlays declarativos sin plantillas.
- **ArgoCD / Flux:** GitOps - el estado del cluster sigue a Git.
- **Istio / Linkerd:** service mesh con traffic shaping, mTLS, observabilidad.

## ¿Por qué importa?

- **Reproducibilidad:** eliminas el drift entre entornos. Si pasa el test con la imagen X, la imagen X en prod se comporta igual.
- **Isolación:** cada servicio en su propio contenedor; conflictos de dependencias desaparecen.
- **Escalabilidad declarativa:** `kubectl scale deployment/model --replicas=50` y K8s se encarga.
- **Zero-downtime deployments:** rolling updates reemplazan Pods gradualmente verificando health.
- **Portabilidad multi-cloud:** la misma imagen corre en EKS, GKE, AKS, on-prem.
- **Densidad y costo:** varios modelos pueden compartir el mismo nodo GPU con límites claros.
- **Recuperación automática:** si un Pod muere por OOM, K8s lo reinicia en segundos.

Sin estos cimientos, operar modelos en producción exige scripts frágiles, procedimientos manuales y oncalls aterradores.

## ¿Cómo funciona?

### Dockerfile multi-stage para ML

```dockerfile
# =============== Stage 1: builder ===============
FROM nvcr.io/nvidia/pytorch:24.03-py3 AS builder

WORKDIR /build
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential libgl1 libglib2.0-0 && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --user --no-cache-dir --no-warn-script-location -r requirements.txt

# =============== Stage 2: runtime ===============
FROM nvcr.io/nvidia/pytorch:24.03-py3

# Usuario no-root por seguridad
RUN useradd -m -u 1000 appuser && \
    mkdir -p /app /models && \
    chown -R appuser:appuser /app /models

# Copia solo lo necesario del builder
COPY --from=builder /root/.local /home/appuser/.local
ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    MODEL_PATH=/models \
    LOG_LEVEL=INFO \
    WORKERS=2

WORKDIR /app
COPY --chown=appuser:appuser ./src /app/src
COPY --chown=appuser:appuser ./main.py /app/

USER appuser
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
```

Buenas prácticas aplicadas: multi-stage para no cargar compiladores en runtime, usuario no-root, variables de entorno para config, healthcheck, `start-period` largo que da tiempo al warmup del modelo.

### requirements.txt pinneado

```text
# Core
fastapi==0.115.0
uvicorn[standard]==0.30.6
pydantic==2.9.2

# ML stack
torch==2.4.1
transformers==4.44.2
accelerate==0.34.2
sentencepiece==0.2.0

# Infra / observabilidad
redis==5.0.8
prometheus-client==0.20.0
structlog==24.4.0
opentelemetry-sdk==1.27.0
opentelemetry-instrumentation-fastapi==0.48b0

# ... (dependencias transitivas generadas con pip-compile o uv lock)
```

Alternativas modernas: **uv**, **Poetry**, **pip-tools**. Todas generan lockfiles reproducibles.

### Base image: elegir correctamente

| Base | Tamaño | Cuándo usar |
|---|---|---|
| `python:3.12-alpine` | ~50 MB | CPU puro, binarios ligeros (musl). Problemas con wheels pre-compiladas. |
| `python:3.12-slim` | ~130 MB | CPU inference, servicios REST sin GPU. |
| `python:3.12` | ~1 GB | Debug, incluye muchas tools. Evitar en prod. |
| `nvidia/cuda:12.4-runtime-ubuntu22.04` | ~2 GB | GPU inference, instala PyTorch tú mismo. |
| `nvcr.io/nvidia/pytorch:24.03-py3` | ~9 GB | PyTorch + CUDA + cuDNN + NCCL + TensorRT ya optimizados. |
| `vllm/vllm-openai:latest` | ~8 GB | Serving directo de LLMs con vLLM. |

### Kubernetes: Deployment, Service, HPA

```yaml
# model-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sentiment-server
  namespace: ml-prod
  labels: { app: sentiment, version: v1-3-0 }
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate: { maxSurge: 1, maxUnavailable: 0 }
  selector:
    matchLabels: { app: sentiment }
  template:
    metadata:
      labels: { app: sentiment, version: v1-3-0 }
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8000"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: ml-serving
      nodeSelector: { "nvidia.com/gpu.product": "A100-SXM4-40GB" }
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
          effect: NoSchedule
      initContainers:
        - name: fetch-model
          image: amazon/aws-cli:2.15.0
          command: ["sh", "-c"]
          args:
            - aws s3 cp s3://my-models/sentiment-v1.3.0.tar.gz /models/m.tgz
              && tar -xzf /models/m.tgz -C /models
          volumeMounts:
            - { name: models, mountPath: /models }
      containers:
        - name: server
          image: 123.dkr.ecr.us-east-1.amazonaws.com/sentiment:v1.3.0
          imagePullPolicy: IfNotPresent
          ports: [ { containerPort: 8000, name: http } ]
          env:
            - name: MODEL_PATH
              value: /models
            - name: REDIS_URL
              valueFrom:
                configMapKeyRef: { name: ml-config, key: redis_url }
            - name: API_KEY
              valueFrom:
                secretKeyRef: { name: ml-secrets, key: api_key }
          resources:
            requests: { cpu: "2", memory: "8Gi", nvidia.com/gpu: "1" }
            limits:   { cpu: "4", memory: "16Gi", nvidia.com/gpu: "1" }
          startupProbe:
            httpGet: { path: /ready, port: http }
            periodSeconds: 10
            failureThreshold: 30         # da hasta 5 min para cargar modelo
          livenessProbe:
            httpGet: { path: /health, port: http }
            periodSeconds: 30
            failureThreshold: 3
          readinessProbe:
            httpGet: { path: /ready, port: http }
            periodSeconds: 5
            failureThreshold: 2
          lifecycle:
            preStop:
              exec:
                command: ["sh", "-c", "sleep 20"]   # drena in-flight antes de kill
          volumeMounts:
            - { name: models, mountPath: /models, readOnly: true }
      volumes:
        - name: models
          emptyDir:
            sizeLimit: 10Gi
      terminationGracePeriodSeconds: 60
```

```yaml
# model-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: sentiment-server
  namespace: ml-prod
spec:
  selector: { app: sentiment }
  ports:
    - { port: 80, targetPort: 8000, name: http }
  type: ClusterIP
```

```yaml
# model-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: sentiment-hpa
  namespace: ml-prod
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: sentiment-server
  minReplicas: 3
  maxReplicas: 30
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 30
      policies:
        - { type: Percent, value: 100, periodSeconds: 30 }
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - { type: Percent, value: 10, periodSeconds: 60 }
  metrics:
    - type: Resource
      resource: { name: cpu, target: { type: Utilization, averageUtilization: 70 } }
    - type: Pods
      pods:
        metric: { name: inference_queue_depth }
        target: { type: AverageValue, averageValue: "5" }
```

### Helm chart (templating)

```yaml
# charts/model/values.yaml
image:
  repository: 123.dkr.ecr.us-east-1.amazonaws.com/sentiment
  tag: v1.3.0
replicaCount: 3
resources:
  requests: { cpu: "2", memory: "8Gi", nvidia.com/gpu: "1" }
  limits:   { cpu: "4", memory: "16Gi", nvidia.com/gpu: "1" }
autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 30
  targetCPU: 70
model:
  s3Path: s3://my-models/sentiment-v1.3.0.tar.gz
```

Deploy: `helm upgrade --install sentiment ./charts/model -n ml-prod -f values.prod.yaml`.

### ArgoCD Application (GitOps)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sentiment-prod
  namespace: argocd
spec:
  project: ml
  source:
    repoURL: git@github.com:org/ml-deployments.git
    targetRevision: main
    path: charts/model
    helm:
      valueFiles: [ values.prod.yaml ]
  destination:
    server: https://kubernetes.default.svc
    namespace: ml-prod
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [ CreateNamespace=true ]
```

Cada push a `main` que modifique `values.prod.yaml` dispara un sync automático. Rollback = revertir el commit.

### Tabla comparativa de orquestadores

| Herramienta | Mejor para | Curva aprendizaje | GPU support | Multi-cloud |
|---|---|---|---|---|
| Docker Compose | Dev local, 1 host | Baja | Manual | No |
| Nomad | Simplicidad, mixta VM+contenedor | Media | Sí | Sí |
| AWS ECS | Equipos all-in AWS | Baja | Sí (Fargate limitado) | No |
| Kubernetes | Escala, portabilidad | Alta | Sí (device plugin) | Sí |
| Ray + K8s | Workloads ML distribuidos | Alta | Sí | Sí |

### Fórmula de réplicas

```
replicas = ceil( peak_rps × avg_latency_s / max_concurrent_por_pod × safety_factor )

Ejemplo: 2000 rps peak, 50 ms latencia, 10 concurrent/pod, factor 1.4
         replicas = ceil(2000 × 0.05 / 10 × 1.4) = 14
```

## Ejemplo con código

Deploy end-to-end: build de imagen, push a registry, aplicación a cluster, verificación.

```bash
# 1. Build de la imagen con tag inmutable (commit SHA)
TAG=$(git rev-parse --short HEAD)
docker build \
  --build-arg BASE_IMAGE=nvcr.io/nvidia/pytorch:24.03-py3 \
  -t 123.dkr.ecr.us-east-1.amazonaws.com/sentiment:${TAG} \
  -f Dockerfile .

# 2. Scan de vulnerabilidades
trivy image --severity CRITICAL,HIGH --exit-code 1 \
  123.dkr.ecr.us-east-1.amazonaws.com/sentiment:${TAG}

# 3. Push al registry
aws ecr get-login-password | docker login --username AWS --password-stdin 123.dkr.ecr.us-east-1.amazonaws.com
docker push 123.dkr.ecr.us-east-1.amazonaws.com/sentiment:${TAG}

# 4. Deploy via Helm (o commit a GitOps repo si usas ArgoCD)
helm upgrade --install sentiment ./charts/model \
  -n ml-prod \
  --set image.tag=${TAG} \
  --wait --timeout 10m

# 5. Verificar
kubectl -n ml-prod rollout status deployment/sentiment-server
kubectl -n ml-prod get pods -l app=sentiment
kubectl -n ml-prod port-forward svc/sentiment-server 8000:80 &
curl -X POST http://localhost:8000/predict \
  -H 'Content-Type: application/json' \
  -d '{"text":"amazing"}'
```

Rollback: `helm rollback sentiment` o revertir el commit en el repo GitOps.

## Errores comunes

- **Imágenes de 10+ GB con el modelo adentro.** `docker pull` tarda 5-10 min; autoscaling se vuelve inviable. Mueve modelos a S3/GCS y descarga en init container.
- **No usar multi-stage builds.** Terminas con compiladores, headers y caches de pip en producción. Reduce 50-70% el tamaño.
- **Correr como root.** Un CVE en una dep + volumen montado = escape de contenedor. `USER appuser` siempre.
- **`latest` tag en producción.** Rollback imposible, builds no reproducibles. Usa SHA del commit o SemVer.
- **No pin de dependencias.** `pip install torch` instala diferente según el día. Usa lockfile.
- **Resource requests mal calibrados.** Underrequest → OOMKill. Overrequest → waste y bin-packing malo. Profilea bajo carga real.
- **Readiness probe inexistente o mal configurada.** Pod aceptando traffic antes de que el modelo cargue → 503 masivos. Usa `startupProbe` con `failureThreshold` alto.
- **Sin `preStop` hook.** Deploy rolling mata pods a mitad de requests. Agrega `sleep 20` y `terminationGracePeriodSeconds=60`.
- **Sin `initContainer` para descarga de modelo.** El modelo se descarga en el main container → race conditions, bloqueo del probe.
- **GPU sin tolerations/nodeSelector.** El Pod puede programarse en nodos sin GPU, falla al iniciar.
- **No limitar GPU memory en frameworks.** vLLM/PyTorch por default toman toda la VRAM. Usa `--gpu-memory-utilization 0.9`.
- **Sin HPA o con targets agresivos.** Scaling de 1 a 30 pods instantáneo satura S3 descargando el modelo.
- **ConfigMaps/Secrets en el image.** Credenciales hardcodeadas → leak garantizado. Siempre externas y rotables.

## Contexto industrial

- **Google** operó Borg (antecesor de K8s) desde ~2003; K8s nace open source en 2014.
- **Meta** usa **Tupperware** (propio) para contenedores a hiperescala con GPU scheduling custom.
- **Spotify, Airbnb, Shopify, Pinterest** operan sobre K8s + ArgoCD/Flux + Helm.
- **Netflix** usa **Titus** (propio) para ML, con integración profunda a sus pipelines.
- **Hugging Face Inference Endpoints**, **Together AI**, **Modal**, **Replicate**: todos son K8s + custom schedulers debajo.
- **CNCF** mantiene el ecosistema K8s (Prometheus, Envoy, Istio, Linkerd, ArgoCD, Flux, Flagger, Keda, Cert-Manager).

Buenas prácticas de la industria: **inmutable infra** (nunca `kubectl edit` en prod), **GitOps** (todo cambio via PR), **progressive delivery** (Argo Rollouts / Flagger), **chaos engineering** (Chaos Mesh, Litmus), **cost monitoring** (OpenCost, Kubecost).

## Resumen

- **Docker** empaqueta tu modelo + runtime + deps en una imagen inmutable y reproducible.
- **Kubernetes** orquesta esos contenedores: scheduling, autoscaling, health, networking, rolling updates.
- **Multi-stage builds**, **non-root user**, **healthchecks** y **pinning estricto** son no-negociables para imágenes de producción.
- Para modelos grandes, descarga en **initContainer** desde S3/GCS en lugar de embeberlos.
- **HPA** escala con CPU/memoria o métricas custom (queue depth, p99 latency); afina `scaleUp` y `scaleDown` para evitar flapping.
- **GPU scheduling** requiere `nvidia.com/gpu` en requests + nodeSelector + tolerations.
- **Helm** templiza manifiestos; **ArgoCD/Flux** implementan GitOps (el repo es la fuente de verdad del cluster).
- **Rolling updates** + **readiness probes** + **preStop hooks** garantizan zero-downtime.
- Herramientas clave: Docker, Kubernetes, Helm, Kustomize, ArgoCD, Flux, Istio, Prometheus, Grafana, Trivy, OpenCost.
- El objetivo final: deploys **frecuentes, pequeños, automáticos y reversibles**.
