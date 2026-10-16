# argo-09 — Secretos con GitOps (lesson)

> 12 secciones. Prosa en español, código y comandos en inglés.

---

## 1. El problema: por qué secretos en claro en Git **nunca**

GitOps convierte el repositorio en la *fuente de verdad*. Esa misma propiedad —todo el estado es replicable desde un `git clone`— se vuelve catastrófica si los secretos viven ahí en claro:

- **Replicación irrecuperable**: cada mirror, fork, backup, build artifact o laptop con el repo clonado tiene el valor. No existe un `git rm` que lo revoque; el commit queda en el historial, en los reflogs de todos los clones, y a menudo cacheado en forges (GitHub keeps unreachable blobs).
- **Scope de ataque**: comprometer **cualquier** credencial de lectura al repo compromete *todos* los secretos presentes y pasados.
- **Auditoría imposible**: el `git log` muestra quién introdujo el secreto, pero no quién lo *leyó*.
- **Cultura corrosiva**: un solo `.env` en claro mergeado normaliza la práctica y erosiona el resto de los controles.

> Un repo "privado" no mitiga el problema: la frontera de confianza es mucho mayor que `git push access`. Incluye CI runners, cachés, instancias de GitHub/GitLab, backups, ex-empleados con tokens no revocados y cualquier integración que clone el repo.

La regla operativa es simple: **el valor en claro de un secreto no debe atravesar nunca un `git add`**. Las cinco estrategias de este módulo son maneras distintas de cumplir esa regla sin perder la propiedad GitOps (todo el estado deseado declarado y versionado).

---

## 2. Modelo mental: qué cambia respecto a GitOps "sin secretos"

En GitOps convencional el `desired state` vive en Git y el agente lo materializa. Con secretos aparece una capa adicional:

```
Git (desired state)  ──▶  Agente/plugin  ──▶  Cluster (Secret nativo)
                              │
                              └── fuente de verdad del VALOR (fuera de Git):
                                  SOPS key / Sealed controller key /
                                  Secret manager externo / Vault
```

El **manifiesto** del secreto siempre está en Git. Lo que cambia por estrategia es **dónde vive el valor** y **quién lo descifra o lo obtiene**:

| Estrategia | Dónde vive el **valor** | Quién lo materializa | Qué llega a etcd |
|---|---|---|---|
| SOPS + KSOPS | Cifrado en Git (clave en KMS/age) | Plugin KSOPS en Argo CD repo-server | `Secret` nativo |
| Sealed Secrets | Cifrado en Git (clave pública del controller) | `sealed-secrets-controller` | `Secret` nativo |
| ESO | Secret manager externo | `external-secrets-operator` | `Secret` nativo |
| CSI Driver | Secret manager externo | `csi-secrets-store` montando tmpfs | *Nada* (tmpfs en el pod) |
| Vault Agent Injector | Vault | Sidecar/init que escribe archivos | *Nada* (archivos en el pod) |

Las dos últimas evitan materializar un `Secret` nativo; las tres primeras lo materializan, lo que hace que el secreto quede en etcd (y requiera `EncryptionConfiguration` para estar cifrado en reposo).

---

## 3. SOPS + KSOPS

**SOPS** (Secrets OPerationS, por Mozilla) cifra YAML/JSON/env/binario *campo a campo*, dejando las claves en claro para que el diff en Git siga siendo útil. Soporta backends: **AWS KMS**, **GCP KMS**, **Azure Key Vault**, **PGP** y **age** (recomendado hoy: curva25519, UX simple, sin cloud).

Un `Secret` SOPS se ve así:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db
type: Opaque
data:
  password: ENC[AES256_GCM,data:xyz...,iv:...,tag:...,type:str]
sops:
  age:
    - recipient: age1xxxxx...
      enc: |
        -----BEGIN AGE ENCRYPTED FILE-----
        ...
        -----END AGE ENCRYPTED FILE-----
