# REFERENCE — jk-01-02-jenkins-cost-estimate

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que comparar tus números.

---

# Cost Estimate — Jenkins mantener vs migrar (Nordhaus Insurance)

## Supuestos

| Supuesto | Valor | Razón |
|----------|-------|-------|
| Coste hora cargado (platform senior, Europa) | **100 USD/h** | Salario + overhead + beneficios; cifra conservadora para rol senior. |
| Jornada efectiva | **1.840 h/año** | 40 h/sem × 46 sem efectivas (descontando vacaciones, formación, enfermedad). |
| Duración migración planificada | **18 meses** | Olas de 50–100 jobs/mes sobre 1.400 jobs, con 20–30% retirados sin reemplazo. |
| Jobs activos a migrar | **~1.000** | De los 1.400, se asume que ~400 se retiran por desuso al inventariar. |
| Dedicación equipo plataforma a Jenkins hoy | **~1 FTE equivalente** | 2 personas × ~50% del tiempo cada una. |
| Moneda | **USD** | Elegida por simplicidad; convertir a EUR si auditoría local lo exige. |

## Mantener (estado actual, anual)

| Categoría | Detalle | Horas/año | USD/año |
|-----------|---------|-----------|---------|
| Personas (operación recurrente) | 2 FTE × 50% dedicados a Jenkins | 1.840 | 184.000 |
| Infra on-prem | Controller (1 VM 8c/32GB) + ~30 agents + storage + backup | - | 25.000 |
| Plugin / CVE lifecycle | Monitorización feed, parcheo, pruebas, rollback | 400 | 40.000 |
| Incidentes y re-runs | ~12 caídas/año × 20 h cada una (debug + comunicación + re-runs) | 240 | 24.000 |
| Deuda operativa (modernización incremental) | Pequeñas mejoras sin plan global | 150 | 15.000 |
| **Total mantener (status quo)** | | **~2.630** | **~288.000** |

Nota: no incluye licencia **CloudBees** (actualmente no se usa). Si se adoptara CloudBees añadir ~80.000–150.000 USD/año según tier.

## Migrar (one-off, horizonte 18 meses)

| Categoría | Detalle | Horas totales | USD totales |
|-----------|---------|---------------|-------------|
| Inventario y clasificación | Script + entrevistas con dueños de job (1.400 jobs) | 300 | 30.000 |
| Re-escritura freestyle → Declarative | Prerrequisito para migrar limpio (~560 freestyle × ~3 h) | 1.700 | 170.000 |
| Port Declarative → `.gitlab-ci.yml` + reusable components | ~1.000 jobs × ~2 h promedio | 2.000 | 200.000 |
| Dual-run (cómputo duplicado) | Agents extra en GitLab Runners durante ~14 meses | - | 50.000 |
| OIDC federation (reemplazo de secretos de larga vida) | Diseño + implementación + migración por cuenta cloud | 300 | 30.000 |
| Aprendizaje + enablement equipo | Sesiones, pair-programming, documentación | 200 | 20.000 |
| Archivado histórico (Solvency II: 7 años) | Export de logs, firmas, cold storage | 150 | 15.000 |
| Gestión del proyecto + overhead | Steering, revisión ADRs, reporting | 300 | 30.000 |
| **Total migrar (one-off)** | | **~4.950** | **~545.000** |

## Estado anual **tras** migración (año 2+ desde fin de migración)

| Categoría | USD/año |
|-----------|---------|
| Personas (operación GitLab CI self-managed, menos superficie) | 100.000 |
| Infra (GitLab Runners en el cluster existente) | 15.000 |
| Mantenimiento GitLab CI (upgrades, templates) | 15.000 |
| Incidentes (reducidos ~70%) | 8.000 |
| **Total post-migración** | **~138.000** |

## Break-even

- **Ahorro anual** tras migración: 288.000 − 138.000 = **150.000 USD/año**.
- **Coste one-off** de migración: 545.000 USD.
- **Payback simple**: 545.000 / 150.000 ≈ **3,6 años** desde el fin de la migración.
- Como la migración dura 18 meses, el **break-even total desde hoy** es:

```
  mes 0 ───── migración (18m, 545k) ─────┐
                                         │
                                         ▼
  mes 18 ────── ahorro 150k/año ──────── mes 18 + ~44m ≈ mes 62
```

- **Break-even total**: **~5 años** desde la decisión. No es espectacular, pero el **coste de no migrar** no es cero: la deuda operativa crece y los CVE lifecycle se multiplican.

## Sensibilidad

| Variable | Cambio | Impacto en break-even |
|----------|--------|-----------------------|
| Coste hora | 100 → 150 USD/h (+50%) | Tanto `mantener` como `migrar` suben proporcionalmente; break-even **estable** en años, pero USD absolutos aumentan ~50%. |
| Duración migración | 18 → 24 meses | Break-even sube ~6 meses y hay 6 meses más de dual-run (coste extra ~20.000 USD). |
| Jobs a migrar | 1.000 → 600 (más retiros) | Migración baja a ~380.000 USD; break-even cae a ~4 años totales. |
| Jobs a migrar | 1.000 → 1.400 (nada se retira) | Migración sube a ~700.000 USD; break-even sube a ~6 años totales. |
| Incidentes anuales | +50% en Jenkins si no se moderniza | `mantener` sube ~15.000 USD/año; mejora el caso de migrar. |
| CVE grave con exfiltración | 1 evento | **No cuantificado aquí**; típicamente > 500.000 USD en banca/seguros entre notificación GDPR + remediación + reputación. Argumento más fuerte a favor de migrar. |

## Riesgos financieros no capturados en la tabla

1. **Multa GDPR** por brecha vía plugin vulnerable: potencialmente millones.
2. **Hallazgo Solvency II** por auditoría ("no reproducible" por falta de JCasC): sanción regulatoria.
3. **Rotación del equipo**: perder al único que entiende las Shared Libraries puede paralizar releases una semana (coste reputacional).
4. **Lock-in creciente**: cada año en Jenkins añade jobs; migrar en el año 5 costará más que hoy.

## Recomendación

**Migrar por olas**, en el horizonte de 18–24 meses, con las siguientes condiciones:

1. **Fase A de modernización** (0–6 meses) para estabilizar el Jenkins actual **mientras** se planifica la migración (sin esto no se puede migrar nada sin romper producción).
2. **Dual-run obligatorio** ≥ 4 semanas por ola. Sin excepciones.
3. **Olas de bajo riesgo primero** (lint, builds de staging); release-crítico va en olas 5+.
4. **Revisión del plan** cada 6 meses contra métricas reales de ahorro y riesgo.
5. **Si en los primeros 6 meses el ahorro proyectado se desvía > 20%**, replantear decisión.

El break-even puro no es dramático (~5 años), pero la decisión no es solo financiera: es **reducir superficie de ataque**, **cumplir expectativa de la CTO**, **retener talento** y **evitar un incidente mayor cuya factura excedería largamente el coste de la migración**. La recomendación financiera y la estratégica coinciden: **migrar**, no "fuera Jenkins ya".

---

## Notas sobre los números

- Todas las cifras son **estimaciones defendibles**, no mediciones. Se asumen conservadoras.
- Ajusta a tu geografía: en EE. UU. el coste hora puede ser 150–200 USD/h; en Latam/India puede ser 30–60 USD/h, lo que mueve el payback.
- Para un modelo más fino, convertir las tablas a un spreadsheet con variables y simular 1000 escenarios (Monte Carlo); fuera del alcance de este módulo.
