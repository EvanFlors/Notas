{{/*
Common labels. NOTE: no leading indentation inside the define — the caller
decides via `include ... | nindent N`.
*/}}
{{- define "app.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
ConfigMap body — reused by configmap.yaml AND hashed into the Deployment
annotation. This hash trick is ONLY possible via `include`, because `template`
cannot be piped to `sha256sum`.
*/}}
{{- define "app.configmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-config
data:
  key: {{ .Values.config.key | quote }}
{{- end }}
