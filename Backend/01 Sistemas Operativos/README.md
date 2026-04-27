# Módulo 1 — Sistemas Operativos y Fundamentos

## Propósito

Este módulo establece la base sobre la que opera todo backend: el sistema operativo. Cada request que tu servidor procesa pasa por scheduling de CPU, allocation de memoria, file descriptors y system calls. Sin dominar estos conceptos, optimizar o debuggear un backend es imposible.

## Por qué importa en producción

- Un memory leak en heap crashea tu servicio a las 3 AM
- Un thread pool mal dimensionado causa starvation bajo carga
- No entender `epoll` vs blocking I/O significa elegir el modelo de concurrencia incorrecto
- File descriptor leaks causan `Too many open files` y rechazo de conexiones
- Context switching excesivo destruye throughput en servicios de alta concurrencia

## Problemas reales que resuelve

- Diagnosticar por qué un proceso consume 100% CPU (CPU-bound vs busy-wait)
- Entender por qué un servidor con 1000 threads rinde peor que uno con 4 threads + event loop
- Identificar memory leaks con herramientas de OS (`strace`, `lsof`, `/proc`)
- Elegir entre threads, async o procesos para tu caso de uso
- Tuning de kernel parameters para servidores de alto throughput

## Temas

- 1.1 Arquitectura de computadoras
- 1.2 Procesos e hilos
- 1.3 Memoria
- 1.4 Kernel y system calls
- 1.5 CPU scheduling
- 1.6 Modelos de I/O y concurrencia
- 1.7 CLI y entorno

## Grafo de dependencias

```
  (ninguno)
      │
      ▼
  [Módulo 1: Sistemas Operativos] ──► Módulo 2: Networking
                                  ──► Módulo 6: Backend Execution
```
