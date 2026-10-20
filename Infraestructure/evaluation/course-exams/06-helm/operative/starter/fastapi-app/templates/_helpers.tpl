{{/*
Helpers del chart fastapi-app. Starter deliberadamente INCOMPLETO:
el estudiante debe añadir `fastapi-app.selectorLabels`, `fastapi-app.labels`
y usar `include` (no `template`) en los recursos.
*/}}

{{- define "fastapi-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "fastapi-app.fullname" -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
TODO (estudiante):
  - define "fastapi-app.selectorLabels"  -> app.kubernetes.io/name + instance
  - define "fastapi-app.labels"          -> selectorLabels + managed-by + version
  - define "fastapi-app.image"           -> repository:tag con `default .Chart.AppVersion`
*/}}
