# Solución de referencia — jk-07-02-audit-and-remediate-legacy

> Una lista posible, no "la" lista. Tu audit puede diferir si cubre las 4 categorías obligatorias y la priorización es coherente.

## Hallazgos obligatorios (están sembrados en el snapshot)

### 1. Plugin con CVE crítica — `script-security:1.76`

- Versión obsoleta con CVE Critical publicada en 2024.
- Impacto: sandbox escape → RCE potencial sobre el controller.
- Fix: actualizar a la última LTS del plugin (y revisar también `workflow-cps:2.80` y `credentials:2.6.1`).

### 2. Credential con scope inadecuado — `aws-prod-keys` duplicada en `SYSTEM`

- Credentials de AWS producción duplicadas: una `GLOBAL` y una `SYSTEM`.
- Impacto: nadie sabe cuál usa qué pipeline; rotación imposible sin coordinación.
- Fix: eliminar la copia `SYSTEM`; migrar la `GLOBAL` a Vault con AppRole, o a OIDC federation si posible.

### 3. Script approval con escape de sandbox — `GroovyShell.evaluate` + `InvokerHelper.invokeMethod`

- Ambas firmas aprobadas desactivan el sandbox de facto.
- Impacto: cualquier pipeline puede ejecutar código arbitrario sin control.
- Fix: eliminar ambas firmas del `scriptApproval.xml`; refactorizar los pipelines que las necesiten a Shared Library versionada (que corre fuera del sandbox pero con revisión por PR).

### 4. Rol asignado a `anonymous` — `anon-read` con `Overall/Read`

- Lectura pública del controller y de jobs.
- Impacto: fuga de nombres de pipelines, parámetros, builds (potencialmente con stacktraces que revelan rutas internas).
- Fix: eliminar el role `anon-read`; si hay necesidad legítima de status público, exponerlo vía reverse proxy con solo esa página.

## Hallazgos adicionales plausibles

- `allowsSignup: true` → cualquiera registra un usuario. Severidad High.
- `CSRF debilitado` (`excludeClientIPFromCrumb: true`). Severidad High.
- Usuarios inactivos con `Overall/Administer` (`jmartinez`, `contractor-2023`). Severidad High.
- Grupo entero `developers` como admin global. Severidad High (reducir a project roles por folder).
- Plugins sin uso: `cvs`, `subversion`, `blueocean*`. Severidad Medium — fix: desinstalar.
- `gh-pat-personal-jose` (PAT de ex empleado). Severidad High — rotar y revocar.
- `old-svn-password` (3 años sin uso). Severidad Low — eliminar.
- Falta de folders por equipo → scope `GLOBAL` universal. Severidad Medium — rediseño progresivo.

## Priorización — matriz de referencia

| Severidad | Esfuerzo bajo | Esfuerzo medio | Esfuerzo alto |
|-----------|---------------|-----------------|---------------|
| Critical | script-security update, eliminar `anon-read`, eliminar firmas sandbox-escape | — | — |
| High | revocar PAT de Jose, revocar usuarios inactivos, `allowsSignup: false`, CSRF endurecer | reducir `developers` admin → project roles, actualizar `workflow-cps` y `credentials` | migrar credentials a Vault |
| Medium | desinstalar `cvs`, `subversion`, `blueocean*` | eliminar duplicado `aws-prod-keys SYSTEM` | diseñar folders por equipo |
| Low | eliminar `old-svn-password` | — | — |

## Fases sugeridas (`REMEDIATION-PLAN.md`)

### Fase 1 - Hoy (ventana de emergencia)

- Actualizar `script-security` → fix la Critical.
- Eliminar `anon-read` role → cierra lectura pública.
- Eliminar firmas `GroovyShell.evaluate` e `InvokerHelper.invokeMethod` del script approval.
- Revocar `gh-pat-personal-jose` y usuarios `jmartinez`, `contractor-2023`.

### Fase 2 - Esta semana

- `allowsSignup: false`; CSRF `excludeClientIPFromCrumb: false`.
- Reducir role global de `developers` → project roles por folder.
- Actualizar `workflow-cps` y `credentials` plugins.
- Documentar inventario de credentials con owner por cada id.

### Fase 3 - Esta quincena

- Desinstalar plugins sin uso (`cvs`, `subversion`, `blueocean*`, `groovy-postbuild` si nadie lo usa).
- Resolver duplicado `aws-prod-keys` (eliminar la `SYSTEM`, dejar una autoritativa).
- Rotar todas las credentials que llevan > 90 días sin rotación.

### Fase 4 - Backlog

- Diseñar folders por equipo y migrar credentials a scope folder.
- Integrar Vault como provider; retirar PATs y keys estáticas de larga vida.
- Versionar `jenkins.yaml` completo con JCasC; dejar la UI como solo lectura.
- Suscribir el canal `#platform-sec` al feed oficial de advisories.

### Criterios de éxito

- 0 CVE `Critical` pendientes al final de Fase 1.
- 0 roles asignados a `anonymous`.
- 0 firmas con `invoke` o `evaluate` en `scriptApproval`.
- 100% de credentials con owner identificado al final de Fase 2.
- < 60 plugins instalados al final de Fase 3 (desde ~22 pero legacy real suele tener 100+).

### Rollback

- Backup del `$JENKINS_HOME` antes de cada fase.
- Snapshot del `plugins.txt` previo a cada upgrade.
- Procedimiento documentado para revertir plugins uno a uno si un pipeline crítico falla.
- Smoke de 5 pipelines canarios tras cada fase; si rojo, rollback automático a snapshot anterior.
