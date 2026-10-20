# Lección — Projects, RBAC y boundaries en Argo CD

> 12 secciones. Lee en una pasada; vuelve a cada sección cuando toque el ejemplo o la actividad asociada.

---

## 1. Por qué existen los `AppProject`

Argo CD, instalado sin más, trae un project llamado `default` que es **completamente permisivo**: cualquier repo, cualquier cluster, cualquier namespace, cualquier tipo de recurso. Es útil para empezar y catastrófico para multi-tenancy.

Un `AppProject` es, por diseño, **la barrera de tenencia** de Argo CD. No el namespace del cluster target, ni el repo de Git, ni el usuario humano: el project. Cada `Application` pertenece a un project (campo `spec.project`), y las policies del project deciden si una `Application` puede siquiera *crearse* con esos parámetros, y qué roles pueden operarla.

Dicho con un ejemplo: un equipo "payments" no debería poder sincronizar en el namespace `checkout-prod` aunque, por accidente, apunte su `Application` ahí. El project `team-payments` debería rechazar la Application antes de que ningún `kubectl apply` ocurra.

La consecuencia práctica: **si no diseñas projects, no tienes multi-tenancy**. Tienes un cluster compartido con todos operando como admin.

---

## 2. Anatomía del CR `AppProject`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-payments
  namespace: argocd           # SIEMPRE en el namespace de Argo CD
spec:
  description: "Boundaries for the Payments team"

  sourceRepos:
    - https://github.com/acme/payments-manifests.git
    # - '*'   # anti-patrón: equivale a 'cualquier repo'

  destinations:
    - server: https://kubernetes.default.svc
      namespace: payments-*            # glob permitido
    # Si usas destination.name en lugar de .server, DEBES declarar el cluster
    # con argocd cluster add y su "name" aquí.

  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
    - group: rbac.authorization.k8s.io
      kind: ClusterRole

  clusterResourceBlacklist: []

  namespaceResourceWhitelist:
    - group: ''
      kind: '*'
    - group: apps
      kind: '*'
    - group: networking.k8s.io
      kind: '*'

  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota     # el equipo NO decide sus cuotas

  orphanedResources:
    warn: true                # avisa de recursos no gestionados en el namespace

  roles: []                   # ver sección 6
