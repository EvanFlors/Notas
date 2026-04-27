# Módulo 07 — Proxies y Load Balancing

## Propósito

Todo tráfico de producción pasa por al menos un proxy. Entender los tipos de proxy, algoritmos de balanceo, y las herramientas disponibles permite diagnosticar cuellos de botella y diseñar arquitecturas de alta disponibilidad.

## Temas

| Archivo | Tema | Conceptos clave |
|---------|------|-----------------|
| 7.1 | Tipos de proxy | Forward, reverse, diferencia fundamental |
| 7.2 | Load balancing | L4 vs L7, algoritmos, health checks, sticky sessions |
| 7.3 | Casos especiales | WebSocket proxying, gRPC, TLS termination |
| 7.4 | Herramientas | Nginx, HAProxy, Envoy, Traefik |

## Dependencias

```
Módulo 3 (HTTP) + Módulo 4 (TLS) → Módulo 7 (Proxies operan sobre HTTP/TLS)
```
