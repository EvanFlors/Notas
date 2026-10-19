# jk-07 — Seguridad en Jenkins: RBAC, Credentials y Script Approval

## Identificación

- **ID:** `jk-07-security-rbac-credentials-and-script-approval`
- **Curso:** `jenkins`
- **Nivel:** avanzado
- **Duración estimada:** 4 h
- **Prerrequisitos:** `jk-02` (instalación), `jk-06` (JCasC), curso **devsecops** ≥ Nivel 2.

## Objetivo

Endurecer un controller Jenkins — crítico porque históricamente es uno de los componentes de CI/CD con **más CVEs activos**, casi todos originados en plugins. Al terminar deberías poder: diseñar un **modelo de RBAC** con `Role-based Authorization Strategy`, almacenar y consumir **credentials** sin filtrarlas en logs, operar el ciclo del **Groovy sandbox + script approval**, y auditar una instalación legacy priorizando hallazgos por severidad y esfuerzo.

Todo se opera **desde JCasC** (`jenkins.yaml`): es la única forma reproducible de versionar y revisar la configuración de seguridad en PR.

## Alcance

Este módulo cubre:

- **Autenticación**: Jenkins DB local, LDAP, SAML, OAuth/OIDC vía plugin. Cuándo usar cada una.
- **Autorización**: `Role-based Authorization Strategy` plugin (roles **global**, **project**/folder, **node**); `matrix-based security` para granularidad fina.
- **Credentials store**: tipos (`string`, `usernamePassword`, `sshUserPrivateKey`, `file`, `certificate`); scopes (`SYSTEM`, `GLOBAL`, `folder`); binding seguro en pipelines con `withCredentials { ... }` y enmascarado automático en logs.
- **Groovy sandbox + In-process Script Approval**: cada API Groovy nueva requiere aprobación explícita; el flujo real que debe seguir un admin.
- **CSRF protection** (siempre on), **agent → controller access control**, **anonymous read deshabilitado**.
- **Integraciones**: HashiCorp Vault (plugin oficial), AWS Secrets Manager, Azure Key Vault; patrón "credentials provider" vs "fetch en pipeline".
- **Rotación de secretos** y **CVE lifecycle** de Jenkins y plugins.

Lo que **no** cubre:

- Operar Jenkins en producción (HA, backup, capacity) → `jk-08`.
- La parte generalista DevSecOps (SAST, SBOM, firma, OIDC federation) → curso `devsecops`.
- La instalación base ni JCasC introductorio → ya cubiertos en `jk-02` y `jk-06`.

Este módulo es **config-as-code + ejercicios en papel**. **No** se levanta un Jenkins real; se construye el `jenkins.yaml` que lo describe y se valida su estructura. Credentials usan valores **dummy** — nunca secretos reales (ver sección "Costos y seguridad" abajo).

## Materiales

- **`theory/lesson.md`** — lección profunda con 10 secciones.
- **`examples/`** — demostraciones (lectura y análisis):
  - `01-rbac-with-role-strategy/` — anatomía de un `jenkins.yaml` con roles globales y de proyecto, grupos y asignaciones.
  - `02-credentials-and-script-approval/` — `credentials:` dummy + flujo de `scriptApproval:` con hashes aprobados.
  - `03-plugin-cve-audit-flow/` — pasos reales para auditar plugins: `Manage Plugins → Updates`, consulta a advisories, matriz de severidad.
- **`activities/`** — dos actividades **independientes**:
  - `01-harden-fresh-jenkins/` — producir un `jenkins.yaml` que configure authorizationStrategy + credentials dummy + script approval + hardening básico. **Guided lab**.
  - `02-audit-and-remediate-legacy/` — a partir de un snapshot de instalación legacy (plugins instalados con versiones, roles existentes, credentials inventariadas), producir `AUDIT.md` con hallazgos priorizados y `REMEDIATION-PLAN.md` con fases. **Independent**.
- **`resources/links.md`** — advisories, docs de plugins, lecturas.

## Competencias esperadas

| Dimensión | Al terminar deberías |
|-----------|----------------------|
| Conceptual | Explicar por qué el 90% de CVEs Jenkins viven en plugins; diferencia entre `GLOBAL` y `SYSTEM` scope de credentials; qué protege realmente el Groovy sandbox. |
| Operativa (JCasC) | Escribir un `jenkins.yaml` con `jenkins.authorizationStrategy.roleBased`, `credentials.system.domainCredentials`, `security.scriptApproval` sin leaks. |
| Arquitectónica | Diseñar un modelo RBAC para 3 equipos y 2 ambientes sin terminar en "everybody admin"; priorizar un backlog de hardening con criterio severidad × esfuerzo. |

## Criterios de evaluación

- Dado un `jenkins.yaml`, identifica qué roles existen, qué permisos otorgan y a quién están asignados.
- Lee una definición de credential y explica el scope correcto para un pipeline multi-folder.
- Decide, ante una API Groovy no aprobada, si se aprueba, se refactoriza para evitarla, o se mueve a Shared Library confiable.
- Prioriza una lista de 10 hallazgos de audit por (severidad CVSS × esfuerzo de remediación).
- Entrega las dos actividades con los validadores estructurales en verde.

## Entregables

- **`jenkins.yaml`** (actividad 01) con RBAC + credentials dummy + script approval + hardening baseline.
- **`AUDIT.md`** y **`REMEDIATION-PLAN.md`** (actividad 02).

## Costos y seguridad

**Ninguno — y crítico que siga así.** Todo el módulo se desarrolla contra archivos YAML/Markdown locales. **Prohibido** usar credenciales reales (tokens de GitHub, llaves AWS, passwords de prod) en los `jenkins.yaml` que escribas, aun si no se van a aplicar. Usa siempre los valores dummy indicados:

- `string` → `"dummy-token-xxxxxxxxxxxx"`
- `usernamePassword` → `"demo-user"` / `"CHANGE-ME-NOT-A-REAL-PASSWORD"`
- `sshUserPrivateKey` → fingerprint ficticio y clave `"-----BEGIN DUMMY KEY-----..."`.

El validador rechazará archivos que contengan patrones evidentes de secretos reales (`ghp_...`, `AKIA...`, cadenas largas aleatorias en claro).

## Siguiente módulo

→ `jk-08-operate-at-scale-and-migration-to-modern` — operar Jenkins en producción (HA, backup, upgrades) y planificar/ejecutar migración a GHA/GitLab/Argo.
