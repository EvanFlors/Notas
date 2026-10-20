# jk-07 — Lección: seguridad en Jenkins (RBAC, credentials, script approval)

> 10 secciones. Prerrequisitos: `jk-02`, `jk-06`, curso `devsecops` ≥ Nivel 2.

---

## 1. Por qué Jenkins es crítico de endurecer

Jenkins es, por diseño, un **ejecutor remoto de código arbitrario** con acceso a secretos, al código fuente y a entornos de despliegue. Cualquier compromiso del controller normalmente equivale a comprometer *toda* la cadena de entrega: fuentes, artefactos, firmas, credenciales de cloud, acceso a producción.

El problema no es solo conceptual. Jenkins tiene **el historial de CVEs activo más largo** del ecosistema CI/CD moderno, no tanto por el core, sino por **plugins**:

- Core de Jenkins: ~1 advisory relevante al mes en promedio.
- Plugins: suele haber **cientos de advisories por año**, muchos con `RCE` o `credentials exposure`.
- Un controller típico corre entre 60 y 150 plugins; cada uno es superficie de ataque independiente.

> **Idea clave #1:** la primera medida de hardening no es *configurar algo*, es *desinstalar plugins que no usas*. La segunda es *pinnear y actualizar con disciplina*. Todo lo demás viene después.

Las secciones 2–8 cubren el "todo lo demás". La sección 9 cierra con el CVE lifecycle, que es lo que mantiene vivo (o no) el hardening.

---

## 2. Autenticación: quién entra

Jenkins separa **autenticación** (quién eres) de **autorización** (qué puedes hacer). Son dos settings distintos en `Manage Jenkins → Security` y en JCasC viven bajo claves diferentes.

### 2.1 Opciones de autenticación

| Realm | Cuándo | Riesgo |
|-------|--------|--------|
| **Jenkins own user database** | Dev local, demos, labs. | Nunca en prod: no hay rotación central, no hay MFA, no hay auditoría. |
| **LDAP** | Enterprises con AD/OpenLDAP. | Depende de la higiene del directorio. Soporta grupos nativos. |
| **SAML 2.0** (plugin) | SSO corporativo. | Correcto; verificar `signRequest` y validar firma del IdP. |
| **OIDC** (plugin `oic-auth`) | SSO moderno (Okta, Entra ID, Google, Keycloak). | Preferido en 2026 para instalaciones nuevas. |
| **GitHub / Bitbucket OAuth** | Jenkins dedicado a un solo tenant Git. | Útil, pero ata la autenticación al proveedor Git. |

**Regla operativa:** en producción, **nunca** uses la DB local. Elige SSO corporativo y deshabilita el signup abierto (`Allow users to sign up`). Si el proveedor soporta grupos, mapéalos al realm — luego la autorización se hace sobre grupos, no sobre usuarios individuales.

### 2.2 En JCasC

```yaml
jenkins:
  securityRealm:
    local:
      allowsSignup: false
      enableCaptcha: true
      users:
        - id: "admin-bootstrap"
          password: "${ADMIN_BOOTSTRAP_PASSWORD}"   # desde env, nunca inline
```

En prod, `local:` se reemplaza por `oic:` / `saml:` / `ldap:`. El `admin-bootstrap` existe solo para el primer arranque; se desactiva una vez el SSO funciona.

> **Idea clave #2:** cualquier password/token en `jenkins.yaml` debe venir de **variable de entorno** o del **secrets store del container** (Kubernetes Secret, Vault agent). Nunca en el YAML en claro — ni en demo, por hábito.

---

## 3. Autorización: qué puede cada quien

Jenkins ofrece varias estrategias de autorización. Solo dos valen hoy en prod.

### 3.1 `Role-based Authorization Strategy` (plugin, recomendado)

Define **roles** con permisos y los asigna a usuarios/grupos. Hay tres tipos:

- **Global roles**: permisos sobre el controller completo (`Overall/Administer`, `Overall/Read`, `Agent/Build`, etc.).
- **Project roles** (también llamados *item roles*): permisos sobre jobs cuyo nombre coincide con un **patrón regex** (p.ej. `team-a-.*`). Esto es cómo se consigue "el equipo A solo ve y edita sus jobs".
- **Node roles**: permisos sobre agents cuyo nombre coincide con patrón. Útil cuando distintos equipos tienen agents distintos.

