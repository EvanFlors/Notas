# REFERENCE — plat-11-01-build-dora-dashboard

> Una **referencia** razonada contra la que compararte. No es la única respuesta correcta.

## Resultado esperado al correr el starter

Con `--seed 42 --window-days 28`:

### checkout-api

```
== DORA (service=checkout-api, window=28d) ==
  Deployment Frequency      : ~0.86 deploys/day  (24 successful deploys in 28 days)
  Lead Time for Changes     : ~4.5 h (median)
  Change Failure Rate       : ~12.50 %  (3 of 24 deploys caused incidents)
  Failed Deploy Recovery T. : ~42 min (median)
  --> Bucket (reporte reciente): HIGH
```

### legacy-billing

```
== DORA (service=legacy-billing, window=28d) ==
  Deployment Frequency      : ~0.11 deploys/day  (3 successful deploys in 28 days)
  Lead Time for Changes     : ~5.0 d (median)
  Change Failure Rate       : ~33.33 %  (1 of 3 deploys caused incidents)
  Failed Deploy Recovery T. : ~6.0 h (median)
  --> Bucket (reporte reciente): LOW
```

Los números exactos pueden variar ±10 % según decisiones de la seed.

## DORA.md modelo

### Sección A — Resumen ejecutivo

> `checkout-api` opera en el bucket **HIGH** (0.86 deploys/día, lead ~4.5 h, CFR 12 %, recovery 42 min). `legacy-billing` opera en el bucket **LOW**: 1 deploy cada ~10 días, lead ~5 días, CFR 33 % y recovery ~6 h. **Mismo platform team, perfiles opuestos** — la plataforma por sí sola no mejora un servicio; necesita que el equipo adopte sus patrones.

### Sección B — Tabla de métricas

| Métrica                              | checkout-api | legacy-billing | Bucket checkout | Bucket billing |
|--------------------------------------|--------------|----------------|-----------------|----------------|
| Deployment Frequency (deploys/día)   | 0.86         | 0.11           | HIGH            | LOW            |
| Lead Time for Changes (mediana)      | 4.5 h        | 5.0 d          | HIGH            | LOW            |
| Change Failure Rate                  | 12.5 %       | 33.3 %         | HIGH            | LOW            |
| Failed Deploy Recovery T. (mediana)  | 42 min       | 6.0 h          | HIGH            | LOW            |

### Sección C — Interpretación

**checkout-api (HIGH):**

- La métrica que *fija* el bucket es CFR (12.5 %) y DF (0.86/d) — está cerca del umbral Elite pero no lo alcanza porque CFR no es < 10 % de forma sostenida.
- Palancas: feature flags para separar deploy de release, canary deploy para mitigar CFR, mejor test suite de integración.
- No celebrar DF aisladamente — bajar lead time empujando merges a toda hora puede subir CFR. Mirar siempre el par velocidad/estabilidad.

**legacy-billing (LOW):**

- La métrica *fija* el bucket es lead time (5 días): el pipeline o el proceso de review están rotos; probablemente batches grandes.
- Palancas: trunk-based desarrollo, lotes pequeños, pipeline sin pasos manuales, strangler-fig para migrar lógica a un servicio moderno.
- Tentación clásica: celebrar "solo 3 deploys y 1 incident" sin notar que la mediana de **5 días de lead time** significa que un bug tarda 5 días en salir del dev y 6 h en resolverse. CFR del 33 % en una muestra de 3 es ruido estadístico — necesitas más datos antes de decir que "fue mejor que antes".

### Sección D — 3 recomendaciones accionables

1. **Habilitar feature flags en `checkout-api` vía plataforma (template v1.5)** → objetivo: bajar CFR del 12.5 % al 7 % en Q+1, moviendo el bucket a *Elite*.
2. **Migrar `legacy-billing` a trunk-based + pipeline con auto-merge** → objetivo: bajar lead time de 5 días a <1 día en 2 trimestres, moviendo el bucket a *Medium*.
3. **Instrumentar `caused_by_deploy_id` en PagerDuty vía el template de la plataforma** → objetivo: dejar de aproximar CFR por ventana temporal; medir CFR real con confianza para que las decisiones no se tomen sobre ruido. Es un *leading indicator* para la calidad de los otros 2 recommendaciones.

## Antipattern evitado

> Si solo midiéramos *deployment frequency* en el dashboard de la plataforma, `checkout-api` saldría premiado y `legacy-billing` ignorado. Peor: si el bonus del platform team dependiera de DF, incentivaríamos deploys triviales (bump de patch) en `checkout-api` y ningún trabajo en `legacy-billing`, cuando el *outcome* para el negocio sería exactamente el opuesto. Esto es **Goodhart's Law**: la métrica se vuelve objetivo y deja de ser métrica.

## Qué NO está en este modelo (y por qué)

- **No proponemos quitar `legacy-billing` del dashboard.** Mostrar los servicios *low* es tan importante como celebrar los *elite* — es donde el platform team tiene mayor leverage.
- **No hablamos de SPACE ni de NPS.** Están fuera del alcance de esta actividad; se tocan en la actividad 02 y en la lección.
- **No mezclamos las 4 métricas en un único score.** Un *"platform health score = DF + (1-CFR) + ..."* es un vanity metric compuesto. Los 4 ejes se reportan separados por diseño DORA.
