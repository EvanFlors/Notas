# Ejemplo 02 — Chart mínimo desde cero

## Concepto que demuestra

El **chart más pequeño posible** que es realmente útil: un `Chart.yaml`, un
`values.yaml`, y dos manifests (Deployment + Service). Sin `helm create`, sin
`_helpers.tpl`, sin `NOTES.txt`. Para entender que "chart" es un contrato muy
simple.

## Contexto

A veces, en lugar de recortar lo que `helm create` genera, es más instructivo
construir el chart de cero. Esto fuerza a enfrentarse al mínimo irreducible y
luego añadir solo lo que *justifiques*.

## Objetivo

- Escribir un `Chart.yaml` v2 válido a mano.
- Escribir `values.yaml` y dos templates sin helpers.
- Correr `helm lint` + `helm template` + `helm install --dry-run`.

## Prerrequisitos

- `helm` instalado.
- `kubectl` configurado contra un cluster (opcional; para `install --dry-run`
  basta contexto).

## Ejecución

```bash
# Preparar workspace
rm -rf /tmp/mini-chart && mkdir -p /tmp/mini-chart/templates && cd /tmp/mini-chart

# 1. Chart.yaml (metadatos obligatorios)
cat > Chart.yaml <<'EOF'
apiVersion: v2
name: mini
description: Minimal chart with just Deployment + Service
type: application
version: 0.1.0
appVersion: "1.0.0"
EOF

# 2. values.yaml (contrato de inputs)
cat > values.yaml <<'EOF'
image:
  repository: nginx
  tag: "1.27-alpine"
  pullPolicy: IfNotPresent

replicaCount: 1

service:
  type: ClusterIP
  port: 80
EOF

# 3. templates/deployment.yaml
cat > templates/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-mini
  labels:
    app.kubernetes.io/name: mini
    app.kubernetes.io/instance: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app.kubernetes.io/name: mini
      app.kubernetes.io/instance: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: mini
        app.kubernetes.io/instance: {{ .Release.Name }}
    spec:
      containers:
        - name: app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 80
              name: http
EOF

# 4. templates/service.yaml
cat > templates/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}-mini
  labels:
    app.kubernetes.io/name: mini
    app.kubernetes.io/instance: {{ .Release.Name }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: mini
    app.kubernetes.io/instance: {{ .Release.Name }}
EOF

# 5. Verificar
helm lint .
helm template demo .
helm install demo . --dry-run --debug | head -50   # requiere kubecontext accesible
```

## Resultado esperado

- `helm lint` termina con `0 chart(s) failed`.
- `helm template` imprime Deployment + Service con nombres `demo-mini`.
- `helm install --dry-run` muestra los mismos manifests.

## Interpretación

- No necesitas `_helpers.tpl` para que el chart funcione; **sí** lo necesitas si
  tu release tiene nombres largos (los helpers truncan a 63 chars) o si quieres
  labels estándar completas.
- Omitir `NOTES.txt` solo quita el mensaje post-install.
- Un chart así es un buen punto de partida pedagógico; para producción añadirás
  helpers, probes, `resources`, probablemente `ServiceAccount` dedicada, y un
  `values.schema.json`.

## Errores frecuentes

- Olvidar `apiVersion: v2` → Helm asume `v1` (Helm 2 legacy) y falla.
- Repetir labels en 4 sitios y que diverjan — por eso existen `_helpers.tpl`.
- Hard-codear `name` sin incluir `.Release.Name` → dos releases en el mismo
  namespace colisionan.

## Limpieza

```bash
rm -rf /tmp/mini-chart
```
