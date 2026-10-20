# sec-13 — Lección: secretos a escala con Vault, ESO y Workload Identity

> 12 secciones. Mezcla conceptual + comandos ilustrativos. El laboratorio real vive en `examples/` y `activities/`.

---

## 1. El problema: por qué los secretos "normales" no escalan

Un equipo pequeño suele empezar así:

```
app/.env       ──► committed (o casi) en Git
k8s/secret.yaml ──► stringData: password: "s3cr3t"  (o base64, "idéntico")
CI/CD           ──► GITHUB_SECRETS inyecta vars
```

Durante **seis meses** funciona. Entonces aparecen *todos* los problemas a la vez:

1. **Rotación.** La password de la DB se filtró en un log. Hay que rotarla en 23 servicios, 4 environments, 2 clusters, el CI, el bastion y en el pager de 3 ingenieros. **Nadie** la rota. Vive para siempre.
2. **Auditoría.** El auditor pregunta: *¿quién leyó la API key de Stripe en los últimos 90 días?*. Nadie puede responder. El secreto estaba montado como env var en 11 Pods; cualquiera con `kubectl exec` podía leerla.
3. **Blast radius.** Un desarrollador junior aprende `kubectl get secret -o yaml` y descubre que ve todos los secretos de todos los servicios porque el `ServiceAccount` por defecto tiene permisos amplios.
4. **Compliance.** El equipo quiere SOC2 / ISO27001. El control pide "los secretos no se almacenan en texto plano fuera del vault". Un `Secret` K8s con `data` base64 **es** texto plano para el control: base64 no es cifrado.
5. **Multi-cloud / multi-cluster.** Hay 1 Secret Manager en AWS, 1 en GCP, y 2 clusters EKS/GKE. ¿Dónde vive la fuente de verdad? ¿Cómo evitamos que cada servicio reinvente el fetcher?

El patrón que resuelve las cinco cosas a la vez: **vault centralizado + secretos efímeros + puente declarativo hacia K8s + identidad cloud nativa en el Pod**.

Las tres piezas:

- **Vault centralizado** — HashiCorp Vault (o un Secret Manager cloud) como *source of truth*.
- **Puente declarativo** — External Secrets Operator (ESO) o Secrets Store CSI Driver.
- **Identidad del Pod** — Workload Identity (IRSA, GKE WI, Azure WI) para que el Pod se autentique sin tokens estáticos.

El resto de la lección descompone cada pieza.

---

## 2. HashiCorp Vault en 90 segundos

Vault es un *secret broker*: habla **secret engines** por detrás y **auth methods** por delante.

```
            ┌──────────── auth methods ────────────┐
            │  kubernetes | approle | oidc | cloud │
   client ──►  (prueba quién eres) → emite TOKEN  │
            └────────────────────┬─────────────────┘
                                 │
                                 ▼
                          ┌────────────┐
                          │   Vault    │
                          │  policies  │  ← ACLs: path + capabilities
                          └─────┬──────┘
                                │
            ┌───────────────────┴─────────────────────┐
            │           secret engines                │
            │  kv-v2 | database | pki | transit | aws │
            │  gcp   | azure    | ssh | totp   | ...  │
            └─────────────────────────────────────────┘
```

Tres conceptos clave:

- **Secret engine** — monta un *tipo* de secreto en un *path*. Ejemplos: `kv/` para pares clave/valor; `database/` para credenciales *dinámicas* contra un motor; `pki/` para emitir certificados X.509; `transit/` para cifrar/firmar como servicio.
- **Auth method** — cómo prueba un cliente quién es. **No** entregamos el token root por la red: lo cambiamos por un `vault token` tras un login (ej. `kubernetes` auth: *"soy el SA `payments` en el namespace `prod`"*).
- **Policy** — ACL asociada al token. Formato HCL. Permite capabilities `read | create | update | delete | list | sudo` sobre `path "kv/data/payments/*"`.

Modo **dev**: `vault server -dev` levanta un Vault **in-memory**, pre-inicializado y pre-unsealed, con un `root token` conocido. Lo usamos durante toda esta lección y los ejemplos. En producción, el flujo es:

```
init → recibe 5 unseal keys (Shamir) + root token
unseal → 3 de 5 operadores aportan su key
rotate root → el root token inicial se destruye
auto-unseal (cloud KMS) → elimina la ceremonia manual en reinicios
```

Pero esa parte **no** cabe en 6 h. Para el laboratorio, `vault server -dev -dev-root-token-id=root` basta.

