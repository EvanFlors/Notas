# argo-11 — Lección: Internals y seguridad de Argo CD

> 12 secciones. Al final hay preguntas de evaluación. Responde sin consultar.

## 1. Por qué este módulo

Hasta aquí usamos Argo CD como una caja negra benigna: lo instalamos (`argo-02`), aprendimos sus Applications/Projects/ApplicationSets, y empezamos a *delegarle* la operación del cluster. Pero Argo CD tiene **permisos de dios** sobre uno o varios clusters: su ServiceAccount `argocd-application-controller` suele ir atado a un `ClusterRole/cluster-admin` por default. Comprometer Argo CD es comprometer el fleet entero.

Este módulo cambia la postura: dejamos de confiar en los defaults, abrimos el capó, y endurecemos la instalación igual que endureceríamos un `kube-apiserver`. La prueba de éxito no es "funciona", es "**sobrevive una auditoría**": SSO, no admin local, HTTPS, PSA `restricted`, backup verificado.

El tema divide limpiamente en tres bloques:

- **Internals** — qué es cada pod, cómo hablan entre sí, dónde vive el estado.
- **Seguridad** — autenticación, Argo CD RBAC (distinto del RBAC de K8s), hardening.
- **Resiliencia** — backup/restore. Como el estado es CRs, un backup del namespace basta.

## 2. Componentes y comunicación interna

Instalación estándar (manifiesto `install.yaml` o chart `argo-cd`) despliega:

```
                          ┌──────────────────────────────────┐
Browser / argocd CLI ───▶ │  argocd-server (Deployment)       │
   HTTPS + gRPC-web       │  - Web UI, REST, gRPC             │
                          │  - Autenticación (local/OIDC/SSO) │
                          │  - Autorización (argocd-rbac-cm)  │
                          └──────────────────────────────────┘
                                 │ gRPC
                                 ▼
   ┌───────────────────────────────────────────────────────────┐
   │  repo-server (Deployment)   │  application-controller      │
   │  - clona repos Git          │  (StatefulSet, sharded)      │
   │  - render helm/kustomize/   │  - reconcilia Applications   │
   │    jsonnet                  │  - watcher de recursos del   │
   │  - devuelve manifests       │    cluster target            │
   │    como texto               │  - decide sync/health        │
   └───────────────────────────────────────────────────────────┘
                 │                          │
                 ▼                          ▼
         ┌──────────────┐           ┌──────────────────┐
         │  redis       │           │  K8s apiserver   │
         │  (caché TTL) │           │  (cluster target)│
         └──────────────┘           └──────────────────┘

   ┌───────────────────────────────┐    ┌──────────────────────────┐
   │ applicationset-controller     │    │ notifications-controller │
   │ (expande ApplicationSets a    │    │ (triggers → Slack/webhook│
   │  N Applications)              │    │  /email/opsgenie…)       │
   └───────────────────────────────┘    └──────────────────────────┘

   ┌───────────────────────────────┐
   │ dex-server (opcional)         │
   │ federa OIDC/SAML/LDAP/GitHub  │
   └───────────────────────────────┘
```

**Protocolos reales**:

- `argocd-server` ↔ `repo-server`: **gRPC** interno (puerto `8081`), sin TLS por default dentro del cluster — se asume que la red del cluster está aislada; si no, usa NetworkPolicy o mTLS por sidecar.
- `argocd-server` ↔ `application-controller`: ambos leen/escriben los mismos CRs; no se hablan directamente. Coordinan vía apiserver + `redis`.
- Todos ↔ `redis`: TCP, auth por password opcional (`argocd-redis-cm`); si lo expones, pon password y TLS.
- `argocd-server` ↔ `dex-server`: HTTP interno (puerto `5556`).
- Cliente (browser, CLI) ↔ `argocd-server`: HTTPS por default; `gRPC-web` sobre HTTP/2 para el CLI y la UI.

**Redis es *caché, no estado***: guarda manifests renderizados, estado de Applications precomputado, sesiones. Si se cae, Argo CD lo reconstruye (más lento). **No requiere backup**.

## 3. Dónde vive el estado

Argo CD es casi *stateless* a nivel de disco. Todo su estado persistente son objetos de la API de Kubernetes:

