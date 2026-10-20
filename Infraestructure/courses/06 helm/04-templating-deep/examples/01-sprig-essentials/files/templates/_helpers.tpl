{{/*
Render the ConfigMap body (used both for the ConfigMap resource and for its
checksum annotation on the Deployment).
*/}}
{{- define "sprig-essentials.configmap" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-config
data:
  greeting: {{ .Values.config.greeting | quote }}
  loglevel: {{ .Values.config.loglevel | default "info" | quote }}
{{- end }}
