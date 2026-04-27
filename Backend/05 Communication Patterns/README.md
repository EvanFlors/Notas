# Módulo 05 — Backend Communication Patterns

## Propósito

No todo es request/response. Elegir el patrón correcto de comunicación define la escalabilidad, la experiencia del usuario, y la complejidad operacional de tu sistema.

## Temas

| Archivo | Tema | Conceptos clave |
|---------|------|-----------------|
| 5.1 | Request/Response | Anatomía, content negotiation, chunked encoding |
| 5.2 | Sync vs Async | Blocking/non-blocking, cuándo usar cada uno |
| 5.3 | Comunicación en tiempo real | Short/long polling, SSE, WebSockets, push vs pull |
| 5.4 | Mensajería y eventos | Message queues, pub/sub, event-driven, DLQ |
| 5.5 | Estado y sesiones | Stateful/stateless, idempotency, delivery guarantees |
| 5.6 | Multiplexing y connections | HTTP/2 streams, connection pooling |
| 5.7 | Sidecar pattern | Service mesh, Envoy, proxying |

## Dependencias

```
Módulo 3 (HTTP, WebSocket, gRPC) → Módulo 5 (Patterns sobre esos protocolos)
                                  → Módulo 6 (Execution patterns)
```
