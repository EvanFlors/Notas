# AUDIT.md — Jenkins legacy (snapshot 2026-09-30)

## Resumen ejecutivo

El controller lleva ~4 años en producción sin revisión de seguridad formal. Encontramos 10 hallazgos relevantes: 3 Critical (script-security con CVE, lectura pública vía `anonymous`, dos firmas de script approval que desactivan el sandbox), 4 High (allowsSignup abierto, CSRF debilitado, usuarios inactivos con admin, PAT de ex empleado) y varios Medium/Low de higiene (plugins sin uso, credentials duplicadas, scope `GLOBAL` universal). La primera medida de hardening recomendada **no** es configurar nada: es **desinstalar los plugins que nadie usa** (`cvs`, `subversion`, `blueocean*`) — reduce superficie permanentemente y simplifica el audit siguiente.

## Hallazgos

### Critical — Plugin `script-security:1.76` con CVE crítica

Versión obsoleta con una CVE Critical de sandbox escape publicada en 2024. Impacto: RCE sobre el controller. Fix: actualizar a la última LTS en ventana de mantenimiento de hoy mismo.

### Critical — Firmas de script approval desactivan el sandbox

En `scriptApproval.xml` están aprobadas `method groovy.lang.GroovyShell evaluate ...` y `staticMethod ... InvokerHelper invokeMethod ...`. Ambas son escapes universales del sandbox: cualquier pipeline puede ejecutar código arbitrario. Impacto: equivalente a sandbox desactivado. Fix: eliminarlas y refactorizar los pipelines consumidores a Shared Library versionada.

### Critical — Rol `anon-read` asignado al grupo `anonymous`

El `anonymous` tiene `Overall/Read`, `View/Read` y `Job/Read`. Impacto: nombres de pipelines, parámetros y logs potencialmente leaks internos (rutas, stacktraces). Fix: eliminar el role; si hay demanda de status público, exponerlo vía reverse proxy.

### High — `allowsSignup: true` en el realm local

Cualquiera que llegue al controller puede registrarse como usuario autenticado. Impacto: superficie de brute force y abuso de recursos. Fix: `allowsSignup: false` + captcha.

### High — Usuarios inactivos con `Overall/Administer`

`jmartinez` dejó la empresa en 2024; `contractor-2023` lleva 18 meses sin uso. Siguen con admin. Impacto: credenciales olvidadas = cuentas comprometidas latentes. Fix: revocar hoy; proceso de off-boarding integrado con el IdP.

### High — PAT `gh-pat-personal-jose` de ex empleado

Token a nombre personal de un empleado que dejó la empresa hace 14 meses. Impacto: si GitHub rota el token por abandono, el pipeline que lo usa falla sin alerta — y si no lo rota, es un acceso de larga vida sin owner. Fix: revocar en GitHub y crear PAT organizacional owned por el equipo.

### Medium — CSRF debilitado (`excludeClientIPFromCrumb: true`)

Reduce la validez del crumb a solo cookie. Fix: `false` (valor por defecto moderno).

### Medium — Credentials duplicadas `aws-prod-keys` (GLOBAL + SYSTEM)

Nadie recuerda cuál usa qué pipeline. Rotación imposible sin coordinación. Fix: eliminar la copia `SYSTEM`; dejar una autoritativa y planificar migración a Vault.

### Medium — Plugins sin uso detectado (`cvs`, `subversion`, `blueocean*`, `groovy-postbuild`)

Superficie de ataque sin valor de negocio. Fix: desinstalar en la ventana de la próxima quincena.

### Low — Credential `old-svn-password` sin uso desde 2022

Repo SVN migrado hace 3 años. Fix: eliminar.

## Matriz severidad por esfuerzo

| Severidad | Esfuerzo bajo | Esfuerzo medio | Esfuerzo alto |
|-----------|---------------|-----------------|---------------|
| Critical | actualizar `script-security`, eliminar `anon-read`, eliminar firmas sandbox-escape | — | — |
| High | `allowsSignup:false`, revocar `jmartinez`/`contractor-2023`, revocar `gh-pat-personal-jose` | reducir admin del grupo `developers`, actualizar `workflow-cps` + `credentials` | migrar a Vault |
| Medium | `excludeClientIPFromCrumb:false`, desinstalar `cvs`, `subversion`, `blueocean*` | eliminar duplicado `aws-prod-keys` SYSTEM | diseñar folders por equipo |
| Low | eliminar `old-svn-password` | — | — |