---

## 3. Secret engines: `kv-v2`, `database`, `transit`, `pki`

### 3.1 `kv-v2` — el más común, el más mal usado

```
vault secrets enable -path=kv kv-v2
vault kv put kv/payments/stripe api_key=sk_test_abc123
vault kv get kv/payments/stripe
```

**v2** añade **versionado** y **soft-delete**. Lo que mete el equipo aquí es:

- **Secretos estáticos externos** que no se pueden emitir dinámicamente: API keys de SaaS, OAuth client secrets, webhook signing keys.
- **Credenciales raíz** que Vault usa para emitir dinámicas (ej. password del superuser de Postgres).

**Antipatrón:** meter en `kv/` passwords de DB *gestionadas por el equipo*. Eso debería ser `database/` dinámico.

### 3.2 `database` — el *killer feature*

```
vault secrets enable database

vault write database/config/payments-db \
    plugin_name=postgresql-database-plugin \
    allowed_roles="payments-app" \
    connection_url="postgresql://{{username}}:{{password}}@db:5432/payments?sslmode=disable" \
    username="vault_root" \
    password="<raíz-que-Vault-rota>"

vault write database/roles/payments-app \
    db_name=payments-db \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
                         GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="2m" max_ttl="10m"
```

Ahora cualquier cliente autorizado puede pedir **una credencial nueva**:

```
vault read database/creds/payments-app
# username = v-token-payments-app-abc-1700000000
# password = <aleatoria>
# lease_duration = 120s
```

La credencial **vive 2 minutos**. Pasado el TTL, Vault la **revoca** (ejecuta `DROP ROLE`). La app pide otra.

**Esto cambia el modelo mental:**

> "Rotación" deja de ser un *evento* y se convierte en una *propiedad del TTL*.

Un atacante que *robe* la password tiene **120 s** para explotarla. Comparado con "la password vive 2 años en 23 Pods", el blast radius colapsa.

### 3.3 `transit` — encryption as a service

Vault no te devuelve una clave; recibe tu plaintext y te devuelve el ciphertext. Las claves **nunca** salen de Vault.

```
vault secrets enable transit
vault write -f transit/keys/pii-at-rest
vault write transit/encrypt/pii-at-rest plaintext=$(echo -n "evan@example.com" | base64)
# → ciphertext = vault:v1:AbC...
vault write transit/decrypt/pii-at-rest ciphertext=vault:v1:AbC...
```

Casos de uso:

- **Column-level encryption** en una DB: la columna `email` se guarda cifrada; la app pide a Vault que descifre cuando necesita el valor.
- **Rotación de clave sin tocar datos**: `vault write -f transit/keys/pii-at-rest/rotate`. Los ciphertexts viejos siguen descifrando (prefijo `v1:`); los nuevos usan `v2:`.
- **Pivote hacia HSM** o KMS cloud sin reescribir la app (Vault abstrae la clave real).

### 3.4 `pki` — certificados cortos

```
vault secrets enable pki
vault write pki/roles/internal-service allowed_domains="svc.cluster.local" allow_subdomains=true max_ttl="24h"
vault write pki/issue/internal-service common_name="payments.svc.cluster.local" ttl="1h"
```

Certs de **1 hora** firmados por una CA interna. Combinable con cert-manager (`issuer: vault`).

### 3.5 Otros engines mencionables

- `aws`, `gcp`, `azure` — Vault emite credenciales **cloud** efímeras (STS/service-account tokens) para que un workload temporal (CI job, pipeline) tenga permisos cloud sin IAM user permanente.
- `ssh` — Vault firma claves SSH **efímeras**; el bastion acepta solo certificados firmados por Vault con TTL de 15 min.
- `totp` — Vault emite códigos 2FA; útil para bots que necesiten 2FA en servicios externos.

---

## 4. Auth methods: `kubernetes`, `approle`, `oidc`, cloud IAM

### 4.1 `kubernetes`

El más usado dentro de un cluster. El Pod monta su **ServiceAccount token** (proyectado); Vault valida ese token contra el **TokenReview API** del cluster.

Flujo:

```
Pod ──► reads /var/run/secrets/kubernetes.io/serviceaccount/token
   │        (JWT firmado por el cluster)
   │
   ├──► POST /v1/auth/kubernetes/login { role=payments, jwt=<...> }
   │
   │   Vault ──► TokenReview(jwt) hacia el API server del cluster
   │   Vault ◄── OK, SA = system:serviceaccount:payments:payments-app
   │
   ◄──  vault token + ttl (ligado a la policy del role)
```

