# Ejemplo 03 — Suite de tests Rego con `opa test`

> Local, sin red. Enseña el ciclo "regla + fixture positivo + fixture negativo".
> SKIP automático si `opa` no está instalado.

## 1. Qué vas a hacer

- Escribir una regla `deny` para "memory limit obligatorio en containers".
- Escribir 3 tests: happy path, violación obvia, caso borde (sin `resources`).
- Correr `opa test -v` y leer la salida.

## 2. Prerrequisitos

- `opa` (`brew install opa`).

## 3. Policy

```rego
# policy/resources.rego
package k8s.resources

import rego.v1

deny contains msg if {
    input.kind == "Pod"
    some c in input.spec.containers
    not c.resources.limits.memory
    msg := sprintf("container %q has no resources.limits.memory", [c.name])
}
```

## 4. Tests

```rego
# policy/resources_test.rego
package k8s.resources

import rego.v1

# Fixture builders (helpers)
_pod_with(container) := {
    "kind": "Pod",
    "spec": {"containers": [container]}
}

test_deny_when_memory_limit_missing if {
    pod := _pod_with({
        "name": "app",
        "image": "nginx:1.27",
        "resources": {"requests": {"memory": "64Mi"}}
    })
    some msg in deny with input as pod
    contains(msg, "no resources.limits.memory")
}

test_allow_when_memory_limit_present if {
    pod := _pod_with({
        "name": "app",
        "image": "nginx:1.27",
        "resources": {"limits": {"memory": "128Mi"}}
    })
    count(deny) == 0 with input as pod
}

test_deny_when_resources_block_absent if {
    pod := _pod_with({
        "name": "app",
        "image": "nginx:1.27"
    })
    count(deny) == 1 with input as pod
}
```

## 5. Walk-through

```bash
tmp="/tmp/sec-10-03-opa-test"
mkdir -p "$tmp/policy" && cd "$tmp"
# escribe los dos archivos de las secciones 3 y 4

opa test -v policy/
```

Salida esperada:

```
policy/resources_test.rego:
data.k8s.resources.test_deny_when_memory_limit_missing: PASS (xxx µs)
data.k8s.resources.test_allow_when_memory_limit_present: PASS (xxx µs)
data.k8s.resources.test_deny_when_resources_block_absent: PASS (xxx µs)
--------------------------------------------------------------------------------
PASS: 3/3
```

## 6. Introduce un bug a propósito

Cambia la regla a:

```rego
    not c.resources.memory      # BUG: deberia ser c.resources.limits.memory
```

Vuelve a correr:

```
data.k8s.resources.test_allow_when_memory_limit_present: FAIL
```

El test que esperaba 0 denies ahora saca 1 porque la condición es demasiado estricta. **Para esto escribimos tests.** Un refactor "inocente" se detecta en segundos.

Restaura la regla antes de seguir.

## 7. Lecturas clave

1. `with input as X` es el mecanismo **único** para mockear `input`. También existe `with data.foo as Y` para mockear datos externos.
2. Nombres `_pod_with` (underscore inicial) convencionalmente marcan helpers no exportados — Rego no tiene visibility real pero el convenio ayuda.
3. `opa test -v` es verboso; sin `-v` solo imprime failures. En CI usar sin `-v` + `--format=json` para parsing.

## 8. Preguntas de autocomprobación

1. ¿Qué test añadirías para proteger la regla contra "pod con dos containers, uno bien y otro mal"?
2. ¿Qué diferencia hay entre `count(deny) == 0` y `not deny` como aserción?
3. Si quisieras testear que **el mensaje concreto** mencione el nombre del container, ¿cómo lo harías?

(Respuestas: 1) un fixture con 2 containers; esperar `count(deny) == 1`; 2) `not deny` falla porque `deny` es siempre definida (como set), aunque esté vacía — para sets usar `count`; 3) `some msg in deny with input as pod; contains(msg, "app")`.)

## 9. Limpieza

```bash
rm -rf /tmp/sec-10-03-opa-test
```
