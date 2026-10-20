# HARDENING-NOTES.md — jk-07-01 (referencia)

> Documento de muestra. Tu versión puede diferir en estilo; lo relevante es que cada sección exista con contenido justificativo.

## Autenticacion

- Realm: `local` únicamente para `admin-bootstrap`; `allowsSignup: false`; captcha on.
- Password del bootstrap via `${ADMIN_BOOTSTRAP_PASSWORD}` — no en claro, no en Git.
- **Pendiente**: migrar a SSO corporativo (OIDC con Entra ID o Okta); una vez funcional, deshabilitar la DB local.

## Autorizacion

- Estrategia: `Role-based Authorization Strategy`.
- Global roles: `admin` (plataforma) y `readonly-everyone` (toda la empresa).
- Items roles por regex: `^team-a/.*` y `^team-b/.*` separan folders de los equipos. Un job nuevo del team-a hereda permisos sin tocar config.
- `anonymous` **sin** ningún role → cero lectura sin login.
- Asignaciones solo a **grupos** (`jenkins-admins`, `team-a`, `team-b`, `all-staff`). Ningún usuario individual.
- **Pendiente**: añadir role `qa-rerun` cuando el equipo QA empiece a reintentar builds; añadir role de solo `Credentials/View` para el equipo de auditoría.

## Credentials

- 3 tipos cubiertos: `string` (GitHub PAT), `usernamePassword` (registry), `basicSSHUserPrivateKey` (deploy key staging).
- Todos los secretos vienen de `${ENV_VAR}` — inyectadas al container por el secrets store (Vault agent o Kubernetes Secret).
- Scope `GLOBAL` porque todavía no hay folders por equipo; cuando los haya, mover a `folder` scope para reducir blast-radius.
- **Pendiente**: integrar `hashicorp-vault-plugin` como provider → eliminar persistencia en `$JENKINS_HOME`; evaluar OIDC federation para AWS (quita la `deploy-key-staging`).

## Script Approval

- 3 firmas aprobadas, todas lecturas benignas de metadata del build:
  - `hudson.model.Run getPreviousBuild`
  - `java.lang.Math max int int`
  - `hudson.model.Job getLastBuild`
- **No** se incluye ninguna firma con `invoke` ni `evaluate` — son escapes universales del sandbox.
- Flujo acordado: toda aprobación llega al YAML via PR con contexto (pipeline que la necesita, revisor).
- **Pendiente**: revisión trimestral del listado; retirar firmas que ya no se usen (medición: cuántas builds al mes dependen de cada firma).

## Pendiente

- SSO real (OIDC) y deshabilitar DB local.
- Vault como provider de credentials; retirar scope `GLOBAL` y mover a `folder`.
- OIDC federation a AWS → retirar deploy keys y PATs cuando se pueda.
- `audit-trail` plugin + export a SIEM.
- `plugins.txt` versionado con CI nightly que compara contra advisories.
- Reverse proxy con HTTPS obligatorio y rate-limit.
- Backup programado del `$JENKINS_HOME` (Velero si corre en K8s).