| Tipo | Objeto | Qué contiene |
|------|--------|--------------|
| CR | `applications.argoproj.io` | Applications (source, destination, syncPolicy, status) |
| CR | `appprojects.argoproj.io` | Projects (sourceRepos, destinations, roles RBAC CSV, JWT tokens) |
| CR | `applicationsets.argoproj.io` | ApplicationSets (generators, template) |
| ConfigMap | `argocd-cm` | Settings globales: URL, OIDC config, resource customizations, kustomize version, Dex config inline |
| ConfigMap | `argocd-rbac-cm` | Policy CSV (quién puede qué en Argo CD) |
| ConfigMap | `argocd-cmd-params-cm` | Flags de los componentes (`server.insecure`, `controller.repo.server.timeout.seconds`, …) |
| ConfigMap | `argocd-tls-certs-cm` | CAs confiables para repos HTTPS self-signed |
| ConfigMap | `argocd-ssh-known-hosts-cm` | `known_hosts` para repos SSH |
| ConfigMap | `argocd-notifications-cm` | Templates y triggers de notifications |
| Secret | `argocd-secret` | `server.secretkey` (firma JWT), `admin.password` (bcrypt), `admin.passwordMtime`, OIDC client secret, webhook secrets |
| Secret | `argocd-initial-admin-secret` | Password temporal del admin, se borra tras cambiarla |
| Secret `type=repository` | Credenciales de repos (SSH key, token, GitHub App) |
| Secret `type=cluster` | Kubeconfig de clusters target registrados |
| Secret `type=repo-creds` | Credenciales *template* por URL prefix (p. ej. todos los repos `github.com/myorg/*`) |

**Consecuencia operativa**: haz backup del namespace `argocd` y recuperas el 100% del Argo CD en otro cluster. No hay base de datos, no hay volúmenes persistentes (más allá de PVCs opcionales de redis-HA o del repo-server para caché local, que no son críticos).

## 4. Modelo de autenticación

### 4.1 Admin local

Al instalar, Argo CD genera `argocd-initial-admin-secret` con el password del usuario `admin`. **Es la red de seguridad del primer día**: te permite entrar antes de configurar SSO. Se persiste como bcrypt en `argocd-secret` (`admin.password`).

Problemas:

- Sin rotación forzada ni expiración.
- Un solo credencial compartido — rompe trazabilidad.
- MFA imposible.

Regla productiva: **deshabilitar** en cuanto SSO esté verificado. En `argocd-cm`:

```yaml
data:
  admin.enabled: "false"
```

### 4.2 OIDC directo

Argo CD habla OIDC nativo si tu IdP lo soporta (Okta, Auth0, Keycloak, Entra ID, Google, …). En `argocd-cm`:

```yaml
data:
  url: https://argocd.example.com
  oidc.config: |
    name: Okta
    issuer: https://acme.okta.com
    clientID: 0oabcdefghi
    clientSecret: $oidc.okta.clientSecret   # referencia a key en argocd-secret
    requestedScopes: ["openid", "profile", "email", "groups"]
    requestedIDTokenClaims:
      groups:
        essential: true
```

El `$oidc.okta.clientSecret` es una **referencia a `argocd-secret`** (key `oidc.okta.clientSecret`). Nunca el valor literal en `argocd-cm`.

### 4.3 Dex (federador)

Dex se incluye en la instalación default. Útil cuando:

- Tu IdP es LDAP, SAML, o GitHub (OIDC estilo, no estándar).
- Quieres múltiples connectors (GitHub + Google + LDAP).

Config inline en `argocd-cm` bajo `dex.config:` (ver `examples/01-oidc-with-github/`).

### 4.4 SAML

Vía Dex con connector `saml`. Útil para IdPs enterprise (ADFS, Shibboleth). Más frágil que OIDC — usa OIDC si tu IdP lo ofrece.

### 4.5 JWT project tokens

Para automatización (CI que llama al API de Argo CD) no quieres usuario humano. En un `AppProject` creas un **role** con permisos acotados y generas un **JWT**:

```bash
argocd proj role create myproj ci-sync
argocd proj role add-policy myproj ci-sync \
  -a sync -o 'myproj/*' -p allow
argocd proj role create-token myproj ci-sync --expires-in 24h
```

El token es un JWT firmado con `server.secretkey`. Revocación: `argocd proj role delete-token myproj ci-sync <id>` o rotar `server.secretkey` (invalida todos los JWTs del cluster — nuclear).

## 5. Argo CD RBAC (CSV estilo Casbin)

**No es el RBAC de Kubernetes.** Es un sistema de autorización interno al propio Argo CD, que decide *quién puede hacer qué en la UI/API/CLI de Argo CD*. El RBAC de K8s decide *qué puede hacer el ServiceAccount de Argo CD en el cluster target*. Son dos capas distintas.

