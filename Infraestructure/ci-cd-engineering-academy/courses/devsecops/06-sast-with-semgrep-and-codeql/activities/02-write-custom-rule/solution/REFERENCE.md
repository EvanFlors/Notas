# REFERENCE — sec-06-02-write-custom-rule

> Modelo. Hay varias formas válidas de escribir esta regla.

## 1. La regla (modelo)

```yaml
# .semgrep/no-requests-without-timeout.yml
rules:
  - id: no-requests-without-timeout
    languages: [python]
    severity: ERROR
    message: >-
      requests.$METHOD(...) debe recibir timeout=<float>. Sin timeout un peer
      lento cuelga el worker; en un pool pequeño basta uno para dejar el
      servicio sin capacidad.
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
      - pattern-not: requests.$M(..., **$KW)
```

## 2. El fixture (modelo)

```python
# .semgrep/no-requests-without-timeout.test.py
import requests

kwargs = {"timeout": 5}

# BAD: should fire
requests.get("https://x")                                    # ruleid: no-requests-without-timeout
requests.post("https://x", json={"a": 1})                    # ruleid: no-requests-without-timeout
requests.request("GET", "https://x")                         # ruleid: no-requests-without-timeout
requests.delete("https://x")                                 # ruleid: no-requests-without-timeout

# GOOD: should NOT fire
requests.get("https://x", timeout=5)                         # ok: no-requests-without-timeout
requests.post("https://x", json={"a": 1}, timeout=(3, 10))   # ok: no-requests-without-timeout
requests.get("https://x", **kwargs)                          # ok: no-requests-without-timeout
```

Esperado: `semgrep --test .semgrep/` → `7/7 cases passed`.

## 3. TEMPLATE.md (ver `solution/TEMPLATE.md`)

Entrega esperada: 4 secciones completas.

## 4. Decisiones

- **Por qué `**$KW` como pattern-not**: aceptar `requests.get(url, **kwargs)` reduce FP cuando el kwargs expand incluye `timeout`. Trade-off: puede ocultar código real sin timeout. Documentar.
- **Por qué ERROR y no WARNING**: no tener timeout es una fuente clásica de outage. Prefiero bloquear y pedir decisión explícita.
- **Alternativa**: wrapper interno `platform.http.get()` que siempre inyecta timeout + metrics. Cuando exista, migrar a él y añadir `pattern-not-inside: platform.http.$F(...)` para no reportar sobre el wrapper.
