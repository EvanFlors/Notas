# helm-03-01 — Chart propio para la app FastAPI del capstone

## 1. Identificación

- **ID:** `helm-03-01-chart-for-fastapi`
- **Tecnología:** helm
- **Módulo:** `03-chart-anatomy`
- **Dificultad:** intermediate
- **Duración estimada:** 90 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a crear el chart base del capstone: `fastapi-app`. Será la unidad de
despliegue que se irá enriqueciendo en los módulos siguientes (`helm-04`:
helpers y probes; `helm-05`: values por entorno; `helm-07`: hooks). En este
módulo construimos el **esqueleto limpio**: metadatos correctos, un
`values.yaml` que es contrato, y dos templates (Deployment + Service) idiomáticos.

La app es una FastAPI genérica que escucha en `0.0.0.0:8000` y expone
`/health`. Imagen de referencia: `ghcr.io/acme/fastapi-app:1.0.0`
(sustituible por values).

## 3. Objetivos

- Generar un scaffold con `helm create fastapi-app`.
- Recortar los knobs innecesarios (ingress, hpa, serviceaccount, test
  por defecto).
- Dejar un `Chart.yaml` v2 válido con `name`, `version`, `appVersion`, `type`.
- Diseñar un `values.yaml` con secciones `image`, `replicaCount`, `service`,
  `resources` (sin inflarlo).
- Conservar `_helpers.tpl` con los helpers estándar.
- Validar con `helm lint` + `helm template`.

## 4. Prerrequisitos

- Conocimientos: lección `theory/lesson.md` leída.
- Software: `helm` ≥ v3.14. (Opcional: `kind` + `kubectl` para probar
  `install --dry-run`).
- Shell POSIX.
- Permisos: ninguno especial; todo en `/tmp/`.
- Costos: cero (sin cluster real necesario).

## 5. Instrucciones

Trabaja en `/tmp/helm-03-01/`. El validator espera el chart en
`/tmp/helm-03-01/fastapi-app/`.

### Paso 1 — Workspace limpio

```bash
rm -rf /tmp/helm-03-01
mkdir -p /tmp/helm-03-01
cd /tmp/helm-03-01
```

### Paso 2 — Generar scaffold y recortar

```bash
helm create fastapi-app
cd fastapi-app
rm -f templates/hpa.yaml
rm -f templates/ingress.yaml
rm -f templates/serviceaccount.yaml
rm -f templates/httproute.yaml   # Helm v4 scaffold incluye este
rm -rf templates/tests
```

> ¿Por qué? Esta app no se expone por Ingress (ni Gateway API) en este módulo,
> no usa HPA todavía, y no necesita SA dedicada aún. `helm-07` traerá tests.
>
> Nota: Helm v3 genera `hpa.yaml`, `ingress.yaml`, `serviceaccount.yaml`,
> `tests/`. Helm v4 genera `httproute.yaml` en su lugar (Gateway API).
> `rm -f` tolera archivos ausentes, así que la lista anterior cubre ambos casos.

### Paso 3 — `Chart.yaml`

Reescribe `Chart.yaml` con los campos obligatorios y una descripción corta:

```yaml
apiVersion: v2
name: fastapi-app
description: FastAPI capstone application
type: application
version: 0.1.0
appVersion: "1.0.0"
maintainers:
  - name: Capstone team
```

### Paso 4 — `values.yaml`

Sustituye `values.yaml` por un contrato acotado:

```yaml
# Container image.
image:
  repository: ghcr.io/acme/fastapi-app
  tag: ""                 # defaults to .Chart.AppVersion
  pullPolicy: IfNotPresent

# Deployment.
replicaCount: 2

# Service.
service:
  type: ClusterIP
  port: 80
  targetPort: 8000

# Pod resources.
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Health probes paths (FastAPI /health).
probes:
  path: /health
  port: 8000
```

### Paso 5 — `templates/deployment.yaml`

