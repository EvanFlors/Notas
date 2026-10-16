# Ejemplo 01 — Sprig essentials: `default`, `required`, `quote`, `toYaml`, `nindent`, `b64enc`, `sha256sum`

## Concepto que demuestra

Las 7 funciones Sprig que vas a usar en el 90% de los charts. Cada una resuelve un problema concreto; conocerlas en conjunto es lo que separa un chart idiomático de uno "yaml-con-interpolación".

## Contexto

Chart mínimo con un `Deployment`, un `Secret` y un `ConfigMap` que ejercita las funciones en situaciones reales:

- `default` → replicas con fallback.
- `required` → image.repository obligatorio.
- `quote` → `appVersion` como string.
- `toYaml` + `nindent` → bloque `resources` inyectado desde values.
- `b64enc` → valor del `Secret`.
- `sha256sum` + `include` → anotación `checksum/config` para rolling restart.

## Prerrequisitos

- Helm 3+ (`helm version`). Testeado con Helm v4.3.1.
- Directorio escribible (usaremos `/tmp/`).

## Ejecución

```bash
# Copia el chart a /tmp y renderiza
EX_DIR="$(dirname "$(realpath "$0" 2>/dev/null || echo .)")/files"
# Si copias este bloque manualmente, apunta EX_DIR a la carpeta files/ de este ejemplo
cp -r files /tmp/sprig-essentials

# Render limpio con todos los defaults
helm template demo /tmp/sprig-essentials

# Render forzando el fallo de 'required': quita image.repository
helm template demo /tmp/sprig-essentials --set image.repository=null
#   Error: execution error at (sprig-essentials/templates/deployment.yaml:17:19):
#     .Values.image.repository es obligatorio

# Observa que el checksum/config cambia si cambias algo en el ConfigMap
helm template demo /tmp/sprig-essentials | grep checksum/config
helm template demo /tmp/sprig-essentials --set config.greeting=hola | grep checksum/config
# los hashes difieren → el Deployment se re-aplicaría y los pods rotarían
```

## Resultado esperado

- Render exitoso con `image.repository=nginx` por default.
- `replicas: 2` por default (`.Values.replicas | default 2`).
- `appVersion` en comillas: `app.kubernetes.io/version: "1.21.0"`.
- Bloque `resources:` bien indentado bajo el container.
- `data.token` en el Secret: `aGVsbG8td29ybGQ=` (base64 de `hello-world`).
- Annotation `checksum/config: <sha256>` presente.

## Interpretación

- **`default`** opera "si falsy" — no solo nil. `0` también es falsy, cuidado al permitir `replicas: 0`.
- **`required`** aborta el *render*, antes de llegar al cluster. Esto es lo que convierte un chart en una API con contrato explícito.
- **`toYaml | nindent 4`** es el idiom para inyectar sub-objetos sin fallar la indentación.
- **`sha256sum` de un `include`** convierte un ConfigMap en el disparador natural de un rollout.

## Errores frecuentes

- `nindent` olvidado → "mapping values are not allowed in this context" al apply.
- `default` con valor "0 válido" → siempre cae al default y nunca aplicas 0.
- `required` con mensaje genérico ("missing") → inútil al depurar; sé específico.

## Limpieza

```bash
rm -rf /tmp/sprig-essentials
```
