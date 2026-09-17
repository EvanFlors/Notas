## Docker for ML Model Deployment

Containers solve the classic "it works on my machine" problem by packaging your model with its complete runtime environment. This makes deployment reliable and reproducible across different environments.

A Docker container bundles your model files, serving code, Python interpreter, system libraries, and dependencies into a single artifact. You build the container image once, test it thoroughly, and deploy the exact same image to staging and production. This eliminates environment discrepancies that cause mysterious failures.

Your Dockerfile defines how to build the container image. Start with a base image that includes Python and system dependencies. Copy your model files and serving code. Install Python dependencies. Specify the command to run when the container starts. This declarative approach documents your entire runtime environment.

Here is what a complete ML serving Dockerfile looks like:

Dockerfile

```dockerfile
# Multi-stage build for smaller final image
# Stage 1: Build stage with all build dependencies
FROM python:3.11-slim as builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  gcc \
  g++ \
  && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Stage 2: Runtime stage with only necessary components
FROM python:3.11-slim

# Create non-root user for security
RUN useradd -m -u 1000 modelserver && \
  mkdir -p /app /models && \
  chown -R modelserver:modelserver /app /models

# Copy installed packages from builder stage
COPY --from=builder /root/.local /home/modelserver/.local

# Set PATH to include user-installed packages
ENV PATH=/home/modelserver/.local/bin:$PATH

# Set working directory
WORKDIR /app

# Copy application code
COPY --chown=modelserver:modelserver ./src /app/src
COPY --chown=modelserver:modelserver ./main.py /app/

# Switch to non-root user
USER modelserver

# Expose the API port
EXPOSE 8000

# Health check - ensures container is ready to serve
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD python -c "import requests; requests.get('http://localhost:8000/health')"

# Environment variables (can be overridden at runtime)
ENV MODEL_PATH=/models/model.pkl \
  LOG_LEVEL=INFO \
  WORKERS=4

# Start the model server
CMD ["python", "main.py"]
```

This Dockerfile follows production best practices: it uses multi-stage builds to minimize image size, runs as a non-root user for security, includes health checks for Kubernetes readiness probes, and uses environment variables for configuration flexibility.

Base image selection affects image size, build time, and security. Official Python images range from 900MB (full Debian-based) to 50MB (Alpine-based slim images). Larger images include more system tools and libraries, making them easier to work with but slower to download and deploy. Smaller images minimize attack surface and deployment time but may lack libraries your code needs.

For ML workloads, using GPU-enabled base images is common. NVIDIA provides CUDA base images that include GPU drivers and CUDA libraries. Starting from nvidia/cuda:11.8.0-runtime-ubuntu22.04 gives you GPU access without manual driver installation. This is essential for deploying models that run on GPUs.

Dependency management in containers requires attention to reproducibility. Pin exact versions in requirements.txt rather than using loose version constraints. tensorflow==2.13.0 is better than tensorflow>=2.0 because it ensures consistent behavior. Loose versions might install different packages when building at different times, causing subtle bugs.

Multi-stage builds reduce final image size. You might need build tools like gcc to compile dependencies but do not need them at runtime. A multi-stage build uses one stage with build tools to compile and install dependencies, then copies only the runtime artifacts to a slim final image. This can reduce image size by 50 percent or more.

Layer caching speeds up builds. Docker caches each layer of your image. If a layer has not changed, Docker reuses the cached version. Structure your Dockerfile to maximize cache hits: copy and install dependencies before copying code, since dependencies change less frequently than code. This makes iterative development faster.

Model files present a challenge for containerization. A 5GB model file in your container image makes the entire image 5GB. Pushing and pulling 5GB images is slow and expensive. The alternative is storing models in object storage (S3) and downloading them when the container starts. This keeps images small but adds startup time and complexity.

Environment variables configure containers at runtime. Rather than hardcoding values like model paths or API keys, use environment variables. This lets you use the same container image in different environments with different configurations. Your production container might use MODEL_PATH=s3://prod-models/ while staging uses MODEL_PATH=s3://staging-models/.


Kubernetes for Model Orchestration
Kubernetes orchestrates containers at scale, handling deployment, scaling, networking, and failure recovery automatically. This transforms container deployment from manual process to declarative configuration.

A Kubernetes Deployment defines how your model server containers should run. You specify the container image, number of replicas, resource requirements, health checks, and environment variables. Kubernetes ensures this desired state is maintained: if a container crashes, Kubernetes restarts it; if you update the deployment, Kubernetes rolls out the change safely.

Pods are the basic unit in Kubernetes. A Pod runs one or more containers that share networking and storage. For model serving, you typically run one container per Pod. The Pod specification includes resource requests and limits: "this Pod needs 4 CPU cores and 8GB memory, and can use up to 8 cores and 16GB."

