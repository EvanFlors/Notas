# Intent del Compliance Framework Internal-Baseline

Este documento acompaña al skeleton del framework (compliance pipeline + CODEOWNERS + approval rules). Lo lee quien aplicará el framework en Fase 4 y los equipos consumidores que lo "recibirán" en sus projects.

## compliance-pipeline

El archivo `compliance-pipeline.yml` es el **pipeline inyectado** por el Compliance Framework `Internal-Baseline`. Vive en `platform/compliance-pipelines`. Al etiquetar un project del grupo `workloads/*` con el framework, GitLab compone cada pipeline del project ejecutando primero:

- **compliance:sast** — scanner estático de código, bloquea en findings `high`.
- **compliance:secret-detection** — detecta credenciales commiteadas por error, bloquea siempre.
- **compliance:dependency** — SCA de dependencias, bloquea en findings `critical`.
- **compliance:license-report** — reporta licencias en el post-stage, no bloquea deploy pero deja audit trail.

Los 4 son `allow_failure: false`, de modo que si fallan, el pipeline del project **no** continúa a `build` ni a `deploy`. El pattern del `include:` recíproco (`$CI_PROJECT_PATH` + `$CI_CONFIG_PATH`) permite al framework "envolver" cualquier project sin que éste tenga que declararlo. Es la expresión canónica de **Compliance Framework** en GitLab antes de la generación de Pipeline Execution Policies.

## CODEOWNERS

El archivo `CODEOWNERS` plantilla define quién debe aprobar MRs según los paths tocados. Decisiones:

- **Owners por grupo** (`@group/platform`, `@group/sre`, `@group/compliance`, `@group/security`, `@group/payments`, `@group/docwriters`) y nunca por usuario individual: evita que la rotación de personas rompa reglas.
- **Secciones nombradas** (`[Infra]`, `[Compliance]`, `[Payments]`, `[Documentation]`) para pedir approval explícito de cada equipo relevante.
- **Protección de `.gitlab-ci.yml` y `/.gitlab/`** por `@group/compliance`: segunda línea para que nadie altere la config de CI sin firma de compliance, independientemente del framework del group.

Code Owners por sí solo es sólo documentación. Para que **bloquee** el merge, debe existir la regla `codeowners` en `approval-rules.yml` con `code_owner_approval_required: true`, descrita abajo.

## approval-rules

El archivo `approval-rules.yml` describe de forma declarativa las **approval rules** que un script de Fase 4 aplicará con la API de GitLab:

- **`default-two-approvers`**: 2 approvers del grupo `workloads/checkout-reviewers`, con `prevent_author_approval` y `prevent_committers_approval` para cerrar el self-approval. `reset_on_push: true` invalida aprobaciones si alguien pushea código nuevo.
- **`codeowners`**: `code_owner_approval_required: true` convierte el `CODEOWNERS` en bloqueante.
- **`security-high-findings`**: si el pipeline produce findings `high` o `critical` de SAST/Dependency, pide approval adicional del grupo `platform/security`.
- **`release-branch-extra`**: sólo aplica a `release/*`, pide 1 release manager extra.

Juntas, las reglas forman las tres **puertas** del módulo:
1. El pipeline (que incluye el Compliance Pipeline inyectado — SAST, Secret Detection, Dependency).
2. Las approval rules (approvers + Code Owners + security findings).
3. El protected branch (push=No one, merge=Maintainers), que vive en settings del repo y no en este YAML.

## Lo que el project puede y no puede sobrescribir

El project consumidor (p. ej. `workloads/checkout`) **puede extender** el framework:

- Añadir stages adicionales (`qa`, `smoke`, `canary`) después de los declarados por el framework.
- Añadir jobs propios en los stages `build`, `test`, `deploy`.
- Pasar `variables:` que el framework consume.
- Proponer cambios al propio framework vía MR al repo `platform/compliance-pipelines`.

El project consumidor **no puede omitir** el framework:

- No puede borrar los jobs `compliance:*` (están definidos en el YAML del framework; cualquier job local con el mismo nombre se solapa con el del framework, y el del framework gana el segundo include).
- No puede cambiar `allow_failure` de los jobs del framework.
- No puede modificar `rules:` para que los jobs se saltan en su branch.
- No puede desetiquetar el project del framework desde su propia UI; sólo un Owner del grupo puede hacerlo, y esa acción genera un **audit event** (`compliance_framework_unassigned_from_project`) que debería alertar al equipo de compliance.

En resumen: la **extensión** es libre, la **omisión** es imposible desde el project. Esto es gobernanza como código real, no sólo documental.
