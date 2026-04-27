# Módulo 06 — Backend Execution Patterns

## Propósito

Cómo tu servidor acepta, lee, procesa y responde conexiones determina su rendimiento bajo carga. Desde single-thread hasta event loops y socket sharding, cada patrón tiene trade-offs de throughput, latencia, y complejidad.

## Temas

| Archivo | Tema | Conceptos clave |
|---------|------|-----------------|
| 6.1 | Lifecycle de una request | accept → read → process → write |
| 6.2 | Patrones de ejecución | Thread-per-connection, thread pool, event loop, reactor/proactor |
| 6.3 | Arquitecturas de servidor | Listener/reader variations, SO_REUSEPORT, pre-fork |
| 6.4 | Optimización kernel/TCP | Nagle, delayed ACK, TCP_NODELAY, zero-copy, backpressure |

## Dependencias

```
Módulo 1 (I/O, epoll, threads) + Módulo 2 (TCP) → Módulo 6
```