Fuente: ConfigMap `argocd-rbac-cm`.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly    # default role si no matchea nada
  scopes: '[groups]'               # qué claim del JWT usar como "sujeto"
  policy.csv: |
    # Formato: p, <subject>, <resource>, <action>, <object>, <effect>
    #   subject  = role:<name> | <user> | proj:<proj>:<role>
    #   resource = applications | clusters | repositories | projects | logs | exec | accounts | gpgkeys | certificates
    #   action   = get | create | update | delete | sync | override | action/* | *
    #   object   = <project>/<app>  (o <object>/<name>, o *)
    #   effect   = allow | deny
    p, role:readonly, applications, get, */*, allow
    p, role:readonly, projects, get, *, allow
    p, role:readonly, clusters, get, *, allow

    p, role:platform-admin, *, *, */*, allow

    p, role:team-a-dev, applications, get,    team-a/*, allow
    p, role:team-a-dev, applications, sync,   team-a/*, allow
    p, role:team-a-dev, applications, update, team-a/*, deny     # explicit deny

    # Bindings: g, <subject>, <role>
    g, platform-sre@acme.com,    role:platform-admin
    g, acme-github-org:team-a,   role:team-a-dev
```

**Reglas de evaluación** (orden importa):

1. `deny` gana sobre `allow` cuando ambos matchean.
2. Si nada matchea, se aplica `policy.default` (recomendado: `role:readonly` o `""` — este último = *deny-by-default*, el más seguro).
3. `scopes: '[groups]'` indica que los `g, <subject>, …` matchean contra el claim `groups` del ID token OIDC. Puedes ampliar a `'[groups, email]'`.

**Patrones productivos**:

- Un `role:readonly` global para visibilidad.
- Un role por **project** por **rol funcional** (`dev`, `operator`, `admin`).
- Admin global solo para `platform-admin`.
- `policy.default: ""` (deny-by-default) una vez que todos los grupos tienen binding.

**Anti-patrón clásico**:

```
p, role:*, applications, *, */*, allow
```

Esto es "quién sea con cualquier role puede hacer lo que sea sobre cualquier app". Lo verás en instalaciones hereditarias — es el equivalente Argo CD a `kubectl create clusterrolebinding --clusterrole=cluster-admin --user=…`.

## 6. Sharding del `application-controller`

El `application-controller` corre como **StatefulSet** porque cada réplica se asigna un **shard** estable (índice ordinal). Cada shard reconcilia un subconjunto de **clusters** registrados. El hash de distribución es por cluster, no por Application — todas las Apps de un cluster van al mismo shard, lo que preserva la coherencia de la vista.

Flags relevantes (en `argocd-cmd-params-cm` o directamente en el StatefulSet):

- `--replicas N` (equivalente al `.spec.replicas` del StatefulSet).
- `--sharding-algorithm` (`legacy` por default; `round-robin` disponible desde 2.8).
- `ARGOCD_CONTROLLER_REPLICAS` env var para que cada réplica sepa el total.

Cuándo escalar:

- >50 clusters, o
- >1000 Applications, o
- reconciliación tarda > `timeout.reconciliation` (default `180s`).

Cuándo **no** escalar: si solo tienes el cluster local, una réplica basta. Cada shard extra consume ~200–400 MiB de RAM.

## 7. ConfigMaps de configuración

Los cuatro ConfigMaps clave y qué va en cada uno:

- **`argocd-cm`**: *settings de aplicación*. `url`, `oidc.config`, `dex.config`, `resource.customizations` (health y ignoreDifferences globales por GVK), `kustomize.buildOptions`, `admin.enabled`, `users.anonymous.enabled`.
- **`argocd-rbac-cm`**: *solo* `policy.default`, `policy.csv`, `scopes`.
- **`argocd-cmd-params-cm`**: *flags* de los binarios de los componentes. Ej.: `server.insecure: "false"`, `controller.repo.server.timeout.seconds: "60"`, `applicationsetcontroller.enable.progressive.syncs: "true"`.
- **`argocd-secret`**: *secretos*. `admin.password` (bcrypt), `server.secretkey` (firma JWT), `oidc.<provider>.clientSecret`, webhook secrets.

**Regla**: nunca pongas secretos en `argocd-cm`; úsalos como referencias `$name:key` que resuelven contra `argocd-secret` o cualquier Secret del namespace. Ej.: `clientSecret: $argocd-secret:oidc.okta.clientSecret`.

## 8. Credenciales de repos

Tres niveles de granularidad:

1. **Por repo** (`Secret type=repository`): URL exacta + credencial. Específico pero no escala.
2. **Por prefijo** (`Secret type=repo-creds`): matchea URLs por prefijo (`https://github.com/myorg/`), ideal para "todos los repos de mi org usan esta GitHub App".
3. **Declarativo vs CLI**: puedes crearlos con `argocd repo add` (CLI) o aplicarlos con `kubectl apply` (declarativo + GitOps). Preferir declarativo — así el propio Argo CD puede gestionarse por GitOps.

