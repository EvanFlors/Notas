# Módulo 09 — Performance y Bottlenecks

## Propósito

Cuantificar el rendimiento del sistema con métricas formales (latencia, throughput, IOPS), identificar los tres tipos fundamentales de bottleneck (CPU-bound, memory-bound, IO-bound), y aplicar los principios teóricos (Ley de Amdahl, Ley de Little) que gobiernan la escalabilidad.

## Temas

| # | Archivo | Tema |
|---|---------|------|
| 9.1 | `9.1_Metricas.md` | Latencia, throughput, IOPS |
| 9.2 | `9.2_Bottlenecks.md` | CPU-bound, memory-bound, IO-bound |
| 9.3 | `9.3_Principios.md` | Ley de Amdahl, Ley de Little |

## Dependencias

- Módulo 03 (CPU)
- Módulo 04 (memoria)
- Módulo 05 (almacenamiento — IOPS)

## Conexión con el sistema

Todo problema de rendimiento se reduce a identificar el bottleneck. Si tu app es CPU-bound, añadir más disco no ayuda. Si es IO-bound, un CPU más rápido no cambia nada. La Ley de Amdahl te dice cuánto puedes ganar paralelizando. La Ley de Little te dice cuántos requests concurrentes necesitas para saturar el throughput disponible. Estas son las herramientas mentales para diagnosticar rendimiento.
