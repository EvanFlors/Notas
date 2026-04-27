# Módulo 03 — CPU (Unidad Central de Procesamiento)

## Propósito

Entender la CPU como el motor de ejecución del sistema: sus componentes internos (ALU, FPU, registros), su microarquitectura moderna (ejecución fuera de orden, branch prediction), la realidad multicore/multithreading, y las métricas que cuantifican su rendimiento.

## Temas

| # | Archivo | Tema |
|---|---------|------|
| 3.1 | `3.1_Componentes_Internos.md` | ALU, FPU, unidad de control, registros |
| 3.2 | `3.2_Microarquitectura.md` | Decodificación, ejecución fuera de orden, reorder buffer |
| 3.3 | `3.3_Branch_Prediction.md` | Predicción estática, dinámica, impacto en rendimiento |
| 3.4 | `3.4_Multicore_Multithreading.md` | Núcleos físicos vs lógicos, SMT, hyper-threading |
| 3.5 | `3.5_Metricas_de_Rendimiento.md` | Clock frequency, IPC, CPI |

## Dependencias

- Módulo 01 (circuitos, registros)
- Módulo 02 (ciclo de instrucción, pipeline, paralelismo)

## Conexión con el sistema

La CPU es donde se ejecuta cada instrucción de tu programa. Branch prediction determina cuánto cuesta un `if`. Out-of-order execution reordena tu código para explotar el pipeline. SMT comparte un core entre dos hilos. Entender la CPU explica por qué código branch-heavy es más lento que código branchless, y por qué hyper-threading no duplica el rendimiento.
