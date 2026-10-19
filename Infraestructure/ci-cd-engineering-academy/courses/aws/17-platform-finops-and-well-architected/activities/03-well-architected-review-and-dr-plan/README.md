# Actividad 03 — Capstone: Well-Architected Review + plan DR

## 1. Identificación

- **ID:** `aws-17-03-well-architected-review-and-dr-plan`
- **Tecnología:** `aws`
- **Módulo:** `aws-17-platform-finops-and-well-architected`
- **Dificultad:** advanced
- **Duración estimada:** 2.5–3 h
- **Tipo:** scenario (capstone de síntesis del módulo y del track AWS)

## 2. Contexto

**Workload hipotético: `orders-platform`.**

- SaaS B2C de comercio electrónico. 300k MAU, 25M requests/mes al API, 10 % en picos de Black Friday.
- Stack: ALB → ECS Fargate (`checkout`, `catalog`, `payments`) → Aurora PostgreSQL (Multi-AZ, single region `us-east-1`) + Redis ElastiCache + S3 para assets + CloudFront.
- Un pipeline de datos nocturno con AWS Batch sobre instancias Spot que consume de S3 y RDS, alimenta Redshift.
- IAM gestionado desde Identity Center (SSO), permisos vía SCPs y permission sets.
- Observabilidad: CloudWatch + Prometheus/Grafana federado, logs en S3.
- Negocio exige: **RTO ≤ 60 min** para `checkout` y `payments`; `catalog` y batch pueden aceptar RTO de 24 h.
- Facturación mensual actual ~`$42k`. El CFO pide un plan de reducción de 15–20 % sostenible en 2 trimestres.

**Tu encargo (como *platform lead* externa):** conducir un **Well-Architected Review** sobre `orders-platform` y entregar:

1. Un `WELL-ARCHITECTED-REVIEW.md` con los 6 pilares cubiertos y hallazgos priorizados.
2. Un `DR-PLAN.md` con el patrón DR elegido por workload crítico, RPO/RTO, factura relativa y runbook.
3. Un `COST-EXPLORER-WALKTHROUGH.md` textual con los pasos para validar el pilar Cost Optimization sin tocar AWS.

**No** se ejecuta nada en AWS. No se usan credenciales. Es una entrega escrita de arquitectura.

## 3. Objetivos

Al terminar deberías poder:

- Articular una **revisión WA** cubriendo los 6 pilares con preguntas, respuestas y riesgos.
- Clasificar hallazgos como **HRI** (High Risk Issue) o **MRI** (Medium Risk Issue).
- Elegir un **patrón DR** por workload con RPO/RTO y coste relativo justificados.
- Escribir un **runbook de failover** mínimo (6–10 pasos).
- Hacer un **walkthrough escrito de Cost Explorer** para una revisión mensual.

## 4. Prerrequisitos

