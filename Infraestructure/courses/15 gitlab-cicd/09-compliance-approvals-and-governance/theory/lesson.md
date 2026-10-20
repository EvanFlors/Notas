# gl-09 — Lección: compliance, approvals y governance

> 10 secciones. Mayoritariamente conceptual. Prerrequisitos: `gl-07`, `gl-08`.

---

## 1. Por qué hablar de "governance" después de los pipelines

En los módulos anteriores aprendiste a **escribir** pipelines (`gl-02`, `gl-04`), **reutilizarlos** (`gl-05`), **operar runners** (`gl-06`), **modelar deployments** (`gl-07`) y **asegurar la cadena de suministro** (`gl-08`). Todo eso resuelve el problema desde el punto de vista del equipo que escribe cada pipeline.

El problema de este módulo es el **inverso**: cuando la organización crece a 20, 50 o 500 projects, el equipo de **plataforma + compliance + security** necesita garantizar que **ningún** project pueda — por descuido o por mala fe — mergear a `main` sin SAST, pushear un `.env` o desactivar la firma de commits. El contrato ya no se escribe en el `.gitlab-ci.yml` de cada project; se escribe **por encima**, a nivel group o instance, y GitLab lo **inyecta**.

> **Idea clave que repetiremos:** el `.gitlab-ci.yml` del project es el **suelo** (lo que el equipo quiere correr). El **Compliance Pipeline** del framework es el **techo** (lo que ningún project puede evitar). Las **approval rules** son la **puerta** (quién autoriza mergear).

Equivalente mental con AWS: el project ≈ una cuenta; el Compliance Framework ≈ una SCP; las approval rules + Code Owners ≈ IAM Identity Center con permission sets.

---

## 2. Compliance Frameworks: la etiqueta que lo cambia todo

Un **Compliance Framework** es una **etiqueta** definida a nivel group (en `Settings → General → Compliance frameworks`). Cada framework tiene:

- **Nombre** (`PCI-DSS`, `SOC2`, `Internal-Baseline`...).
- **Color** y **descripción** (puramente informativo para el humano).
- **Compliance Pipeline configuration** — un *link* a un archivo YAML en un project del grupo, con la forma `path/to/file.yml@group/project:branch` (o la nueva forma con **compliance pipeline execution policies**, en Ultimate reciente).

Un project del grupo puede ser **etiquetado** con uno o más frameworks desde `Project → Settings → General → Compliance frameworks`. En el momento en que un project queda etiquetado:

1. Cualquier pipeline que se dispare en ese project ejecuta **primero** el YAML del Compliance Pipeline.
2. El pipeline del project (`.gitlab-ci.yml`) se **concatena después**: lo trae con un `include:` controlado por GitLab.
3. El project puede **extender** jobs del compliance pipeline (añadir stages, añadir jobs), pero **no puede sobreescribir** los jobs del framework ni retirarlos.

Esto es, en esencia, **pipeline injection controlada por el grupo**. Es lo que GitHub llama *required workflows*.

> **Nota didáctica:** Compliance Frameworks está en Premium, pero el **pipeline injection** sólido (con policies y evaluación por rama) está en **Ultimate**. En Fase 4 debes verificar la vigencia porque GitLab mueve features entre tiers.

---

## 3. Compliance Pipeline: anatomía del YAML inyectado

Un compliance pipeline típico vive en un project dedicado — por ejemplo `platform/compliance-pipelines` — y contiene:

```yaml
# compliance-pipeline.yml  (lo mantiene el equipo de compliance)
include:
  # Trae el pipeline del project consumidor.
  - project: '$CI_PROJECT_PATH'
    file: '$CI_CONFIG_PATH'
    ref: '$CI_COMMIT_REF_NAME'

stages:
  - compliance
  - build
  - test
  - deploy
  - compliance-post

compliance:sast:
  stage: compliance
  image: registry.gitlab.com/security/sast:latest
  script:
    - sast-run --fail-on high
  allow_failure: false
  rules:
    - if: '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH || $CI_PIPELINE_SOURCE == "merge_request_event"'

compliance:secret-detection:
  stage: compliance
  image: registry.gitlab.com/security/secrets:latest
  script:
    - secret-scan --baseline .gitlab/secret-baseline.yml
  allow_failure: false

compliance:license-report:
  stage: compliance-post
  script:
    - gl-license-report --out licenses.json
  artifacts:
    reports:
      license_scanning: licenses.json
```

Lectura clave:

- `include:` con `$CI_PROJECT_PATH` / `$CI_CONFIG_PATH` es la **inversión de control**: en vez de que el project incluya el framework, el framework incluye al project. Esto permite que compliance "envuelva" cualquier project sin que éste lo sepa.
- Los jobs del framework usan prefijos (`compliance:*`) para no colisionar con nombres del project.
- `allow_failure: false` es el candado: si SAST o Secret Detection fallan, el pipeline del project **no** continúa.
- `rules:` se escriben pensando en MRs **y** push a `default_branch`.

