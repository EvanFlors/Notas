# Módulo 08 — Bases de Datos y Persistencia

## Propósito

Los datos son el activo más valioso. Elegir la base correcta, entender sus internals (B-Trees, WAL, MVCC), dominar transacciones e indexación, y diseñar estrategias de scaling (replication, sharding, caching) define la escalabilidad de tu sistema.

## Temas

| Archivo | Tema | Conceptos clave |
|---------|------|-----------------|
| 8.1 | Modelos de datos | Relacional, key-value, document, wide-column, graph, time-series |
| 8.2 | Internals de bases de datos | B-Trees, LSM Trees, WAL, MVCC, buffer pool |
| 8.3 | Transacciones | ACID, isolation levels, locking, deadlocks, distributed transactions |
| 8.4 | Indexación | B-Tree, hash, GIN, covering, EXPLAIN ANALYZE |
| 8.5 | Escalabilidad de datos | Replication, sharding, partitioning, connection pooling |
| 8.6 | Caching | Redis, cache patterns, invalidation, CDN, multi-level |

## Dependencias

```
Módulo 5 (patterns) + Módulo 6 (execution) → Módulo 8
Módulo 8 → Módulo 9 (Arquitectura), Módulo 13 (Distribuidos)
```