### 3.2 `Matrix-based security` / `Project Matrix`

Granularidad por usuario/grupo × permiso. Potente pero inmanejable a escala: con 10 equipos y 50 permisos, la matriz es ilegible. Úsalo solo para excepciones puntuales.

### 3.3 Lo que no debes usar

- `Logged-in users can do anything`: aceptable solo en laboratorios desechables. En prod es "cualquiera que logre loguearse es admin".
- `Anyone can do anything`: literalmente abrir el controller al mundo. **Nunca**.

### 3.4 Modelo mental

```
┌─────────────────────────────────────────────────────────────┐
│                        CONTROLLER                           │
│                                                             │
│   Global roles:          admin   developer   viewer         │
│                            │          │          │          │
│   Grupos (desde SSO):   platform   dev-team-a   all-staff   │
│                                                             │
│   Project roles (regex): "^team-a-.*" → build+configure     │
│                          "^team-b-.*" → build+configure     │
│                          "^infra-.*"  → admin               │
└─────────────────────────────────────────────────────────────┘
```

**Regla operativa:** asigna roles a **grupos**, no a usuarios. Un nuevo miembro del equipo entra al grupo en el IdP y hereda permisos automáticamente. Asignar a usuarios individuales lleva, en 12 meses, a "¿por qué María sigue teniendo admin si cambió de equipo?".

### 3.5 En JCasC

```yaml
jenkins:
  authorizationStrategy:
    roleBased:
      roles:
        global:
          - name: "admin"
            permissions:
              - "Overall/Administer"
            entries:
              - group: "jenkins-admins"
          - name: "developer"
            permissions:
              - "Overall/Read"
              - "Job/Build"
              - "Job/Read"
              - "View/Read"
            entries:
              - group: "developers"
        items:
          - name: "team-a-maintainers"
            pattern: "^team-a-.*"
            permissions:
              - "Job/Configure"
              - "Job/Build"
              - "Job/Read"
            entries:
              - group: "team-a"
```

---

## 4. Credentials: cómo se guardan y se consumen

Jenkins trae un **credentials store** cifrado con la master key del `$JENKINS_HOME`. **No es un secrets manager**; es un almacén razonable para una instalación pequeña, pero en prod serio se delega en Vault / AWS Secrets Manager / Azure Key Vault.

### 4.1 Tipos

| Tipo | Para qué |
|------|----------|
| `string` (secret text) | Tokens de API (GitHub, DockerHub, SonarQube). |
| `usernamePassword` | HTTP Basic, registries, DBs. |
| `sshUserPrivateKey` | Deploy keys, acceso a agents por SSH. |
| `certificate` | mTLS, cliente a APIs internas. |
| `file` | kubeconfigs, service account JSONs, archivos de configuración con secretos embebidos. |

### 4.2 Scopes

- **`SYSTEM`**: solo el controller puede usarlo. Pipelines **no** pueden pedirlo. Para credenciales que usan plugins internos (ej. notificaciones Slack del propio controller).
- **`GLOBAL`**: cualquier job del controller puede pedirlo. **La mayoría de los secrets están aquí**, pero es el scope más amplio.
- **`folder`**: solo jobs dentro de ese folder (y sub-folders) pueden pedirlo. Para separar secrets por equipo cuando los equipos tienen folders propios — es la mejor granularidad práctica.

**Regla operativa:** si tu organización tiene equipos con folders, define las credentials en el **folder**, no en global. Reduce blast-radius ante un pipeline comprometido.

### 4.3 Consumo seguro en pipelines

**Siempre** con `withCredentials`:

```groovy
withCredentials([
  string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN'),
  usernamePassword(credentialsId: 'docker-registry',
                   usernameVariable: 'REG_USER',
                   passwordVariable: 'REG_PASS')
]) {
  sh '''
    echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$REG_USER" --password-stdin
    # El log mostrará "****", NO el valor real.
  '''
}
```

Jenkins **enmascara** el valor en los logs **si** se recupera por `withCredentials` o por el shorthand `credentials('id')`. Si lo imprimes manualmente (`echo "$GITHUB_TOKEN"`), **lo verás en el log**. Hay que escribir el pipeline asumiendo que todo `echo` de una variable sensible es un leak.

### 4.4 En JCasC (dummy, nunca secretos reales)