```

**KSOPS** es un plugin de **Kustomize** que decifra con SOPS en el momento del `kustomize build`. Argo CD lo integra como **Config Management Plugin (CMP)**: el `repo-server` corre Kustomize con KSOPS, obtiene el YAML en claro y lo aplica.

**Pros**:
- El secreto cifrado vive en Git, con historial legible.
- Rotación por valor es trivial (`sops edit`).
- No requiere componentes en el cluster (más allá del plugin en Argo CD).

**Contras**:
- **Blast radius**: el `repo-server` necesita acceso al KMS/age key. Comprometerlo = fugar todo.
- Para rotar la **clave maestra** hay que re-cifrar todos los archivos (automatizable, pero disciplina).
- Diffs cifrados son ruidosos aunque sólo cambie IV.

Usarlo cuando: equipo pequeño o air-gapped, nube no es opción fuerte, o se quiere evitar un operator extra.

---

## 4. Sealed Secrets

**Sealed Secrets** (Bitnami) introduce un CR `SealedSecret` y un **controller** en el cluster. El flujo:

1. El controller genera un **par de claves asimétrico** al arrancar.
2. El cliente usa `kubeseal` con la **clave pública** del controller para producir un `SealedSecret` desde un `Secret` normal.
3. El `SealedSecret` se commitea a Git.
4. El controller detecta el CR, descifra con su clave privada y crea el `Secret` nativo correspondiente.

El cifrado está "ligado" al **cluster + namespace + nombre** por default: un `SealedSecret` producido para `prod/web/db` no puede descifrarse en `stg`. Esto es seguro pero requiere re-sellar al promover.

**Pros**:
- Un solo componente, simple, sin dependencias cloud.
- UX minimalista (`kubeseal`).

**Contras**:
- **Rotación de clave maestra es cara**: si la clave privada se compromete o se quiere rotar, hay que re-sellar *todos* los `SealedSecret`.
- Si pierdes la clave privada del controller y no tienes backup, pierdes *todos* los secretos cifrados.
- La clave privada vive en un `Secret` del cluster → tiene que respaldarse de forma segura (fuera de banda).

Usarlo cuando: no hay secret manager externo, se busca simplicidad extrema y la rotación es infrecuente.

---

## 5. External Secrets Operator (ESO) — patrón recomendado

**ESO** es un operator que introduce dos CRs principales:

- `SecretStore` / `ClusterSecretStore`: declara un *provider* (AWS Secrets Manager, GCP Secret Manager, Vault, Azure Key Vault, Doppler, 1Password, un *fake* para tests, etc.) y la autenticación hacia él.
- `ExternalSecret`: declara *qué* keys del provider pullear y *cómo* mapearlas a un `Secret` nativo (nombre, tipo, template).

Flujo:

```
          ┌──────────────────────────┐
Git ──▶   │ ExternalSecret manifest   │  ──▶ Argo CD aplica el CR
          └──────────────┬────────────┘
                         │ pull periódico (refreshInterval)
                         ▼
               ┌──────────────────┐          ┌──────────────────┐
               │  ESO controller  │ ────────▶│  Secret Manager  │
               └────────┬─────────┘          └──────────────────┘
                        │ crea/actualiza
                        ▼
                 Secret nativo (etcd)
```

Lo clave: **en Git sólo hay referencias y mapeo**. El valor nunca pasa por el repo.

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-sm
    kind: ClusterSecretStore
  target:
    name: db                 # name of the resulting native Secret
    creationPolicy: Owner
  data:
    - secretKey: password
      remoteRef:
        key: prod/db
        property: password
```

**Pros**:
- **Desacople correcto**: Git declara *qué* necesita la app, el secret manager guarda el *valor*.
- **Rotación automática**: cambia el valor en el provider, ESO lo propaga en el próximo `refreshInterval` (o vía webhook).
- Multi-provider; migración entre proveedores sin tocar las apps.
- Encaja con cuentas cloud existentes (IAM roles, Workload Identity).

**Contras**:
- Un operator más que operar.
- Un secret manager externo es requisito (costo de licencia / costo cloud).
- Autenticación del operator al provider es crítica (IRSA, Workload Identity, Vault AppRole…).

