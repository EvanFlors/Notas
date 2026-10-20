# k8s-12 — RBAC, ServiceAccounts, Admission y Policy-as-Code

> Lección completa del módulo. 12 secciones. Prosa en español, código en inglés.

---

## 1. El viaje de una request por el API server

Toda interacción con Kubernetes es, al final, una petición HTTP contra el `kube-apiserver`. Entender su recorrido es el requisito para razonar sobre seguridad, admission y políticas.

```
┌─────────┐   HTTPS   ┌──────────────────────────────────────────────────────────┐
│ client  │ ────────► │ kube-apiserver                                           │
└─────────┘           │  1. authn  (certs / tokens / OIDC)                       │
                      │  2. authz  (RBAC / ABAC / Webhook / Node authorizer)     │
                      │  3. mutating admission   (webhooks + built-in)           │
                      │  4. object schema validation (OpenAPI, defaults)         │
                      │  5. validating admission (webhooks + built-in + VAP CEL) │
                      │  6. persist to etcd                                      │
                      └──────────────────────────────────────────────────────────┘
```

Puntos clave:

- Cada fase puede **denegar** la request con un error distinto (`401`, `403`, `admission webhook denied the request`).
- Solo `mutating` puede **modificar** el objeto. `validating` solo acepta o rechaza.
- `VAP` corre *dentro* del API server, sin webhook externo (menor latencia, menor superficie de fallo).
- El audit log (`audit.k8s.io/v1`) registra todas las fases: útil para forense.

Comprender esta cadena te permite diagnosticar errores sin "adivinar": si recibes `403 forbidden`, el problema está en authz (RBAC). Si recibes `admission webhook ... denied`, está en admission.

---

## 2. ServiceAccount: identidad de los Pods

Un `ServiceAccount` (SA) es el "usuario" que un Pod presenta al API server cuando necesita hablar con él (operadores, controladores, pipelines corriendo dentro del cluster).

- Cada namespace tiene un SA `default` creado automáticamente. **Nunca** lo uses para workloads reales; es como correr todo como `root`.
- Un SA real se crea con un YAML explícito y se asocia a Pods vía `spec.serviceAccountName`.
- El API server identifica al SA como `system:serviceaccount:<namespace>:<name>` y lo coloca en el grupo `system:serviceaccounts:<namespace>` y `system:serviceaccounts`.

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deployer
  namespace: apps
automountServiceAccountToken: false   # explícito: no monta token si no se usa
```

### 2.1 Token projection (BoundServiceAccountTokenVolume)

Desde K8s 1.22+ los tokens de SA son **proyectados** (`projected` volume) por el kubelet:

- Rotación automática.
- `audience` específica (no sirve el token para otros servicios).
- `expirationSeconds` configurable.
- Scoped al Pod (si el Pod muere, el token muere).

El patrón recomendado:

```yaml
volumes:
  - name: token
    projected:
      sources:
        - serviceAccountToken:
            path: token
            audience: vault.internal
            expirationSeconds: 3600
```

Esto reemplaza los *long-lived tokens* históricos en `kube-system/<sa>-token-xxxxx` Secrets. Si ves un cluster con esos Secrets, es señal de deuda de seguridad.

---

## 3. RBAC: verbos, resources, namespaces

RBAC (`rbac.authorization.k8s.io/v1`) es el autorizador por defecto. Cuatro objetos:

| Objeto               | Scope         | Qué define                                 |
|----------------------|---------------|--------------------------------------------|
| `Role`               | namespace     | permisos dentro de un namespace             |
| `RoleBinding`        | namespace     | asocia subjects a un `Role` (o a un `ClusterRole` *reutilizado en un ns*) |
| `ClusterRole`        | cluster       | permisos cluster-wide o reutilizables       |
| `ClusterRoleBinding` | cluster       | asocia subjects a un `ClusterRole`          |

### 3.1 Anatomía de un Role

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: apps
  name: pod-reader
rules:
  - apiGroups: [""]            # core group → "", named groups → "apps", "batch", …
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
```