Nunca almacena password. El "secreto" de autenticación es el SA token, que **ya existe** por ser un Pod.

### 4.2 `approle`

Para workloads **fuera** del cluster (CI jobs, scripts, agentes). Dos factores:

- **RoleID** — identificador semi-público (puede vivir en env var).
- **SecretID** — token efímero, "wrap-and-deliver" (Vault entrega un wrapping token de 1 uso que, al desenvolver, produce el SecretID real).

```
vault read -field=role_id auth/approle/role/ci-job/role-id
vault write -f -wrap-ttl=60s auth/approle/role/ci-job/secret-id
# → wrapping_token = s.xxx (vivo 60 s, 1 solo uso)
```

Patrón "**trusted orchestrator**": el pipeline recibe el wrapping token; solo él puede desenvolverlo. Si alguien más lo intenta, Vault alerta y lo invalida.

### 4.3 `oidc`

Para humanos. Login con el IdP corporativo (Google Workspace, Okta, Azure AD) y Vault emite token con las policies derivadas del grupo del usuario. Reemplaza "cada ingeniero tiene su root token" por "cada ingeniero hace `vault login -method=oidc`".

### 4.4 Cloud IAM auth (`aws`, `gcp`, `azure`)

Vault valida la **identidad cloud nativa** de la máquina/instancia (STS caller identity, GCP metadata, Azure MSI). Útil cuando Vault vive en una VPC y los clientes son VMs.

### 4.5 Regla práctica

| Workload | Auth method |
|----------|-------------|
| Pod dentro del cluster | `kubernetes` |
| CI/CD en SaaS externo (GitHub Actions, GitLab) | `jwt` (OIDC) o `approle` |
| Script en una VM | `aws`/`gcp`/`azure` IAM |
| Humano | `oidc` |
| App legacy, bootstrap puntual | `approle` (último recurso) |

---

## 5. External Secrets Operator (ESO)

Vault resuelve el *backend*. Pero una app K8s típica consume secretos vía `env:` con `secretKeyRef`, o montándolos como ficheros desde un `Secret`. **ESO** es el puente declarativo: define en Git **qué secreto necesitas** y **de dónde** sin exponer el *valor*.

Dos CRDs principales:

- `SecretStore` / `ClusterSecretStore` — describe **dónde** está el backend (URL de Vault, auth method, path).
- `ExternalSecret` — describe **qué** sincronizar en qué `Secret` K8s destino, con qué `refreshInterval`.

Ejemplo:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-dev
spec:
  provider:
    vault:
      server: "http://vault.vault.svc.cluster.local:8200"
      path: "kv"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "payments"
          serviceAccountRef:
            name: "external-secrets"
            namespace: "external-secrets"
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: payments-stripe
  namespace: payments
spec:
  refreshInterval: "1m"
  secretStoreRef:
    kind: ClusterSecretStore
    name: vault-dev
  target:
    name: payments-stripe        # el Secret K8s resultante
    creationPolicy: Owner        # ESO lo crea y lo gestiona
  data:
    - secretKey: STRIPE_API_KEY
      remoteRef:
        key: payments/stripe
        property: api_key