Patrón recomendado hoy para cualquier organización con secret manager disponible.

---

## 6. Secrets Store CSI Driver

**CSI Secrets Store** es un driver CSI que **monta** secretos desde un provider como un volumen tmpfs en el pod, sin materializar un `Secret` nativo (opcionalmente puede sincronizarse a uno).

Flujo:

```
Pod ─(volumeMount)─▶ csi.secrets-store ─▶ Provider plugin (AWS/GCP/Azure/Vault)
```

**Pros**:
- El secreto **no toca etcd** (si no se habilita `secretObjects.sync`).
- Rotación controlada por el driver (`rotation-poll-interval`).
- Montaje atómico; patrón "archivos" natural para muchas apps.

**Contras**:
- Acopla el pod al driver y al provider; menos portable.
- No sirve si la app sólo lee env vars (requiere wrapper o re-arquitectura).
- Debug menos trivial.

Usarlo cuando: regulación exige que el secreto no viva en etcd, o cuando la app ya consume archivos y hay un provider nativamente integrado.

---

## 7. Vault Agent Injector

**Vault Agent Injector** (HashiCorp) es un mutating webhook: anotas el pod con `vault.hashicorp.com/*` y el inyector añade un **init container** (y opcional sidecar) que:

1. Se autentica a Vault (Kubernetes auth method, AppRole, JWT…).
2. Rinde una plantilla con los secretos.
3. Deja archivos en `/vault/secrets/*` para el main container.

**Pros**:
- Integración profunda con Vault (dynamic secrets, leases, tokens de corta vida).
- No necesita `Secret` nativo.
- Plantillas potentes (consul-template).

**Contras**:
- Requiere Vault operado (no trivial).
- Pod startup añade latencia (init container).
- Sidecar aumenta memoria/CPU por pod.

Usarlo cuando: la organización ya tiene Vault y quiere aprovechar dynamic secrets o políticas finas.

---

## 8. Rotación

| Estrategia | Rotar un valor | Rotar la clave maestra |
|---|---|---|
| SOPS + KSOPS | `sops edit` + commit | re-cifrar todos los archivos |
| Sealed Secrets | re-sellar y commit | re-sellar **todos** los secretos |
| ESO | cambiar valor en provider; ESO lo pullea | rotar credencial del controller al provider |
| CSI Driver | cambiar valor en provider; driver remonta | rotar credencial del driver |
| Vault Injector | cambiar en Vault o usar dynamic lease | rotar policies en Vault |

**Lectura clave**: ESO/CSI/Vault pagan la complejidad del operator pero obtienen rotación *continua* y *desacoplada* del repo. SOPS y Sealed Secrets requieren disciplina humana para rotar porque la rotación produce un commit visible.

**Política saludable por defecto**:
- Secretos de aplicación (DB password, API key): rotación trimestral si no hay dynamic secrets.
- Claves maestras: anual con drill de rollback.
- Credenciales de operator al provider: rotación semi-automática con alertas de expiración.

---

## 9. Auditoría: qué queda en Git, en etcd y en el provider

| Estrategia | Git | etcd | Provider |
|---|---|---|---|
| SOPS + KSOPS | ciphertext + metadata | `Secret` plano | — |
| Sealed Secrets | `SealedSecret` CR | `Secret` plano + clave privada del controller | — |
| ESO | `ExternalSecret` CR (sólo refs) | `Secret` plano | valor real + access logs |
| CSI Driver | `SecretProviderClass` CR | nada (si no se sincroniza) | valor real + access logs |
| Vault Injector | annotations + policy references | nada | valor real + audit log |

**En Git nunca** hay valores en claro, pero sí metadata que, mal entendida, filtra inventario (nombres de secretos, estructura). Esto raramente es sensible por sí mismo; aun así, limitar lectura al repo de infra sigue siendo prudente.

