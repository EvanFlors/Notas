# REMEDIATION-PLAN.md — Jenkins legacy

## Fase 1 - Hoy

- Actualizar `script-security` → última LTS. Owner: @platform.
- Eliminar role `anon-read` (y toda referencia al grupo `anonymous`). Owner: @platform.
- Eliminar firmas `GroovyShell.evaluate` e `InvokerHelper.invokeMethod` del `scriptApproval.xml`. Owner: @platform.
- Revocar en GitHub el PAT `gh-pat-personal-jose`. Owner: @security.
- Deshabilitar en el realm a `jmartinez` y `contractor-2023`. Owner: @platform.

## Fase 2 - Esta semana

- `allowsSignup: false` + captcha en el realm local. Owner: @platform.
- `crumbIssuer.standard.excludeClientIPFromCrumb: false`. Owner: @platform.
- Reducir el role global del grupo `developers` → mover a project roles por folder cuando los haya; mientras tanto, acotar a permisos de `Job/Build` + `Job/Read` globales. Owner: @platform.
- Actualizar `workflow-cps` y `credentials` plugins. Owner: @platform.
- Documentar owner por cada credential del inventario. Owner: @security + leads de equipo.

## Fase 3 - Esta quincena

- Desinstalar plugins sin uso detectado: `cvs`, `subversion`, `blueocean*`, `groovy-postbuild`. Owner: @platform.
- Eliminar el duplicado `aws-prod-keys SYSTEM`; validar que ningún pipeline del controller lo pide (`SYSTEM` no debería ser pedible por jobs, pero verificarlo). Owner: @platform.
- Rotar toda credential con > 90 días sin rotación: `signing-key`, `aws-prod-keys GLOBAL`. Owner: @security.
- Smoke de los 5 pipelines más críticos tras cada cambio. Owner: @qa.

## Fase 4 - Backlog

- Diseñar estructura de folders por equipo; migrar credentials a scope `folder`.
- Integrar Vault como provider de credentials; retirar PATs/keys estáticas; evaluar OIDC federation a AWS.
- Versionar el controller completo con JCasC en Git; UI pasa a solo lectura.
- Suscribir el canal `#platform-sec` al feed oficial de advisories de Jenkins.
- CI nightly con `jenkins-plugin-cli --available-updates` que abra PR cuando haya updates de seguridad.

## Criterios de exito

- Fase 1: 0 CVEs Critical pendientes; `grep anonymous jenkins-security-export.yaml` sin resultados; `grep -E 'evaluate|invoke' scriptApproval.xml` sin resultados.
- Fase 2: `allowsSignup: false`; CSRF endurecido; 0 usuarios inactivos con permisos; 100% credentials con owner identificado.
- Fase 3: < 15 plugins instalados (desde los 22 actuales); 0 credentials sin rotación > 90 días; 0 duplicados.
- Fase 4: `jenkins.yaml` versionado y aplicado por CI; `anonymous` no aparece en el YAML; 0 credentials estáticas de larga vida al cloud.

## Rollback

- Backup completo del `$JENKINS_HOME` **antes** de cada fase; retenido 30 días.
- Snapshot del `plugins.txt` previo a cada upgrade; permite reinstalar versiones anteriores con `jenkins-plugin-cli -f plugins.txt.previous`.
- Procedimiento documentado para revertir plugins uno a uno si falla un pipeline canario.
- Smoke de 5 pipelines canarios tras cada fase; si rojo, rollback automático al snapshot anterior y re-planificar.
- Comunicación al Slack `#dev-platform` 24h antes de cada ventana + mensaje de rollback si aplica.
