# Módulo 05 — Almacenamiento

## Propósito

Entender los dispositivos de almacenamiento persistente (HDD, SSD, NVMe), su mecánica interna, las interfaces que los conectan al sistema, los sistemas de archivos que organizan los datos, y RAID como mecanismo de redundancia y rendimiento.

## Temas

| # | Archivo | Tema |
|---|---------|------|
| 5.1 | `5.1_Tipos.md` | HDD, SSD, NVMe — comparación y casos de uso |
| 5.2 | `5.2_Internals_HDD.md` | Platos, cabezales, seek time, rotational latency |
| 5.3 | `5.3_Internals_SSD.md` | NAND Flash, wear leveling, garbage collection, write amplification |
| 5.4 | `5.4_Interfaces.md` | SATA, PCIe, NVMe protocol |
| 5.5 | `5.5_Sistemas_de_Archivos.md` | Inodos, bloques, journaling |
| 5.6 | `5.6_RAID.md` | RAID 0, 1, 5, 10 — redundancia vs rendimiento |

## Dependencias

- Módulo 04 (jerarquía de memoria, almacenamiento como nivel inferior)
- Módulo 06 (buses PCIe)

## Conexión con el sistema

Todo dato que sobrevive un reboot vive en almacenamiento. La latencia de un HDD (~10ms seek) vs un NVMe (~10μs) es una diferencia de 1000x que determina el rendimiento de bases de datos, logs, y cualquier workload IO-bound. El sistema de archivos y su journaling determinan la integridad de datos tras un crash. RAID determina la durabilidad y el throughput agregado.
