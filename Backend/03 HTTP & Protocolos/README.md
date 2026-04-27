# Módulo 03 — HTTP y Protocolos de Aplicación

## Propósito

HTTP es el idioma que habla tu API. Cada versión resuelve limitaciones de la anterior. Entender la evolución de HTTP/1.0 a HTTP/3, junto con protocolos modernos como WebSockets y gRPC, determina las decisiones de comunicación en tu arquitectura.

## Temas

| Archivo | Tema | Conceptos clave |
|---------|------|-----------------|
| 3.1 | Fundamentos HTTP | Request/response, methods, status codes, headers |
| 3.2 | Serialización de datos | JSON, Protobuf, MessagePack, trade-offs |
| 3.3 | Evolución de HTTP | HTTP/1.0 → 1.1 → 2 → 3, multiplexing, QUIC |
| 3.4 | Protocolos modernos | WebSockets, gRPC, WebRTC, SSE |
| 3.5 | Propiedades de protocolos | Stateful/stateless, duplex, reliable |

## Dependencias

```
Módulo 2 (TCP/UDP) → Módulo 3 (HTTP sobre TCP/QUIC)
                   → Módulo 4 (TLS sobre TCP)
```
