# helm-03 — Anatomía de un chart (lección)

Esta lección se enfoca en la **estructura** de un chart: qué archivo cumple qué
rol, qué es obligatorio, qué es convención, y dónde empiezan los errores de
diseño que después cuestan caro.

---

## 1. Qué es un chart (y qué no)

Un **chart** es un directorio (o un `.tgz`) con una forma convenida: `Chart.yaml`
en la raíz, `values.yaml` al lado, y un `templates/` con manifests Kubernetes
parametrizados en Go templates. Nada más es *obligatorio*; todo lo demás son
convenciones que la comunidad y la CLI de Helm asumen.

Un chart **no** es:

- Una aplicación corriendo (eso es un **release**: una instancia del chart
  aplicada a un cluster/namespace con un nombre único y valores efectivos).
- Un sustituto de un operador: si tu software requiere lógica de reconciliación
  activa (reparar, promover, escalar según métricas), un chart es insuficiente;
  usa (o escribe) un operador y, si acaso, empaqueta el operador *en* un chart.
- Un contenedor de código: no genera binarios ni compila; solo renderiza YAML.

Mental model útil: *un chart es una función pura* `(values) -> manifests[]`.
Entra JSON/YAML, salen manifests. Las impurezas (hooks, orden de instalación)
son matizaciones de este modelo que se verán en `helm-07`.

---

## 2. Scaffold de `helm create <name>`

`helm create fastapi-app` genera:

```
fastapi-app/
├── .helmignore
├── Chart.yaml
├── values.yaml
├── charts/                     ← subcharts (vacío)
└── templates/
    ├── NOTES.txt
    ├── _helpers.tpl
    ├── deployment.yaml
    ├── hpa.yaml
    ├── ingress.yaml
    ├── service.yaml
    ├── serviceaccount.yaml
    └── tests/
        └── test-connection.yaml
```

Este scaffold está pensado para **demostrar** y **no** para ser el chart final de
tu app. Trae muchos "knobs" (ingress con TLS parametrizado, HPA condicional,
ServiceAccount opcional, imagePullSecrets, podSecurityContext, tolerations,
nodeSelector, affinity) que inflan `values.yaml` y hacen el chart difícil de
leer. **Es válido borrar el 80%** y dejar solo lo que tu app realmente ofrece
como *contrato*.

Regla práctica: cada knob que dejas en `values.yaml` lo tienes que *soportar*
(probar, documentar, no romper al cambiar). Menos knobs = menos superficie de
error.

---

## 3. `Chart.yaml` v2: metadatos y contrato de identidad

Campos **obligatorios** (Helm 3, API v2):

| Campo | Semántica |
|-------|-----------|
| `apiVersion: v2` | Siempre `v2` en Helm 3. `v1` es Helm 2 (ya no debería usarse). |
| `name` | Nombre del chart. Debe coincidir con el directorio. Minúsculas, `-`, `.`. |
| `version` | **SemVer** del *chart* (no de la app). Debe cambiar en cada release. |
| `appVersion` | Versión de la *aplicación* empaquetada (free-form; convencionalmente SemVer). |
| `type` | `application` (por default) o `library` (ver §9). |

Opcionales relevantes: `description`, `icon`, `home`, `sources[]`, `keywords[]`,
`maintainers[]`, `kubeVersion` (restricción semver sobre el cluster), `dependencies[]`.

Diferencia crítica — **`version` vs `appVersion`**:

- `version` cambia cuando *el chart* cambia (templates, defaults, deps). Un
  arreglo en el template es un bump de `version` aunque no cambie la app.
- `appVersion` cambia cuando cambia *la imagen* / artefacto que se despliega.

Un chart puede subir `version` sin subir `appVersion` (p. ej. refactor de
templates) y viceversa (nueva imagen, mismo chart).

---

## 4. `values.yaml`: el contrato de inputs

`values.yaml` **no** es "configuración interna" — es la **API pública** del
chart. Si publicas el chart (o lo consumes desde Argo CD / Flux / pipelines),
cualquier cambio a `values.yaml` es un cambio de interfaz y aplica reglas de
compatibilidad hacia atrás como cualquier API.

Buenas prácticas:

1. **Documenta cada clave con comentarios YAML** sobre la línea.
2. **Agrupa por responsabilidad**: `image`, `service`, `ingress`, `resources`,
   `probes`, `env`.
3. **Defaults sanos y seguros**: nunca defaults que requieran estar en un
   cluster privilegiado, nunca secrets por default.
4. **Nombres estables**: renombrar una clave es un breaking change; evítalo o
   súbelo a `version` major.
5. **No pongas lo que no debe ser configurable**: si solo tu equipo lo usa y
   solo con un valor, hard-codéalo en el template.

Ejemplo (fragmento):

