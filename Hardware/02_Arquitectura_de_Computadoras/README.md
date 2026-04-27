# Módulo 02 — Arquitectura de Computadoras

## Propósito

Comprender los modelos arquitectónicos que definen cómo se organiza una computadora (Von Neumann, Harvard), cómo se ejecuta una instrucción paso a paso, cómo el pipeline multiplica el throughput, y cómo el paralelismo a distintos niveles (instrucción, datos, hilos) escala el rendimiento.

## Temas

| # | Archivo | Tema |
|---|---------|------|
| 2.1 | `2.1_Modelos_Arquitectonicos.md` | Von Neumann, Harvard, separación memoria-instrucciones |
| 2.2 | `2.2_Ciclo_de_Instruccion.md` | Fetch, decode, execute, memory access, write-back |
| 2.3 | `2.3_Pipeline.md` | Etapas, hazards (data, control, structural) |
| 2.4 | `2.4_Paralelismo.md` | ILP, SIMD, TLP |

## Dependencias

- Módulo 01 (lógica booleana, circuitos secuenciales, representación de datos)

## Conexión con el sistema

La arquitectura define el contrato entre hardware y software. El pipeline determina cuántas instrucciones por ciclo puede sostener la CPU. Los hazards explican por qué branch mispredictions cuestan ciclos. El paralelismo explica por qué un programa single-threaded no puede explotar un procesador moderno multicore.
