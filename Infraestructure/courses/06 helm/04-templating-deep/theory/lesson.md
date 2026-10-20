# Lección — Templating en Helm sin "yaml hell"

> Objetivo: entender Go templates aplicados a YAML con el detalle suficiente para escribir charts idiomáticos y depurar los errores inevitables cuando el render falla.

---

## 1. ¿Por qué templating sobre YAML y no otra cosa?

Helm eligió **Go templates** como motor por una razón pragmática: ya estaba en el runtime (Kubernetes usa Go) y es un lenguaje de templating textual, agnóstico del formato de salida. Esa elección arrastra una consecuencia incómoda: **Helm no sabe YAML**. Para Helm, un template renderiza *texto*; que ese texto resulte ser YAML válido depende de que el autor del chart maneje bien la indentación y los tipos.

Alternativas como **Kustomize** (overlays sobre YAML real) o **ytt** (templating YAML-aware) resuelven el problema de raíz, pero Helm ganó por adopción. Entenderlo no es optar por él sin crítica; es asumir sus tradeoffs y neutralizar sus trampas.

Dos reglas de supervivencia desde el primer día:

1. **Siempre** renderiza localmente con `helm template --debug` antes de instalar.
2. **Siempre** usa `_helpers.tpl` para labels y nombres: la duplicación es la fuente #1 de inconsistencia entre `Deployment`, `Service` y selectores.

---

## 2. Sintaxis Go templates aplicada a Helm

Toda sintaxis Go template vive entre `{{ }}`. Lo que esté fuera se emite tal cual.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-app
  labels:
    chart: {{ .Chart.Name }}
```

**Control de whitespace con `-`.** Un guión pegado al delimitador consume el whitespace adyacente (incluyendo newlines).

```yaml
{{- if .Values.enabled }}       # consume el newline anterior
enabled: true
{{- end }}                       # consume el newline anterior al end
```

Sin los guiones, cada `{{ ... }}` dejaría líneas en blanco en el output. Con el tiempo se vuelve automático.

**Pipelines `|`.** Como en bash, el output de la izquierda entra como *último* argumento de la derecha.

```yaml
name: {{ .Values.name | default "myapp" | quote }}
# equivalente a: quote (default "myapp" .Values.name)
```

**Comentarios.** `{{/* ... */}}` NO sale al render. `# ...` sí (es un comentario YAML, no de template).

---

## 3. Objetos built-in: la API disponible en todo template

| Objeto           | Qué contiene                                                                 |
|------------------|-------------------------------------------------------------------------------|
| `.Values`        | Valores efectivos (merge de `values.yaml` + `-f` + `--set`).                 |
| `.Chart`         | Metadata del `Chart.yaml` (`.Chart.Name`, `.Chart.Version`, `.Chart.AppVersion`). |
| `.Release`       | Datos del release (`.Release.Name`, `.Release.Namespace`, `.Release.IsInstall`, `.Release.IsUpgrade`, `.Release.Revision`). |
| `.Files`         | Acceso a archivos en el chart (`.Files.Get`, `.Files.Glob`, `.Files.AsConfig`). |
| `.Capabilities`  | Features del cluster target (`.Capabilities.KubeVersion.Minor`, `.Capabilities.APIVersions.Has`). |
| `.Template`      | Metadata del template actual (`.Template.Name`, `.Template.BasePath`).       |

**`.Capabilities`** es la vía correcta para condicionales por versión de K8s: `{{ if .Capabilities.APIVersions.Has "policy/v1/PodDisruptionBudget" }}`.

---

## 4. Funciones built-in y Sprig: las 7 que usarás a diario