Verbos relevantes: `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`, `deletecollection`, `impersonate`, `bind`, `escalate`, `use` (para `podsecuritypolicies` legacy / `scc` en OpenShift).

### 3.2 Subjects

```yaml
subjects:
  - kind: ServiceAccount
    name: deployer
    namespace: apps
  - kind: User
    name: alice@example.com
    apiGroup: rbac.authorization.k8s.io
  - kind: Group
    name: platform-admins
    apiGroup: rbac.authorization.k8s.io
```

### 3.3 Aggregation

Un `ClusterRole` con `aggregationRule` compone permisos de otros ClusterRoles por label selector. Así es como `view`, `edit`, `admin` crecen cuando instalas un CRD con su propio ClusterRole marcado `rbac.authorization.k8s.io/aggregate-to-view: "true"`.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-view
aggregationRule:
  clusterRoleSelectors:
    - matchLabels:
        rbac.authorization.k8s.io/aggregate-to-view: "true"
rules: []   # el controller rellena las reglas
```

---

## 4. Patrón de least privilege

La política por defecto en K8s es **negar** (RBAC es permisivo-aditivo: todo lo no permitido explícitamente queda denegado). La disciplina es:

1. **Un SA por workload** (nunca compartir SA entre apps distintas).
2. **Role por SA**, no `ClusterRole` salvo que sea realmente cluster-wide.
3. Verbos y resources **exactos**: `["get","list","watch"]` es muy distinto de `["*"]`.
4. **Nombrar recursos específicos** con `resourceNames:` cuando aplica.
5. Nunca `cluster-admin` para aplicaciones.
6. Auditar con `kubectl auth can-i --list --as=system:serviceaccount:apps:deployer -n apps`.

Un ejemplo de mala práctica típica:

```yaml
# ⛔ Antipatrón: aplicación con cluster-admin
kind: ClusterRoleBinding
metadata:
  name: my-app-admin
roleRef:
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: default
    namespace: apps
```

Esto permite leer todos los Secrets del cluster, modificar nodos, instalar CRDs y escalarse a cualquier identidad. Siempre reemplazar por un `Role` mínimo.

---

## 5. Impersonation

Con el verbo `impersonate` un sujeto puede ejecutar como otro usuario, grupo o SA:

```bash
kubectl get pods -n apps --as=system:serviceaccount:apps:deployer
kubectl auth can-i list secrets -n apps \
  --as=system:serviceaccount:apps:deployer
```

Usos legítimos: auditoría ("¿qué puede hacer este SA?"), tests de policy, operadores que delegan. Riesgos: un sujeto con `impersonate: users` sobre `*` es equivalente a `cluster-admin`. Audita cualquier aparición de `impersonate` fuera de casos muy acotados.

---

## 6. Admission controllers built-in

Los admission controllers son plugins compilados en el `kube-apiserver`. Los relevantes:

| Controller                 | Fase        | Qué hace                                                       |
|----------------------------|-------------|----------------------------------------------------------------|
| `NamespaceLifecycle`       | validating  | impide crear objetos en namespaces en `Terminating`             |
| `ResourceQuota`            | validating  | enforce de `ResourceQuota` por namespace                        |
| `LimitRanger`              | mutating    | inyecta `requests/limits` default                               |
| `ServiceAccount`           | mutating    | monta el token del SA si `automountServiceAccountToken != false`|
| `DefaultStorageClass`      | mutating    | asigna StorageClass default a PVCs sin uno                      |
| `PodSecurity`              | validating  | aplica Pod Security Standards por namespace                     |
| `MutatingAdmissionWebhook` | mutating    | fan-out a webhooks externos                                     |
| `ValidatingAdmissionWebhook` | validating| fan-out a webhooks externos                                     |

Están casi todos activos en clusters managed. Deshabilitar `NamespaceLifecycle` o `ResourceQuota` es una señal de alarma en una auditoría.

---

## 7. MutatingAdmissionWebhook y ValidatingAdmissionWebhook

Son objetos (`admissionregistration.k8s.io/v1`) que registran un servicio HTTPS externo al que el API server llama cuando una request matchea `rules`. Esquema simplificado:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: vwc-example
webhooks:
  - name: vw.example.io
    clientConfig:
      service:
        name: webhook-service
        namespace: policy
        path: /validate
      caBundle: <base64>
    rules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        resources: ["pods"]
        operations: ["CREATE","UPDATE"]
    sideEffects: None
    admissionReviewVersions: ["v1"]
    failurePolicy: Fail
    timeoutSeconds: 5
```

