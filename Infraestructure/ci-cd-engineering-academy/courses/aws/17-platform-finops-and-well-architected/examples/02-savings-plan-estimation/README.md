# Ejemplo 02 — Estimación de Savings Plan vs on-demand

> Lectura y análisis. Sin ejecución. Los **precios son placeholders ilustrativos**, no tarifas reales. Verifica siempre contra la calculadora oficial de AWS para números finales.

## 1. El escenario

Un servicio de backend corre en **8 instancias `m6i.large`** de forma estable 24×7 en `us-east-1`. Observabilidad confirma 2–3 meses de baseline sin picos. El equipo quiere decidir entre:

- **A.** Seguir on-demand.
- **B.** Compute Savings Plan 1 año "no upfront".
- **C.** Compute Savings Plan 3 años "all upfront".

## 2. Datos de entrada (hipotéticos)

```
Precio on-demand m6i.large  : $0.096/h   (placeholder)
Horas/mes                   : 730
Instancias                  : 8
Baseline $/h total          : $0.768/h
Baseline $/mes              : $560.64
```

Descuentos típicos de **Compute Savings Plan** (bandas de referencia):

```
1y no upfront   : ~27 %
1y all upfront  : ~31 %
3y no upfront   : ~45 %
3y all upfront  : ~54 %
```

## 3. Hoja de cálculo mental

```
Baseline anual on-demand   : $560.64 × 12 = $6,727.68

A. On-demand               : $6,727.68 / año
B. SP 1y no upfront (27%)  : $4,911.21 / año     (ahorro $1,816 vs A)
C. SP 3y all upfront (54%) : $3,094.73 / año     (ahorro $3,633 vs A por año)
                             upfront ~$9,284 (los 3 años completos)
```

## 4. El trabajo real no es el cálculo

El cálculo es trivial. Las decisiones son:

- **¿Cuánto del baseline es "realmente estable"?** Si el servicio puede bajar a 4 instancias en 6 meses por rightsizing (Compute Optimizer sugiriendo `m6i.large` → `t4g.large` Graviton), comprometerte a 8 por 3 años es ineficiente. **Regla**: comprometer el **mínimo que mantendrás seguro todo el período**.
- **¿Horizonte del workload?** Si el proyecto podría morir en 18 meses, el SP de 3 años es un pasivo.
- **¿Qué tanto cash tienes?** All-upfront compromete liquidez; no todas las orgs lo aceptan contablemente.
- **¿Flexibilidad arquitectónica?** Compute SP cubre EC2, Fargate y Lambda. EC2 Instance SP cubre más barato pero menos. Si vas a migrar parte a Fargate en 1 año, Compute SP es la elección.
- **¿Compra escalonada?** Comprar 60 % hoy, 20 % en 3 meses, 20 % en 6 meses mitiga el riesgo de equivocarte con el tamaño.

## 5. Qué recomienda el motor de AWS

AWS Cost Management → **Savings Plans → Recommendations** devuelve un conjunto por *purchase option* y período, usando las últimas 7, 30 o 60 días como ventana. Lee la *estimated savings* **y** la *break-even point* (en días). Si el break-even es > 180 días, piénsalo dos veces.

## 6. Combinando palancas

En la práctica:

1. **Rightsize primero** (Compute Optimizer).
2. **Mueve lo elegible a Graviton**.
3. **Compra Savings Plan sobre el baseline post-rightsizing**.
4. **Spot para batch/CI** (ortogonal).
5. **Monitorea cobertura** `(hours covered by SP) / (total hours)` como KPI mensual.

No invertir el orden. Comprar SP antes de rightsize es la receta clásica para pagar un ahorro negativo.

## 7. Qué NO cubre un Savings Plan

- RDS reservations — van por **Reserved Instances** aparte.
- S3, data transfer, NAT Gateway — no hay compromiso.
- Elasticache, Redshift, DynamoDB — tienen sus propias RIs/compromisos.
- Workloads muy *bursty* donde el baseline estable es casi cero — mejor on-demand o Spot.

## 8. Preguntas de autocomprobación

1. Si **compras más SP del baseline real**, ¿qué pasa con la cobertura no usada? ¿Es dinero perdido? ¿Hasta qué grado?
2. ¿Por qué el break-even de un plan 3y all-upfront puede ser > 1 año a pesar de que el descuento es grande?
3. ¿En qué condiciones un **EC2 Instance SP** supera al **Compute SP** y por qué AWS vende los dos?
4. Si el workload se migra a **Fargate** mañana, ¿qué pasa con el Compute SP comprado para EC2?

Respuestas: discusión en la actividad `02-finops-dashboard-and-anomaly/`.