- Haber completado las actividades 01 y 02 de este módulo.
- Haber leído la lección completa, especialmente §5 (DR), §8 (WA), §9 (Cost Explorer).
- Haber recorrido `../../examples/03-dr-pilot-light/`.
- Herramientas: `bash`, editor Markdown. **Ninguna** credencial AWS.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/aws-17-war
cd /tmp/aws-17-war
```

### 5.2 Escribir `WELL-ARCHITECTED-REVIEW.md`

Un documento con **estas secciones**:

#### 5.2.1 Resumen ejecutivo

2–3 párrafos. Scope (`orders-platform`), fecha de la review, equipo entrevistado (ficticio), 3 hallazgos principales y recomendación global.

#### 5.2.2 Un apartado por cada pilar (6 secciones)

Para **cada** uno de los 6 pilares WA (Operational Excellence, Security, Reliability, Performance Efficiency, Cost Optimization, Sustainability):

- **Preguntas cubiertas**: 2–3 preguntas en lenguaje natural.
- **Estado actual**: 1 párrafo describiendo cómo `orders-platform` responde hoy.
- **Hallazgos**: lista con `HRI` o `MRI` + descripción.
- **Recomendaciones**: lista priorizada con acción + palanca + esfuerzo + impacto esperado.

**Mínimo 1 hallazgo por pilar; mínimo 6 hallazgos en total.**

#### 5.2.3 Plan de mejora priorizado

Tabla final:

| # | Hallazgo | Pilar | Riesgo | Esfuerzo | Impacto | Owner | Trimestre |
|---|----------|-------|--------|----------|---------|-------|-----------|
| 1 | ... | ... | HRI | medio | alto | platform | Q1 |

Al menos **6 filas**.

### 5.3 Escribir `DR-PLAN.md`

Con **5 secciones**:

1. **Clasificación de workloads por criticidad** — tabla:
   | Workload | Criticidad | RTO objetivo | RPO objetivo | Patrón DR |
   |----------|------------|--------------|--------------|-----------|
   | `checkout` | crítico | ≤ 60 min | ≤ 5 min | pilot-light |
   | `payments` | crítico | ≤ 60 min | ≤ 5 min | pilot-light |
   | `catalog` | medio | 24 h | 24 h | backup+restore |
   | batch Redshift | bajo | 24 h | 24 h | backup+restore |

   Debe haber al menos **3 workloads** y mencionar al menos **2 patrones** distintos.

2. **Justificación de patrones** — por qué cada patrón, con 2–3 líneas comparando contra las alternativas rechazadas.

3. **Factura relativa a baseline** — para los workloads críticos, cuánto crece la factura al adoptar el patrón (ej. `pilot-light ≈ 1.4× baseline del workload crítico`). Usar bandas, no cifras exactas.

4. **Runbook de failover** — para el workload más crítico (`checkout`), lista numerada de **al menos 7 pasos** desde decisión humana hasta "SLO verificado en secundaria".

5. **Prueba y mantenimiento** — cadencia de game days, tabletops, DNS failover tests. Al menos tres cadencias (trimestral/semestral/anual).

### 5.4 Escribir `COST-EXPLORER-WALKTHROUGH.md`

Textual (sin acceso real). **Al menos 10 pasos numerados** cubriendo:

- Filtros por período y granularidad.
- Group by Service, Usage Type, Tag.
- Validar cobertura de Savings Plans / RIs.
- Guardar vistas.
- Rituales mensuales (quién, cuándo, qué se produce).

### 5.5 Entregables

```
/tmp/aws-17-war/
├── WELL-ARCHITECTED-REVIEW.md
├── DR-PLAN.md
└── COST-EXPLORER-WALKTHROUGH.md
```

## 6. Resultado esperado

- Los tres archivos existen y tienen las secciones requeridas.
- La review cubre los 6 pilares, cada uno con ≥ 1 hallazgo.
- El plan DR nombra al menos 3 workloads, 2 patrones y runbook con ≥ 7 pasos.
- El walkthrough tiene ≥ 10 pasos.
- `bash tests/validate.sh /tmp/aws-17-war` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: hallazgos clasificados con riesgo; recomendaciones con palanca específica (no "optimizar").
- **Realismo**: patrones y cifras coherentes con la lección y los ejemplos; no inventa servicios.
- **Reproducibilidad**: otro ingeniero puede priorizar sin reinterpretar.

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-17-war
```

Comprueba estructura. **Compara con `solution/REFERENCE.md`** después para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Qué pilar WA es el que **más** se correlaciona con FinOps y por qué no es solo "Cost Optimization"?
2. ¿Puede un workload tener RTO de 60 min **sin** replicación cross-region? ¿Cuándo sí y cuándo no?
3. ¿Qué pasa con la postura WA cuando no hay Config Aggregator ni Security Hub en la cuenta `audit`?
4. ¿Cuál es la trampa clásica de un plan DR aprobado pero **no probado**?
5. ¿Qué sección del walkthrough es la que más valor da en una org con tagging incompleto?

## 10. Extensiones

- Añade un pilar transversal **"Platform Engineering"** con 3 hallazgos propios.
- Añade un *game day plan* detallado para el próximo trimestre.
- Añade un apartado "métricas de postura WA" (p. ej. % HRIs cerrados por trimestre).
- Si tienes tiempo, extiende el walkthrough con **Cost and Usage Report** (CUR) descargable a S3.

## 11. Limpieza

```bash
rm -rf /tmp/aws-17-war
```

No hay recursos AWS que destruir.