**En etcd**: salvo CSI/Vault Injector, el valor acaba allí. Esto hace que `EncryptionConfiguration` del `kube-apiserver` sea *obligatorio* en prod (y una práctica de higiene en dev).

**En el provider**: la auditoría es *mejor* (quién accedió, cuándo). ESO, CSI y Vault heredan ese audit log — argumento operativo fuerte a su favor.

---

## 10. Migración entre estrategias

Las cinco estrategias son **convertibles** porque todas producen (o reemplazan) un `Secret` nativo o un archivo:

- **De SOPS a ESO**: inventariar secretos, cargarlos al provider, generar `ExternalSecret` por cada `Secret` SOPS, eliminar los SOPS cuando los `ExternalSecret` estén `SecretSynced=True`. Hay que coordinar en el mismo commit para evitar ventana sin secreto.
- **De Sealed Secrets a ESO**: igual que arriba. El `kubeseal unseal` sólo es posible con la clave privada; muchas veces es más fácil re-ingresar los valores humanamente.
- **De ESO a Vault Injector**: cambia el *consumer pattern* de la app (de env/file de un Secret a file inyectado). Suele requerir cambio de código.
- **Entre providers de ESO**: trivial, cambiar `secretStoreRef`.

Regla práctica: **migrar app por app**, con *dual-write* en el provider nuevo durante una ventana, y cutover por commit.

---

## 11. Anti-patrones frecuentes

1. **"Lo cifro con `openssl` y lo commiteo"**: no es rotable, no es auditable, no encaja con herramientas estándar. Evitar.
2. **Secretos en `values.yaml`** de Helm "porque es privado": sigue siendo claro en Git. Usar `values-secret.yaml` cifrado (SOPS) o referencias a ESO.
3. **Compartir Sealed Secrets entre clusters**: imposible por diseño (scoping namespace/cluster) salvo configurar scope `cluster-wide` (desaconsejado).
4. **Argo CD con permisos de admin al KMS corporativo**: concede un blast radius enorme. Mínimo privilegio por project y por cluster.
5. **ESO sin `refreshInterval` adecuado**: si lo pones muy bajo tiras al API del provider y acumulas costos; muy alto y la rotación se vuelve lenta. `1h` es un buen default; `15m` para críticos.
6. **No respaldar la clave privada del Sealed Secrets controller**: pérdida del cluster = pérdida irrecuperable de los secretos.
7. **`creationPolicy: Owner` + edición manual del `Secret`**: ESO reconcilia y revierte. Modificar sólo en el provider.
8. **Usar `set -o pipefail` con `grep -q`** en los scripts de validación: `grep -q` cierra temprano y la etapa upstream recibe SIGPIPE (exit 141), que `pipefail` transforma en fallo espurio. Mantener los validadores sin `pipefail`.

---

## 12. Decisión: árbol para elegir

```
¿Tienes un secret manager operado (AWS SM / GCP SM / Vault)?
├── Sí
│   ├── ¿La app ya consume env/files y quieres rotación continua?  → ESO
│   ├── ¿Regulación exige que el valor no toque etcd?               → CSI Driver
│   └── ¿Ya operas Vault y quieres dynamic secrets / short-lived?   → Vault Agent Injector
└── No
    ├── ¿Air-gapped o equipo pequeño sin apetito por otro operator? → SOPS + KSOPS (age)
    └── ¿Un cluster, equipo pequeño, UX minimalista?                 → Sealed Secrets
```

Ejemplos aplicados:

- **Startup en AWS, 20 ingenieros**: ESO + AWS Secrets Manager + IRSA. Patrón canónico 2026.
- **Agencia pública air-gapped**: SOPS + age, con claves en HSM USB custodiadas.
- **Fintech con Vault y auditoría estricta**: Vault Agent Injector para los servicios core; ESO para el resto.
- **Equipo de 3 personas con un cluster**: Sealed Secrets.
- **Multi-cluster federado**: ESO con un `ClusterSecretStore` por región y provider único.

Documenta la decisión en un ADR (actividad 02) con criterios ponderados y revísala anualmente.
