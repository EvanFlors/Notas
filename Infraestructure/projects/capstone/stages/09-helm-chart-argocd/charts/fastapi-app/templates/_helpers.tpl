{{/*
Nombre base del chart. Si fullnameOverride esta definido, lo gana.
Si no, usa .Release.Name + .Chart.Name truncado a 63 caracteres.
*/}}
{{- define "fastapi-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "fastapi-app.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "fastapi-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Labels comunes (recommended labels de Kubernetes).
*/}}
{{- define "fastapi-app.labels" -}}
helm.sh/chart: {{ include "fastapi-app.chart" . }}
{{ include "fastapi-app.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: capstone
{{- end -}}

{{- define "fastapi-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fastapi-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Nombre de la ServiceAccount a usar.
*/}}
{{- define "fastapi-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "fastapi-app.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}
