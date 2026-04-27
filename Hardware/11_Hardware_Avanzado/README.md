# Módulo 11 — Hardware Avanzado

## Propósito

Explorar hardware especializado que extiende las capacidades de la CPU general: GPUs para paralelismo masivo, SmartNICs para offloading de red programable, FPGAs para lógica reconfigurable, y ASICs para funciones especializadas de máximo rendimiento.

## Temas

| # | Archivo | Tema |
|---|---------|------|
| 11.1 | `11.1_GPUs.md` | Arquitectura masivamente paralela, CUDA, OpenCL |
| 11.2 | `11.2_SmartNICs.md` | Offloading programable de red |
| 11.3 | `11.3_FPGAs.md` | Reconfigurabilidad, uso en networking |
| 11.4 | `11.4_ASICs.md` | Chips especializados, switching de alta velocidad |

## Dependencias

- Módulo 03 (CPU como punto de comparación)
- Módulo 06 (PCIe — cómo se conectan al sistema)
- Módulo 07 (NICs — contexto para SmartNICs)

## Conexión con el sistema

Las CPUs son general-purpose pero no óptimas para todo. Las GPUs procesan miles de hilos en paralelo (ML, rendering). Las SmartNICs descargan procesamiento de red de la CPU (firewalling, encryption). Los FPGAs permiten implementar lógica custom con latencia de nanosegundos. Los ASICs son chips fijos ultra-optimizados para una tarea (e.g., switching Ethernet a 400Gbps). Saber cuándo usar hardware especializado es clave para sistemas de alto rendimiento.
