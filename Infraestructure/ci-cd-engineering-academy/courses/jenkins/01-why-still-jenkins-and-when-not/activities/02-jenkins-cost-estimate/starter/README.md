# Starter — jk-01-02-jenkins-cost-estimate

Esta actividad es **independiente** y **analítica**. No hay código. Tu entregable es un documento Markdown con tablas y cifras.

## Pasos

1. Lee `../README.md` completo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/jk-01-cost
   cd /tmp/jk-01-cost
   ```
3. Crea `COST-ESTIMATE.md` con las 6 secciones requeridas: Supuestos, Mantener, Migrar, Break-even, Recomendación (más el encabezado).
4. En **Supuestos** declara: coste hora cargado, horas/semana por persona, duración planificada de la migración, moneda.
5. En **Mantener** incluye al menos 3 categorías con tabla `horas/año` y `USD/año`. Sugerencia: personas, infra/agents, plugin/CVE lifecycle, incidentes.
6. En **Migrar** incluye al menos 3 categorías con tabla `horas totales` y `USD totales`. Sugerencia: inventario, re-escritura, dual-run, OIDC, aprendizaje, archivado histórico.
7. Calcula **break-even** explícito en meses (fórmula: `coste_migración / (coste_mantener_año − coste_mantener_tras_migración_año) * 12`).
8. Añade **sensibilidad** (`+/- X%` sobre coste hora o duración).
9. Escribe la **recomendación** final (mantener / migrar / híbrido).
10. Valida:
    ```bash
    bash <ruta-repo>/courses/jenkins/01-why-still-jenkins-and-when-not/activities/02-jenkins-cost-estimate/tests/validate.sh /tmp/jk-01-cost
    ```
11. Compara con `../solution/REFERENCE.md`.

## Plantilla sugerida (opcional)

```markdown
# Cost Estimate — Jenkins mantener vs migrar (Nordhaus Insurance)

## Supuestos
- Coste hora cargado: **100 USD/h** (senior platform engineer, Europa).
- Jornada: 40 h/semana × 46 semanas efectivas/año = ~1.840 h/año.
- Duración migración planificada: **18 meses**.
- Moneda: USD.

## Mantener (anual, estado actual)

| Categoría | Horas/año | USD/año |
|-----------|-----------|---------|
| Personas (2 FTE × 50% dedicación) | 1.840 | 184.000 |
| Infra (controller + agents on-prem) | - | 25.000 |
| Plugin / CVE lifecycle | 400 | 40.000 |
| Incidentes y re-runs | 300 | 30.000 |
| **Total mantener** | | **279.000** |

## Migrar (one-off, 18 meses)

| Categoría | Horas totales | USD totales |
|-----------|---------------|-------------|
| Inventario y clasificación | 300 | 30.000 |
| Re-escritura freestyle → Declarative + port a GitLab CI | 2.500 | 250.000 |
| Dual-run (duplicación cómputo) | - | 40.000 |
| OIDC federation | 200 | 20.000 |
| Aprendizaje + archivado histórico | 400 | 40.000 |
| **Total migrar** | | **380.000** |

## Break-even

- Coste anual tras migración: ~130.000 USD (menos personas, cero plugin CVE lifecycle, menos incidentes).
- Ahorro anual: 279.000 − 130.000 = **149.000 USD/año**.
- Break-even: 380.000 / 149.000 ≈ **2,55 años** desde fin de migración (~mes 48 desde hoy).

## Sensibilidad
- Coste hora +20% → break-even sube ~15%.
- Si la migración se extiende a 24 meses → break-even sube ~6 meses.
- Si solo 60% de los jobs se migran (el resto se retira sin reemplazo) → break-even baja ~8 meses.

## Recomendación
Migrar por olas. El break-even de ~4 años no es espectacular, pero:
- La **superficie CVE** desaparece.
- El **riesgo de incidente mayor** se reduce.
- La **expectativa de la CTO** (24 meses) se cumple.
- El coste de **no migrar** no es cero; es "mantener creciendo".
```