Riesgos a controlar:

- `failurePolicy: Fail` + servicio caído = **bloqueas todo el API** (incluido tú mismo). Nunca registres un webhook crítico sin excluir `kube-system`.
- Webhooks con `timeoutSeconds` alto degradan la latencia global del API server.
- Un `MutatingWebhook` malicioso o buggy puede inyectar sidecars no deseados.

Es exactamente por estos riesgos que `ValidatingAdmissionPolicy` nació.

---

## 8. ValidatingAdmissionPolicy (CEL)

Desde K8s 1.30 **GA**, `ValidatingAdmissionPolicy` evalúa expresiones **CEL** (Common Expression Language) *dentro* del API server. Sin servicio externo, sin TLS, sin red.

Composición:

- `ValidatingAdmissionPolicy` — define las reglas CEL.
- `ValidatingAdmissionPolicyBinding` — instancia la policy sobre un conjunto de recursos (match constraints).
- `ParamKind` (opcional) — permite parametrizar la policy.

Ejemplo: "contenedores no pueden correr como root":

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-nonroot
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE","UPDATE"]
        resources: ["pods"]
  validations:
    - expression: >
        object.spec.securityContext.runAsNonRoot == true ||
        object.spec.containers.all(c, c.securityContext.runAsNonRoot == true)
      message: "all containers must set runAsNonRoot=true"
```

Ventajas sobre un webhook:

- Latencia menor (sin salto de red).
- Sin TLS/CA bundle a rotar.
- No tiene un "modo bloqueo total" por un servicio caído.
- Testeable con `kubectl alpha policy` y herramientas CEL.

Limitaciones: CEL no hace side-effects, no muta, no genera. Para eso sigue siendo Kyverno/Gatekeeper.

---

## 9. Pod Security Admission (PSA)

PSA es el **reemplazo** de PodSecurityPolicy (PSP), removido en K8s 1.25. Es un admission controller built-in que aplica los **Pod Security Standards** (perfiles `privileged`, `baseline`, `restricted`) por namespace vía labels:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: apps
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

Modos:

- `enforce` — rechaza Pods que violan el perfil.
- `audit` — permite pero añade entrada en el audit log.
- `warn` — permite pero devuelve warning al cliente (útil durante migración).

El perfil **restricted** exige entre otras cosas: `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `seccompProfile.type: RuntimeDefault`, sin `hostPath`, sin `hostNetwork`, sin `hostPID`, sin `hostIPC`.

Para workloads que no pueden cumplir restricted (p. ej. un agent de observabilidad que necesita `hostPath`), aíslalos en un namespace con `baseline` o `privileged` y aplica controles compensatorios.

---

## 10. OPA/Gatekeeper

[OPA](https://www.openpolicyagent.org/) es un motor general de policy; [Gatekeeper](https://github.com/open-policy-agent/gatekeeper) es su integración con K8s admission. Dos objetos:

- `ConstraintTemplate` — define un *tipo* de policy en Rego.
- `Constraint` (CRD dinámico creado por el Template) — instancia la policy.

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names:
        kind: K8sRequiredLabels
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels:
              type: array
              items: { type: string }
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          required := input.parameters.labels
          provided := input.review.object.metadata.labels
          missing := required[_]
          not provided[missing]
          msg := sprintf("missing required label: %v", [missing])
        }