```

Campo a campo:

- **`sourceRepos`** — lista blanca de repos Git/Helm/OCI. Se admite glob. `*` es equivalente a "cualquier repo"; no lo pongas en projects reales.
- **`destinations`** — pares `(cluster, namespace)` permitidos. El cluster se identifica por `server` (URL) o `name` (etiqueta configurada con `argocd cluster add`). El namespace soporta glob.
- **`clusterResourceWhitelist`** — recursos cluster-scoped que el project puede crear. Vacío = **ninguno**. Si tu Application necesita crear un `Namespace`, debe listar `(group: '', kind: Namespace)` aquí.
- **`clusterResourceBlacklist`** — lista negra de cluster-scoped (se evalúa después del whitelist).
- **`namespaceResourceWhitelist` / `namespaceResourceBlacklist`** — análogo para recursos namespaced.
- **`orphanedResources`** — detecta recursos en los namespaces target que no vienen de ninguna `Application` del project. `warn: true` solo avisa; útil para ver drift humano.
- **`roles`** — roles *de project*, con sus policies y JWT tokens asociados (sección 6).

Regla mental: whitelists vacías significan **nada permitido**. Si una Application falla con `is not permitted in project`, el 90 % de las veces falta una entrada en algún whitelist.

---

## 3. Dos RBAC distintos: Argo CD RBAC vs Kubernetes RBAC

Confusión número uno del módulo. Hay dos sistemas de permisos, totalmente independientes:

**Argo CD RBAC** — gobierna **quién puede hacer qué dentro de Argo CD**:

- ¿El usuario `alice` puede ver la Application `payments-api`?
- ¿Puede `sync`-earla? ¿Puede `override` de parámetros? ¿Puede `delete`?
- ¿Puede crear nuevas Applications en el project `team-payments`?

Se configura en el ConfigMap `argocd-rbac-cm` (y en los `roles` del `AppProject`). El sujeto es un usuario, un grupo SSO o un JWT token.

**Kubernetes RBAC** — gobierna **qué puede hacer Argo CD en el cluster target**:

- Cuando el `application-controller` aplica un manifest en el cluster, lo hace con un **ServiceAccount**. Ese SA tiene (o no) permisos para `create deployments`, `patch services`, `delete namespaces`, etc.
- Si falta permiso, el apply falla con un `Forbidden` nativo de Kubernetes — Argo CD no puede "saltárselo" aunque la policy de Argo CD diga que sí.

En el cluster donde se instala Argo CD, el ServiceAccount `argocd-application-controller` suele ser `cluster-admin` (install por defecto). En **clusters remotos** registrados con `argocd cluster add`, Argo CD crea un SA en ese cluster y lo bindea con los permisos que indiques — ahí sí puedes y debes aplicar mínimo privilegio.

Resumen operativo:

| Capa | Pregunta que responde | Dónde se configura |
|------|-----------------------|---------------------|
| Argo CD RBAC | ¿Puedo pulsar "Sync" en esta Application? | `argocd-rbac-cm` + `AppProject.roles` |
| K8s RBAC | ¿Puede Argo CD crear ese `Deployment`? | `ServiceAccount` + `Role/ClusterRoleBinding` en el cluster target |
| `AppProject` boundaries | ¿Puede siquiera *existir* esta Application con este source/destination? | `AppProject.spec` |

Las tres capas se aplican en cadena. Si cualquiera dice no, la operación falla.

---

## 4. El modelo Casbin y el formato CSV de policies

El RBAC de Argo CD está construido sobre [Casbin](https://casbin.org/) y usa un formato CSV de policies. El `argocd-rbac-cm` se ve así:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    # Reglas: p, <subject>, <resource>, <action>, <object>, <effect>
    p, role:payments-admin, applications, *, team-payments/*, allow
    p, role:payments-admin, projects, get, team-payments, allow
    p, role:payments-viewer, applications, get, team-payments/*, allow

    # Asignaciones: g, <user o grupo>, <role>
    g, alice@acme.com, role:payments-admin
    g, acme:payments-team, role:payments-admin
    g, acme:security-readonly, role:readonly
```

Partes:

- **`policy.default`** — role que se aplica si el usuario no coincide con ninguno asignado. `role:readonly` es un buen default; `role:admin` sería un desastre.
- **`p` lines** — permisos. Formato: `p, subject, resource, action, object, effect`.
  - `resource`: `applications`, `projects`, `clusters`, `repositories`, `exec`, `logs`, `certificates`, `gpgkeys`, `accounts`.
  - `action`: `get`, `create`, `update`, `delete`, `sync`, `override`, `action/<name>`, `*`.
  - `object`: patrón `<project>/<app>` para applications. Soporta glob.
  - `effect`: `allow` o `deny`. `deny` tiene prioridad.
- **`g` lines** — mapean usuarios o grupos SSO a roles.

El object `team-payments/*` significa "cualquier Application cuyo `spec.project` sea `team-payments`". Combinado con los boundaries del propio `AppProject`, obtienes aislamiento real.

Nota: las policies del `AppProject.spec.roles[].policies` usan el mismo formato CSV, pero el `subject` está implícito (el role del project) y el `object` debe empezar por el nombre del project.

---

## 5. Built-in roles y por qué no debes usarlos tal cual

Argo CD trae dos roles built-in:

- **`role:admin`** — todo permitido. Equivalente a `cluster-admin`.
- **`role:readonly`** — `get` en todo. Útil como `policy.default`.

Son útiles para arrancar y para break-glass, pero **no son suficientes para equipos**. Si tu única granularidad es "admin total" vs "readonly total", no tienes multi-tenancy; tienes dos castas.

El patrón real es crear roles por equipo y por función:

- `role:team-payments-admin` → `*` sobre `team-payments/*`.
- `role:team-payments-developer` → `get`, `sync`, `action/*` sobre `team-payments/*`; sin `delete`, sin `override`.
- `role:team-payments-viewer` → `get` sobre `team-payments/*`.
- `role:ci-syncer-payments` → `get`, `sync` sobre `team-payments/*`. Para pipelines.

Y luego mapear grupos SSO (o usuarios individuales si no hay SSO todavía) a esos roles.

---

## 6. `AppProject.roles`: roles locales al project y JWT tokens

Los `roles` definidos *dentro* de un `AppProject` son otra forma de otorgar permisos, con una característica única: **pueden emitir JWT tokens**. Son perfectos para pipelines de CI que necesitan `sync` desde fuera del cluster sin credenciales de usuario humano.

```yaml
spec:
  roles:
    - name: ci-syncer
      description: "CI pipeline: solo puede sync-ear apps de este project"
      policies:
        - p, proj:team-payments:ci-syncer, applications, get, team-payments/*, allow
        - p, proj:team-payments:ci-syncer, applications, sync, team-payments/*, allow
      groups: []            # también se pueden mapear grupos SSO aquí
```

El `subject` del role tiene formato `proj:<project>:<role>` — es implícito, Argo CD lo construye.

Para emitir el token:

```bash
argocd proj role create-token team-payments ci-syncer \
  --expires-in 24h \
  --token-only
# imprime el JWT; guárdalo en un secret del runner de CI
```

Propiedades importantes:

- El token es un **JWT firmado por Argo CD** (secret `argocd-secret`, campo `server.secretkey`).
- Se autentica contra `argocd` CLI con `--auth-token <jwt>`.
- Se puede listar y revocar: `argocd proj role list-tokens team-payments ci-syncer` y `argocd proj role delete-token`.
- **No tiene refresh**. Caduca y punto. Rota antes de la expiración.
- Si rotas el `server.secretkey`, invalidas todos los JWT emitidos. Útil en incident response.

Anti-patrón: emitir un token del role `admin` del project `default` "para que CI tenga permisos amplios". Entonces no has restringido nada.

---

## 7. SSO/OIDC: por qué el flujo cambia radicalmente

Sin SSO, Argo CD gestiona usuarios locales (`argocd-cm` → `accounts.<name>`). Es manejable para un equipo pequeño, pero no escala y acopla el ciclo de vida de usuarios al despliegue de Argo CD.

Con SSO (OIDC directo contra un IdP, o vía **Dex** empaquetado con Argo CD), el flujo es:

1. El usuario abre la UI de Argo CD y hace clic en "Login via <IdP>".
2. OIDC redirige al IdP (Google, Okta, Keycloak, GitHub…), autentica y devuelve un ID token.
3. Argo CD extrae `sub` (identidad) y `groups` (membresías) del token.
4. El RBAC CSV mapea esos `groups` a roles:
   ```
   g, acme:payments-team, role:team-payments-admin
   ```
5. El usuario queda autorizado según el role.

Dos elementos clave:

- **El claim `groups`** debe venir en el token. En Google requiere configuración extra; en Keycloak es trivial; en GitHub se mapea desde el claim `teams` de la organización (ver `argocd-cm` → `dex.config` para github connector).
- **`scopes`** en `argocd-cm` debe incluir `groups` para que Argo CD confíe en el claim:
  ```yaml
  oidc.config: |
    name: Keycloak
    issuer: https://keycloak.acme.com/realms/acme
    clientID: argocd
    clientSecret: $oidc.keycloak.clientSecret
    requestedScopes: ["openid", "profile", "email", "groups"]
    requestedIDTokenClaims:
      groups:
        essential: true
  ```

El ejemplo `02-rbac-with-oidc-groups/` muestra el ConfigMap completo (sin IdP real; es demostrativo).

---

## 8. `orphanedResources`, `signatureKeys` y otras garantías

Dos campos del `AppProject` que suelen ignorarse y que suben el listón de seguridad:

**`orphanedResources`**:

```yaml
orphanedResources:
  warn: true
  ignore:
    - kind: ConfigMap
      name: istio-ca-root-cert
```

