# sec-05 — SCA y container scanning con Trivy

## Identificación

- **ID:** `sec-05-sca-container-scanning-with-trivy`
- **Curso:** `devsecops`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `sec-03` (panorama de scanning: SAST / DAST / SCA / IaC / container / secret), curso **docker** (saber construir imágenes y leer un `Dockerfile`).

## Objetivo

Aprender a **detectar CVEs y misconfigs** en dependencias de 3P y en imágenes contenedor con **Trivy**, elegir una **política de severidad** razonable, integrar el scan en **CI** haciendo fallar el pipeline cuando aparece una vulnerabilidad **CRITICAL** sin excepción documentada, y **reducir el inventario de CVEs** cambiando a una base image más fina (`slim`, `distroless`, `chainguard`) sin perder funcionalidad.

Al terminar deberías poder justificar la política "fallar en `CRITICAL` + warn en `HIGH`" vs "fallar en `MEDIUM`" y defender la elección con argumentos SLO-driven, no de miedo.

## Alcance

Este módulo cubre:

- **Qué es Trivy** y por qué un solo binario cubre SCA + container + IaC + secret + license + SBOM; su posición frente a **Grype** (Anchore) y **Snyk** (comercial).
- Los **modos** de escaneo: `trivy fs`, `trivy image`, `trivy repo`, `trivy config`, `trivy k8s`.
- **Formatos de salida** (table, json, sarif, cyclonedx, spdx) y **upload de SARIF a GitHub Code Scanning**.
- **Política de severidad** con `--severity CRITICAL,HIGH`, `--exit-code 1`, y la diferencia entre **CVSS** (severidad teórica), **EPSS** (probabilidad de explotación) y **KEV** (ya explotados en el mundo real).
- **Suppressions con `.trivyignore`** y por qué cada excepción necesita **razón + expiración + aprobador**.
- La **caché** de la DB de vulnerabilidades (`--cache-dir`) y por qué es crítica en CI para no abusar del endpoint.
- **Trivy Operator** en Kubernetes: cómo despliega CRs `VulnerabilityReport`, `ConfigAuditReport`, `ClusterSbomReport` sobre cada workload.
- Comparación de **fuentes de datos** (NVD, GitHub Advisory, GitLab Advisory DB, OSV, Red Hat Security Data).

Lo que **no** cubre (se verá después):

- Emisión formal de **SBOM** y provenance SLSA → `sec-08`.
- **Firma y attestations** con cosign/sigstore → `sec-09`.
- **Admisión en K8s** verificando firma e imagen escaneada → `sec-11`.
- Políticas corporativas de vuln management lifecycle, exception policy formalizada e inventario centralizado → `sec-14`.

## Materiales

- **`theory/lesson.md`** — lección profunda con 11 secciones (qué es Trivy, por qué un multi-tool, modos, formatos, SARIF, política de severidad, ignores, caché, Trivy Operator, fuentes de datos, decisiones).
- **`examples/`** — tres ejemplos **de lectura y comentario** (no ejecución):
  - `01-trivy-image-ci/` — un job GitHub Actions mínimo que corre `trivy image` sobre la imagen recién construida y falla en `CRITICAL`.
  - `02-sarif-to-github-code-scanning/` — mismo job pero exportando SARIF y subiéndolo a **Code Scanning** para ver hallazgos como alerts en la UI del repo.
  - `03-trivy-operator-in-cluster/` — walkthrough de qué recursos crea el Operator y cómo leerlos (`kubectl get vulnerabilityreports`).
- **`activities/`** — dos actividades **independientes**:
  - `01-scan-and-fail-on-critical/` — construir una imagen deliberadamente vulnerable, escanearla con Trivy, demostrar que falla en `CRITICAL`, documentar un ignore justificado y volver a pasar.
  - `02-reduce-cves-by-base-swap/` — tomar la misma app y cambiar la base image (`python:3.12` → `python:3.12-slim` → `cgr.dev/chainguard/python:latest`), medir la **reducción porcentual de CVEs** y escribir un ADR.
- **`resources/links.md`** — referencias oficiales (Trivy, Aqua, OSV, CISA KEV, FIRST EPSS, Chainguard, Distroless).

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar en una frase qué es SCA, qué es container scanning y por qué Trivy hace ambos con un solo binario. Distinguir CVSS vs EPSS vs KEV. |
| Operativa | Correr `trivy image` y `trivy fs` localmente, interpretar la tabla de hallazgos, filtrar por severidad y por ignore, subir SARIF a GitHub Code Scanning. |
| Arquitectónica | Diseñar una **política de severidad** defendible para una org pequeña (qué falla el merge, qué solo advierte, qué va a nightly) y argumentar por qué `--severity MEDIUM` como gate es insostenible. |
| Platform | Entender qué aporta **Trivy Operator** en K8s frente a correr `trivy image` solo en CI (visibilidad continua vs puntual en build). |

## Criterios de evaluación

- Nombra los **5 modos** de Trivy (`fs`, `image`, `repo`, `config`, `k8s`) y qué consume cada uno.
- Explica por qué `--severity CRITICAL,HIGH --exit-code 1` es un gate razonable para una org naciente y qué cambiaría al madurar.
- Enumera **3 fuentes** de datos de CVEs que Trivy consulta y qué aporta cada una (NVD baseline, GitHub Advisory para ecosistemas de lenguaje, OSV para OSS).
- Dado un `.trivyignore` sin razón ni expiración, lo rechaza con argumentos.
- Mide una **reducción de CVEs** cambiando a una base image más fina y lo registra en un ADR corto.
- Entrega las dos actividades con sus validadores estructurales en verde.

## Entregables

- Pipeline CI del proyecto piloto que **falla en `CRITICAL` sin excepción** (sale de la actividad `01`).
- ADR corto "swap de base image" con la reducción porcentual medida (sale de la actividad `02`).

## Decisiones de diseño del módulo

- **Pin de versión del binario de Trivy**: usamos `aquasec/trivy:0.56.2` siempre que corramos vía Docker, para que los ejemplos sean reproducibles y el output no cambie entre runs. En CI real, pinearías por SHA del action `aquasecurity/trivy-action`.
- **SKIP gracioso**: si no hay `trivy`, `docker` o `kind` en PATH, los validadores reportan `SKIP: ...` y salen `0`. El módulo es ejecutable sin herramientas instaladas (para lectura) y con herramientas instaladas (para práctica real).
- **Sin secretos reales ni costo cloud**: todo corre contra imágenes públicas pequeñas (`alpine:3.14` como blanco deliberadamente vulnerable, `python:3.12`/`python:3.12-slim` para el swap). Ningún registry privado, ningún cloud.
- **Scratch bajo `/tmp/sec-05-*`**: cada actividad usa su propio directorio y lo limpia al final.

## Siguiente módulo

→ `sec-06-sast-with-semgrep-and-codeql` — análisis estático del código fuente (Semgrep + CodeQL) para patrones peligrosos antes de que lleguen a la base image.
