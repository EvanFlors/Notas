# Módulo 10 — Interacción Hardware-Software

## Propósito

Trazar el camino completo que recorren los datos desde la NIC hasta el disco, pasando por kernel y user space. Entender las syscalls que cruzan la frontera hardware-software, el rol de los buffers, las optimizaciones zero-copy, y las técnicas de kernel bypass para rendimiento extremo.

## Temas

| # | Archivo | Tema |
|---|---------|------|
| 10.1 | `10.1_Camino_de_Datos.md` | NIC → kernel → user space → CPU → memoria → disco |
| 10.2 | `10.2_Syscalls.md` | read(), write(), send(), recv(), accept() |
| 10.3 | `10.3_Buffers.md` | Kernel buffers, user buffers |
| 10.4 | `10.4_Zero_Copy.md` | sendfile(), mmap() |
| 10.5 | `10.5_Kernel_Bypass.md` | DPDK, RDMA |

## Dependencias

- Módulo 03 (CPU)
- Módulo 04 (memoria, memoria virtual)
- Módulo 06 (DMA, interrupciones)
- Módulo 07 (NIC)

## Conexión con el sistema

Este módulo es el puente entre hardware y software. Cada `read()` es una syscall que cruza de user space a kernel space (context switch). Cada paquete de red pasa por la NIC → DMA → kernel buffer → user buffer (al menos dos copias). Zero-copy y kernel bypass eliminan estas copias para maximizar throughput. Entender esta interacción explica por qué nginx con sendfile() es más rápido sirviendo archivos estáticos, y por qué DPDK puede procesar millones de paquetes por segundo.
