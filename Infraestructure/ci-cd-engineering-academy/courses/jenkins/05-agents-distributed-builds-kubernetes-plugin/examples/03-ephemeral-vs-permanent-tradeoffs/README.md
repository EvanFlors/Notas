# Ejemplo 03 — Ephemeral vs permanent: tabla de decisión

> Marco para elegir modelo de agent. No hay respuesta universal; hay criterios.

## 1. Tabla comparativa

| Criterio | Permanent (SSH / JNLP) | Ephemeral Docker | Ephemeral K8s |
|----------|------------------------|------------------|---------------|
| Cold-start | 0 s (ya encendido) | 2–10 s (pull + run) | 10–60 s (schedule + pull + start) |
| Reproducibilidad | Baja (contamination acumulada) | Alta (imagen por build) | Alta (Pod por build) |
| Aislamiento | Nulo (mismo host) | Medio (kernel compartido) | Alto (Pod boundary + PSS) |
| Blast-radius de un build malicioso | Compromete el host, persiste | Scope al contenedor | Scope al Pod + policy |
| Escalado | Manual (añadir hosts) | Semi-manual (pool fijo) | Automático (HPA + autoscaler) |
| Coste idle | Alto (hosts encendidos siempre) | Medio | Bajo (solo cuando hay cola) |
| Debugabilidad post-mortem | Fácil (`ssh` al nodo) | Media | Media/alta (`kubectl logs`, Pod retention) |
| Hardware específico (GPU, Mac) | Única opción práctica | Limitado | Vía nodeSelector/taints |
| Operación | Pet (parcheo manual) | Cattle parcial | Cattle completo |

## 2. Reglas rápidas

- **Builds cortos (< 30 s) con imagen grande (> 2 GB)**: permanent o ephemeral Docker con cache local. Cold-start de K8s mata el throughput.
- **Builds largos (> 5 min) con herramientas estándar**: K8s ephemeral. El cold-start es ruido.
- **Compliance de aislamiento**: K8s ephemeral + NetworkPolicy + PSS `restricted`. No hay alternativa seria.
- **Hardware específico**: permanent con `label` descriptivo (`gpu-a100`, `macos-m2`). Minoriza su número.
- **Pico de carga irregular**: K8s ephemeral con cluster-autoscaler. Permanent desperdicia capacidad en valle.

## 3. Decisión por tipo de equipo

| Perfil | Recomendación |
|--------|---------------|
| Equipo que ya opera K8s | K8s ephemeral; permanent solo para hardware especial. |
| Equipo con hosts Docker y sin K8s | Ephemeral Docker; evaluar K8s cuando el pool se vuelva ingestionable (> 10 hosts). |
| Equipo con 1 host Jenkins y 5 pipelines | Permanent está bien; no sobre-ingeniar. |
| Equipo migrando a GitHub Actions | ARC + Pods efímeros; no invertir más en Jenkins + K8s plugin. |

## 4. Falso dilema

"Permanent es más rápido, ephemeral es más seguro" **no** es dicotomía estricta. Con warm pools e imágenes pre-cacheadas, un ephemeral K8s llega a cold-starts de 5 s. Con hardening agresivo, un permanent se puede mantener seguro. El criterio real es **a quién le toca mantenerlo** y qué le cuesta.
