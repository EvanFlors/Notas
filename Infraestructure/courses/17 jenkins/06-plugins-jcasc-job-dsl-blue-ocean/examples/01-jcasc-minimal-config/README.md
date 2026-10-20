# Ejemplo 01 — `jenkins.yaml` mínimo con JCasC

Objetivo: leer un `jenkins.yaml` suficientemente completo para reproducir un controller real pero suficientemente mínimo para entender cada bloque.

Este ejemplo **no se ejecuta**. Es material de lectura y análisis.

## Archivos

- `jenkins.yaml` — configuración completa de un controller: `jenkins`, `security`, `credentials`, `unclassified`, `tool`, `jobs` (seed).

## Qué configura cada bloque

| Bloque | Qué hace |
|--------|----------|
| `jenkins.systemMessage` | Banner visible en la portada del controller. Deja marca explícita de "gestionado por JCasC". |
| `jenkins.numExecutors: 0` | El controller no ejecuta builds. Builds van a agents (en este ejemplo, cloud K8s). |
| `jenkins.mode: EXCLUSIVE` | Solo corre jobs que piden explícitamente un label. Evita que un job sin label caiga en el controller. |
| `jenkins.securityRealm.local` | Autenticación local con base de datos interna. Para prod real se cambia por LDAP / SAML / OIDC. |
| `jenkins.authorizationStrategy.roleBased` | Autorización por roles. Role Strategy plugin requerido. |
| `jenkins.clouds[0].kubernetes` | Cloud K8s para spawn de agents efímeros (ver `jk-05`). |
| `credentials.system.domainCredentials` | Credenciales globales. `${GITHUB_TOKEN}` resuelve a env var. |
| `unclassified.location.url` | URL pública del controller, usada por plugins que arman links (ej. GitHub status). |
| `unclassified.gitHubPluginConfig` | Config del plugin GitHub. |
| `tool.git.installations` | Herramienta Git disponible para los pipelines. |
| `jobs[0].script` | Define el *seed job* inline — ver ejemplo 02 para su contenido Groovy. |

## Puntos a notar

1. **No hay secrets en claro**: todas las contraseñas y tokens son `${VAR}`.
2. **El controller no construye nada**: `numExecutors: 0` + `mode: EXCLUSIVE` fuerzan a usar agents.
3. **Un único seed job**: el resto de jobs los genera Job DSL — no se definen aquí.
4. **Ningún bloque de UI**: Blue Ocean, si se quiere, se añade por plugin + no requiere config.
