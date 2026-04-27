# Módulo 04 — Jerarquía de Memoria

## Propósito

Comprender por qué la memoria se organiza en una jerarquía (registros → cache → RAM → disco), cómo funciona la cache y su coherencia en sistemas multicore, los mecanismos de memoria virtual (paginación, TLB), y la arquitectura NUMA en servidores multi-socket.

## Temas

| # | Archivo | Tema |
|---|---------|------|
| 4.1 | `4.1_Niveles.md` | Registros, cache L1/L2/L3, RAM, almacenamiento secundario |
| 4.2 | `4.2_Cache.md` | Localidad temporal/espacial, write-through/write-back, replacement policies |
| 4.3 | `4.3_Coherencia_de_Cache.md` | Protocolo MESI, cache coherence problem |
| 4.4 | `4.4_Memoria_Principal.md` | DRAM vs SRAM, latencia vs ancho de banda |
| 4.5 | `4.5_Memoria_Virtual.md` | Paginación, segmentación, page faults |
| 4.6 | `4.6_TLB.md` | Translation Lookaside Buffer, TLB hit/miss |
| 4.7 | `4.7_NUMA.md` | Non-Uniform Memory Access, afinidad de memoria |

## Dependencias

- Módulo 01 (representación de datos)
- Módulo 03 (CPU, registros)

## Conexión con el sistema

La jerarquía de memoria es el factor dominante del rendimiento real. Un cache miss en L1 cuesta ~4ns; un acceso a RAM cuesta ~100ns; un page fault que va a disco cuesta ~10ms. La diferencia entre un programa que cabe en cache y uno que no puede ser 10-100x en rendimiento. En servidores multi-socket, NUMA locality determina si un acceso a memoria cuesta 100ns o 300ns.