Services provide stable networking for Pods. Pods are ephemeral and might be recreated with new IP addresses. A Service provides a stable IP and DNS name that routes traffic to healthy Pods. Your model service might have 10 Pods running, but clients connect to a single Service endpoint that load balances across them.

Horizontal scaling adjusts the number of Pod replicas based on load. You might run 5 replicas normally and scale to 20 during peak traffic. The Horizontal Pod Autoscaler monitors metrics like CPU utilization or custom metrics like request queue depth and adjusts replica count automatically. This ensures you have enough capacity without over-provisioning.

Resource requests and limits control how much CPU and memory each Pod can use. Requests are what the Pod is guaranteed. Limits are the maximum it can use. Set requests based on typical usage and limits based on maximum usage. A Pod requesting 2 CPU cores and limiting to 4 cores will be scheduled on a node with 2 free cores but can burst to 4 cores if available.

For GPU workloads, you request GPUs as a resource. A Pod might request 1 NVIDIA GPU. Kubernetes schedules it on a node with an available GPU and ensures no other Pod uses that GPU. This simplifies GPU allocation compared to manual management. However, GPU resources are expensive, so careful resource planning is essential.

Node selectors and affinity rules control where Pods run. You might have GPU nodes and CPU nodes in your cluster. Use nodeSelector to ensure GPU-requiring Pods only run on GPU nodes. Affinity rules provide more sophisticated scheduling: run Pods near their data sources, spread Pods across availability zones for reliability, or keep certain Pods apart to reduce failure blast radius.

ConfigMaps and Secrets manage configuration and sensitive data. Rather than baking configuration into container images, store it in ConfigMaps that Pods mount at runtime. This lets you update configuration without rebuilding images. Secrets work similarly but encrypt sensitive data like API keys and database passwords.

Rolling updates enable zero-downtime deployments. When you update a Deployment, Kubernetes gradually replaces old Pods with new ones. It creates new Pods, waits for them to become healthy, then terminates old Pods. If new Pods fail health checks, the rollout pauses and can be reverted. This provides safe, automated deployments.

Namespaces isolate resources within a cluster. You might use separate namespaces for staging and production. Resources in different namespaces are logically separate, simplifying access control and organization. Your prod namespace and staging namespace can run different model versions with different configurations.

Here is a complete Kubernetes deployment configuration for an ML model server:

config.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
name: model-server
spec:
replicas: 3
selector:
  matchLabels:
    app: model-server
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
template:
  metadata:
    labels:
      app: model-server
  spec:
    nodeSelector:
      gpu: "true"
    containers:
    - name: model-server
      image: myregistry.io/model-server:v1.0.0
      ports:
      - containerPort: 8000
      resources:
        requests:
          memory: "4Gi"
          cpu: "2"
          nvidia.com/gpu: "1"
        limits:
          memory: "8Gi"
          cpu: "4"
          nvidia.com/gpu: "1"
      livenessProbe:
        httpGet:
          path: /health
          port: 8000
        initialDelaySeconds: 30
        periodSeconds: 10
      readinessProbe:
        httpGet:
          path: /ready
          port: 8000
        initialDelaySeconds: 10
        periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
name: model-server
spec:
selector:
  app: model-server
ports:
- port: 80
  targetPort: 8000
type: LoadBalancer
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
name: model-server-hpa
spec:
scaleTargetRef:
  apiVersion: apps/v1
  kind: Deployment
  name: model-server
minReplicas: 3
maxReplicas: 10
metrics:
- type: Resource
  resource:
    name: cpu
    target:
      type: Utilization
      averageUtilization: 70
```

This configuration creates a production-ready deployment with three replicas, health checks for automatic restarts, resource limits to prevent resource exhaustion, and autoscaling to handle traffic spikes.


Managing Dependencies and Resource Allocation
Getting ML models running reliably in containers requires careful dependency management and resource allocation strategies.

Python dependency conflicts are common in ML projects. Your model uses TensorFlow 2.13, but another dependency requires NumPy 1.24, which conflicts with the NumPy version TensorFlow needs. Virtual environments in local development help, but in containers you need reproducible dependency resolution.

The solution is pinning all transitive dependencies. Rather than just listing tensorflow==2.13.0 in requirements.txt, list every package TensorFlow depends on with exact versions. Generate this with pip freeze after installing your dependencies in a clean environment. This 200-line requirements.txt is verbose but eliminates surprise dependency conflicts.

Here is an example of properly pinned dependencies for an ML serving application:

requirements.txt

```text
# Core web framework - pinned to exact version
fastapi==0.109.0
uvicorn==0.27.0
pydantic==2.5.3

