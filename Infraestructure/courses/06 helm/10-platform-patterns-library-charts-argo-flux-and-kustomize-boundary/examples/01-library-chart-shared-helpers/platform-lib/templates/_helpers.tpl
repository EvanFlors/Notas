{{/*
Platform library helpers. Importable from any chart that lists platform-lib
as a dependency. No renderable manifests must live in this file — only
`define` blocks.
*/}}

{{- define "platform.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "platform.fullname" -}}
{{- $name := include "platform.name" . -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "platform.labels" -}}
app.kubernetes.io/name: {{ include "platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | default .Chart.Version | quote }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
platform.example.com/owner: {{ .Values.owner | default "unknown" | quote }}
{{- end -}}

{{- define "platform.selectorLabels" -}}
app.kubernetes.io/name: {{ include "platform.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "platform.probes" -}}
livenessProbe:
  httpGet:
    path: {{ .Values.probes.path | default "/healthz" }}
    port: {{ .Values.probes.port | default "http" }}
  initialDelaySeconds: 10
  periodSeconds: 10
readinessProbe:
  httpGet:
    path: {{ .Values.probes.path | default "/healthz" }}
    port: {{ .Values.probes.port | default "http" }}
  initialDelaySeconds: 5
  periodSeconds: 5
{{- end -}}