**GitHub App > PAT** siempre que sea posible: rotación nativa, scopes finos, auditoría por app.

**SSH deploy key** > HTTPS token para repos privados pequeños — pero no escala a muchas apps.

**`insecure: true`** o `insecureIgnoreHostKey: true`: solo para desarrollo. En prod registra el host key en `argocd-ssh-known-hosts-cm` y los certs CA en `argocd-tls-certs-cm`.

## 9. Hardening priorizado

Lista en orden de **impacto / esfuerzo** (haz 1→N):

1. **Rotar `admin.password`** y guardarla en un password manager; borrar `argocd-initial-admin-secret`.
2. **SSO obligatorio** vía OIDC (sección 4). Verifica que puedes entrar como usuario humano real.
3. **Deshabilitar admin local**: `data.admin.enabled: "false"` en `argocd-cm`. Mantén el password en un sobre sellado para break-glass (y rota si lo usas).
4. **HTTPS obligatorio**: quita `--insecure` del Deployment `argocd-server` (equivale a `server.insecure: "false"` en `argocd-cmd-params-cm`) y pon un Ingress/Gateway con TLS real.
5. **Policy CSV *deny-by-default*** con roles por project (sección 5). `policy.default: ""`.
6. **PSA `restricted`** en el namespace `argocd`: labels `pod-security.kubernetes.io/enforce=restricted` (+ `audit`, `warn`). Los charts oficiales ya cumplen; aplica el label y verifica que ningún pod rompe.
7. **NetworkPolicy** default-deny en el namespace `argocd` con reglas específicas (ingress solo desde Ingress controller al `argocd-server`; egress a Git, a los apiservers de los clusters target, y a tu IdP).
8. **Rotación de `server.secretkey`** calendarizada (p. ej. cada 90 días o tras incidente). **Invalida todos los JWTs vigentes** — avisa a los equipos de CI.
9. **Backup Velero del ns `argocd`** con política diaria + ejercicio de restore trimestral.
10. **Auditar y recortar permisos de los Secrets `type=cluster`**: cada kubeconfig que registras es una llave; usa el `namespaces:` field para restringir el blast radius a los namespaces esperados (sin él, el controller tiene acceso cluster-wide en el target).

Dos puntos sutiles:

- **`kubectl.kubernetes.io/last-applied-configuration`**: cuando Argo CD aplica Secrets, por default este annotation **expone el Secret completo en claro**. Para Secrets gestionados por Argo CD, usa `ServerSideApply=true` (que no genera ese annotation) o `argocd.argoproj.io/sync-options: ServerSideApply=true` en el recurso.
- **Dex expone `/dex/callback` sin TLS interno**: si tu Ingress no termina TLS correctamente, el OIDC flow filtra el ID token. Verifica con `curl -I` el redirect.

## 10. Pod Security y NetworkPolicy en el ns `argocd`

PSA `restricted` nivel namespace:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

El manifest oficial de Argo CD cumple `restricted` en versiones recientes. Si usas el chart, verifica `securityContext` en los subcharts (controller, server, repo-server, dex). Si algún pod rompe, abre issue antes de bajar el nivel — típicamente es un flag heredado.

NetworkPolicy esquelética (ajusta a tu red):

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny, namespace: argocd }
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
# ingress al server desde el Ingress controller
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: ingress-to-server, namespace: argocd }
spec:
  podSelector: { matchLabels: { app.kubernetes.io/name: argocd-server } }
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: ingress-nginx } }
      ports: [{ port: 8080 }, { port: 8083 }]
---
# egress del repo-server a Git (HTTPS 443 + SSH 22)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: egress-git, namespace: argocd }
spec:
  podSelector: { matchLabels: { app.kubernetes.io/name: argocd-repo-server } }
  policyTypes: [Egress]
  egress:
    - to: [{ ipBlock: { cidr: 0.0.0.0/0, except: [10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16] } }]
      ports: [{ port: 443 }, { port: 22 }]
    - to: [{ namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: kube-system } } }]
      ports: [{ port: 53, protocol: UDP }]
