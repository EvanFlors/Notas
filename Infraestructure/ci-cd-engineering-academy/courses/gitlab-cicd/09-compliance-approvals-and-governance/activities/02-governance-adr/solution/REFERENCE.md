# ADR 001 — Baseline de gobernanza GitLab (solución de referencia)

> Esta es **una** solución defendible, no *la* única. Úsala para contrastar completitud y coherencia tras escribir la tuya.

## Estado

Propuesto — a aprobar por CTO + Head of Security + Head of Compliance antes de arrancar la migración GHA → GitLab.

## Contexto

Fintech de 180 personas (90 ingenieros, 20 data, 10 security, resto negocio) con 50 proyectos activos en GitHub Enterprise Cloud. Migramos a GitLab SaaS por tres razones: consolidar en una plataforma única (hoy pipelines en GHA + registry en Harbor + security scans en herramientas sueltas), preparar auditoría **SOC2 Type II** en 12 meses, y mantener compatibilidad con el programa **PCI-DSS** del equipo `checkout`.

Constraints:

- **Compliance**: ISO 27001 ya certificada; SOC2 Type II objetivo en 12 meses; `checkout` requiere PCI-DSS scope reducido.
- **IdP**: Okta ya es la fuente única de identidad corporativa. SCIM obligatorio para offboarding en < 24h.
- **SIEM**: Splunk corporativo en producción; audit events deben ingerirse ahí.
- **DX**: los developers vienen de GHA y "no quieren que GitLab les frene". Baseline debe ser *mínimo defensible*, no *máximo controlable*.
- **Coste**: Ultimate es ~3× Premium per-user; justificar.

Workloads heterogéneos:

- `checkout` — pagos, PCI, SLA 99.9%.
- `fraud-detection` — ML, lee datos de checkout pero no toca tarjetas.
- `internal-tools` — 20+ projects pequeños, propiedad diluida.
- `website` — marketing, bajo riesgo.

## Decisión

### 1. Tier: **Ultimate**

Features que **requieren Ultimate** y que son innegociables en nuestro baseline:

- **Pipeline Execution Policies** (sucesor moderno de Compliance Pipelines) — pipeline injection declarativa, auditable, con scoping por branch.
- **MR Approval Policies con security_findings** por severidad (`report_type: vulnerability`).
- **Audit event streaming** a Splunk HEC (en Premium sólo exportas CSV manual).
- **SAST/DAST/Dependency/Secret Detection** completos (en Free el set es limitado).
- **SCIM provisioning** desde Okta (Premium en SaaS lo trae, confirmar en Fase 4).

Coste: ~3× Premium per-user. Justificado porque las 4 features bloqueantes son auditables como control SOC2 (CC7.2) y SOC2 CC6.1.

### 2. Compliance Frameworks

Definimos **3 frameworks** a nivel de la top-group:

- **`Internal-Baseline`** → aplicado por default a **todo** project del grupo `workloads/*`. Pipeline inyectado: SAST + Secret Detection + Dependency Scanning, todos `allow_failure: false`. Mantenido por `@group/compliance`.
- **`PCI-Light`** → aplicado adicionalmente a `checkout` (y a cualquier project que toque datos de tarjeta). Añade Container Scanning + firma cosign obligatoria + reporte de licencias.
- **`Marketing`** → aplicado a `website`. Pipeline **más laxo**: sólo Secret Detection y lint, sin SAST pesado. Reduce fricción donde no aporta.

Clave: `internal-tools` **también** lleva `Internal-Baseline`. No queda nada "sin cubrir".

### 3. MR Approval rules

Tres reglas por default en todo project (plus una extra en `release/*`):

- **`default-two-approvers`** — `approvals_required: 2`, `prevent_author_approval: true`, `prevent_committers_approval: true`, `reset_on_push: true`.
- **`codeowners`** — `code_owner_approval_required: true`. Hace **bloqueante** el `CODEOWNERS`.
- **`security-high-findings`** — `report_type: vulnerability`, `severity_levels: [high, critical]`, `approvals_required: 1` del grupo `platform/security`. Invisible en el día a día, bloqueante en MRs con vulnerabilidad real.
- **`release-branch-extra`** — en `release/*`, pide `+1 release manager`.

Para `checkout` (PCI) añadimos una **cuarta** regla: `approvals_required: 3` en MRs a `main` que tocan `/src/payments/`.

### 4. CODEOWNERS plantilla

Owners **por grupo**, nunca por usuario. Secciones:

- `[Platform]` default `@group/platform`.
- `[Infra]` `/infra/`, `/terraform/` → `@group/platform @group/sre`.
- `[Compliance]` `.gitlab-ci.yml`, `/.gitlab/` → `@group/compliance`.
- `[Security]` `/src/payments/`, `/db/migrations/` → `@group/security @group/payments`.

### 5. Protected branches

- `main`: push=No one, merge=Maintainers, `code_owner_approval_required=true`, allow force push=No one.
- `release/*`: idem + merge sólo `@group/release-managers`.
- Protected **tags** `v*`: create=`CI/CD only` (vía project access token con scope `write_repository`), ningún humano puede crear tags a mano.

### 6. Push rules

Configuradas en todo project vía API al crear:

