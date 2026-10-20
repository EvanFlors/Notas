# sec-06 — SAST con Semgrep y CodeQL

## Identificación

- **ID:** `sec-06-sast-with-semgrep-and-codeql`
- **Curso:** `devsecops`
- **Nivel:** intermedio
- **Duración estimada:** 4 h
- **Prerrequisitos:** `sec-03-scanning-landscape-sast-dast-sca-iac-container-secret`.

## Objetivo

Entender **SAST** (Static Application Security Testing): qué puede y qué **no puede** detectar, cuándo elegir **Semgrep** (rápido, reglas declarativas), cuándo **CodeQL** (motor de dataflow, nativo de GitHub Code Scanning) y cuándo complementar con **Bandit** (Python). Al terminar deberías poder meter SAST en un pipeline sin generar fatiga de alertas, y escribir al menos **una regla custom** para un patrón específico de tu organización.

## Alcance

Este módulo cubre:

- Qué es SAST y por qué no reemplaza a SCA, DAST ni a los tests.
- **Semgrep**: patrón declarativo tipo "código con huecos", registry público, reglas locales en `.semgrep/`, integración CI.
- **CodeQL**: AST + dataflow + taint-tracking, **modo primario como GitHub Code Scanning** (hosted). Walkthrough del workflow `codeql.yml` oficial. La CLI local se menciona pero el módulo asume Code Scanning como camino canónico.
- **Bandit**: reglas canónicas de seguridad para Python, útil como refuerzo barato.
- **Reglas custom**: cuándo escribirlas (patrón específico tuyo, no cubierto por registry), estructura mínima, cómo probarlas.
- **Triage**: `# nosemgrep`, `// codeql[rule-id]`, excepciones justificadas con TTL.
- **Falsos positivos** y por qué SAST sin dataflow es ruidoso.

Lo que **no** cubre:

- Snyk Code / Checkmarx / Veracode (comerciales equivalentes) — se nombran, no se profundiza.
- IaC scanning (`sec-07`), secret scanning (`sec-04`), DAST (otro curso).
- SARIF upload desde terceros — se vio ya en `sec-05` con Trivy.

## Materiales

- **`theory/lesson.md`** — lección profunda: 10 secciones (qué es SAST, Semgrep en profundidad, CodeQL en profundidad, Bandit, reglas custom, triage, FP/FN, pipeline integration, elección de herramienta, antipatrones).
- **`examples/`** — tres ejemplos de lectura:
  - `01-semgrep-ci/` — un workflow mínimo de GitHub Actions que corre Semgrep sobre el repo y publica SARIF.
  - `02-codeql-github-advanced-security/` — walkthrough del workflow oficial `codeql.yml` con autobuild + build manual, cómo se habilita Code Scanning y cómo se lee un Alert.
  - `03-custom-rule-for-org/` — una regla Semgrep custom en YAML y un `.ql` CodeQL de ejemplo, con sus unit tests.
- **`activities/`** — dos actividades independientes:
  - `01-add-sast-to-capstone/` — meter Semgrep + Bandit en un repo Python ejemplo y configurar un workflow CodeQL (doc-only); clasificar 10 findings.
  - `02-write-custom-rule/` — escribir una regla Semgrep para un patrón organizacional (`requests.get(...)` sin `timeout=`), con tests.
- **`resources/links.md`** — docs oficiales.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Diferenciar SAST de SCA, DAST y tests. Saber cuándo pedir **dataflow** (CodeQL) y cuándo basta pattern-matching (Semgrep). |
| Operativa | Integrar Semgrep y Bandit en CI; redactar un workflow `codeql.yml`; interpretar SARIF; triar un finding con criterio (fix / suppress con razón / FP). |
| Diseño de reglas | Escribir una regla Semgrep custom con `metavariable-pattern`, un `message`, `severity`, y tests `rule-id.yaml` + fixtures `ok`/`bad`. |

## Criterios de evaluación

- Explica por qué CodeQL es más preciso que Semgrep (dataflow) y más lento.
- Dado un workflow `codeql.yml`, identifica si usa `autobuild` o `build manual`.
- Dados 10 findings, decide fix / suppress-con-razon / FP y justifica.
- Entrega una regla custom funcional con `ok` y `bad` fixtures.

## Entregables

- Pipeline del capstone con Semgrep + Bandit + CodeQL (último doc-only) y una regla custom.
- Documento con el triage de los 10 findings.

## Siguiente módulo

→ `sec-07-iac-scanning-checkov-trivy-config-tfsec` — misconfig en Terraform/K8s/CloudFormation antes de aplicar.