Reemplaza por una versión mínima pero idiomática (usa los helpers del scaffold):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "fastapi-app.fullname" . }}
  labels:
    {{- include "fastapi-app.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "fastapi-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "fastapi-app.selectorLabels" . | nindent 8 }}
    spec:
      containers:
        - name: app
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.probes.port }}
              protocol: TCP
          livenessProbe:
            httpGet:
              path: {{ .Values.probes.path }}
              port: http
          readinessProbe:
            httpGet:
              path: {{ .Values.probes.path }}
              port: http
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

### Paso 6 — `templates/service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "fastapi-app.fullname" . }}
  labels:
    {{- include "fastapi-app.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "fastapi-app.selectorLabels" . | nindent 4 }}
```

### Paso 6b — Reemplaza `NOTES.txt`

El `NOTES.txt` del scaffold referencia knobs que ya borraste (`ingress`,
`httpRoute`), lo que rompe el render. Sustitúyelo por una versión mínima:

```
Thanks for installing {{ .Chart.Name }} (release "{{ .Release.Name }}").

Port-forward locally:
  kubectl -n {{ .Release.Namespace }} port-forward svc/{{ include "fastapi-app.fullname" . }} 8080:{{ .Values.service.port }}

Then open http://localhost:8080{{ .Values.probes.path }}
```

### Paso 7 — Validar

```bash
cd /tmp/helm-03-01/fastapi-app
helm lint .
helm template demo .
# Opcional (requiere kubecontext accesible):
helm install demo . --dry-run --debug >/dev/null && echo "dry-run OK"
```

Si todo pasa, corre el validator:

```bash
bash <REPO>/courses/helm/03-chart-anatomy/activities/01-chart-for-fastapi/tests/validate.sh
```

## 6. Resultado esperado

- Chart en `/tmp/helm-03-01/fastapi-app/` con la estructura:
  ```
  fastapi-app/
    Chart.yaml
    values.yaml
    .helmignore
    templates/
      _helpers.tpl
      deployment.yaml
      service.yaml
      NOTES.txt
  ```
- `helm lint` sin errores.
- `helm template demo .` imprime un Deployment y un Service válidos con
  nombre `demo-fastapi-app`.

## 7. Criterios de aceptación

- `Chart.yaml` tiene `apiVersion: v2`, `name: fastapi-app`, `type: application`,
  `version` y `appVersion` presentes.
- Los archivos `hpa.yaml`, `ingress.yaml`, `serviceaccount.yaml` **no** existen.
- `templates/deployment.yaml` y `templates/service.yaml` usan `include "fastapi-app.fullname"`
  y los helpers estándar.
- `helm lint` termina con `0 chart(s) failed`.
- `helm template` produce al menos un `kind: Deployment` y un `kind: Service`.

## 8. Validación

```bash
bash tests/validate.sh
# o con CHART_DIR custom:
CHART_DIR=/path/to/fastapi-app bash tests/validate.sh
```

El validator detecta `helm` ausente y hace **skip graceful** (exit 0 con
mensaje) en vez de fallar.

## 9. Preguntas de reflexión

1. ¿Por qué eliminar `templates/ingress.yaml` en vez de dejarlo
   `enabled: false` por default?
2. ¿Qué pasa si pones `tag: 1.0.0` (sin comillas) en `values.yaml`? ¿Y si
   `appVersion: 1.0.0` en `Chart.yaml`?
3. Tu colega quiere parametrizar `livenessProbe.initialDelaySeconds`.
   ¿Cuándo tiene sentido exponerlo en `values` y cuándo mantenerlo fijo?
4. ¿Qué romperías si cambias `include "fastapi-app.selectorLabels"` por
   `include "fastapi-app.labels"` en el `selector` del Service?

## 10. Extensiones

- Añade `ServiceAccount` dedicada y `serviceAccountName` al Deployment.
- Añade `podSecurityContext` + `securityContext` con `runAsNonRoot: true`.
- Añade `strategy.rollingUpdate` explícita (`maxUnavailable: 0`).
- Preparación para la actividad siguiente: añade `values.schema.json`.

## 11. Limpieza

```bash
rm -rf /tmp/helm-03-01
```
