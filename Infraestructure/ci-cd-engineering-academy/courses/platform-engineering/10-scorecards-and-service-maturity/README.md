# plat-10 — Scorecards y madurez de servicios

## Identificación

- **ID:** `plat-10-scorecards-and-service-maturity`
- **Curso:** `platform-engineering`
- **Nivel:** producción (advanced)
- **Duración estimada:** 4 h
- **Prerrequisitos:** `plat-05` (catalog), `plat-08` (plugins). Opcionalmente `plat-04`.

## Objetivo

Diseñar y operar un sistema de **scorecards** que mida la madurez de cada servicio del catálogo, defina **niveles** (bronze/silver/gold) y publique **adopción** como KPI de la propia plataforma. Al terminar deberías poder justificar qué chequeos pones, cuáles **no**, cómo evitas que el scorecard se gamifique y cómo lo integras con el proceso de **production readiness review (PRR)**.

## Alcance

Este módulo cubre:

- Qué es un **scorecard** y por qué es la respuesta objetiva a *"¿estamos mejorando?"*.
- **Backstage TechInsights / Soundcheck** como implementación de referencia (fact collectors + checks + score), y alternativas comerciales (**OpsLevel**, **Cortex**).
- **Cómo elegir** los chequeos: empezar con **5–8**, no con 50; priorizar los que **miden resultado**, no los que son fáciles de medir; evitar los que inducen *gaming*.
- **Niveles de madurez** (bronze/silver/gold) como camino, no como etiqueta de clasificación social.
- **Adopción** (% de servicios ≥ bronze / silver / gold) como el KPI más honesto que puede publicar la plataforma.
- **Escalation path**: quién ayuda a un equipo a subir de nivel. Sin este punto el scorecard es *stick*, no *carrot*.
- Integración con la **production readiness review (PRR)**: el scorecard **alimenta** la PRR, pero no la reemplaza.
- **Antipatrones** típicos: 50 chequeos triviales, score ponderado opaco, ranking público entre equipos, chequeos que miden "¿tiene el archivo X?" sin preguntar si está vivo.

Lo que **no** cubre (se verá después):

- **DORA / SPACE** y plataforma-como-producto → `plat-11`.
- **Gobernanza y platform SLOs** → `plat-12`.
- Cómo se implementa un **plugin de Backstage** desde cero → `plat-08`.
- Cómo se modela el **catalog** → `plat-05`.

Este módulo es ejecutable de forma **mínima**: todos los ejemplos y actividades funcionan con `python3` + `bash`, sin levantar Backstage. Si tienes `backstage` o `node` instalado, hay notas sobre cómo trasladar el ejercicio allí, pero **el camino principal evita esa dependencia**.

## Materiales

- **`theory/lesson.md`** — lección con 12 secciones.
- **`examples/`** — tres ejemplos (lectura y, en los dos últimos, ejecución local con Python):
  - `01-techinsights-fact-and-check/` — anatomía de un *fact collector* y un *check* al estilo Backstage TechInsights, con un ejemplo YAML comentado.
  - `02-maturity-levels/` — cómo pasar de 5–8 chequeos a 3 niveles (bronze/silver/gold) sin que el peso se vuelva opaco.
  - `03-adoption-dashboard/` — qué métricas se publican, qué cortes se hacen y cómo se evita el ranking entre equipos.
- **`activities/`** — dos actividades **independientes** (sin dependencia entre sí):
  - `01-scorecard-for-capstone/` — diseñar un scorecard real (YAML) con 5–8 chequeos y evaluarlo contra un catálogo sintético usando un script Python local.
  - `02-production-readiness-review-template/` — redactar una plantilla PRR que **cite** el scorecard sin reemplazarlo.
- **`resources/links.md`** — referencias oficiales (TechInsights/Soundcheck, OpsLevel, Cortex) y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar en una frase por qué sin scorecards no hay forma objetiva de responder "¿estamos mejorando?". Nombrar 3 antipatrones de diseño de scorecards. |
| Operativa | Escribir un scorecard YAML con 5–8 chequeos, evaluarlo contra un catálogo y leer los números de adopción. |
| Arquitectónica | Diseñar la relación entre scorecard, niveles de madurez y production readiness review sin solaparlos. |
| Humana | Argumentar por qué un scorecard mal diseñado genera resistencia y por qué el escalation path es parte del diseño, no un extra. |

## Criterios de evaluación

- Explica, con palabras propias, por qué 5–8 chequeos superan a 50.
- Nombra 3 chequeos que **medirían resultado** y 3 que **inducen gaming** (y explica la diferencia).
- Da una definición de bronze/silver/gold defendible para su capstone.
- Entrega las dos actividades con sus validadores estructurales en verde.
- Propone 3 chequeos nuevos tras un *feedback simulado* (criterio del roadmap).

## Entregables

- `scorecard.yaml` + reporte de adopción generados por la actividad `01-scorecard-for-capstone`.
- `PRR-TEMPLATE.md` producido por la actividad `02-production-readiness-review-template`.
- Notas personales sobre antipatrones observados en tu propio capstone.

## Siguiente módulo

→ `plat-11-metrics-dora-space-and-platform-as-product` — del scorecard por servicio a las métricas de la plataforma como producto (DORA, SPACE, adoption, NPS).
