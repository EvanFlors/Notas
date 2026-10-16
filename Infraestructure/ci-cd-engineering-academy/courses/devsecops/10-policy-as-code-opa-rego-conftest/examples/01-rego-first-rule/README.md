# Ejemplo 01 — Primera regla Rego sobre un manifest K8s

> Local, sin cluster. Usa `opa eval` sobre un pod YAML convertido a JSON.
> SKIP automático si `opa` no está instalado.

## 1. Qué vas a hacer

- Preparar un pod K8s "malo" (corre como root, usa `:latest`).
- Escribir una regla Rego `deny` que detecte ambas cosas.
- Ejecutar `opa eval` y leer la salida.
- Modificar el pod para que cumpla y verificar que `deny` queda vacío.

## 2. Prerrequisitos

- `opa` (`brew install opa`) — opcional pero recomendado.
- `python3` (para convertir YAML → JSON en el walk-through sin dependencias extra; alternativamente `yq`).

## 3. Fixture (pod malo)

```yaml
# bad-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
spec:
  containers:
    - name: nginx
      image: nginx:latest
      securityContext:
        runAsNonRoot: false
```

Como JSON (lo que OPA recibe realmente):

```json
{
  "apiVersion": "v1",
  "kind": "Pod",
  "metadata": {"name": "web"},
  "spec": {
    "containers": [
      {
        "name": "nginx",
        "image": "nginx:latest",
        "securityContext": {"runAsNonRoot": false}
      }
    ]
  }
}
```

## 4. Regla Rego

```rego
# policy.rego
package k8s.security

import rego.v1

deny contains msg if {
    input.kind == "Pod"
    some c in input.spec.containers
    endswith(c.image, ":latest")
    msg := sprintf("container %q uses forbidden :latest tag", [c.name])
}

deny contains msg if {
    input.kind == "Pod"
    some c in input.spec.containers
    not c.securityContext.runAsNonRoot
    msg := sprintf("container %q runs as root (runAsNonRoot != true)", [c.name])
}
```

Lectura:

- `deny contains msg if { ... }` acumula mensajes.
- `some c in input.spec.containers` itera por cada container.
- `not c.securityContext.runAsNonRoot` es verdadero si vale `false` o si **no existe**. Importante: en Rego, el acceso a un campo inexistente **no** lanza error — simplemente deja la expresión indefinida.

## 5. Walk-through

```bash
# 1. preparar scratch
tmp="/tmp/sec-10-01-rego-first-rule"
mkdir -p "$tmp" && cd "$tmp"

# 2. escribir fixture + policy (ver secciones 3 y 4)

# 3. convertir YAML -> JSON (una línea python, sin deps)
python3 -c "import json,yaml,sys;print(json.dumps(yaml.safe_load(open('bad-pod.yaml'))))" > bad-pod.json
# (si no tienes PyYAML, cópialo del JSON de la sección 3 directamente)

# 4. evaluar
opa eval --format pretty \
  --input bad-pod.json \
  --data policy.rego \
  "data.k8s.security.deny"
```

Salida esperada:

```
[
  "container \"nginx\" runs as root (runAsNonRoot != true)",
  "container \"nginx\" uses forbidden :latest tag"
]
```

## 6. Pod bueno (control)

```yaml
# good-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
spec:
  containers:
    - name: nginx
      image: nginx:1.27.1
      securityContext:
        runAsNonRoot: true
```

```bash
opa eval --format pretty \
  --input good-pod.json \
  --data policy.rego \
  "data.k8s.security.deny"
# []
```

Conjunto vacío → cero violaciones → política satisfecha.

## 7. Lecturas clave

1. Las reglas Rego **se componen** por adición: añadir un tercer chequeo (p. ej. "no `hostNetwork: true`") es escribir otro bloque `deny contains msg if { ... }` sin tocar los anteriores.
2. `opa eval` es la vía **programática**; `opa test` es la vía **ejecutable repetible** (ver ejemplo 03).
3. En producción, nadie corre `opa eval` a mano: lo hace **Conftest** (ejemplo 02) o un **admission controller** (sec-11).

## 8. Preguntas de autocomprobación

1. ¿Qué pasa si el pod **no define** `securityContext` para un container?
2. ¿Cómo cambiarías la regla para permitir `:latest` solo en `namespace == "dev"`?
3. ¿Por qué `not c.securityContext.runAsNonRoot` es más robusto que `c.securityContext.runAsNonRoot == false`?

(Respuestas: 1) la regla `deny` del root se dispara porque el acceso queda indefinido y `not undefined == true`; 2) añadir `input.metadata.namespace != "dev"` como condición extra; 3) porque también atrapa el caso "campo ausente".)

## 9. Limpieza

```bash
rm -rf /tmp/sec-10-01-rego-first-rule
```
