# Ejemplo 03 — `values.schema.json`: validar el contrato

## Concepto que demuestra

Cómo añadir un **JSON Schema** al chart para que Helm **valide** `values`
automáticamente antes de renderizar: tipos, `required`, `enum`, rangos.

## Contexto

`values.yaml` documenta el contrato por convención. Un typo (`replicas:` en vez
de `replicaCount:`), un valor fuera de rango (`replicaCount: 5000`), o un tipo
incorrecto (`port: "80"` como string) no son detectados por Helm por defecto; el
chart renderiza manifests que luego el API server (o peor, el runtime del Pod)
rechaza. `values.schema.json` cierra ese hueco.

## Objetivo

- Escribir un `values.schema.json` draft-07 que valide el `values.yaml` del
  chart `mini` del ejemplo anterior.
- Observar cómo Helm rechaza inputs inválidos antes de generar manifests.

## Prerrequisitos

- Ejemplo `02-minimal-chart-from-scratch` reproducido (`/tmp/mini-chart`
  existente) **o** chart equivalente.

## Ejecución

```bash
# Reutilizamos /tmp/mini-chart del ejemplo 02 (regenera si no existe).
cd /tmp/mini-chart

# 1. Añadir el schema
cat > values.schema.json <<'EOF'
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "title": "mini chart values",
  "type": "object",
  "required": ["image", "service"],
  "properties": {
    "replicaCount": {
      "type": "integer",
      "minimum": 1,
      "maximum": 50,
      "description": "Pod replicas; keep sane."
    },
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
  },
  "additionalProperties": false
}
EOF

# 2. Caso feliz
helm template demo . --values values.yaml > /dev/null && echo "render OK"

# 3. Casos negativos (debe fallar cada uno):

# 3a. Tipo incorrecto: port como string
helm template demo . --set service.port=\"80\" 2>&1 | tail -5

# 3b. Fuera de rango
helm template demo . --set replicaCount=9999 2>&1 | tail -5

# 3c. Enum violado
helm template demo . --set image.pullPolicy=Yolo 2>&1 | tail -5

# 3d. Typo (gracias a additionalProperties: false)
helm template demo . --set replicas=3 2>&1 | tail -5
```

## Resultado esperado

- 3a: `service.port: Invalid type. Expected: integer, given: string`.
- 3b: `replicaCount: Must be less than or equal to 50`.
- 3c: `image.pullPolicy: image.pullPolicy must be one of the following: "Always", "IfNotPresent", "Never"`.
- 3d: `(root): Additional property replicas is not allowed`.

Cada error se produce **antes** de que Helm imprima un solo byte de YAML
renderizado. Esto es el valor: fallo temprano y legible.

## Interpretación

- JSON Schema sobre `values` convierte la "API" del chart de un contrato en
  prosa a un contrato ejecutable.
- `additionalProperties: false` convierte typos silenciosos en errores
  explícitos. Es estricto; aplícalo por sección cuando no quieres bloquear
  extensiones laterales.
- Los mensajes de error incluyen el *path* del valor inválido — muy útil cuando
  el chart lo consume Argo CD o un pipeline y el error aparece en logs.

## Errores frecuentes

- Usar draft-2020-12 u otros drafts recientes: Helm valida con draft-07.
- Olvidar `"type": "object"` en el root: el schema no aplica a nada.
- Marcar `additionalProperties: false` en el root cuando el usuario necesita
  añadir claves custom (p. ej. `global:` de subcharts). Mejor marcar por sección.

## Limpieza

```bash
rm -rf /tmp/mini-chart
```