- **Commit message regex** `^(JIRA|SEC|OPS)-\d+:` — fuerza referencia a ticket.
- **Deny secret files** (built-in list: `*.pem`, `.env`, `id_rsa`, `*.key`) + regex custom para `credentials.(json|yml)`.
- **Author email regex** `^[a-z.]+@corp\.example\.com$` — rechaza commits con email personal.
- **Reject unsigned commits** — fuerza firma GPG/SSH.
- **File size limit** 50 MB — evita binarios accidentales.
- **Branch name regex** `^(feature|fix|chore|release)/[a-z0-9-]+$`.

### 7. SSO / SCIM

- **SAML SSO** contra Okta, con `enforce SSO for group` activo. Nadie accede al grupo sin pasar por Okta.
- **SCIM provisioning** obligatorio: creación / baja de usuarios automatizada desde Okta. SLA de offboarding < 24h.
- **IP allowlist**: no activa por default. Opcional para subgroups con contratistas externos.

### 8. Audit event streaming

- Destino: **Splunk HEC** corporativo (endpoint HTTPS con token mTLS).
- Eventos alertados en el SIEM (SOAR rule):
  - `protected_branch_removed` sobre `main` o `release/*` → P1.
  - `compliance_framework_unassigned_from_project` → P1.
  - `project_visibility_changed` private → public → P2.
  - `deploy_token_created` con `write_repository` → P2.
  - `audit_streaming_destination_updated` → P1 (meta-evento: alguien intentó silenciar el stream).

### 9. Diagrama end-to-end

```text
                     developer
                        │
                        ▼ git push
                 ┌─────────────────┐
                 │ Push rules      │  ← commit msg regex, deny secrets,
                 │ (pre-receive)   │     signed commits, author domain
                 └────────┬────────┘
                          │ (si pasa)
                          ▼
                 ┌─────────────────┐
                 │ Pipeline        │
                 │  Compliance:    │  ← SAST / Secret / Dependency
                 │   (framework)   │
                 │  Project:       │  ← build / test / deploy del equipo
                 │   (.gitlab-ci)  │
                 └────────┬────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │ MR Approvals    │  ← default-two-approvers,
                 │                 │     codeowners (bloqueante),
                 │                 │     security-high-findings
                 └────────┬────────┘
                          │ (si pasa)
                          ▼
                 ┌─────────────────┐
                 │ Merge           │  ← Maintainer hace merge en main
                 └────────┬────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │ Audit event     │  ── stream HTTPS ──▶ Splunk HEC
                 │ generado        │                       │
                 └─────────────────┘                       ▼
                                                     SOAR alerts
```

### 10. Mapeo a controles compliance

| Control | Baseline que lo cubre |
|---|---|
| ISO 27001 **A.9.4.5** (restricción de acceso al código fuente) | Protected branches + CODEOWNERS + MR approvals |
| ISO 27001 **A.12.4.1** (registro de eventos) | Audit event streaming a Splunk |
| ISO 27001 **A.14.2.2** (procedimientos de control de cambios) | MR approval rules + Code Owners obligatorios |
| SOC2 **CC6.1** (control de acceso lógico) | SAML SSO enforce + SCIM + IP allowlist opcional |
| SOC2 **CC7.2** (monitoreo de operaciones y detección de anomalías) | Audit event streaming + Compliance Pipeline obligatorio |
| PCI-DSS **6.3.2** (revisión de código antes de release) | MR approval rules + `security-high-findings` + framework `PCI-Light` en `checkout` |

## Consecuencias

### Positivas

- **Baseline uniforme** aplicado por default a 50 projects. `internal-tools` deja de ser el agujero crónico de vulnerabilidades.
- **Auditoría SOC2 Type II**: los controles descritos son trazables y evidenciables desde los audit events + settings de GitLab. Reduce horas de preparación en ~60%.
- **Offboarding en < 24h** automatizado vía SCIM. Cierra uno de los 3 hallazgos típicos de auditores en orgs medianas.
- **DX razonable**: 2 approvers y Code Owners por default es equivalente al workflow que ya tienen en GHA. Las push rules son un cambio pequeño con beneficio alto.

### Negativas

- **Coste**: Ultimate ~3× Premium per-user. Para 180 personas, impacto anual significativo. Debe aprobarse en el plan financiero antes de firmar.
- **Fricción inicial**: push rules con regex corporativo rechazarán commits con email personal (frecuente en forks/contrib). Equipo DX debe comunicar el cambio y acompañar 2 semanas.
- **Dependencia del SIEM**: si Splunk cae y no se recoge el stream, auditoría puede marcarlo. Mitigación: GitLab bufferiza eventos del stream; configurar alertas sobre lag del endpoint.
- **Compliance Framework añade minutos de runner** (SAST + Secret + Dependency en todo pipeline). Impacto estimado +2–5 min por pipeline. Compensado por minutos ahorrados en herramientas externas fuera de GitLab.

## Alternativas descartadas

1. **Quedarse en Premium y renunciar a Pipeline Execution Policies + security approvals**. Más barato, pero obliga a construir controles manuales fuera de GitLab (scripts, revisiones ad hoc) que no son auditables de forma trazable. SOC2 Type II exigiría re-trabajo significativo. Rechazado.

2. **GitLab self-managed en nuestro propio Kubernetes**. Daría control total y menor coste per-user a escala, pero añade operación de la plataforma a un equipo de 3 personas sin capacity. Rechazado para la Fase 1; re-evaluar cuando pasemos de 500 usuarios.

3. **Mantener GHA y añadir herramientas de compliance encima** (p. ej. Allstar, SOC2 OSS tooling). Preserva la familiaridad del equipo pero no resuelve la consolidación de registry/scans y multiplica superficies de audit. Rechazado.