> **Idea clave:** el `include:` recíproco no es un hack; es el **patrón oficial** documentado para compliance pipelines antes de las policies modernas. Las nuevas **Pipeline Execution Policies** (Ultimate) ofrecen una sintaxis declarativa superior, pero el patrón del `include:` sigue funcionando y es más fácil de enseñar.

---

## 4. MR Approval Rules: el filtro humano antes del merge

Un **MR Approval Rule** es una condición que debe cumplirse antes de que un Merge Request pueda mergearse. Vive en `Project → Settings → Merge Requests → Merge request approvals`. Opciones principales:

- **Approvers**: usuarios o grupos cuya aprobación cuenta.
- **Approvals required**: número mínimo (p. ej. 2).
- **Rule by target branch**: la regla sólo aplica a MRs cuyo target es `main` (o `release/*`).
- **Code Owners**: si el MR toca paths listados en `CODEOWNERS`, los owners de esos paths deben aprobar.
- **Security approvals** (Ultimate): si el pipeline del MR produce findings de SAST/DAST/Dependency de severidad ≥ `high`, la aprobación del grupo `security` es obligatoria.
- **Prevent author approval** y **Prevent committers from approving**: ortogonal al número de approvers; cierra el loophole del self-approval.
- **Require password to approve**: audit trail más fuerte.
- **Reset approvals on new commits**: si alguien pushea tras aprobación, se resetea.

Representación típica en YAML (lo que escribirás en la actividad 01, pensado para que un script lo aplique con la API):

```yaml
# approval-rules.yml
project: group/subgroup/checkout
rules:
  - name: default-two-approvers
    applies_to_all_protected_branches: true
    approvals_required: 2
    reset_on_push: true
    prevent_author_approval: true
    prevent_committers_approval: true

  - name: security-high-findings
    applies_to_all_protected_branches: true
    report_type: vulnerability
    severity_levels: [high, critical]
    approvals_required: 1
    users_or_groups:
      - group: group/security

  - name: codeowners
    applies_to_all_protected_branches: true
    code_owner_approval_required: true
```

> **Idea clave:** `code_owner_approval_required` **no** sustituye al número de approvers; es un filtro **adicional**. Un MR que toca `/infra/` necesitará el approval de los owners de `/infra/` **más** los 2 approvers del `default-two-approvers`.

---

## 5. Code Owners: el fichero `CODEOWNERS`

El archivo `CODEOWNERS` vive en la raíz del repo, en `.gitlab/CODEOWNERS` o en `docs/CODEOWNERS`. Sintaxis:

```CODEOWNERS
# Default owners para todo el repo
*                               @group/platform

# Infra: dos equipos co-owners.
/infra/                         @group/platform @group/sre
/terraform/                     @group/platform @group/sre

# Compliance: cambios en el pipeline son del equipo de compliance.
/.gitlab-ci.yml                 @group/compliance
/.gitlab/                       @group/compliance

# Seguridad del dominio pago.
/src/payments/                  @group/security @group/payments

# Secciones nombradas (opcional, para separar reglas por categoría).
[Documentation]
docs/                           @group/docwriters

[Compliance] @group/compliance
.gitlab-ci.yml
.gitlab/
```

Comportamiento:

- Si `code_owner_approval_required: true` está activo en el protected branch target del MR, cada **sección sin aprobación** bloquea el merge.
- Secciones nombradas en `[Compliance]` permiten pedir N approvers de un equipo, no de todos los paths; útil cuando compliance quiere firmar explícitamente aunque no todos los files toquen `/infra/`.

---

## 6. Protected branches y tags: quién puede qué

En `Project → Settings → Repository → Protected branches`:

- **Allowed to push and merge** / **Allowed to merge** / **Allowed to push** son listas separadas. Lo típico en `main`:
  - **Push**: `No one` (ni siquiera maintainers; sólo CI/CD vía un token con permisos elevados).
  - **Merge**: `Maintainers` (los developers abren MR; maintainers mergean).
- **Code owner approval required**: enlaza al `CODEOWNERS` descrito arriba.
- **Allowed to force push**: `No one`. Siempre.

Para tags, lo típico es proteger `v*` y permitir sólo a CI/CD (vía deploy token o Project Access Token) crear tags, nunca a humanos a mano.

---

## 7. Push rules: el muro antes del commit

Las **push rules** se configuran en `Project → Settings → Repository → Push rules` (Premium+). Las más usadas en un baseline:

