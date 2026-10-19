# WALL-CLOCK — gl-04-02

## Duraciones medidas

| Job | Stage | Duración | Depende de |
|-----|-------|----------|------------|
| `build-amd64` | `build` | 3 min | — |
| `build-arm64` | `build` | 3 min | — |
| `lint` | `test` | 1 min | nada |
| `unit-tests` | `test` | 5 min | `build-amd64` |
| `integration-tests` | `test` | 4 min | `build-amd64`, `build-arm64` |
| `deploy-stg` | `deploy` | 2 min | `unit-tests` |

## Wall clock lineal (sin `needs:`)

Cada stage espera al anterior entero. El wall clock es la suma del `max()` de cada stage:

```
max(build)   = max(3, 3)       = 3 min
max(test)    = max(1, 5, 4)    = 5 min
max(deploy)  = max(2)          = 2 min
TOTAL         = 3 + 5 + 2       = 10 min
```

`lint` tarda 1 min pero bloquea el stage. `deploy-stg` espera también a `integration-tests` (4 min) aunque no lo necesite.

## Wall clock DAG (con `needs:`)

Camino crítico: la cadena más larga de dependencias.

- Cadena A: `build-amd64` (3) → `unit-tests` (5) → `deploy-stg` (2) = **10 min**.
- Cadena B: `build-amd64` (3) + `build-arm64` (3, en paralelo) → `integration-tests` (4) = 3 + 4 = 7 min.
- `lint`: arranca en t=0 con `needs: []` y termina en 1 min.

El wall clock es el **máximo** de todos los caminos = **10 min**. Igual que el lineal **en este caso concreto**, porque la cadena `build-amd64 → unit-tests → deploy-stg` sigue siendo la crítica.

## Dónde está la ganancia real

El valor del DAG no se ve en este snapshot "feliz"; se ve cuando una duración empeora:

| Escenario | Lineal | DAG | Comentario |
|-----------|--------|-----|------------|
| `integration-tests` sube a 7 min | 3 + **7** + 2 = **12 min** | 10 min | DAG no cambia: `integration` no está en el camino crítico de `deploy`. |
| `lint` sube a 6 min | 3 + **6** + 2 = **11 min** | 10 min | DAG no cambia: `lint` no bloquea `deploy`. |
| Añadimos `security-scan` (2 min) con `needs: []` | 3 + max(5, 1, 4, 2) + 2 = 10 | 10 | DAG no sufre al añadir jobs independientes. |

La ganancia **estructural** es que el pipeline ya no se degrada cuando alguien hace lento un job que no está en el camino crítico. En pipelines reales con 15+ jobs, esto suele traducirse en **20–40%** menos de wall clock promedio.

## Decisiones justificadas

1. **`deploy-stg` depende sólo de `unit-tests`, no de `integration-tests`.**
   Razón: los tests de integración corren contra staging **después** del deploy en esta org (post-deploy smoke). Si eso cambiase (p. ej. integration debiese pasar antes de desplegar a prod), el `deploy-prod` posterior sí los incluiría en `needs:`, pero `deploy-stg` no.

2. **`lint` con `needs: []` explícito.**
   Razón: hacerlo explícito documenta la intención. Un `lint` sin `needs:` arrancaría cuando el stage `test` empiece — es decir, esperaría a `build`. Con `needs: []` arranca en t=0.

3. **`unit-tests` y `integration-tests` NO comparten `needs:`.**
   Razón: `integration-tests` necesita ambas arquitecturas; `unit-tests` sólo amd64. Reflejarlo en los `needs:` evita que un fallo de `build-arm64` cancele `unit-tests` innecesariamente.

## Qué pasa si un job falla

- Si `build-amd64` falla: se saltan `unit-tests`, `integration-tests`, `deploy-stg`. `lint` **sí** corre (no depende).
- Si `build-arm64` falla: se salta `integration-tests`. `unit-tests` y `deploy-stg` siguen.
- Si `lint` falla: no afecta a nadie (nadie depende de él). Pero el pipeline queda rojo.
- Si `unit-tests` falla: se salta `deploy-stg`. `integration-tests` sigue.
