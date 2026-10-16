{{/*
TODO: define cuatro bloques:
  - platform.name
  - platform.fullname
  - platform.labels
  - platform.selectorLabels

Pistas:
  - Usa trunc 63 | trimSuffix "-" para respetar el limite DNS.
  - include en el consumer, define aqui.
  - .Values.owner se consume desde el chart application (demo-app).
*/}}

{{- define "platform.name" -}}
TODO
{{- end -}}

{{- define "platform.fullname" -}}
TODO
{{- end -}}

{{- define "platform.labels" -}}
# TODO: at least these labels must be emitted:
#   app.kubernetes.io/name
#   app.kubernetes.io/instance
#   app.kubernetes.io/managed-by
#   helm.sh/chart
#   platform.example.com/owner
TODO: labels
{{- end -}}

{{- define "platform.selectorLabels" -}}
# TODO: app.kubernetes.io/name + app.kubernetes.io/instance
TODO: selector labels
{{- end -}}
