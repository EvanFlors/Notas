# Ejemplo 02 — Credentials y Script Approval en JCasC

> Lectura y análisis. Sin ejecución. Objetivo: ver un `jenkins.yaml` con el bloque de credentials **dummy** y entender el flujo del Script Approval.

## 1. Credentials con valores dummy

```yaml
credentials:
  system:
    domainCredentials:
      - credentials:
          # ---- Secret text (API tokens, PATs) ----
          - string:
              scope: GLOBAL
              id: "github-token"
              secret: "${GITHUB_TOKEN_SECRET}"
              description: "GitHub PAT for CI (dummy via env in demo)."

          # ---- Username + password (registries, DBs) ----
          - usernamePassword:
              scope: GLOBAL
              id: "docker-registry"
              username: "demo-user"
              password: "${DOCKER_REGISTRY_PASSWORD}"
              description: "Container registry push (dummy)."

          # ---- SSH private key (deploy keys, agent SSH) ----
          - basicSSHUserPrivateKey:
              scope: GLOBAL
              id: "deploy-key-staging"
              username: "deploy"
              description: "SSH deploy key for staging (dummy)."
              privateKeySource:
                directEntry:
                  privateKey: "${STAGING_DEPLOY_PRIVATE_KEY}"

          # ---- Secret file (kubeconfigs, SA JSON) ----
          - file:
              scope: GLOBAL
              id: "kubeconfig-staging"
              fileName: "kubeconfig"
              secretBytes: "${KUBECONFIG_STAGING_B64}"
              description: "kubeconfig for staging cluster (dummy base64)."
```

### Notas clave

- **Todos los `secret:` / `password:` / `privateKey:` vienen de variables de entorno** (`${...}`). El YAML en Git nunca contiene el valor.
- **`description`** siempre incluye `(dummy)` o `(demo)` en los ejemplos para dejar claro que no es prod.
- **`scope: GLOBAL`** es correcto solo si no hay folders por equipo. Si los hay, estas credentials deberían moverse dentro del folder.

## 2. Consumo en pipeline (snippet)

```groovy
pipeline {
  agent any
  stages {
    stage('Login y push') {
      steps {
        withCredentials([
          string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN'),
          usernamePassword(credentialsId: 'docker-registry',
                           usernameVariable: 'REG_USER',
                           passwordVariable: 'REG_PASS')
        ]) {
          sh '''
            # Jenkins enmascara los valores en el log si vienen de withCredentials.
            # NO HAGAS: echo "token es $GITHUB_TOKEN"  <-- leak garantizado.
            echo "$REG_PASS" | docker login ghcr.io -u "$REG_USER" --password-stdin
            curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" \
                 https://api.github.com/user >/dev/null
          '''
        }
      }
    }
  }
}
```

## 3. Script Approval: anatomía

Cuando un pipeline llama una API Groovy fuera de la lista blanca del sandbox, falla con:

```
org.jenkinsci.plugins.scriptsecurity.sandbox.RejectedAccessException:
Scripts not permitted to use method hudson.model.Run getPreviousBuild
```

El controller registra la firma pendiente. En JCasC, las firmas aprobadas quedan declaradas así:

```yaml
security:
  scriptApproval:
    approvedSignatures:
      # Lectura de metadata del build previo — razonable.
      - "method hudson.model.Run getPreviousBuild"

      # Suma de ints — benigno, lo pedía un pipeline matemático.
      - "staticMethod java.lang.Math max int int"

      # Clasificación por campos accesibles — lectura segura.
      - "method hudson.model.Job getLastBuild"

    # NUNCA incluyas aquí:
    #   - "method groovy.lang.GroovyShell evaluate java.lang.String"
    #   - "staticMethod ... invoke ..."
    # Son escapes universales del sandbox: aprobarlos = sandbox off.
```

## 4. Walkthrough: aprobar un script paso a paso

Pipeline `team-a/build` falla con:

```
Scripts not permitted to use method hudson.model.Run getPreviousBuild
```

### 4.1 Antes de aprobar — las 4 preguntas

1. **¿Qué pipeline la necesita?** → `team-a/build`.
2. **¿Para qué?** → leer el estado del build anterior y decidir si saltar la stage de integración.
3. **¿Es una API razonable o un escape?** → lectura de metadata ⇒ razonable. No es `invoke` ni `evaluate`.
4. **¿Hay alternativa declarative?** → `when { changeRequest() }` cubre PR, pero no "estado del build anterior". No hay alternativa clean.

Conclusión: aprobar la firma concreta.

### 4.2 Aprobar y versionar

1. UI: `Manage Jenkins → In-process Script Approval → Approve`.
2. Añadir la línea al `jenkins.yaml`:
   ```yaml
   security:
     scriptApproval:
       approvedSignatures:
         - "method hudson.model.Run getPreviousBuild"
   ```
3. Commit:
   ```
   security(script-approval): allow Run.getPreviousBuild for team-a/build
   
   Pipeline uses previous build status to decide skip of integration stage.
   Reviewed-by: @alice-platform
   Owner: team-a
   ```
4. PR revisado por otro admin de plataforma.
5. Merge → en el próximo `configuration-as-code reload`, Jenkins reconcilia el estado.

### 4.3 Qué pasa si alguien aprueba desde UI y no commitea

El controller lo acepta, el pipeline deja de fallar, nadie se entera. En 6 meses nadie recuerda por qué `getPreviousBuild` está aprobado — ni si la necesidad sigue viva. En la revisión trimestral de `scriptApproval` nadie puede justificar quitarla. Resultado: una lista blanca que solo crece.

> **El commit es la auditoría.** Sin él, el control no existe.

## 5. Red flags en bloques `credentials:` / `scriptApproval:`

| Red flag | Por qué |
|----------|---------|
| `secret: "ghp_XXXXXXXXXXXX..."` en el YAML | Token real en Git. Rotarlo YA. |
| `password: "P@ssw0rd!"` literal | Idem. |
| `approvedSignatures:` incluye `GroovyShell.evaluate` o `MethodCall.invoke` | Sandbox desactivado de facto. |
| Dos usuarios distintos con `scope: SYSTEM` para credenciales que usan pipelines | SYSTEM significa "solo controller". Un pipeline no puede leerlo; alguien va a "arreglarlo" moviendo todo a SYSTEM. |
| `scope: GLOBAL` para una credencial que solo usa un folder | Scope mayor del necesario; mover a folder. |

## 6. Para profundizar

- Documentación de credentials: `https://plugins.jenkins.io/credentials/`.
- Documentación de script security / sandbox: `https://plugins.jenkins.io/script-security/`.
- Vault plugin: `https://plugins.jenkins.io/hashicorp-vault-plugin/`.
