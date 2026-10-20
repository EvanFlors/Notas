# Recursos — jk-03 Declarative Pipeline

## Documentación oficial

- [Pipeline — Getting started](https://www.jenkins.io/doc/book/pipeline/) — introducción oficial a Pipeline-as-Code.
- [Pipeline Syntax (Declarative)](https://www.jenkins.io/doc/book/pipeline/syntax/) — referencia completa de la sintaxis declarative.
- [Pipeline Steps Reference](https://www.jenkins.io/doc/pipeline/steps/) — catálogo de todos los steps disponibles por plugin.
- [Using credentials](https://www.jenkins.io/doc/book/using/using-credentials/) — gestión del credentials store.
- [Jenkinsfile best practices](https://www.jenkins.io/doc/book/pipeline/pipeline-best-practices/) — recomendaciones oficiales de mantenibilidad.

## Linting y validación

- [Pipeline Model Definition plugin](https://plugins.jenkins.io/pipeline-model-definition/) — plugin que habilita el `declarative-linter` HTTP.
- [`jenkins-cli declarative-linter`](https://www.jenkins.io/doc/book/pipeline/development/#linter) — invocación por CLI.
- [`pipeline-model-converter/validate` HTTP endpoint](https://www.jenkins.io/doc/book/pipeline/development/#linter) — para integrar en pre-commit sin instalar la CLI.

## Patrones y comparación con otros stacks

- [GitHub Actions workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions) — referencia para portar workflows a Jenkinsfile (actividad `01`).
- [Argo Workflows vs Jenkins](https://argoproj.github.io/argo-workflows/) — para contextualizar cuándo *no* elegir Jenkins (ver `jk-01`).

## Lecturas recomendadas

- Jenkins Handbook, cap. *Pipeline* — manual de la Fundación Jenkins.
- *Continuous Delivery with Jenkins Pipeline* — Nikhil Pathania (Packt) — buen complemento práctico.
- [Jenkins CVE feed](https://www.jenkins.io/security/advisories/) — para disciplina de parcheo (relevante en `jk-07`).

## Herramientas de apoyo

- `jq` — manipulación de JSON (no específico de Jenkins, útil para extraer datos de la API).
- `yq` — equivalente YAML; útil al portar workflows GHA.
- `shellcheck` — para los `sh` dentro del Jenkinsfile.
