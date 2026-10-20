# Actividad 02 — Estimar la factura mensual de GHA de una org

## 1. Identificación

- **ID:** `gha-15-02-cost-exercise`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-15-platform-patterns-and-cost-governance`
- **Dificultad:** intermediate
- **Duración estimada:** 30–60 min
- **Tipo:** guided-lab (automated validation)

## 2. Contexto

Antes de "poner orden" en el CI/CD de una org (actividad 01), hace falta saber **cuánto cuesta hoy**. En producción esto se hace cruzando el billing CSV con los datos de workflow-runs, pero el modelo mental hay que tenerlo primero: unidad = *runner-minute cobrable*, multiplicador por SO, SKU separado para larger runners, y storage que también se cobra.

En esta actividad calculas la factura mensual de una org pequeña a partir de un perfil de uso definido y un tarifario *fijo* (dado para que la respuesta sea reproducible).

## 3. Objetivos

- Aplicas la fórmula `cobrable = minutos × multiplicador_SKU` por tipo de runner.
- Sumas storage de artifacts + GHCR al cálculo.
- Entregas un YAML con tu estimación.
- Un script valida tu total dentro de ±5% del valor oficial.

## 4. Prerrequisitos

- Lección `gha-15` leída (especialmente §2.6).
- `python3` + `PyYAML` (`pip install pyyaml`).
- Calculadora (o Python interactivo). No necesitas red.

## 5. Instrucciones

### 5.1 Perfil de uso de la org (dado)

> **Org:** `ACME-mini`, 20 repos privados, ventana de **30 días** (1 mes contable).
>
> Promedios diarios agregados (toda la org):
>
> | SKU | runs/día | duración media (min) |
> |-----|---------:|---------------------:|
> | `ubuntu-latest`         |     400 |  4 |
> | `windows-latest`        |      50 |  6 |
> | `macos-latest`          |      10 |  8 |
> | `ubuntu-latest-16-core` |      20 |  5 |
>
> Storage al final del mes:
>
> | Recurso | Volumen |
> |---------|--------:|
> | Artifacts | 50 GB-mes |
> | GHCR      | 200 GB-mes |
> | Actions cache | dentro del límite de 10 GB/repo (no cobra adicional) |

### 5.2 Tarifario (dado, fijo para este ejercicio)

> **Minutos** (precio *base* por minuto Ubuntu; multiplicadores por SKU según política oficial):
>
> | SKU | $/min efectivo |
> |-----|---------------:|
> | `ubuntu-latest` (×1)         | 0.008 |
> | `windows-latest` (×2)        | 0.016 |
> | `macos-latest` (×10)         | 0.080 |
> | `ubuntu-latest-16-core` (larger, SKU aparte) | 0.064 |
>
> **Storage** (unificado para el ejercicio): `0.25 $/GB-mes` tanto para Artifacts como para GHCR.
>
> **Ignora** cualquier bolsa gratuita mensual incluida en el plan. El cálculo es **gross usage × precio**.

### 5.3 Fórmula

Para cada SKU de minutos:

```
minutos_mes   = runs_dia × duracion_media × 30
costo_minutos = minutos_mes × precio_por_minuto_sku
```

Para cada bucket de storage:

```
costo_storage = gb_mes × 0.25
```

**Total** = suma de todos los `costo_minutos` + suma de todos los `costo_storage`.

### 5.4 Entregable

Edita `starter/cost-estimate.yaml` rellenando los campos. **No cambies los nombres de clave**; el validador los lee literalmente.

### 5.5 Validar

```bash
python3 tests/validate_cost.py starter/cost-estimate.yaml
```

- Debe terminar en `OK`.
- Tolerancia: ±5% del total oficial.
- Si falla, el output muestra el delta y qué línea desvía.

### 5.6 (Opcional) comparar con la referencia

Tras intentarlo, `solution/cost-estimate.yaml` tiene el desglose exacto.

## 6. Resultado esperado

- `cost-estimate.yaml` con el breakdown y el total.
- El validador reporta `OK` con tu total dentro de ±5%.

## 7. Criterios de aceptación

- [ ] YAML válido y parseable.
- [ ] Claves requeridas presentes (ver `starter/cost-estimate.yaml`).
- [ ] `total_usd` dentro de ±5% del total oficial.
- [ ] `tests/validate_cost.py` pasa.

## 8. Validación

```bash
python3 tests/validate_cost.py starter/cost-estimate.yaml
```

## 9. Preguntas de reflexión

1. ¿Qué pasaría con el total si convirtieras los 10 runs/día de `macos-latest` a `ubuntu-latest-arm`? Haz la cuenta.
2. ¿Qué fracción del total viene de minutos vs. storage? ¿Dónde optimizarías primero?
3. Si la bolsa incluida fuera de 50 000 min/mes a precio Linux, ¿cómo cambia la cuenta?
4. ¿Por qué larger runners se cobran por SKU aparte y no como múltiplo de ×1 estándar?
5. ¿Cómo cambia la factura real si el `actions/cache` se te va por encima de 10 GB en 3 repos?

## 10. Extensiones

- **E1** — Añade un cuarto SKU hipotético `ubuntu-latest-64-core` a `$0.256/min` con 5 runs/día × 10 min. Recalcula.
- **E2** — Modela el *ahorro* de activar `cancel-in-progress: true` en CI de PR, asumiendo que el 30% de los runs ubuntu son reruns por force-push de PRs vivos.
- **E3** — Convierte tu `cost-estimate.yaml` en un dashboard: usa `examples/02-cost-dashboard-metrics/pipeline_metrics.py` como punto de partida para alimentar los números desde la API real.

## 11. Limpieza

Esta actividad no crea recursos remotos. Para empezar de cero:

```bash
git checkout -- starter/cost-estimate.yaml
```
