{{/* Standard labels, intentionally stable — a change here should break snapshots. */}}
{{- define "demo-app.labels" -}}
app.kubernetes.io/name: demo-app
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
