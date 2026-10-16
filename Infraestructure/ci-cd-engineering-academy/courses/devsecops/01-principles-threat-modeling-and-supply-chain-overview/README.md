# sec-01 — Principios, threat modeling y supply chain

## Identificación

- **ID:** `sec-01-principles-threat-modeling-and-supply-chain-overview`
- **Curso:** `devsecops`
- **Nivel:** fundamentos
- **Duración estimada:** 4 h
- **Prerrequisitos:** curso **docker**, curso **github-actions**. No se requiere instalar nada en este módulo.

## Objetivo

Interiorizar los **principios** de DevSecOps (shift-left + defense-in-depth), practicar **threat modeling** con **STRIDE** y entender la **supply chain** como superficie de ataque. Al terminar deberías poder modelar amenazas de un servicio simple en una página, distinguir los niveles de **SLSA**, y explicar en qué se diferencian **SBOM** y **provenance**.

## Alcance

Este módulo cubre:

- **DevSecOps vs "security team al final"**: por qué pegar seguridad al final del pipeline fracasa, y por qué shift-left + defense-in-depth son complementarios (no sustitutos).
- **Threat modeling práctico con STRIDE** (Spoofing, Tampering, Repudiation, Information disclosure, Denial of service, Elevation of privilege): cómo aplicarlo sin ceremonia pesada.
- **Data flow diagrams (DFD)** mínimos y **trust boundaries**: cómo dibujar lo justo para que las amenazas emerjan.
- **Supply chain** como superficie: **SolarWinds**, **log4shell**, **xz-utils**, **tj-actions** como casos reales de aprendizaje.
- **SLSA v1.0** niveles 1–4 (visión conceptual): L1 build script, L2 provenance hospedado, L3 non-forgeable, L4 (futuro).
- **SBOM** (inventario) vs **provenance** (historia): dos artefactos distintos, dos preguntas distintas.

Lo que **no** cubre (se verá después):

- Secretos y rotación → `sec-02`.
- Taxonomía de scanners (SAST, DAST, SCA, IaC, container, secret) → `sec-03`.
- Emitir y verificar SBOM/provenance en la práctica → `sec-08`.
- Firma de artefactos con cosign → `sec-09`.

Este módulo es **100 % conceptual**. No se levanta infraestructura. Las actividades son análisis escritos que se validan con `bash`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-stride-of-fastapi-service/` — STRIDE aplicado a un servicio FastAPI simple con DB y cache.
  - `02-dfd-capstone/` — DFD mínimo del capstone con trust boundaries marcados.
  - `03-slsa-levels-walkthrough/` — recorrido guiado por los 4 niveles de SLSA v1.0 con ejemplos de qué hace falta en cada uno.
- **`activities/`** — dos actividades **independientes** (sin dependencia entre sí):
  - `01-threat-model-exercise/` — producir un threat model STRIDE de un servicio dado.
  - `02-slsa-gap-analysis/` — mapear nivel SLSA actual del capstone contra el deseado, con roadmap.
- **`resources/links.md`** — referencias oficiales y lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Definir DevSecOps sin recurrir al cliché "shift-left". Explicar por qué shift-left y defense-in-depth no se oponen. Nombrar las 6 letras de STRIDE y una amenaza típica de cada una. |
| Operativa (sin infra) | Dado un servicio simple (una API con DB), dibujar su DFD mínimo, marcar trust boundaries y producir una tabla STRIDE con 1–2 amenazas por letra y mitigaciones priorizadas. |
| Arquitectónica | Clasificar un pipeline existente en nivel SLSA (L0/L1/L2/L3) y proponer el delta concreto para subir un nivel. Diferenciar SBOM de provenance con un ejemplo. |

## Criterios de evaluación

- Explica, con palabras propias, por qué eliminar un **vector** es más barato que detectar un **abuso**.
- Nombra las 6 letras de STRIDE y da una amenaza típica de cada una en el contexto de un servicio web.
- Dado un pipeline (GitHub Actions con `docker build` + `docker push`), identifica en qué nivel SLSA está y qué le falta para L2 y L3.
- Distingue **SBOM** de **provenance** con un ejemplo concreto.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- Threat model documentado (sale de la actividad `01-threat-model-exercise`).
- Mapa de niveles SLSA actuales vs deseados con roadmap (sale de la actividad `02-slsa-gap-analysis`).

## Siguiente módulo

→ `sec-02-secrets-overview-and-principles` — dónde pueden vivir los secretos y qué principios aplican antes de elegir una herramienta.
