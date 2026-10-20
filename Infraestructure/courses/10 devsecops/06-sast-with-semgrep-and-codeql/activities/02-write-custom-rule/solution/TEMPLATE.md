# TEMPLATE — no-requests-without-timeout

## Qué detecta

Llamadas `requests.get/post/put/delete/patch/head/options/request(...)` que **no** reciben `timeout=`. Sin timeout, la conexión queda bloqueada indefinidamente ante un peer lento o un socket colgado.

## Cuándo suprimir

Solo si **puedes demostrar** que el call site está envuelto por un circuit breaker con timeout propio (p. ej. `pybreaker`, Istio sidecar con `timeout` en VirtualService). Suprimir así:

```python
# nosemgrep: no-requests-without-timeout — razón: envuelto en pybreaker CB con timeout=10s
requests.get(url)
```

Toda `# nosemgrep` sin "razón: X" es rechazada en PR.

## Cuándo migrar al wrapper interno

Si tu repo depende de `platform.http`, úsalo:

```python
# antes
requests.get("https://api.example.com/x", timeout=5)

# después
from platform import http
http.get("https://api.example.com/x")
```

El wrapper inyecta: `timeout` por defecto, headers de trace, métricas RED. Reduce tanto el ruido del scanner como las dependencias de infra en el call site.

## Dueño

`@platform-team` (ver CODEOWNERS). Cambios a la regla requieren review de este equipo.