Detecta recursos en los namespaces target del project que **no pertenecen a ninguna Application** del project. Es ruido útil: aparece un `Deployment` creado a mano con `kubectl apply` por alguien que no debería, y Argo CD te avisa. No prune automático (ese flag no existe aquí; `prune` es por Application).

**`signatureKeys`**:

```yaml
signatureKeys:
  - keyID: 4AEE18F83AFDEB23
```

Si está configurado, Argo CD **rechaza commits sin firma GPG válida** de una de las keys listadas. Combinado con "require signed commits" en el repo, cierra el bucle: nadie puede inyectar manifests sin firmar. Requiere `gpgkeys` configuradas en Argo CD.

Otros útiles:

- `syncWindows` — ventanas de mantenimiento (bloquea/permite sync en horarios específicos; se verá a fondo en `argo-05`).
- `permitOnlyProjectScopedClusters: true` — fuerza que el project solo use clusters registrados explícitamente para ese project (defensa en profundidad contra el patrón `destinations: '*/*'`).

---

## 9. ServiceAccounts en clusters remotos y mínimo privilegio en K8s

Cuando registras un cluster remoto:

```bash
argocd cluster add my-remote-context --name prod-eu
```

Lo que ocurre internamente:

1. `kubectl` lee el context `my-remote-context`.
2. Argo CD crea en ese cluster: `ServiceAccount argocd-manager` en `kube-system`, `ClusterRole argocd-manager-role` con `*/*/*`, y un `ClusterRoleBinding`.
3. Guarda el token del SA en un `Secret` del namespace `argocd` (en el cluster donde está Argo CD) con label `argocd.argoproj.io/secret-type=cluster`.

El default es **cluster-admin en el remoto**. Para mínimo privilegio:

- Crea tú el ServiceAccount y el `ClusterRole` acotado (solo los recursos y namespaces que ese Argo CD necesitará tocar).
- Pasa `--service-account <nombre>` a `argocd cluster add`, o edita el secret manualmente apuntando al token/CA correctos.
- O usa `--namespace` repetido para limitar a namespaces concretos y Argo CD creará RoleBindings namespaced en lugar de un ClusterRoleBinding.

En producción, un patrón común es:

- Un cluster "mgmt" con Argo CD.
- Clusters "prod-eu", "prod-us", "dev" registrados cada uno con un SA distinto y permisos acotados.
- Cada `AppProject` referencia solo los clusters donde ese equipo tiene derecho a desplegar.

---

## 10. Patrones de modelado: cuántos projects, cómo nombrarlos

No hay una regla única. Patrones que funcionan:

**Project por equipo** (recomendado por defecto):

- `team-payments`, `team-checkout`, `team-platform`.
- Cada project lista los namespaces de su equipo (`payments-*`, `checkout-*`).
- Un equipo con dev/stg/prod tiene **un solo project** y usa namespaces por entorno.

**Project por entorno** (menos común):

- `env-prod`, `env-staging`, `env-dev`.
- Útil si la segmentación crítica es "quién puede tocar prod", no "qué equipo".
- Problema: no aísla equipos entre sí dentro de prod.

**Híbrido (project por equipo-y-entorno)**:

- `team-payments-prod`, `team-payments-dev`.
- Máximo aislamiento, cuádruple de ruido.
- Lo justificable solo si prod tiene requisitos regulatorios distintos (PCI, HIPAA) de dev.

Reglas de pulgar:

- Empieza con **project por equipo**. Añade granularidad solo cuando duela.
- Los nombres son parte del contrato del `object` en policies CSV; cambiar `team-payments` → `payments` significa reescribir policies. Decide pronto.
- Nunca uses `default` para nada real. Déjalo intacto o endurécelo quitando los `*`.

---

## 11. Auditoría: cómo detectar un project laxo

Preguntas que te haces (o le haces a `jq` sobre `argocd proj get -o json`):

