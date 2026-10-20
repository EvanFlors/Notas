# Ejemplo 01 — Estructura de una composite action

## Concepto que demuestra

Anatomía mínima y completa de una **composite action**: `action.yml` con `inputs`, `outputs`, `runs.using: composite` y `steps:` que combinan `run:` + `uses:`.

## Contexto

Las composite son el primer paso: sin runtime propio, sin lenguaje nuevo, sin `node_modules`. Si lo que quieres hacer se puede expresar como "una secuencia de pasos de shell", esta es la mejor opción (ergonomía, transparencia, cero dependencias).

## Objetivo

Al terminar:
- Reconoces las claves obligatorias (`name`, `description`, `runs.using`, `runs.steps`).
- Entiendes cómo se declaran `inputs` con `required`/`default`.
- Entiendes cómo se exponen `outputs` propagando desde `steps.<id>.outputs.<n>`.
- Verificas la validez del `action.yml` con un parser YAML + un smoke local que simula el runner.

## Prerrequisitos

- Bash, `python3` (para parsear YAML en el smoke).
- Opcional: Node o Docker (no se usan aquí).

## Ejecución

Usa `files/run-example.sh` o reproduce manualmente:

```bash
bash files/run-example.sh /tmp/composite-demo
```

El script crea `/tmp/composite-demo/greet-action/action.yml` con esta forma:

```yaml
name: "Greet (composite)"
description: "Prints a greeting; emits it as an output"
inputs:
  who:
    description: "Target name"
    required: false
    default: "world"
  shout:
    description: "If true, uppercase the greeting"
    required: false
    default: "false"
outputs:
  greeting:
    description: "The emitted greeting"
    value: ${{ steps.emit.outputs.greeting }}
runs:
  using: composite
  steps:
    - id: emit
      shell: bash
      env:
        WHO: ${{ inputs.who }}
        SHOUT: ${{ inputs.shout }}
      run: |
        g="Hello, ${WHO}!"
        if [ "$SHOUT" = "true" ]; then
          g="$(echo "$g" | tr '[:lower:]' '[:upper:]')"
        fi
        echo "$g"
        echo "greeting=$g" >> "$GITHUB_OUTPUT"
```

Y luego **simula al runner** así:

```bash
# El runner expande cada step. Para una composite, ese expand es equivalente a:
cd /tmp/composite-demo/greet-action
export GITHUB_OUTPUT=/tmp/composite-demo/github_output
: > "$GITHUB_OUTPUT"
export WHO="mundo"
export SHOUT="true"
bash -c '
  g="Hello, ${WHO}!"
  if [ "$SHOUT" = "true" ]; then
    g="$(echo "$g" | tr '"'"'[:lower:]'"'"' '"'"'[:upper:]'"'"')"
  fi
  echo "$g"
  echo "greeting=$g" >> "$GITHUB_OUTPUT"
'
cat "$GITHUB_OUTPUT"
# greeting=HELLO, MUNDO!
```

Observaciones:
- La action **no se ejecuta por sí sola**; el runner expande sus steps.
- El output se emite al archivo `$GITHUB_OUTPUT`.
- El `env:` del step evita *script injection*: aunque `inputs.who` viniera de datos no confiables, aquí entra como variable de entorno, no como texto interpolado en el script.

## Resultado esperado

- `action.yml` válido (parsea).
- Simular el step produce `greeting=HELLO, MUNDO!` en `$GITHUB_OUTPUT`.

## Interpretación

- `runs.using: composite` → sin runtime; el runner expande.
- `outputs.<name>.value` referencia un `steps.<id>.outputs.<n>` — el `<id>` tiene que coincidir con el `id:` del step que escribió.
- Usar `env:` para pasar inputs al shell es **mejor práctica**: fíjate que **no** hay `${{ inputs.who }}` dentro del `run:`; solo en el `env:`. Esto es `gha-13` adelantado.

## Errores frecuentes

- **Falta `shell:` en el `run:`** → la composite falla con `shell is required`. En composite siempre va explícito.
- **`using: Composite`** (mayúscula) → GHA no reconoce. Debe ser `composite` en minúscula.
- **Olvidar `id:`** y aun así referenciar `steps.<id>.outputs.<n>` en `outputs.<out>.value` → el valor sale vacío.
- **Pensar que puedes `require('@actions/core')`** aquí: no, no corres Node.

## Limpieza

```bash
rm -rf /tmp/composite-demo
```
