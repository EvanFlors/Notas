# Starter — k8s-04-01

Trabaja en `/tmp/k8s-04-01/`. No hay archivo "roto" aquí: tu trabajo es escribir desde cero `manifest.yaml` siguiendo los requisitos del README de la actividad.

Al mínimo necesitas:

- Un `Deployment` llamado `webapi`, 3 réplicas, `app: webapi`, imagen `nginx:alpine`.
- Un `Service` llamado `webapi`, tipo `ClusterIP`, `selector: app=webapi`, `port: 80`, `targetPort: 80`.

Esquema sugerido (no copies ciegamente — entiende cada campo):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapi
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapi
  template:
    metadata:
      labels:
        app: webapi
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: webapi
spec:
  type: ClusterIP
  selector:
    app: webapi
  ports:
    - port: 80
      targetPort: 80
```

Aplica con:

```bash
kubectl apply -f manifest.yaml
```

Luego valida con `tests/validate.sh`.