```yaml
credentials:
  system:
    domainCredentials:
      - credentials:
          - string:
              scope: GLOBAL
              id: "github-token"
              secret: "${GITHUB_TOKEN_SECRET}"   # desde env
              description: "GitHub PAT for CI (dummy in demo)"
          - usernamePassword:
              scope: GLOBAL
              id: "docker-registry"
              username: "demo-user"
              password: "${DOCKER_REGISTRY_PASSWORD}"
              description: "Registry push (dummy)"
```

> **Idea clave #3:** el `jenkins.yaml` debe estar en Git. **Los valores no.** Siempre `${ENV_VAR}` para los secretos, y el env se inyecta desde el secrets store al arrancar el container.

### 4.5 Rotación

- **Manual** con calendario (p. ej. cada 90 días): humano actualiza el valor en Vault, el controller lo relee en el próximo arranque. Simple, frágil.
- **Automática** vía Vault AppRole + Jenkins Vault plugin: la credencial se **fetchea en cada build**, no se almacena en el controller. Mejor patrón.
- **OIDC federation** al cloud (ej. Jenkins → AWS IAM Role vía OIDC token): elimina la credencial estática. Es el estado del arte, pero requiere plugin + IdP soportado.

---

## 5. Groovy sandbox e in-process script approval

Pipelines corren **Groovy**. Groovy, sin restricciones, puede leer `/etc/shadow`, abrir sockets, invocar Java reflection — es decir, es equivalente a RCE sobre el controller. Jenkins protege esto con dos mecanismos:

### 5.1 Groovy sandbox

Cuando un Jenkinsfile corre con `sandbox: true` (default en Pipelines modernos), el intérprete Groovy **restringe** las APIs disponibles a una lista blanca de métodos "seguros". Intentos de llamar APIs fuera de esa lista fallan en runtime con un error "Scripts not permitted to use method X".

### 5.2 In-process Script Approval

Cuando una llamada sale del sandbox, Jenkins **no la ejecuta** y la registra en `Manage Jenkins → In-process Script Approval` como "pendiente de aprobación". El admin puede:

1. **Aprobar la firma** del método (`method java.util.List add java.lang.Object`): la próxima vez se ejecuta sin preguntar.
2. **No aprobar**: el pipeline sigue roto hasta que se refactorice.

Esto es un control real, pero es fricción real. En Jenkins ocupados, el admin recibe decenas de solicitudes por semana. Patrones comunes de uso:

- **Preferir Shared Libraries** (`@Library`) cargadas desde Git versionado: la library corre **fuera del sandbox** por default (configurable). Si el código está en Git revisado por PR, ese es el perímetro de confianza real.
- **No aprobar `MethodCall.invoke` o `GroovyShell.evaluate`**: son escapes universales del sandbox. Aprobar uno de estos es equivalente a desactivar el sandbox.
- **Documentar cada aprobación** en el commit del `jenkins.yaml`: qué pipeline la necesitaba, por qué, quién revisó.

### 5.3 En JCasC

```yaml
security:
  scriptApproval:
    approvedSignatures:
      - "method java.util.List add java.lang.Object"
      - "staticMethod java.lang.Math max int int"
    # NO incluyas aquí 'MethodCall.invoke' ni 'GroovyShell.evaluate'.
```

El fichero vive bajo `$JENKINS_HOME/scriptApproval.xml` cuando se gestiona por UI; JCasC lo escribe. **Revisar este listado es parte del review de seguridad trimestral.**

### 5.4 Flujo real "aprobar un script" — walkthrough

Pipeline nuevo falla con:

```
org.jenkinsci.plugins.scriptsecurity.sandbox.RejectedAccessException:
Scripts not permitted to use method hudson.model.Run getPreviousBuild
```

Pasos del admin:

1. Ir a `Manage Jenkins → In-process Script Approval`. Verás la entrada pendiente.
2. **No apruebes inmediatamente.** Pregúntate:
   - ¿Qué pipeline la necesita? ¿Por qué?
   - ¿Es una API razonable (lectura de metadata) o un escape (`invoke`, `GroovyShell`)?
   - ¿Se podría conseguir el mismo resultado con un **step** declarative existente?