```

Gatekeeper brilla donde ya tienes equipos cómodos con Rego o políticas transversales a plataformas (K8s, Terraform plan, Envoy). Su curva es mayor que Kyverno.

---

## 11. Kyverno

[Kyverno](https://kyverno.io/) es declarativo y "habla YAML". No hay DSL nuevo: las reglas se escriben con el mismo tipo de patrones que ya usas en manifests.

Tres clases de reglas:

- **validate** — rechaza Pods que no cumplen un patrón.
- **mutate** — modifica objetos (añade labels, inyecta sidecars).
- **generate** — crea objetos derivados (p. ej. `NetworkPolicy` default-deny al crear un namespace).

### 11.1 Validate

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-team-label
      match:
        any:
          - resources:
              kinds: ["Pod"]
      validate:
        message: "label 'team' is required"
        pattern:
          metadata:
            labels:
              team: "?*"
```

### 11.2 verifyImages (cosign/sigstore)

El plato fuerte. Cierra la cadena **build → sign → admit**:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-signed-images
spec:
  validationFailureAction: Enforce
  webhookTimeoutSeconds: 30
  rules:
    - name: verify-signature
      match:
        any:
          - resources:
              kinds: ["Pod"]
      verifyImages:
        - imageReferences:
            - "ghcr.io/myorg/*"
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/myorg/*/.github/workflows/release.yml@refs/heads/main"
                    issuer: "https://token.actions.githubusercontent.com"
                    rekor:
                      url: https://rekor.sigstore.dev
```

Si la imagen no está firmada por ese flujo exacto, Kyverno rechaza el Pod en admission.

### 11.3 Kyverno vs Gatekeeper vs VAP

| Dimensión            | VAP (CEL)         | Kyverno             | Gatekeeper (Rego)   |
|----------------------|-------------------|---------------------|---------------------|
| Lenguaje             | CEL               | YAML + CEL (parcial)| Rego                |
| Mutate               | no                | sí                  | sí (desde v3.14+)   |
| Generate             | no                | sí                  | no nativo           |
| verifyImages         | no                | sí                  | sí vía templates    |
| Webhook externo      | no (en-API)       | sí                  | sí                  |
| Curva                | baja              | baja                | media/alta          |

Regla práctica: usa **VAP** para reglas simples sin mutación (y para no añadir dependencia externa); usa **Kyverno** cuando necesites `verifyImages`, mutate o generate; usa **Gatekeeper** si ya tienes Rego/OPA extendido en la organización.

---

## 12. Puesta en común y checklist operativo

Un cluster "con higiene" en términos de este módulo tiene, como mínimo:

- [ ] Cero `ClusterRoleBinding` que apunten a `cluster-admin` para `ServiceAccount`s de aplicaciones.
- [ ] Un `ServiceAccount` dedicado por workload productivo.
- [ ] `automountServiceAccountToken: false` en workloads que no hablan con el API.
- [ ] Namespaces productivos con labels `pod-security.kubernetes.io/enforce: restricted`.
- [ ] Al menos una `ValidatingAdmissionPolicy` o `Kyverno ClusterPolicy` que exige `runAsNonRoot`, `drop: ALL`, `readOnlyRootFilesystem` o equivalente.
- [ ] Una política `verifyImages` activa para los registries corporativos.
- [ ] Audit logging habilitado en el API server (nivel al menos `Metadata` para `secrets` y `rbac`).
- [ ] `kubectl auth can-i --list` ejecutado como cada SA relevante, documentado en un ADR.

Las dos actividades del módulo te llevan por los dos pilares: RBAC mínimo (actividad 01) y policy-as-code obligatoria (actividad 02).

### Lecturas obligatorias para la evaluación

- Kubernetes docs: "Authorization", "Using RBAC Authorization", "Admission Controllers Reference", "Pod Security Admission", "Validating Admission Policy".
- Kyverno docs: "Policy Types", "Verify Images".
- CNCF blog: casos de incidentes por `cluster-admin` indebido en SA de aplicaciones.
