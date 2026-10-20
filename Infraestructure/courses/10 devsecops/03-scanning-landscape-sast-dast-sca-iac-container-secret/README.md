# sec-03 — Panorama de scanning: SAST, DAST, SCA, IaC, container, secret

## Identificación

- **ID:** `sec-03-scanning-landscape-sast-dast-sca-iac-container-secret`
- **Curso:** `devsecops`
- **Nivel:** fundamentos
- **Duración estimada:** 3 h
- **Prerrequisitos:** `sec-01-principles-threat-modeling-and-supply-chain-overview`.

## Objetivo

Mapear **todas las categorías de scanning** que vas a encontrar en un pipeline DevSecOps y poder elegir, con criterio, **qué herramienta por categoría** y **qué política de severidad** aplicar. Al terminar deberías poder dibujar una matriz "capa × herramienta" para un sistema concreto y defender tus elecciones usando el trípode **CVSS × EPSS × KEV**.

Este módulo es **100 % conceptual + ejercicios de decisión**. No se instala Semgrep, Trivy ni gitleaks aquí — eso es trabajo de `sec-04` en adelante. Aquí se construye el **mapa mental** que te permite no confundir SAST con SCA, ni DAST con pentest, ni "fallar en Medium" con una política razonable.

## Alcance

Este módulo cubre:

- Las **siete categorías** de scanning: **SAST**, **DAST**, **SCA**, **IaC scanning**, **container scanning**, **secret scanning** y **CSPM**. Qué miran, cuándo corren, qué cuesta cada una, qué tipo de falsos positivos genera.
- Las herramientas canónicas por categoría — Semgrep, CodeQL, Bandit, OWASP ZAP, Burp, Trivy, Grype, Snyk, Checkov, tfsec, Terrascan, gitleaks, trufflehog, Prowler, Steampipe.
- La **taxonomía de severidad**: **CVSS** (severidad teórica), **EPSS** (probabilidad de explotación), **KEV** (catálogo CISA de vulnerabilidades *ya explotadas*). Por qué CVSS solo es insuficiente y cómo combinarlos.
- **Señal vs ruido**: por qué el triage es el trabajo real y la ejecución es lo barato.
- **Suppressions** vs **exceptions** con justificación y **expiración** — la diferencia entre silenciar un hallazgo con mala higiene y aceptar un riesgo con proceso.
- Cómo elegir **qué scanner por caso** y cómo redactar una **política base** de severidad.

Lo que **no** cubre (se verá después):

- Instalación y configuración concreta de cada scanner — `sec-04` (gitleaks/trufflehog), `sec-05` (Trivy), `sec-06` (Semgrep/CodeQL), `sec-07` (Checkov).
- SBOM y SLSA en profundidad → `sec-08`.
- Firma y attestations → `sec-09`.
- Policy as Code (OPA/Rego) → `sec-10`.
- Admission control en K8s → `sec-11`.

Este módulo es **puramente de taxonomía y decisión**. Las dos actividades son análisis escritos; el único tooling es `bash` + un editor Markdown.

## Materiales

- **`theory/lesson.md`** — lección profunda con 12 secciones.
- **`examples/`** — ejemplos demostrativos (lectura y análisis, no ejecución):
  - `01-scanning-matrix/` — matriz canónica "categoría × herramienta × dónde corre × qué detecta × falsos positivos típicos".
  - `02-cvss-vs-epss-vs-kev/` — tres hallazgos reales analizados con el trípode CVSS/EPSS/KEV para ilustrar cuándo CVSS alto importa poco y cuándo CVSS medio es urgente.
  - `03-exception-policy-sample/` — plantilla de política de excepciones con **justificación**, **compensating control** y **expiración**.
- **`activities/`** — dos actividades **independientes** (sin dependencia entre sí):
  - `01-pick-tooling-for-capstone/` — para un sistema dado (FastAPI + Postgres en EKS, imagen multi-stage, Terraform), decide **qué scanner por capa** y produce la matriz justificada.
  - `02-severity-policy-draft/` — redacta una **política de severidad base** que combine CVSS + EPSS + KEV + ventanas de SLA de remediación.
- **`resources/links.md`** — referencias oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Distinguir SAST, DAST, SCA, IaC, container, secret y CSPM. Explicar la diferencia entre CVSS, EPSS y KEV y por qué los tres son necesarios. |
| Operativa (sin infra) | Dado un stack típico (app + imagen + IaC + repo), elegir una herramienta por capa justificando por costo de FP, lenguaje soportado y punto de ejecución. |
| Arquitectónica | Redactar una política de severidad con SLA de remediación por combinación `(severidad × explotabilidad × exposición)` y proceso de **exception con expiración**. |

## Criterios de evaluación

- Nombra las 7 categorías y una herramienta canónica para cada una.
- Explica, con palabras propias, por qué un CVE con CVSS 9.8 puede ser menos urgente que uno con CVSS 6.5 según EPSS/KEV.
- Dado un stack, justifica inclusiones y exclusiones en su matriz "capa × herramienta".
- Diferencia **suppress** (silenciar un FP) de **exception** (aceptar un riesgo con proceso).
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- Matriz **"capa × herramienta"** para el capstone (sale de la actividad `01-pick-tooling-for-capstone`).
- Documento **política de severidad y excepciones** (sale de la actividad `02-severity-policy-draft`).

## Siguiente módulo

→ `sec-04-secret-scanning-gitleaks-trufflehog-github` — pasamos de taxonomía a instalar y correr el primer scanner concreto: detectar secretos filtrados en código.
