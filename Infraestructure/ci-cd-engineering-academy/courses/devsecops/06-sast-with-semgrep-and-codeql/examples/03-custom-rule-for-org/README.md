# Ejemplo 03 — Reglas custom org-specific

> Lectura y análisis. Puedes ejecutar `semgrep --test` si tienes la CLI.

## Objetivo

Mostrar cómo se escribe una regla **custom** de la organización, cómo se **testea**, y por qué una regla sin test se pudre en semanas.

## Caso: `no-requests-without-timeout`

Patrón organizacional: toda llamada `requests.<METHOD>(...)` debe llevar `timeout=<float>`. Sin timeout, un peer lento cuelga tu worker indefinidamente — en una pool pequeña basta un solo peer malo para dejar el servicio sin capacidad.

### La regla

```yaml
# .semgrep/no-requests-without-timeout.yml
rules:
  - id: no-requests-without-timeout
    languages: [python]
    severity: ERROR
    message: >-
      requests.$METHOD(...) debe recibir timeout=<float>. Sin timeout, un
      servidor lento cuelga el worker indefinidamente.
    metadata:
      category: security
      owner: platform-team
      cwe: "CWE-400: Uncontrolled Resource Consumption"
    patterns:
      - pattern-either:
          - pattern: requests.get(...)
          - pattern: requests.post(...)
          - pattern: requests.put(...)
          - pattern: requests.delete(...)
          - pattern: requests.patch(...)
          - pattern: requests.head(...)
          - pattern: requests.options(...)
          - pattern: requests.request(...)
      - pattern-not: requests.$M(..., timeout=$T, ...)
      - pattern-not: requests.$M(..., **$KW)        # tolerar kwargs explícitos
```

### El test

```python
# .semgrep/no-requests-without-timeout.test.py
import requests

# --- BAD cases: la regla DEBE disparar en estas líneas ---
r = requests.get("https://api.example.com/x")                     # ruleid: no-requests-without-timeout
r = requests.post("https://api.example.com/x", json={"a": 1})     # ruleid: no-requests-without-timeout
r = requests.request("GET", "https://api.example.com/x")          # ruleid: no-requests-without-timeout

# --- GOOD cases: la regla NO DEBE disparar ---
r = requests.get("https://api.example.com/x", timeout=5)          # ok: no-requests-without-timeout
r = requests.post("https://api.example.com/x", json={"a": 1}, timeout=(3, 10))  # ok: no-requests-without-timeout
r = requests.get("https://api.example.com/x", **kwargs)           # ok: no-requests-without-timeout
```

Ejecutar: `semgrep --test .semgrep/`.

Salida esperada:

```
.semgrep/no-requests-without-timeout.test.py: 6/6 cases passed
```

## Caso: CodeQL equivalente (apunte)

En CodeQL se escribiría algo como:

```ql
/**
 * @name requests without timeout
 * @kind problem
 * @problem.severity error
 * @id py/no-requests-without-timeout
 */

import python

from Call c
where c.getFunc().(Attribute).getObject().(Name).getId() = "requests"
  and c.getFunc().(Attribute).getName() in ["get", "post", "put", "delete", "patch"]
  and not exists(c.getANamedArgumentByName("timeout"))
select c, "requests.* without timeout — may hang indefinitely"
```

Más poderoso para análisis cross-function, **mucho más lento** de escribir y de iterar. Para esta clase de regla, Semgrep gana por rentabilidad.

## Reglas del juego para reglas custom

1. **Un ownership claro** (`metadata.owner`). Sin dueño, muere.
2. **Tests obligatorios**. Sin tests, se pudre.
3. **`metadata.cwe`** si aplica — ayuda al triage y al reporting.
4. **Mensaje accionable**: no "unsafe code" — "añade `timeout=<float>` o usa el wrapper `platform.http.get`".
5. **Severidad honesta**: ERROR solo si realmente debe bloquear.
6. **Revisión en PR** cuando se añade / modifica una regla — cambios en reglas son cambios de política.
