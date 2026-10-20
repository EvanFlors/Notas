# Starter — gl-09-01-apply-compliance-framework

Esta actividad es **independiente**: tu entregable son 4 archivos de texto que escribes tú.

## Pasos

1. Lee `../README.md` completo y recorre los tres `examples/` del módulo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gl-09-framework
   cd /tmp/gl-09-framework
   ```
3. Crea los 4 archivos:
   - `compliance-pipeline.yml` — pipeline inyectado con SAST + Secret Detection.
   - `CODEOWNERS` — owners por grupo, 3+ secciones.
   - `approval-rules.yml` — 2 approvers + code owners + security findings.
   - `README-INTENT.md` — 4 secciones justificando cada archivo.
4. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/gitlab-cicd/09-compliance-approvals-and-governance/activities/01-apply-compliance-framework/tests/validate.sh /tmp/gl-09-framework
   ```
5. Compara con `../solution/REFERENCE.md`.

## Plantillas sugeridas (opcional)

### `compliance-pipeline.yml`

```yaml
# Mantenido por el equipo de compliance en platform/compliance-pipelines
include:
  - project: '$CI_PROJECT_PATH'
    file: '$CI_CONFIG_PATH'
    ref: '$CI_COMMIT_REF_NAME'

stages:
  - compliance
  - build
  - test
  - deploy

compliance:sast:
  stage: compliance
  image: registry.gitlab.com/security/sast:latest
  script:
    - sast-run --fail-on high
  allow_failure: false

compliance:secret-detection:
  stage: compliance
  image: registry.gitlab.com/security/secrets:latest
  script:
    - secret-scan
  allow_failure: false
```

### `CODEOWNERS`

```CODEOWNERS
* @group/platform

[Infra]
/infra/        @group/platform @group/sre

[Compliance]
.gitlab-ci.yml @group/compliance
/.gitlab/      @group/compliance

[Payments]
/src/payments/ @group/security @group/payments
```

### `approval-rules.yml`

```yaml
project: workloads/checkout
rules:
  - name: default-two-approvers
    approvals_required: 2
    prevent_author_approval: true
    prevent_committers_approval: true
    reset_on_push: true
  - name: codeowners
    code_owner_approval_required: true
  - name: security-high
    report_type: vulnerability
    severity_levels: [high, critical]
    approvals_required: 1
```

### `README-INTENT.md`

```markdown
# Intent del Compliance Framework Internal-Baseline

## compliance-pipeline
...

## CODEOWNERS
...

## approval-rules
...

## Lo que el project puede y no puede sobrescribir
...
```

> **Importante:** el validador comprueba estructura, no semántica. La corrección conceptual la revisas tú contra la referencia.
