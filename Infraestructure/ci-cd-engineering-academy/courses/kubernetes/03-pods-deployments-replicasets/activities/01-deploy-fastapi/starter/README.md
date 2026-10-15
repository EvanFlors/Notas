# Starter — k8s-03-01-deploy-fastapi

Trabaja en `/tmp/k8s-03-01/`.

```bash
mkdir -p /tmp/k8s-03-01 && cd /tmp/k8s-03-01
kubectl create namespace k8s-03-01 --dry-run=client -o yaml | kubectl apply -f -
```

Esqueleto mínimo para `deployment.yaml` (**completa los TODO**):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fastapi-stub
  namespace: k8s-03-01
  labels:
    app: fastapi-stub
    component: web
spec:
  replicas: 3
  revisionHistoryLimit: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      # TODO: incluir app y component
  template:
    metadata:
      labels:
        # TODO: deben coincidir con el selector (y pueden tener MÁS, no menos)
    spec:
      containers:
        - name: web
          image: nginxdemos/hello:plain-text
          ports:
            - containerPort: 80
```

Aplica, espera y valida con los pasos del README principal.