3. Si la respuesta es "es razonable y no hay alternativa", **aprueba la firma concreta** — nunca `signature wildcarded`.
4. Añade la firma a `jenkins.yaml`:
   ```yaml
   security:
     scriptApproval:
       approvedSignatures:
         - "method hudson.model.Run getPreviousBuild"
   ```
5. Commit con mensaje: `security(script-approval): allow Run.getPreviousBuild for pipeline X (owner: team-a, review: @alice)`.
6. PR revisado por otro admin.
7. Merge → el próximo apply de JCasC deja la aprobación persistente.

> **Idea clave #4:** aprobar scripts por UI sin dejar rastro en Git es la receta estándar para que "nadie sepa por qué el controller permite X". El commit **es** la auditoría.

---

## 6. Controles transversales (y por qué dejarlos siempre on)

### 6.1 CSRF protection

Jenkins exige un `crumb` en cada POST desde la UI. Está **on por default** desde hace años. **Nunca** lo desactives para "arreglar" un script que postea sin el crumb — ese script es el bug. En JCasC:

```yaml
jenkins:
  crumbIssuer:
    standard:
      excludeClientIPFromCrumb: false
```

### 6.2 Agent → controller access control

Los **agents** no deberían poder leer archivos arbitrarios del controller ni invocar métodos del core. El `Agent → Controller Security` filtra las llamadas; está **on por default**. Si un plugin necesita bypass, revisa si es legítimo (muy raro) antes de ampliar la lista blanca.

### 6.3 Anonymous read deshabilitado

En `Role-based Authorization Strategy`, el rol `anonymous` **no debe tener permisos**. Verifica siempre:

```yaml
# NUNCA esto en producción:
# roles:
#   global:
#     - name: "anon-read"
#       permissions: [ "Overall/Read" ]
#       entries: [ { group: "anonymous" } ]
```

### 6.4 CLI remota

Jenkins expone una CLI por HTTP/SSH. Si no la usas (la mayoría de equipos usa UI + API REST), **deshabilítala**: menos superficie.

---

## 7. Integración con secrets managers externos

El credentials store nativo es "suficiente" para orgs pequeñas. En orgs serias el patrón es:

### 7.1 HashiCorp Vault

Plugin oficial: `hashicorp-vault-plugin`. Dos modos:

- **Vault como provider de credentials**: las credentials aparecen en el store de Jenkins, pero su **origen** es Vault. En cada read, el plugin llama a Vault; nunca se persisten en `$JENKINS_HOME`.
- **Fetch explícito en pipeline** con `withVault { ... }`: el pipeline pide el secret al step; se expone solo en ese scope.

Autenticación de Jenkins a Vault: **AppRole** (role-id + secret-id) o **Kubernetes auth** si Jenkins corre en K8s (recomendado — sin secret-id a rotar).

### 7.2 AWS Secrets Manager / Azure Key Vault

Plugins equivalentes. En AWS, cuando Jenkins corre en EC2/EKS, lo correcto es usar el **IAM Role de la instancia** (sin credentials estáticas) y el plugin `aws-secrets-manager-credentials-provider`.

### 7.3 OIDC federation al cloud

Patrón moderno (recomendable cuando el cloud lo soporta): Jenkins obtiene un **OIDC token** firmado por su propio emisor, el cloud confía en ese emisor, y el pipeline asume un IAM Role sin credenciales estáticas. Elimina el problema de rotación.

> **Idea clave #5:** cada credencial estática que elimines con federation reduce el blast-radius de un compromiso del controller.

---

## 8. Hardening baseline (lista real para producción)

Checklist mínimo para un controller nuevo:

- [ ] SSO corporativo configurado; local DB deshabilitada (o con solo `admin-bootstrap`).
- [ ] `Role-based Authorization Strategy` activo; `anonymous` sin permisos; `authenticated` sin permisos globales de escritura.
- [ ] Admins = grupo `jenkins-admins` del IdP (nunca usuarios individuales).
- [ ] CSRF on; Agent → Controller on; CLI deshabilitada si no se usa.
- [ ] `$JENKINS_HOME` fuera del `WORKDIR` del container; montado como volumen persistente con backup regular.
- [ ] Plugins instalados: justificados uno a uno; versiones **pinneadas**; `plugins.txt` o `jenkins-plugin-cli` en Git.
- [ ] Secrets store externo (Vault / Secrets Manager) o, al mínimo, credentials con scope `folder` por equipo.
- [ ] `scriptApproval.xml` versionado en `jenkins.yaml`; revisión trimestral.
- [ ] HTTPS obligatorio (TLS termina en el ingress / reverse proxy).
- [ ] Logs de auditoría activos (`audit-trail` plugin o equivalente); exportados a SIEM.
- [ ] Build retention configurado (ni logs infinitos ni "0 builds retenidos").
- [ ] Suscripción a **Jenkins Security Advisories** (RSS feed oficial).