- **Commit message**: regex como `^(JIRA|SEC)-\d+:` para forzar referencia a ticket.
- **Deny commit message**: regex como `WIP|fixup!|TODO:` para rechazar mensajes vagos.
- **Branch name**: regex como `^(feature|fix|chore|release)/[a-z0-9-]+$`.
- **Commit author**: `@corp\.example\.com$` para rechazar emails personales.
- **Reject unsigned commits**: fuerza firma GPG/SSH.
- **Prevent pushing secret files**: GitLab trae una lista built-in que rechaza `*.pem`, `id_rsa`, `.env`, etc. Puedes añadir regex propias.
- **File size limit**: p. ej. 50 MB para evitar binarios accidentales.

> **Idea clave:** una push rule rechaza en `pre-receive`, antes de que el commit entre al repo. Un hook de pipeline rechaza **después**: el commit ya está. Por eso push rules son más baratas (sin runner, sin minutos) para prevenir casos obvios.

---

## 8. Audit events: el otro cliente del CI/CD

GitLab genera **audit events** por cada acción sensible: cambio de visibility, cambio de protected branch, aprobación de MR, creación de deploy token, cambio de rol, borrado de project, acceso a repository... Los eventos viven en 3 scopes: **project**, **group**, **instance**.

En Ultimate puedes **streamear** audit events a un destino HTTP (SIEM) o a Amazon S3. En Premium los ves en la UI y los exportas en CSV.

Eventos clave para un auditor:

- `user_access_granted_to_project`
- `project_visibility_changed`
- `protected_branch_updated` / `protected_branch_removed`
- `merge_request_approved`
- `deploy_token_created`
- `pipeline_schedule_created`
- `group_runner_created`
- `compliance_framework_assigned_to_project`
- `audit_streaming_destination_updated` (meta-event: alguien tocó el propio streaming)

Un SIEM típico (Splunk/Elastic/Datadog) ingesta estos eventos y los correlaciona con los logs del cluster y del cloud. Es la **misma pata** que CloudTrail en AWS: sin audit stream, no hay forensics ni demostración de compliance.

---

## 9. RBAC, SSO, SCIM, IP allowlist

- **RBAC**: `Guest / Reporter / Developer / Maintainer / Owner`. Developer es el default razonable; Maintainer es quien mergea; Owner cambia settings del group. En compliance mode, Owner suele ser un grupo pequeño con MFA obligatorio.
- **SSO (SAML)**: integras el IdP corporativo (Okta/Entra ID/Google Workspace). En Premium+ puedes forzar que **toda** la sesión al group pase por SSO (`SAML SSO enforce`).
- **SCIM** (Ultimate self-managed / Premium saas): provisioning automático. Cuando RRHH quita a alguien del IdP, GitLab lo deprovisona del group sin intervención manual.
- **IP allowlist** (Ultimate): restringe accesos al group a un rango de IPs. Útil para proveedores externos; peligroso si no mantienes la lista.

> **Idea clave:** sin SCIM, el offboarding es manual y lento. El 80% de hallazgos de auditoría en orgs medianas vienen de accesos huérfanos: alguien que salió hace meses sigue teniendo Developer en un project de Prod.

---

## 10. Síntesis: el baseline mínimo defendible

Para una org de 50 proyectos, el baseline que vas a proponer en la actividad 02 debería incluir, como mínimo:

1. **Un Compliance Framework** llamado `Internal-Baseline` aplicado por default a todo project del grupo `workloads/*`.
2. **Un Compliance Pipeline** que corra `SAST`, `Secret Detection` y `Dependency Scanning` como `allow_failure: false`.
3. **Dos frameworks adicionales** (`PCI-Light`, `SOC2`) para proyectos con requisitos extra (p. ej. `checkout`).
4. **Protected branch** `main` con `push=No one`, `merge=Maintainers`, `code_owner_approval_required=true`.
5. **Approval rules**: 2 approvers por default, security approval por findings high/critical, no self-approval.
6. **`CODEOWNERS`** con al menos 3 secciones: `/infra/`, `/.gitlab/`, `/src/<dominio-sensible>/`.
7. **Push rules**: commit message con prefijo `TICKET-\d+`, deny de `.pem/.env/.key`, autor del dominio corporativo, no unsigned commits en `main`.
8. **SSO SAML + SCIM** desde el IdP corporativo.
9. **Audit event streaming** al SIEM corporativo.
10. **IP allowlist** opcional para contratistas externos.

Lo que **no** cae en el baseline (porque frena DX innecesariamente): bloqueo de MRs sin label, approval de 3+ personas por default (deja eso para `release/*`), require password on approve en todo project (sólo en `main` de proyectos regulados).

El criterio general: **mínimo defensible ante auditor, máximo tolerable por developers**. Un baseline que todos los equipos bypassean con PR manuales es un baseline fallido.