```

Lo que queda en Git:

- **Qué** secreto necesita la app (`STRIPE_API_KEY`).
- **Dónde** vive (`payments/stripe` en el `kv` de Vault).

Lo que **no** queda en Git:

- El **valor**. Vive en Vault; ESO lo materializa en el `Secret` K8s cuando el Pod lo necesita.

### 5.1 `refreshInterval` y rotación

Cada `refreshInterval` ESO consulta Vault y actualiza el `Secret` K8s si cambió. Pero **el Pod sigue montando el valor cargado al arrancar**. Para que un cambio en Vault llegue al proceso hay dos patrones:

- **Reiniciar el Pod** (via `kubectl rollout restart deployment/...` o un operator tipo `reloader`).
- **Montar como fichero y usar un sidecar** que detecte cambios (Vault Agent sidecar hace esto nativo; ESO + reloader es el equivalente declarativo).

### 5.2 `creationPolicy`

- `Owner` — ESO crea y borra el `Secret`.
- `Merge` — ESO añade claves a un `Secret` que ya existe (p. ej. secrets gestionados por Helm).
- `None` — ESO solo valida que exista; no toca.

### 5.3 ESO vs vault-agent-injector

| Dimensión | ESO | Vault Agent Injector |
|-----------|-----|----------------------|
| Modelo | Operator K8s nativo, declarativo | Mutating webhook que inyecta sidecar Vault Agent |
| Secret final | `Secret` K8s (puede referenciarse con `secretKeyRef`) | Fichero en el filesystem del Pod |
| Compatibilidad con backends no-Vault | Alta (AWS SM, GCP SM, Azure KV, 1Password…) | Solo Vault |
| GitOps | Nativo (CRDs en Git) | Requiere anotaciones en Deployments |
| Blast radius | Un `Secret` K8s existe (visible con `kubectl get secret`) | Solo visible dentro del Pod |

**Regla:** si la organización tiene multi-backend o multi-cloud, ESO. Si es Vault-only y quieres evitar el `Secret` K8s intermedio, Vault Agent Injector.

### 5.4 Secrets Store CSI Driver (alternativa)

```
┌─ Pod ─────────────────────────┐
│  volumeMounts:                │
│    - name: secrets            │
│      mountPath: /mnt/secrets  │  ← fichero montado directo desde el backend
└───────────────┬───────────────┘
                │
        ┌───────▼──────────────┐
        │ Secrets Store CSI    │
        │ Driver + provider    │ (vault / aws / gcp / azure)
        └──────────────────────┘
```

Ventajas: no crea `Secret` K8s intermedio (menos superficie). Soporta `syncSecret: true` opcional si lo necesitas como env var.

Desventajas: pocas organizaciones lo tienen rodado; el ecosistema ESO es más grande.

---

## 6. Workload Identity (walkthrough)

Hasta aquí el Pod se autentica contra **Vault**. Pero muchas aplicaciones también necesitan hablar con **servicios cloud** (S3, SQS, BigQuery, Blob Storage). El antipatrón:

```
Pod ──► lee AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
        (vive en un Secret, igual que antes; rotación manual; auditoría pobre)
```

El patrón correcto: **Workload Identity**. El Pod proyecta un **OIDC token** firmado por el cluster; AWS/GCP/Azure confían en ese OIDC issuer y, dada una condición (`sub = system:serviceaccount:ns:sa`), emiten credenciales STS **efímeras**.

### 6.1 AWS IRSA (IAM Roles for Service Accounts) — walkthrough

**Pre-requisitos (fuera del scope de este laboratorio local):**

- Cluster EKS con **OIDC provider** registrado en IAM.
- Un IAM Role con `AssumeRoleWithWebIdentity` como trust policy, condicionado al `sub` del SA.

Pasos conceptuales:

```
1. Crear OIDC provider en IAM:
   aws eks describe-cluster --name <c> --query cluster.identity.oidc.issuer
   # Registrar ese issuer como OpenID provider en IAM.

2. Crear IAM Role con trust policy:
   {
     "Effect": "Allow",
     "Principal": { "Federated": "arn:aws:iam::<acct>:oidc-provider/<issuer-host>" },
     "Action": "sts:AssumeRoleWithWebIdentity",
     "Condition": {
       "StringEquals": {
         "<issuer-host>:sub": "system:serviceaccount:payments:payments-app"
       }
     }
   }

3. Anotar el ServiceAccount:
   kind: ServiceAccount
   metadata:
     name: payments-app
     namespace: payments
     annotations:
       eks.amazonaws.com/role-arn: arn:aws:iam::<acct>:role/payments-s3-reader

4. En el Pod no se configura nada: el AWS SDK detecta
   AWS_ROLE_ARN + AWS_WEB_IDENTITY_TOKEN_FILE y hace STS.AssumeRoleWithWebIdentity
   automáticamente, recibiendo credenciales de 1 hora.
```

**EKS Pod Identity** (más reciente) simplifica: no hace falta OIDC provider; el EKS API hace la asociación `SA ↔ Role` directamente. Mismo resultado, menos ceremonia.

### 6.2 GKE Workload Identity — walkthrough

```
1. Habilitar WI en el cluster (--workload-pool=PROJECT.svc.id.goog).
2. Crear GSA (Google Service Account) y conceder roles IAM que necesite.
3. Vincular KSA ↔ GSA:
   gcloud iam service-accounts add-iam-policy-binding \
     --role roles/iam.workloadIdentityUser \
     --member "serviceAccount:PROJECT.svc.id.goog[payments/payments-app]" \
     payments-gsa@PROJECT.iam.gserviceaccount.com