---

## 9. CVE lifecycle: cómo mantener esto vivo

Hardening es un proceso, no un estado. Flujo recomendado:

### 9.1 Fuentes

- **Jenkins Security Advisories** (oficial, RSS): `https://www.jenkins.io/security/advisories/` — publican batches cada ~2 semanas.
- **Mailing list**: `jenkinsci-advisories@googlegroups.com`.
- **UI del propio controller**: `Manage Jenkins → Updates` marca plugins con updates de seguridad en rojo.

### 9.2 Flujo semanal (realista)

1. **Lunes**: revisar advisories nuevos. Clasificar por impacto en *tu* instalación (plugin instalado? versión afectada?).
2. **Martes**: para advisories de severidad `High`/`Critical` → crear ticket. Para `Medium` → batch con el próximo mantenimiento.
3. **Jueves (ventana de mantenimiento)**: aplicar updates en staging; smoke test de pipelines críticos; promover a prod si verde.
4. **Mensual**: revisar lista completa de plugins instalados → ¿alguno sin usar? → desinstalar.
5. **Trimestral**: revisar `scriptApproval.xml` → ¿sigue necesitándose cada firma aprobada?

### 9.3 Priorización por severidad × esfuerzo

| Severidad | Esfuerzo bajo | Esfuerzo medio | Esfuerzo alto |
|-----------|---------------|-----------------|---------------|
| **Critical** | Hoy | Hoy (con workaround) | Hoy (con workaround) |
| **High**     | Esta semana | Esta semana | Esta quincena |
| **Medium**   | Esta quincena | Este mes | Backlog con fecha |
| **Low**      | Batch mensual | Backlog | Backlog |

"Esfuerzo alto" típico: plugin crítico sin reemplazo, update rompe pipelines, o requiere re-aprobar scripts. "Workaround": deshabilitar el feature vulnerable mientras llega la fix.

---

## 10. Errores típicos (y cómo detectarlos)

| Síntoma | Causa probable | Diagnóstico |
|---------|----------------|-------------|
| "Todo el mundo es admin" | `Logged-in users can do anything` o `authenticated` con `Overall/Administer`. | `Manage Jenkins → Configure Global Security` → ver estrategia activa. |
| Secretos en logs | Variable usada sin `withCredentials` o `echo $SECRET`. | `grep -r 'echo .*PASS\|echo .*TOKEN' Jenkinsfile*`. |
| "Nadie sabe por qué este script fue aprobado" | Aprobación hecha por UI sin commit en `jenkins.yaml`. | Diff entre `scriptApproval.xml` vivo y lo versionado. |
| Plugin con CVE crítico sin parchar | Falta proceso de monitor de advisories. | Sin feed activo → crear uno (ver §9). |
| `anonymous` tiene `Overall/Read` | "Para que el status page sea público". | Mover el status a un reverse proxy público; cerrar anonymous. |
| Credentials en `GLOBAL` cuando podrían ser `folder` | Falta de disciplina al crearlas por UI. | Audit del credentials store por scope. |

---

## Resumen operativo

- **Autenticación**: SSO siempre; local DB solo para bootstrap.
- **Autorización**: `Role-based Strategy`; roles a grupos, no a usuarios; project roles por regex para aislar equipos.
- **Credentials**: scope mínimo (`folder` > `GLOBAL` > `SYSTEM`); consumir con `withCredentials`; integrar Vault/Secrets Manager cuando se pueda.
- **Groovy sandbox**: on; cada aprobación de script versionada en `jenkins.yaml` con commit explicativo.
- **Transversales**: CSRF on, agent→controller on, anonymous read off, CLI off si no se usa.
- **CVEs**: suscribirse al feed, ciclo semanal de revisión, prioridad severidad × esfuerzo.
- **Fuente de verdad**: `jenkins.yaml` en Git. Si no está versionado, no existe.