1. ¿`sourceRepos` contiene `*`? → Equipo puede sincronizar desde *cualquier* repo, incluido uno malicioso.
2. ¿`destinations` incluye `'*'` como namespace o server? → Equipo puede desplegar en cualquier cluster/namespace de Argo CD.
3. ¿`clusterResourceWhitelist` incluye `group: '*', kind: '*'`? → Equipo puede crear `ClusterRoleBinding` → escalada a cluster-admin en el target.
4. ¿`namespaceResourceBlacklist` está vacío? → Equipo puede crear `ResourceQuota`, `LimitRange`, `NetworkPolicy` sin consenso con platform.
5. ¿Existen roles con policy `*` sobre `*`? → Equivale a `role:admin` global.
6. ¿Existen JWT tokens emitidos de hace meses sin rotar? (`argocd proj role list-tokens`).
7. ¿`orphanedResources.warn` está `false`? → Perdiendo visibilidad de drift humano.

Script útil:

```bash
argocd proj list -o json | jq -r '
  .[] | select(
    (.spec.sourceRepos | index("*")) or
    (.spec.destinations[]? | .namespace == "*" or .server == "*")
  ) | .metadata.name
'
```

La actividad `02-least-privilege-rbac-adr/` te hace auditar exactamente esto y proponer el mínimo.

---

## 12. Errores comunes y cómo diagnosticarlos

**`application 'foo' is not permitted in project 'team-payments'`**

- Causa típica: el `source.repoURL` no está en `sourceRepos`, o el `destination.namespace` no coincide con ningún patrón de `destinations`.
- Diagnóstico: `argocd app get foo -o yaml | grep -E 'repoURL|namespace|server'` y comparar con `argocd proj get team-payments -o yaml`.
- Trap: `destinations[].server: https://kubernetes.default.svc` y la Application usa `destination.name: in-cluster`. Son equivalentes semánticamente pero el matcher es literal — usa el mismo campo en los dos sitios.

**`resource Namespace is not permitted to be created in project`**

- La Application quiere crear un recurso cluster-scoped (`Namespace`, `ClusterRole`, `CRD`) y falta en `clusterResourceWhitelist`.
- Fix: añadirlo. Si no quieres que ese equipo cree `Namespaces`, usa `SyncOption: CreateNamespace=false` y provisiona namespaces desde platform.

**`permission denied: applications, sync, team-payments/foo`**

- Argo CD RBAC está bloqueando. Mira `argocd-rbac-cm`:
  - ¿El usuario está en algún `g, ...` que mapee a un role?
  - ¿El role tiene `p, role:X, applications, sync, team-payments/*, allow`?
- Habilita `logLevel: debug` en `argocd-server` temporalmente para ver la evaluación de policies.

**`unable to apply <resource>: ... forbidden`**

- Esto NO es Argo CD RBAC, es **K8s RBAC** en el cluster target.
- Mira qué ServiceAccount está usando Argo CD en ese cluster y añade el permiso faltante al `ClusterRole`/`Role` correspondiente.
- No arregles esto bajándole las reglas al project — son capas distintas.

**El JWT del CI dejó de funcionar de golpe**

- ¿Expiró? (`argocd proj role list-tokens`).
- ¿Alguien rotó `server.secretkey` del `argocd-secret`?
- ¿Alguien editó el role dentro del project y borró la policy que necesitabas?

---

## Preguntas de evaluación

Respóndelas sin consultar la lección:

1. Explica, en 3 frases, por qué el namespace del cluster target **no** sirve como barrera de tenencia por sí solo en Argo CD.
2. Un developer hace clic en "Sync" y falla con "not permitted in project". Lista las **tres causas más probables** en orden.
3. Diferencia *con un ejemplo concreto* un permiso de Argo CD RBAC y un permiso de K8s RBAC que coexistan para la misma Application.
4. ¿Por qué un JWT de project role es preferible a un usuario local para un pipeline de CI?
5. Audita el siguiente project y propón el mínimo:
   ```yaml
   spec:
     sourceRepos: ['*']
     destinations: [{server: '*', namespace: '*'}]
     clusterResourceWhitelist: [{group: '*', kind: '*'}]
   ```
6. ¿Qué pasa si un IdP OIDC deja de enviar el claim `groups` tras un cambio de configuración? ¿Cómo lo detectas rápido?
