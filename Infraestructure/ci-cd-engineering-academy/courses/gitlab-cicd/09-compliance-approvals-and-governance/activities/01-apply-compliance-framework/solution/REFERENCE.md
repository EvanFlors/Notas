# Referencia — gl-09-01-apply-compliance-framework

Esta es **una** solución defendible. No es *la* única. Úsala para autoevaluar coherencia y completitud, no para copiar.

## 1. `compliance-pipeline.yml`

Decisiones clave:

- **`include` recíproco** con `$CI_PROJECT_PATH` + `$CI_CONFIG_PATH`: patrón oficial para Compliance Pipelines. El framework incluye al project, no al revés — así el project no puede evadir.
- **5 stages**: `compliance → build → test → deploy → compliance-post`. Los centrales (`build`, `test`, `deploy`) son los que el project consumidor extiende.
- **4 jobs de compliance**: `sast`, `secret-detection`, `dependency`, `license-report`. Los 3 primeros en el stage `compliance` (bloquean el pipeline del project). El último en `compliance-post` (reporta, no bloquea el deploy pero deja audit trail).
- **Todos `allow_failure: false`**: la razón de existir del framework es que falle alto si encuentra algo.
- **`rules:` en `sast`** restringe a MRs + default branch (ahorra minutos en branches de feature).

Alternativas:

- Migrar a **Pipeline Execution Policies** (Ultimate reciente): más declarativo, pero requiere Ultimate y la UI de Security Policies. Para enseñanza, el `include:` recíproco es más explícito.
- Dividir el framework en varios YAML (`sast.yml`, `secrets.yml`, `main.yml`) con `include:local`: más mantenible a gran escala, pero overkill para un baseline inicial.

## 2. `CODEOWNERS`

Decisiones clave:

- **Secciones nombradas** (`[Infra]`, `[Compliance]`, `[Payments]`, `[Documentation]`): permiten pedir approval de cada equipo relevante sin fundir todas las reglas.
- **Owners por grupo**, nunca por usuario individual: si Alice rota de equipo, no hay que editar el CODEOWNERS.
- **`.gitlab-ci.yml` y `/.gitlab/`** protegidos por `@group/compliance`: nadie puede cambiar la config de CI sin firma del equipo de compliance. Esto es ortogonal al Compliance Framework (que es a nivel group), y actúa como segunda línea.
- **`[Documentation]`** sin owner por default: en algunos frameworks docs no es bloqueante; aquí sí porque docwriters es un grupo real; podrías marcar la sección como "no bloqueante" en la UI de settings.

## 3. `approval-rules.yml`

Decisiones clave:

- **`default-two-approvers`** con `prevent_author_approval` y `prevent_committers_approval`: cierra el loophole clásico del self-approval en 2 líneas.
- **`codeowners`** como regla separada con `code_owner_approval_required: true`: necesaria para que el `CODEOWNERS` sea **bloqueante**, no sólo documental.
- **`security-high-findings`** con `report_type: vulnerability`: la regla sólo "aparece" cuando el pipeline produce findings high/critical. En el día a día es invisible; en un MR con vulnerabilidad real, pide a security.
- **`release-branch-extra`**: en `release/*` añade 1 release manager. Mantiene el default DX-friendly en feature branches.

Pitfalls que la solución evita:

- No pone `approvals_required: 3` por default → es cargo-cult, frena DX sin ganancia proporcional.
- No lista usuarios individuales como approvers.
- Usa `reset_on_push: true` para que un push post-approval invalide las aprobaciones.

## 4. `README-INTENT.md`

El documento justifica cada decisión y, crucialmente, deja por escrito el **contrato** entre compliance y los equipos consumidores:

- SAST + Secret Detection + Dependency son **obligatorios** y no omitibles.
- El project **puede extender** con jobs propios en los stages estándar.
- El project **no puede** redefinir ni omitir los jobs `compliance:*`.
- Si quiere customizar (p. ej. SAST con reglas custom para su stack), propone un cambio al framework en `platform/compliance-pipelines` vía MR.

Mencionar explícitamente **Compliance Framework**, **CODEOWNERS**, **approval rules**, **SAST** y **Secret Detection** cumple los chequeos de grep del validador.

## 5. Qué no está en la solución y podrías añadir

- Push rules de repo (viven en settings, no en YAML del repo) — se tratan en la actividad 02 del módulo.
- Streaming de audit events — también en la actividad 02 y en la lección §8.
- SSO SAML + SCIM — contexto del baseline, no de este skeleton.
