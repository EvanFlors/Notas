# Actividad 01 — Endurecer un Jenkins nuevo con JCasC

## 1. Identificación

- **ID:** `jk-07-01-harden-fresh-jenkins`
- **Tecnología:** `jenkins`
- **Módulo:** `jk-07-security-rbac-credentials-and-script-approval`
- **Dificultad:** advanced
- **Duración estimada:** 85–95 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a arrancar un controller **nuevo** para una empresa con 2 equipos (`team-a` y `team-b`), un equipo de plataforma (`jenkins-admins`) y "resto de staff" (`all-staff`). No hay nada en Git todavía. Tu entregable es un **único `jenkins.yaml`** que al aplicarse deje el controller en estado "producción-ready baseline":

- Autenticación local **solo** con un `admin-bootstrap` (password desde env). En prod se cambiará a SSO.
- Autorización por `Role-based Authorization Strategy`.
- `credentials:` con 3 tipos (string, usernamePassword, SSH key), todas con **valores dummy** via `${ENV_VAR}`.
- `security.scriptApproval:` con 2+ firmas explícitas aprobadas, **sin** incluir escapes del sandbox.
- Baseline de hardening: CSRF on, anonymous sin permisos, `allowsSignup: false`.

**Importante:** no se levanta un Jenkins real. El entregable es un YAML + un Markdown justificativo. Prohibido meter secretos reales — el validador rechaza patrones como `ghp_...`, `AKIA...`, strings aleatorias largas en claro.

## 3. Objetivos

Al terminar deberías poder:

- Escribir un `jenkins.yaml` que configure authorizationStrategy, credentials y script approval en un solo documento.
- Explicar la diferencia entre `global:` roles e `items:` roles y por qué asignar a **grupos** y no a usuarios.
- Justificar por qué `GroovyShell.evaluate` nunca debe estar en `approvedSignatures`.
- Documentar en un `HARDENING-NOTES.md` cada bloque: qué protege, por qué está así, qué NO está hardenado todavía.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo y recorrido los 2 primeros `examples/`.
- Herramientas: `bash`, `python3` (para validar YAML), un editor de texto.
- (Opcional) `yq` para pretty-print.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/jk-07-harden
cd /tmp/jk-07-harden
```

Puedes usar otro directorio, pero entonces pásaselo al validador:

```bash
bash tests/validate.sh /tu/ruta
```

### 5.2 Escribe `jenkins.yaml`

Nombre **exacto** (el validador lo busca): `jenkins.yaml`.

#### Bloque A — `jenkins.securityRealm` (local, bootstrap only)

- `allowsSignup: false`.
- Un único usuario `admin-bootstrap` con password desde `${ADMIN_BOOTSTRAP_PASSWORD}`.

#### Bloque B — `jenkins.authorizationStrategy.roleBased`

- **`global` roles:** al menos
  - `admin` → `Overall/Administer`, asignado a grupo `jenkins-admins`.
  - `readonly-everyone` → `Overall/Read`, `View/Read`, `Job/Read`, asignado a grupo `all-staff`.
- **`items` roles:** al menos
  - `team-a-maintainers` → pattern `^team-a/.*`, permisos `Job/Build`, `Job/Configure`, `Job/Read`, grupo `team-a`.
  - `team-b-maintainers` → pattern `^team-b/.*`, permisos equivalentes, grupo `team-b`.
- **No** debe existir ningún rol con `entries` apuntando a `anonymous`.

#### Bloque C — `jenkins.crumbIssuer`

- `standard:` con `excludeClientIPFromCrumb: false`. (CSRF on.)

#### Bloque D — `credentials.system.domainCredentials`

Al menos 3 credenciales **dummy**:

1. `string` con `id: "github-token"`, `secret: "${GITHUB_TOKEN_SECRET}"`, `scope: GLOBAL`.
2. `usernamePassword` con `id: "docker-registry"`, `username: "demo-user"`, `password: "${DOCKER_REGISTRY_PASSWORD}"`.
3. `basicSSHUserPrivateKey` con `id: "deploy-key-staging"`, `username: "deploy"`, clave desde `${STAGING_DEPLOY_PRIVATE_KEY}` via `privateKeySource.directEntry`.

**Prohibido**: valor literal de secret, token, password o key. **Todos** vienen de `${...}`.

#### Bloque E — `security.scriptApproval.approvedSignatures`

- Al menos 2 firmas aprobadas, concretas. Ejemplos razonables:
  - `method hudson.model.Run getPreviousBuild`
  - `staticMethod java.lang.Math max int int`
  - `method hudson.model.Job getLastBuild`
- **Prohibido** incluir `GroovyShell.evaluate`, `MethodCall.invoke` o cualquier variante con `invoke` o `evaluate` no cualificado.

### 5.3 Escribe `HARDENING-NOTES.md`

Secciones **mínimas** (el validador las busca por heading):

- `## Autenticacion`
- `## Autorizacion`
- `## Credentials`
- `## Script Approval`
- `## Pendiente`

En cada una, 3–8 líneas: qué está hecho, por qué, qué NO está hecho todavía (SSO, Vault, folder-scoped credentials, etc.).

### 5.4 Valida localmente

```bash
# Desde el repo:
bash courses/jenkins/07-security-rbac-credentials-and-script-approval/\
activities/01-harden-fresh-jenkins/tests/validate.sh /tmp/jk-07-harden
```

Resultado esperado: `OK: jenkins.yaml y HARDENING-NOTES.md pasan validacion estructural.`

### 5.5 Compara con la solución

Lee `solution/REFERENCE.md` **después** de intentar la actividad. Es solo una referencia posible — hay varias YAML válidos.

## 6. Entregables

- `/tmp/jk-07-harden/jenkins.yaml` — el YAML aplicable (en teoría) por el plugin `configuration-as-code`.
- `/tmp/jk-07-harden/HARDENING-NOTES.md` — justificación por bloque + lista de pendientes.

## 7. Criterios de éxito

- El validador imprime `OK: ...` (0 fallos).
- `HARDENING-NOTES.md` deja claro qué **no** está hardenado todavía (SSO real, Vault, auditoría a SIEM).
- Al leer `jenkins.yaml`, un auditor identifica en < 2 min qué grupo tiene qué.

## 8. Pistas si te atascas

- `yaml` admite `${VAR}` en strings; el plugin JCasC lo resuelve al arrancar.
- Un `role` sin `entries` no otorga nada: no es un error, pero probablemente no es lo que querías.
- Si el validador falla en "no `GroovyShell.evaluate`", revisa que no hayas copiado una firma de ejemplo de internet con `invoke` o `evaluate` genérico.