```yaml
# values.yaml — contrato público del chart
image:
  repository: ghcr.io/acme/fastapi-app
  tag: ""              # default: usa appVersion si está vacío
  pullPolicy: IfNotPresent

replicaCount: 2

service:
  type: ClusterIP
  port: 80
  targetPort: 8000

resources:
  requests: { cpu: 100m, memory: 128Mi }
  limits:   { cpu: 500m, memory: 512Mi }
```

---

## 5. `templates/`: convenciones de archivos

El directorio `templates/` contiene cualquier archivo `.yaml` / `.tpl` que
produzca YAML válido después del render. Nombres convencionales:

| Archivo | Para qué |
|---------|----------|
| `deployment.yaml` | Workload principal (Deployment / StatefulSet / Job). |
| `service.yaml` | Service que expone el workload. |
| `ingress.yaml` | Ingress opcional (típicamente condicional sobre `.Values.ingress.enabled`). |
| `serviceaccount.yaml` | SA dedicada (recomendado para RBAC acotado). |
| `configmap.yaml` / `secret.yaml` | Datos no sensibles / sensibles. |
| `_helpers.tpl` | Named templates reutilizables (no se renderiza como manifest). |
| `NOTES.txt` | Mensaje mostrado tras `install`/`upgrade`. Soporta templating. |
| `tests/*.yaml` | Jobs/Pods ejecutados por `helm test` (anotados `helm.sh/hook: test`). |

Convenciones adicionales:

- Archivos que empiezan con `_` **no** se renderizan (sirven solo como librería
  via `define`/`include`).
- Un archivo que renderiza a documento vacío (solo whitespace o `---`) se
  descarta — útil para generación condicional con `{{- if .Values.foo }}...{{- end }}`.
- El orden de instalación lo decide Helm (hay un orden canónico interno por
  Kind), no el orden alfabético de archivos.

---

## 6. `_helpers.tpl`: nombres estables

El convenio es definir, como mínimo:

- `<chart>.name` — nombre del chart (puede truncarse por limit de 63 chars de K8s).
- `<chart>.fullname` — nombre completo (`<release>-<chart>`), 63 chars max.
- `<chart>.chart` — `<chart>-<version>` para labels.
- `<chart>.labels` — set de labels estándar (`app.kubernetes.io/name`, `instance`,
  `version`, `managed-by`).
- `<chart>.selectorLabels` — subset estable usado por selectors (NO debe incluir
  `version`, porque cambiar `version` haría al selector no match al Deployment viejo).
- `<chart>.serviceAccountName` — nombre efectivo de la SA.

El scaffold de `helm create` ya trae estos helpers correctos — es una de las
pocas cosas que **vale la pena conservar** sin cambios.

---

## 7. `NOTES.txt`: UX post-install

Se renderiza y se imprime al final de `install`/`upgrade`. Un `NOTES.txt` útil
le dice al usuario cómo *verificar* que el release funciona:

```
Thanks for installing {{ .Chart.Name }} release "{{ .Release.Name }}".

Expose the service locally:
  kubectl -n {{ .Release.Namespace }} port-forward svc/{{ include "fastapi-app.fullname" . }} 8080:{{ .Values.service.port }}

Then open http://localhost:8080/health
```

Antipatrón común: `NOTES.txt` llenos de ASCII art o copyright. Mantenlo
operativo.

---

## 8. `.helmignore`

Define qué archivos **no** se empaquetan al correr `helm package`. Funciona como
`.gitignore` (patrones glob, un patrón por línea, `#` comentarios).

Por default ignora `.git`, `*.swp`, `*.tmp`, `OWNERS`, etc. Añade tu propio
ruido: `*.bak`, `.vscode/`, `.idea/`, archivos de dev local.

Importante en flujos CI: si tu chart vive en un repo con binarios/snapshots que
se bajan al build, **ignóralos explícitamente** o acabarás publicando un `.tgz`
de 50 MB en el OCI registry.

---

## 9. `type: application` vs `type: library`

- **`application`** (default): se instala en un cluster, produce manifests.
- **`library`**: *no* se instala; solo exporta helpers (`define`) para que otros
  charts los importen vía `dependencies:` + `include`. Se verá en `helm-10`.
  Mencionado aquí para que el campo `type` tenga sentido completo.

Si pones un `define` útil en un chart `application` y lo necesitas en otros
tres charts internos, probablemente ya quieres un library chart. Pero no te
adelantes: duplica una vez, extrae a library la segunda vez que lo necesites.

---

## 10. `values.schema.json`: endurecer el contrato

`values.yaml` documenta el contrato, pero no lo *valida*. `values.schema.json`
sí: es un **JSON Schema** draft-07 que Helm aplica automáticamente antes de
renderizar. Si los values efectivos no cumplen el schema, `helm install` /
`upgrade` / `template --validate` falla con un error legible, *antes* de generar
manifests inválidos que confundirían al API server.

Ejemplo mínimo:

```json
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["image", "service"],
  "properties": {
    "replicaCount": { "type": "integer", "minimum": 1, "maximum": 50 },
    "image": {
      "type": "object",
      "required": ["repository"],
      "properties": {
        "repository": { "type": "string", "minLength": 1 },
        "tag":        { "type": "string" },
        "pullPolicy": { "type": "string", "enum": ["Always", "IfNotPresent", "Never"] }
      },
      "additionalProperties": false
    },
    "service": {
      "type": "object",
      "required": ["port"],
      "properties": {
        "type": { "type": "string", "enum": ["ClusterIP", "NodePort", "LoadBalancer"] },
        "port": { "type": "integer", "minimum": 1, "maximum": 65535 }
      },
      "additionalProperties": false
    }
  }
}
```

Beneficios:

- Falla temprano, con mensaje claro.
- Documenta tipos y rangos (sirve como spec machine-readable).
- Habilita autocompletado/validación en IDEs vía JSON Schema.

Gotchas:

- Draft-07 (Helm aún no soporta drafts posteriores en todas las versiones).
- `additionalProperties: false` es estricto — útil contra typos, pero puede
  romper si los usuarios añaden claves "privadas"; úsalo con criterio por
  sección.
- Mantener schema y `values.yaml` sincronizados es trabajo manual; en `helm-05`
  veremos patrones para no duplicar.

---

## 11. `files/` y `crds/`: dos directorios especiales

### `files/` (solo-lectura, accesible desde templates)

Cualquier archivo bajo `files/` **no** se renderiza, pero se puede leer con
`.Files.Get`, `.Files.Glob`, `.Files.AsConfig`, `.Files.AsSecrets`.

Casos típicos:

- `files/nginx.conf` → se inyecta en un ConfigMap:
  ```yaml
  data:
    nginx.conf: |-
  {{ .Files.Get "files/nginx.conf" | indent 4 }}
  ```
- `files/dashboards/*.json` → ConfigMap con dashboards de Grafana.
- Scripts, assets, cert bundles de pruebas (nunca secrets reales).

Esto evita tener que *escribir YAML dentro de YAML* (`|-` + indentación manual)
cuando el contenido original es largo o viene de otro formato.

### `crds/` (CustomResourceDefinitions)

Archivos YAML colocados aquí reciben trato especial:

- Se instalan **antes** del render de `templates/`, en `helm install`.
- **No se actualizan** en `helm upgrade`.
- **No se eliminan** en `helm uninstall`.

El motivo es de seguridad y multi-tenant: una CRD puede ser *compartida* por
muchos charts/releases (el ejemplo clásico es `cert-manager`: una sola CRD de
`Certificate` usada por N releases que crean esos recursos). Si Helm permitiera
upgrade automático, un `helm upgrade` del chart A podría romper los recursos
custom del chart B.

Esto fuerza una **estrategia explícita** para evolucionar CRDs:

| Estrategia | Cuándo |
|------------|--------|
| Mantener CRDs en `crds/` y gestionar upgrades manualmente (`kubectl apply`). | Equipos pequeños, pocas CRDs. |
| **Chart separado solo de CRDs** (`<app>-crds` chart), versionado independiente. | Patrón recomendado por `cert-manager`, `prometheus-operator`. Permite actualizar CRDs como artefacto propio. |
| Gestionar CRDs *fuera* de Helm (operator + Argo CD / Flux). | CRDs con lifecycle rico (conversión de versiones). |

Preguntas de evaluación en §12 cubrirán esto.

---

## 12. Preguntas de evaluación

Responde sin consultar docs:

1. ¿Qué diferencia hay entre `Chart.yaml.version` y `Chart.yaml.appVersion`?
   Da un ejemplo donde cambie uno sin el otro.
2. ¿Por qué `helm create` genera un chart "demo" y qué criterios aplicarías
   para decidir qué knobs eliminar en tu versión productiva?
3. Un archivo `templates/_sidecar.tpl` — ¿se renderiza como manifest?
   ¿Por qué?
4. Diseña un `values.schema.json` que acepte `replicaCount` solo entre 1 y 10,
   y que haga `service.type` requerido y restringido a `ClusterIP` o
   `LoadBalancer`.
5. **CRDs**: tu chart `app-v1.4.0` instala una CRD `Widget` v1alpha1 en `crds/`.
   El equipo B tiene `app-v1.3.0` instalado y usa recursos `Widget` v1alpha1
   también. Haces `helm upgrade app` a `v1.5.0` que trae CRD `Widget` v1 (ya no
   alpha). ¿Qué pasa? ¿Qué estrategia aplicas de aquí en adelante?
6. ¿En qué caso usar `files/` + `.Files.Get` es mejor que meter el contenido
   directamente en el template con heredoc?
7. ¿Qué pasa si subes la `version` del chart pero no la `appVersion`? ¿Y al revés?
8. ¿Por qué `<chart>.selectorLabels` **no** debe incluir la label `version`?

---

### Referencias

Ver `../resources/links.md`.