# Model serving dependencies
numpy==1.26.3
scikit-learn==1.4.0
joblib==1.3.2

# Monitoring and logging
prometheus-client==0.19.0
python-json-logger==2.0.7

# HTTP client for health checks
requests==2.31.0

# All transitive dependencies (generated by pip freeze)
annotated-types==0.6.0
anyio==4.2.0
certifi==2023.11.17
charset-normalizer==3.3.2
click==8.1.7
h11==0.14.0
httptools==0.6.1
idna==3.6
pydantic-core==2.14.6
python-dotenv==1.0.0
PyYAML==6.0.1
scipy==1.11.4
sniffio==1.3.0
starlette==0.35.1
threadpoolctl==3.2.0
typing-extensions==4.9.0
urllib3==2.1.0
uvloop==0.19.0
watchfiles==0.21.0
websockets==12.0
```

This requirements.txt pins every dependency to an exact version, ensuring reproducible builds across different environments and preventing surprise breakages from dependency updates.

Poetry and pip-tools provide better dependency management. You declare direct dependencies in a high-level format. These tools resolve all transitive dependencies, check for conflicts, and generate a lock file with exact versions. This combines the simplicity of declaring only direct dependencies with the reproducibility of pinned versions.

System library dependencies require attention. Some Python packages need system libraries. Installing opencv-python requires libglib2.0-0 and other system libraries. If these are missing, the container fails at runtime with cryptic errors. Your Dockerfile needs apt-get install commands for these system dependencies.

Model loading time affects container startup and scaling. A 5GB model takes 30 seconds to load from disk into GPU memory. If a Pod crashes and restarts, users experience 30 seconds of unavailability. If you need to scale up quickly, new Pods take 30 seconds to become ready. Strategies to reduce this include keeping warm standby Pods, loading models lazily only when first needed, or using model caching layers.

Memory allocation requires careful tuning. Your model needs X GB in GPU memory. Python processes use Y GB in CPU memory for serving code and request processing. Kubernetes allocates memory based on your requests. Under-allocating causes out-of-memory kills. Over-allocating wastes resources and increases costs. Profile your actual memory usage under load to set appropriate values.

CPU allocation is less critical but still important. Model inference on GPUs is compute-bound on the GPU, not CPU. However, request preprocessing, post-processing, and data transfer use CPU. Under-allocating CPU can bottleneck GPU throughput. Typical allocations are 2-4 CPU cores per GPU for balanced utilization.

GPU sharing is complex. A single GPU can run multiple models or multiple replicas of one model. However, coordination is required to avoid memory conflicts. NVIDIA Multi-Process Service (MPS) enables GPU sharing but adds complexity. Most production systems dedicate one GPU per Pod for simplicity, though this leaves some GPU compute underutilized.

Storage considerations affect container design. Containers are stateless by default. When a container terminates, any data written to its filesystem disappears. Model serving usually does not need persistent storage, but logging and caching might. Kubernetes Persistent Volumes provide storage that survives container restarts, though they add complexity.

Init containers handle setup tasks before the main container starts. You might use an init container to download the model from S3 before starting the serving container. This separates concerns: the init container handles model retrieval; the main container handles serving. If model download fails, the Pod fails to start rather than starting with no model.

Resource limits prevent noisy neighbor problems. Without limits, one Pod could use all CPU or memory on a node, starving other Pods. Limits ensure fair resource sharing. However, overly restrictive limits cause unnecessary throttling. Balance protection against resource waste.

Summary
Containerization with Docker packages models with their complete runtime environment, solving deployment reproducibility problems. Kubernetes orchestrates containers at scale, handling deployment, scaling, health checks, and failure recovery automatically. Proper dependency management, resource allocation, and container design patterns are essential for reliable production ML serving.

Docker best practices include using appropriate base images, pinning dependencies, leveraging multi-stage builds, and externalizing configuration. Kubernetes concepts like Deployments, Services, autoscaling, and resource requests enable scalable, resilient serving infrastructure.

Key concepts to remember
Container Benefits - Docker containers package models with all dependencies and runtime requirements, eliminating environment discrepancy problems
Optimized Images - Multi-stage Docker builds and external model storage keep container images small for faster deployment
Zero-Downtime Deployments - Kubernetes Deployments with health checks and rolling updates enable zero-downtime deployments with automatic failure recovery
Autoscaling - Horizontal Pod Autoscaling adjusts replica count based on load, ensuring adequate capacity without over-provisioning
Resource Management - Careful resource allocation (CPU, memory, GPU requests and limits) is essential for reliable operation and cost efficiency