4. Anotar el KSA:
   annotations:
     iam.gke.io/gcp-service-account: payments-gsa@PROJECT.iam.gserviceaccount.com
```

El Pod obtiene tokens GCP sin un JSON key file.

### 6.3 Azure Workload Identity — walkthrough

Análogo con `AZURE_CLIENT_ID`/`AZURE_FEDERATED_TOKEN_FILE`; AKS proyecta el token OIDC y Azure AD lo valida contra un **Federated Credential** registrado en una **User Assigned Managed Identity**.

### 6.4 Vault + Workload Identity: combinación poderosa

El flujo completo en producción:

```
Pod (SA = payments-app)
   │
   ├── (A) GKE WI token ──► GCP ──► emite credenciales GCP efímeras (1h)
   │
   └── (B) proyecta SA token ──► Vault kubernetes auth
                              ──► emite vault token (TTL 1h)
                              ──► puede leer kv/payments/* y
                                  pedir database/creds/payments (TTL 2m)
```

**Cero** credenciales estáticas en el Pod. **Cero** credenciales estáticas en Git. Toda credencial efímera. Toda acción auditada.

Esto es el **punto final** del módulo. El capstone (`activities/01`) monta la parte (B) localmente.

---

## 7. Dynamic secrets como herramienta mental

El cambio importante **no** es "Vault emite credenciales". Es:

> El valor efímero por defecto *disuade* del antipatrón de guardarlo en Git / env vars / ConfigMaps.

Compara:

| Modelo | ¿Qué guardas? | Rotación | Blast radius de una fuga |
|--------|---------------|----------|--------------------------|
| Estático (`.env`) | el valor | manual, "cuando toque" | hasta que alguien se dé cuenta |
| Rotado periódicamente | el valor, pero con cron | el período del cron | hasta siguiente rotación |
| **Dynamic (TTL=120s)** | **nada; la app pide al vuelo** | **el TTL** | **≤ 120 s** |

El coste: la app tiene que **saber pedir** (SDK Vault, Vault Agent sidecar, ESO con `refreshInterval`). Un día de ingeniería frente a *n* páginas de incident response ahorradas.

Dynamic secrets **sustituyen** la operación de rotación. No la mejoran: la hacen desaparecer como evento.

---

## 8. Rotation policy: cómo diseñar

No todos los secretos pueden ser dinámicos. Diseñar la **política de rotación** significa, para cada tipo:

- **Trigger** — ¿qué dispara la rotación? (TTL vencido / cron / evento de compromiso / cambio de personal).
- **TTL / frecuencia** — ¿cuánto vive?.
- **Mecanismo** — ¿Vault lo rota solo? ¿Hay que llamar a una API externa? ¿Humano?.
- **Blast radius** — si falla el proceso, ¿qué se rompe?.
- **Zero-downtime path** — ¿se puede rotar sin reiniciar la app?.

Ejemplo para 5 tipos (que es exactamente el ejercicio de la actividad `02`):

| Secreto | Trigger | TTL | Mecanismo | Zero-DT | Comentario |
|---------|---------|-----|-----------|---------|------------|
| DB password | TTL | 2m | Vault `database/` | Sí (connection pool recicla) | Dynamic nativo. |
| API key externa (Stripe) | cron 90d | 90d | Script → API Stripe → Vault kv | Sí (dual-write + ventana) | Externa, no dinámica. |
| Cert TLS | 1/3 del ttl | 30d | cert-manager + Vault PKI | Sí (reload graceful) | Pseudo-dinámico. |
| OAuth client secret | compromiso | años | Humano + consola IdP + Vault kv | No (reinicio) | Rotación rara. |
| SSH host key | nunca (hardware) | ∞ | Reemplazo físico | N/A | No es un secret rotable; se protege. |

El framework: **cuanto más corto el TTL, más barata la fuga; cuanto más rotación requiere humano, más riesgo de que no ocurra**.

---

## 9. Break-glass procedures

Rotación automática + mínimo privilegio dejan un hueco: **la emergencia**. Caso típico:

> La integración de Datadog expiró de madrugada. On-call necesita *ya* la API key para pegarla en el nuevo endpoint. No hay tiempo de pasar por el `oidc` + revisión + merge en Git.

Un break-glass procedure correcto cumple cinco propiedades:

1. **Autenticación fuerte** — el on-call usa 2FA + hardware key.
2. **Rastro inmutable** — el acceso queda en `audit log` de Vault (`vault audit enable file file_path=/var/log/vault_audit.log`), con `timestamp`, `identity`, `path`, `operation`, `request_id`.
3. **Scope mínimo** — la policy `break-glass` solo abre lo necesario (no `root`). Ejemplo: `path "kv/data/datadog/*" { capabilities = ["read"] }`.
4. **TTL explícito** — el token de break-glass vive 15 min; se auto-revoca.
5. **Review obligatorio post-mortem** — en < 24 h el equipo revisa el audit log y confirma que la emergencia justificaba el uso.

Lo que **no** es break-glass:

- Mantener un `root token` escrito en un post-it "por si acaso".
- Compartir el password del admin de la UI.
- Un backdoor permanente "para desarrollo".

Un buen break-glass se diseña **antes** de necesitarlo. Durante la emergencia, lo único que debe estar escrito es la URL del runbook y los pasos.

---

## 10. Auditoría: qué debe quedar grabado

Vault audit log mínimo útil:

```
timestamp | request_id | identity (SA/user) | path | operation (read|write|delete) | source_ip | wrap_ttl | response_sanitized
```

Dos reglas:

- **No reveal values.** El audit log guarda el *path* y los *metadatos*, nunca el valor del secreto. Si lo guardara, el audit log sería *otro* secret store.
- **Hash de respuesta.** Vault incluye un `hmac-sha256` del valor (clave rotable) para que un auditor pueda **verificar** que dos reads devolvieron el mismo valor sin ver el valor.

Preguntas que un buen audit log debe poder responder en 1 query:

- *¿Quién leyó `kv/payments/stripe` en los últimos 30 días?*
- *¿Qué secretos leyó el SA `batch-jobs:nightly-import` el 15 de octubre?*
- *¿Hubo lecturas desde IPs fuera del CIDR corporativo?*
- *¿Cuántas veces fue usado el role de break-glass en el último trimestre?*

En producción el audit log va a un **sink inmutable** (S3 Object Lock, GCS retention policy) con **separación de duty**: los admins de Vault **no** pueden borrar el audit log.

---

## 11. Migración desde el antipatrón

Camino típico desde "`.env` en el repo" a "Vault + ESO + WI":

```
Fase 0:  ".env" en el repo.                               ← inseguro
Fase 1:  .env en 1Password / Bitwarden. Humanos copian.   ← mejor, pero manual
Fase 2:  CI inyecta secretos via GITHUB_SECRETS.          ← scoped, pero estático
Fase 3:  K8s Secret escrito a mano (sealed-secrets o SOPS)← cifrado at rest
Fase 4:  Vault + ESO. Secretos estáticos en kv-v2.        ← source of truth centralizado
Fase 5:  Dynamic secrets donde se pueda.                  ← rotación sin evento
Fase 6:  Workload Identity. Cero credenciales cloud en Pod← end state
```

Cada fase es un **upgrade local** respecto a la anterior; no hace falta llegar a la Fase 6 en el primer sprint. La trampa es **quedarse** en Fase 3 pensando que "ya estamos" porque "los secrets están cifrados". **Cifrados at rest** no significa **efímeros ni auditados**.

---

## 12. Qué llevarse

Al terminar deberías poder:

- Levantar Vault en modo dev, enlazarlo a un cluster `kind` por el método `kubernetes` y hacer que un Pod lea un secreto sin que ese secreto esté nunca en Git.
- Instalar ESO con Helm, declarar un `ClusterSecretStore` y un `ExternalSecret`, y ver cómo aparece un `Secret` K8s *materializado* desde Vault con un `refreshInterval` que lo refresca.
- Reproducir una credencial dinámica de PostgreSQL con TTL de 2 min y ver cómo Vault la revoca al expirar.
- Explicar en una pizarra la diferencia entre **ESO**, **Vault Agent Injector** y **Secrets Store CSI Driver**, y en qué contexto gana cada uno.
- Describir el flujo de **IRSA / GKE WI / Azure WI** y por qué elimina el último `AWS_SECRET_ACCESS_KEY` del Pod.
- Diseñar un ADR de rotación + break-glass defendible frente a un auditor para 5 tipos de secretos distintos.

Síntesis de una línea:

> **Los secretos a escala no se "guardan mejor": se emiten efímeros, se auditan por defecto y la identidad del workload es nativa, no un token pegado con cinta.**

El resto del módulo son los pasos para que esa frase deje de ser slogan.
