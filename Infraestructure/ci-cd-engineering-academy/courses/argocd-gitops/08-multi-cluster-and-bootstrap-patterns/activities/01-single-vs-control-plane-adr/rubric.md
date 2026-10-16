# Rubric — ADR multi-cluster

Evalúa tu propio ADR punto por punto. 0 = ausente, 1 = débil, 2 = correcto, 3 = fuerte.

| # | Criterio | 0–3 |
|---|----------|-----|
| 1 | ¿Cada decisión identifica al menos 3 trade-offs específicos (no genéricos)? | |
| 2 | ¿Cada decisión lista riesgos **y** mitigación por cada uno? | |
| 3 | ¿El flujo "add-a-cluster" es ejecutable (5+ pasos concretos)? | |
| 4 | ¿Las 3 decisiones son internamente consistentes entre sí? | |
| 5 | ¿Menciona herramientas concretas (Velero, ESO, CODEOWNERS, Cluster API, etc.) donde corresponde? | |
| 6 | ¿Admite limitaciones y menciona qué cambiaría la recomendación? | |
| 7 | ¿Discute explícitamente blast radius y recuperación? | |

**≥ 15 / 21** = ADR aceptable. **< 10** = revisar teoría secciones 2 y 9 y reintentar.