```

Ajusta: si tu Git es GitHub Enterprise interno, no abras `0.0.0.0/0`.

## 11. Backup, restore, y DR

Modelo mental: **todo el estado de Argo CD es K8s objects en el namespace `argocd` + los CRs `Application`/`AppProject`/`ApplicationSet` (que viven en `argocd` por default)**. Por tanto hay dos técnicas equivalentes:

**A. Velero** — backup del namespace `argocd` + los CRDs. Pros: automatizable, scheduler nativo, incluye Secrets/ConfigMaps. Contras: requiere object storage y el controller instalado.

```bash
velero backup create argocd-$(date +%F) \
  --include-namespaces argocd \
  --include-cluster-resources=true \
  --wait
```

**B. `argocd admin export`** — dump de todos los objetos a YAML.

```bash
argocd admin export > argocd-state.yaml
# Restore (en cluster nuevo con Argo CD recién instalado):
argocd admin import - < argocd-state.yaml
```

Es más portable (no requiere Velero) pero no incluye los Secrets ni el ns completo — hay que combinarlo con `kubectl get secret -n argocd -o yaml` para los `argocd-secret`, `argocd-initial-admin-secret`, repo creds, y cluster creds.

**Ejercicio de restore**: nadie confía en un backup que no se ha restaurado. Trimestralmente:

1. Levanta un kind nuevo.
2. Instala Argo CD vanilla.
3. `velero restore` del backup.
4. Verifica que `kubectl -n argocd get apps` muestra todas, y que `argocd app sync <any>` funciona.
5. Documenta el tiempo total (RTO).

**Qué NO necesita backup**: `redis` (caché), PVCs del `repo-server` (caché local de repos), observed state en memoria del controller.

## 12. CVEs históricos y lecciones

Argo CD ha tenido CVEs instructivos — no para memorizar, sí para interiorizar el tipo de bugs:

- **CVE-2022-24348** (Path traversal en Helm/Kustomize values): un source malicioso podía leer archivos arbitrarios del `repo-server`. Lección: aislamiento del `repo-server` importa; úsalo en pod propio, con `readOnlyRootFilesystem`, sin secretos montados que no necesite.
- **CVE-2022-29165** (Autenticación bypass): un header manipulado permitía autenticarse como admin. Lección: mantén Argo CD **actualizado** — es un producto activo con parches de seguridad frecuentes; `renovate` o `argocd-image-updater` sobre el propio Argo CD.
- **CVE-2024-21661** (DoS por request grande): mandar un payload grande colgaba el server. Lección: pon rate-limits/body-size en el Ingress por delante.

Patrones recurrentes:

- **Rendering de manifests es ejecución** (Helm render = `helm template`, Jsonnet = evaluación Turing-completa) — el `repo-server` es el componente más atacable, trátalo como código no confiable.
- **La UI es gRPC+WebSocket**: cualquier mal-manejo de autenticación en la frontera gRPC puede saltarse checks.
- **Los Secrets `type=cluster`** son kubeconfigs completos — su robo = acceso al cluster target.

Suscríbete a `argoproj/argo-cd` security advisories en GitHub.

---

## Preguntas de evaluación

Responde sin consultar; luego verifica.

1. ¿Cuál es la diferencia operacional entre **Argo CD RBAC** y **Kubernetes RBAC**? ¿Qué pasa si solo configuras uno de los dos?
2. Dado `policy.default: role:readonly` y un CSV con un `deny` explícito a `role:team-a-dev` sobre `update`, pero sin ninguna línea `allow` para `role:team-a-dev` sobre `get`, ¿puede un usuario del grupo team-a hacer `argocd app get team-a/billing`?
3. ¿Por qué el `application-controller` es un **StatefulSet** y no un Deployment? ¿Qué se rompe si lo cambias?
4. ¿Qué datos de Argo CD **NO** necesitan backup? ¿Por qué?
5. Tienes OIDC funcionando y acabas de desactivar `admin.enabled: "false"`. Un usuario reporta que ya no puede entrar. ¿Qué revisas primero?
6. ¿Qué es `$oidc.okta.clientSecret` en `argocd-cm`? ¿Por qué no se pone el valor literal?
7. ¿Qué efecto tiene rotar `server.secretkey`? ¿Cuándo lo haces?
8. Dibuja la ruta de un `argocd app sync myapp` desde el browser hasta que un `Deployment` cambia en el cluster target. Nombra cada componente que toca.
9. ¿Por qué se recomienda `ServerSideApply=true` para Secrets gestionados por Argo CD?
10. Tras un `velero restore` del namespace `argocd` en un cluster nuevo, ¿las Applications se re-sincronizan solas? ¿Qué podría faltar?
