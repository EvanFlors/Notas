# Starter — gl-09-02-governance-adr

Esta actividad es **independiente**: no hay código ni plantilla que ejecutar. Tu entregable es un ADR Markdown escrito por ti.

## Pasos

1. Lee `../README.md` completo y recorre los tres `examples/` del módulo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gl-09-governance
   cd /tmp/gl-09-governance
   ```
3. Crea `ADR-GOVERNANCE-BASELINE.md` con las 6 secciones requeridas (Estado, Contexto, Decisión, Consecuencias, Alternativas, además del encabezado `# ADR`).
4. Incluye en la Decisión:
   - Un diagrama ASCII del flujo `push → pipeline → approvals → merge → audit` (en code fence).
   - Mención de **Compliance Framework**, **CODEOWNERS**, **protected branches**, **SAML/SSO + SCIM**, **audit events** y un **SIEM**.
   - Al menos 3 approval rules y 3 push rules nombradas.
   - Tier (Premium vs Ultimate) justificado.
   - Tratamiento diferenciado de `checkout` y `internal-tools`.
   - Mapeo a ISO 27001 o SOC2.
5. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/gitlab-cicd/09-compliance-approvals-and-governance/activities/02-governance-adr/tests/validate.sh /tmp/gl-09-governance
   ```
6. Compara tu ADR con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** el validador comprueba estructura y presencia de términos clave, no semántica. La corrección conceptual la revisas tú contra la referencia.

## Plantilla sugerida (opcional)

```markdown
# ADR 001 — Baseline de gobernanza GitLab

## Estado
Propuesto

## Contexto
<por qué: migración desde GHA, 50 projects, ISO 27001, SOC2 en 12 meses, Okta como IdP, Splunk ya corriendo, DX importante>

## Decisión

### 1. Tier y features gated
<Premium vs Ultimate, por qué, qué features justifican el tier>

### 2. Compliance Frameworks
- `Internal-Baseline` para todo project del grupo workloads/*
- `PCI-Light` adicional para checkout
- (ninguno extra para internal-tools, basta con Internal-Baseline)

### 3. MR Approval rules
- default-two-approvers (approvals_required=2, prevent_author_approval)
- codeowners (code_owner_approval_required=true)
- security-high-findings (report_type=vulnerability, severity_levels=[high,critical])

### 4. CODEOWNERS
<secciones y owners por grupo>

### 5. Protected branches
<main: push=No one, merge=Maintainers; release/*: idem + release manager>

### 6. Push rules
- commit message regex `^(JIRA|SEC)-\d+:`
- deny secret files (*.pem, *.env, *.key)
- author email regex `@corp\.example\.com$`
- reject unsigned commits
- max file size 50MB

### 7. SSO/SCIM
<Okta via SAML, SCIM obligatorio, enforce SSO en el group>

### 8. Audit event streaming
<destino Splunk HEC, eventos criticos alertados>

### 9. Diagrama end-to-end
```text
push → push rules → pipeline (compliance + build + test) → approvals (default + codeowners + security) → merge → audit event → Splunk
```

### 10. Mapeo compliance
- ISO 27001 A.9.4.5 → protected branches + CODEOWNERS
- ISO 27001 A.12.4.1 → audit event streaming a Splunk
- SOC2 CC6.1 → SSO SAML + SCIM
- SOC2 CC7.2 → MR approval rules + Compliance Pipeline

## Consecuencias
### Positivas
- ...
### Negativas
- ...

## Alternativas descartadas
### Alt A: quedarse en Premium y renunciar a Pipeline Execution Policies
- Por qué no: ...
### Alt B: forkear GitLab self-managed y customizar
- Por qué no: ...
```
