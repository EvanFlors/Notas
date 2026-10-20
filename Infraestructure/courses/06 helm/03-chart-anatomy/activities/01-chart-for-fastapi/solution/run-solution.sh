#!/usr/bin/env bash
# Reference solution for helm-03-01-chart-for-fastapi.
# Builds a /tmp/helm-03-01/fastapi-app chart matching the expected state.
#
# Usage: bash run-solution.sh [CHART_PARENT_DIR]
#   default CHART_PARENT_DIR = /tmp/helm-03-01

set -euo pipefail

BASE="${1:-/tmp/helm-03-01}"
CHART="$BASE/fastapi-app"

if ! command -v helm >/dev/null 2>&1; then
  echo "helm not installed; cannot build the solution. Install helm v3.x." >&2
  exit 2
fi

rm -rf "$BASE"
mkdir -p "$BASE"
cd "$BASE"

helm create fastapi-app >/dev/null

# Trim scaffold. (Helm v3 generated hpa/ingress/serviceaccount/tests; Helm v4
# generates httproute instead. `rm -f` is tolerant of missing files, so this
# works for both.)
rm -f  "$CHART/templates/hpa.yaml"
rm -f  "$CHART/templates/ingress.yaml"
rm -f  "$CHART/templates/serviceaccount.yaml"
rm -f  "$CHART/templates/httproute.yaml"
rm -rf "$CHART/templates/tests"

# NOTES.txt from Helm v3/v4 references removed knobs (ingress, httpRoute);
# replace with one that only touches what our chart actually exposes.
cat > "$CHART/templates/NOTES.txt" <<'EOF'
Thanks for installing {{ .Chart.Name }} (release "{{ .Release.Name }}").

Port-forward locally:
  kubectl -n {{ .Release.Namespace }} port-forward svc/{{ include "fastapi-app.fullname" . }} 8080:{{ .Values.service.port }}

Then open http://localhost:8080{{ .Values.probes.path }}
EOF

# Chart.yaml
cat > "$CHART/Chart.yaml" <<'EOF'
apiVersion: v2
name: fastapi-app
description: FastAPI capstone application
type: application
version: 0.1.0
appVersion: "1.0.0"
maintainers:
  - name: Capstone team
EOF

# values.yaml
cat > "$CHART/values.yaml" <<'EOF'
image:
  repository: ghcr.io/acme/fastapi-app
  tag: ""
  pullPolicy: IfNotPresent

replicaCount: 2

service:
  type: ClusterIP
  port: 80
  targetPort: 8000

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

probes:
  path: /health
  port: 8000
EOF

# Deployment
cat > "$CHART/templates/deployment.yaml" <<'EOF'
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
EOF

# Service
cat > "$CHART/templates/service.yaml" <<'EOF'
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
EOF

echo "Chart built at: $CHART"
helm lint "$CHART"
helm template demo "$CHART" >/dev/null && echo "helm template OK"