Helm expone todas las funciones de la [librería Sprig](https://masterminds.github.io/sprig/) además de las built-in de Go templates. En la práctica, el 90% de un chart usa estas:

### `default`

```yaml
replicas: {{ .Values.replicas | default 1 }}
```

Si `.Values.replicas` es falsy (ausente, nil, 0, "", lista vacía), usa el default. **Cuidado:** `0` es falsy; para `replicas: 0` legítimo necesitas lógica explícita.

### `required`

```yaml
image: {{ required ".Values.image.repository es obligatorio" .Values.image.repository }}
```

Si el valor es nil o vacío, aborta el render con el mensaje dado. Es el mecanismo correcto para marcar un value como obligatorio en el contrato del chart.

### `quote`

```yaml
labels:
  version: {{ .Chart.AppVersion | quote }}
```

Envuelve en comillas dobles. Imprescindible cuando el valor podría parecer numérico ("1.2") y YAML lo interpretaría como float.

### `toYaml`

```yaml
resources:
  {{- toYaml .Values.resources | nindent 4 }}
```

Serializa un valor Go (mapa/lista) a YAML. Casi siempre va seguido de `nindent`.

### `nindent` vs `indent`

- `indent 4` → añade 4 espacios al principio de cada línea.
- `nindent 4` → igual + emite un `\n` al inicio.

Si el bloque que sigue va a continuación de `:` en la misma línea, necesitas `nindent` para que el YAML sea válido:

```yaml
resources:
  {{- toYaml .Values.resources | nindent 4 }}
```

Con `indent` quedaría pegado:

```yaml
resources:    requests:
      cpu: 100m
```

### `b64enc` y `sha256sum`

```yaml
# Secret
data:
  token: {{ .Values.token | b64enc | quote }}

# ConfigMap-driven rolling restart
annotations:
  checksum/config: {{ include "mychart.configmap" . | sha256sum }}
```

El patrón `checksum/config` es idiomático: cuando el ConfigMap cambia, el checksum cambia, el Deployment se vuelve a aplicar y los pods rotan.

### `include` y `tpl`

Ver §6 (`include`) y §9 (`tpl`).

---

## 5. Control de flujo: `if`, `with`, `range`

### `if / else if / else`

```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
{{- else }}
# sin ingress
{{- end }}
```

### `with`: cambia el scope

```yaml
{{- with .Values.image }}
image: "{{ .repository }}:{{ .tag }}"   # . == .Values.image
{{- end }}
```

Dentro del bloque, `.` apunta a `.Values.image`. **El root deja de ser accesible por `.`**; para alcanzarlo usa `$`:

```yaml
{{- with .Values.image }}
image: "{{ .repository }}:{{ .tag }}"
labels:
  release: {{ $.Release.Name }}         # $ == root
{{- end }}
```

Olvidar esto es una fuente clásica de bugs: dentro de `with`, `.Release.Name` falla con "nil pointer evaluating interface {}.Release".

### `range` sobre listas y mapas

```yaml
# lista
env:
{{- range .Values.env }}
  - name: {{ .name }}
    value: {{ .value | quote }}
{{- end }}

# mapa (clave, valor)
annotations:
{{- range $k, $v := .Values.annotations }}
  {{ $k }}: {{ $v | quote }}
{{- end }}
```

Dentro de `range`, `.` cambia al elemento actual. Igual que con `with`, `$` sigue siendo el root.

---

## 6. Named templates: `define`, `template`, `include`

Un **named template** es un template nombrado reutilizable, normalmente en `_helpers.tpl` (el prefijo `_` lo excluye del render directo).

```gotemplate
{{/* _helpers.tpl */}}
{{- define "myapp.labels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

Hay **dos formas** de usarlo. Y aquí está la lección crítica de este módulo:

### `template` (acción)

```yaml
metadata:
  labels:
    {{- template "myapp.labels" . }}
```

- Emite el output directamente en el stream del render.
- **No se puede pipear** — es una acción, no una función. `{{ template "x" . | nindent 4 }}` es un error de parse.
- Como consecuencia: tienes que confiar en que el `define` ya produce la indentación correcta, lo cual es frágil.

### `include` (función)

```yaml
metadata:
  labels:
    {{- include "myapp.labels" . | nindent 4 }}
```

- **Retorna** el output como string.
- Se puede componer con pipelines: `nindent`, `trim`, `b64enc`, `sha256sum`, lo que sea.
- Es la forma **preferida** en Helm moderno. El `_helpers.tpl` queda limpio (sin indentación hardcoded) y el caller decide cuánto indentar según el contexto.

**Regla práctica:** si estás escribiendo `_helpers.tpl` hoy, usa `include` en todos los call sites. `template` solo aparece en charts legacy.

---

## 7. `_helpers.tpl`: convenciones estándar

Los charts generados por `helm create` incluyen estos cinco helpers. Son el **vocabulario común** de Helm; respétalo aunque te parezca verboso.

```gotemplate
{{/*
Expand the name of the chart.
*/}}
{{- define "myapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncate at 63 chars (DNS label limit) and strip trailing hyphen.
*/}}
{{- define "myapp.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart identifier used in app.kubernetes.io/version.
*/}}
{{- define "myapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels (go on EVERY resource).
*/}}
{{- define "myapp.labels" -}}
helm.sh/chart: {{ include "myapp.chart" . }}
{{ include "myapp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels (subset of common; MUST be immutable).
*/}}
{{- define "myapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "myapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name: either the overridden name, the fullname, or "default".
*/}}
{{- define "myapp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "myapp.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
```

**Por qué `selectorLabels` es un subset:** los selectores en Kubernetes son **inmutables** después del `apply`. Si pusieras `app.kubernetes.io/version` en el selector, cada bump de versión del chart rompería el `Deployment` (K8s rechazaría el apply). La solución canónica: labels completos van en `metadata.labels`, un subset estable va en `spec.selector.matchLabels` y en el `template.metadata.labels` del pod.

---

## 8. Errores comunes al escribir templates

### 8.1 Indentación: `indent` cuando toca `nindent`

```yaml
# MAL
resources:
  {{- toYaml .Values.resources | indent 4 }}
# resources:    requests: ...  ← pegado, YAML inválido

# BIEN
resources:
  {{- toYaml .Values.resources | nindent 4 }}
```

Regla mental: si el pipeline sigue a `:` en la misma línea, `nindent`. Si está en una línea nueva ya con sangría, `indent`.

### 8.2 `null` vs ausencia

```yaml
image: {{ .Values.image.tag }}     # si tag es nil → renderiza "<no value>" o vacío
```

Soluciones:

```yaml
image: {{ .Values.image.tag | default "latest" }}         # fallback
image: {{ required "image.tag required" .Values.image.tag }}  # abortar
```

### 8.3 Listas vs mapas: `range` con tipo incorrecto

```yaml
# values.yaml tiene env como mapa, pero template asume lista
env:
{{- range .Values.env }}
  - name: {{ .name }}
{{- end }}
```

Si `.Values.env` es `{A: 1, B: 2}` en vez de `[{name: A, value: 1}]`, el render produce basura. Documentar el shape en `values.yaml` + validar con `values.schema.json` (ver `helm-05`).

### 8.4 Scoping dentro de `with`

```yaml
{{- with .Values.image }}
image: {{ .repository }}
labels:
  release: {{ .Release.Name }}   # BUG: . es .Values.image, no root
{{- end }}
```

Corrección: `{{ $.Release.Name }}`.

### 8.5 Comillas en strings numéricos

```yaml
appVersion: {{ .Chart.AppVersion }}       # "1.21" se vuelve 1.21 (float)
appVersion: {{ .Chart.AppVersion | quote }}  # "1.21" string
```

Para labels de K8s esto importa: labels deben ser strings.

---

## 9. `tpl`: strings-con-template-dentro

A veces el consumidor del chart quiere poner `{{ .Release.Name }}` dentro de un `values.yaml`. El render *normal* no evalúa eso (los values no se re-renderizan). La función `tpl` lo fuerza:

```yaml
# values.yaml
podAnnotations:
  app.example.com/owner: "team-{{ .Release.Namespace }}"

# template
metadata:
  annotations:
    {{- range $k, $v := .Values.podAnnotations }}
    {{ $k }}: {{ tpl $v $ | quote }}
    {{- end }}
```

`tpl $v $` toma el string `$v` como template y lo evalúa con contexto `$` (root). Útil para annotations/labels dinámicas por entorno sin ramificar en el template.

---

## 10. `helm template --debug`: render local sin cluster

El flujo de trabajo correcto para desarrollar un chart es:

```bash
# render completo en stdout
helm template my-release ./mi-chart

# con values override
helm template my-release ./mi-chart -f values-dev.yaml --set image.tag=abc123

# con debug: muestra el error de template con línea y columna
helm template my-release ./mi-chart --debug

# simular que el cluster tiene cierta versión
helm template my-release ./mi-chart --kube-version 1.29.0
```

El flag `--debug` convierte un `Error: template: mi-chart/templates/deployment.yaml:12:17: executing "mi-chart/templates/deployment.yaml" at <.Values.replicas>: nil pointer evaluating interface {}.replicas` en pistas accionables.

**No necesitas un cluster** para iterar en templates. `helm template` es puro string transformation.

---

## 11. `helm lint`: qué cubre y qué no

```bash
helm lint ./mi-chart
```

Cubre:

- `Chart.yaml` tiene campos obligatorios (`apiVersion: v2`, `name`, `version`).
- `values.yaml` es YAML válido.
- Templates parsean sin error.
- Icon/sources/urls bien formadas.
- Nombres de archivo correctos (`templates/`, `_helpers.tpl`, etc.).

**No cubre:**

- Que el YAML renderizado sea semánticamente válido para Kubernetes (eso lo haría `kubeval`, `kubeconform`, o un `kubectl --dry-run=server`).
- Que `.Values.X` referenciado exista en `values.yaml` (una typo pasa el lint).
- Que las labels del selector coincidan con las del pod template.

Rutina mínima en pre-commit:

```bash
helm lint ./mi-chart && helm template test ./mi-chart | kubeconform -strict -
```

---

## 12. Checklist de un chart templado "con higiene"

- [ ] `_helpers.tpl` define `name`, `fullname`, `chart`, `labels`, `selectorLabels`, `serviceAccountName`.
- [ ] Todos los recursos emiten `labels: {{- include "<chart>.labels" . | nindent 4 }}`.
- [ ] `spec.selector.matchLabels` usa SOLO `selectorLabels` (subset inmutable).
- [ ] Values obligatorios usan `required "<mensaje>" .Values.x`.
- [ ] Values opcionales usan `.Values.x | default <algo>`.
- [ ] Nombres truncados a 63 chars con `trunc 63 | trimSuffix "-"`.
- [ ] Strings que podrían parecer números van con `| quote`.
- [ ] Bloques inyectados con `toYaml` van con `nindent`, no `indent`.
- [ ] Nunca uses `template` donde puedas usar `include`.
- [ ] `helm lint` pasa sin warnings.
- [ ] `helm template --debug` renderiza algo que `kubeconform` acepta.

Si estos diez checks pasan, estás por encima de la mediana de charts que vas a encontrar en el mundo real.
