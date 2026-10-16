# sec-11 — Lección: admission control en Kubernetes

> 10 secciones. Prerrequisitos: `sec-09`, `sec-10`, `k8s-12`.

---

## 1. Qué es admission control y por qué importa

Cuando un cliente (`kubectl`, un operator, Argo CD, un `Job` del cluster) envía un `apply`, el request atraviesa una **pipeline del API server**:

```
   Request ──► Authentication ──► Authorization (RBAC) ──► Admission ──► Schema validation ──► etcd
```

**Admission** es el último punto donde puedes decir *"no, este recurso no entra"* — o modificarlo (`mutating`) — **antes** de que exista en el cluster. Después, el objeto está persistido y cualquier verificación es *reactiva* (lo rechaza el controller, lo detecta un scanner, lo mata runtime).

Dos tipos:

- **MutatingAdmissionWebhook** — modifica el objeto (añadir sidecar, defaults, labels). Corre *antes* del validating.
- **ValidatingAdmissionWebhook** — acepta o rechaza. No modifica.

Ambos son webhooks externos (HTTPS a un service dentro del cluster). El API server los llama con el objeto serializado y espera respuesta en ms. Si el webhook está caído y `failurePolicy: Fail`, **el cluster entero puede rechazar admissions** — por eso excluir los namespaces del plano de control (`kube-system`, el namespace del propio controller) es parte del hardening.

Desde Kubernetes **1.30** existe **ValidatingAdmissionPolicy (VAP)** nativo: expresiones **CEL** evaluadas dentro del API server, sin webhook externo. Latencia ~0, no hay HTTPS, no hay failurePolicy que afinar — pero solo valida (no muta) y solo CEL.

---

## 2. Las cuatro opciones principales

```
┌────────────────────────┬──────────────┬─────────────┬───────────────────────────────────┐
│ Herramienta            │ Lenguaje     │ Donde corre │ Caso ideal                        │
├────────────────────────┼──────────────┼─────────────┼───────────────────────────────────┤
│ Kyverno                │ YAML + JMESPath/CEL │ Webhook externo │ Equipos K8s-nativos: YAML-first │
│ OPA/Gatekeeper         │ Rego         │ Webhook externo │ Equipos que ya usan Rego fuera K8s │
│ sigstore policy-controller │ YAML     │ Webhook externo │ Único problema: firma de imágenes │
│ ValidatingAdmissionPolicy  │ CEL      │ API server   │ Reglas simples, sin dependencias externas │
└────────────────────────┴──────────────┴─────────────┴───────────────────────────────────┘
```

El error típico es "elegir el framework más potente". El correcto es "elegir el más barato que resuelve el problema actual". Si solo necesitas verificar firmas → policy-controller. Si solo necesitas 4 reglas simples → VAP. Si necesitas mutate, generate, verifyImages y validate uniformemente → Kyverno. Si tu equipo ya mantiene Rego para IaC → Gatekeeper reutiliza esa inversión.

---

## 3. Kyverno — modelo YAML-first

Kyverno expone CRs `ClusterPolicy` (cluster-wide) y `Policy` (namespace-scoped). Cada policy tiene uno o más **rules**, y cada rule un **modo**:

- `validate` — acepta / rechaza (con `message` y `pattern` o `deny`).
- `mutate` — añade / cambia campos (strategic merge patch o JSON patch).
- `generate` — crea recursos cuando aparece otro (ej: `NetworkPolicy` por namespace).
- `verifyImages` — verifica firma cosign / attestations antes de admitir el Pod.

Ejemplo minimal (require labels `owner` + `app`):

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-owner-label
spec:
  validationFailureAction: Enforce   # Audit = log only; Enforce = reject
  background: true                    # also scan existing resources
  rules:
    - name: check-owner
      match:
        any:
          - resources:
              kinds: [Pod, Deployment, StatefulSet]
      validate:
        message: "Label 'owner' is required."
        pattern:
          metadata:
            labels:
              owner: "?*"
```

Dos modos fundamentales:

- **Audit** — el recurso entra, pero genera un `PolicyReport` con la violación. Para rollouts seguros.
- **Enforce** — el recurso es rechazado en admisión.

El patrón sano es desplegar nuevas policies en `Audit`, medir el ruido durante 1–2 sprints, y promover a `Enforce` cuando el PolicyReport esté limpio.

---

## 4. Kyverno CLI: testing *offline* (sin cluster)

El killer feature para CI es que `kyverno-cli` ejecuta policies sin cluster:

- **`kyverno apply`** — aplica una o varias policies a un conjunto de manifests YAML y reporta pass / fail por recurso. Perfecto para un job de CI que valida tu `kustomize build` *antes* del merge.
- **`kyverno test`** — formato declarativo (`kyverno-test.yaml`) que especifica "este recurso debería pasar esta policy" / "este recurso debería fallar esta otra". Es el `go test` de policies: ejecutable en cualquier runner sin dependencias de K8s.

Un `kyverno-test.yaml` tiene la forma:

```yaml
name: require-owner-tests
policies:
  - policy.yaml
resources:
  - good-pod.yaml
  - bad-pod.yaml
results:
  - policy: require-owner-label
    rule: check-owner
    resource: good-pod
    result: pass
  - policy: require-owner-label
    rule: check-owner
    resource: bad-pod
    result: fail
```

Esto convierte las policies de admisión en **artefactos testables como código**: cada PR que cambia una policy ejecuta el `kyverno test` y rompe si cambia el comportamiento esperado.

---

## 5. verifyImages — firma cosign en el momento de admisión

Si en `sec-09` firmaste la imagen con `cosign sign` (keyless + Fulcio + Rekor), ahora cierras el loop: la policy admite el Pod **solo si la firma verifica con la identidad esperada**.

```yaml
apiVersion: kyverno.io/v2beta1
kind: ClusterPolicy
metadata:
  name: verify-image-signatures
spec:
  validationFailureAction: Enforce
  webhookTimeoutSeconds: 30
  rules:
    - name: check-signature
      match:
        any:
          - resources:
              kinds: [Pod]
      verifyImages:
        - imageReferences:
            - "ghcr.io/my-org/*"
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/my-org/my-repo/.github/workflows/release.yml@refs/heads/main"
                    issuer: "https://token.actions.githubusercontent.com"
                    rekor:
                      url: https://rekor.sigstore.dev
```

Puntos finos:

- `subject` + `issuer` **son la política**. Sin ellos, cualquier firma válida pasa — lo que es equivalente a no verificar.
- `webhookTimeoutSeconds` tiene que considerar la latencia de Rekor/Fulcio. 30 s es alto; si vas a ese nivel, mantén `failurePolicy: Fail` *solo* fuera de `kube-system`.
- Permite también atestations: `type: slsaprovenance`, `type: cyclonedx` (SBOM), `type: vuln` — con `conditions` sobre el payload.

---

## 6. OPA / Gatekeeper — Rego-first

Gatekeeper separa `ConstraintTemplate` (define el *tipo* de regla en Rego) de `Constraint` (instancia esa regla con parámetros concretos).

```yaml
apiVersion: templates.gatekeeper.sh/v1
kind: ConstraintTemplate
metadata:
  name: k8srequiredlabels
spec:
  crd:
    spec:
      names: {kind: K8sRequiredLabels}
      validation:
        openAPIV3Schema:
          type: object
          properties:
            labels: {type: array, items: {type: string}}
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels
        violation[{"msg": msg}] {
          required := input.parameters.labels
          provided := {k | input.review.object.metadata.labels[k]}
          missing := required[_]
          not provided[missing]
          msg := sprintf("missing label %q", [missing])
        }
```

Elige Gatekeeper cuando tu organización ya mantiene una biblioteca Rego (Conftest, Styra) y quieres reutilizarla en K8s. Si no, Kyverno es más barato de operar.

---

## 7. ValidatingAdmissionPolicy — CEL nativo

Desde K8s 1.30 (GA), VAP corre dentro del API server:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: disallow-latest-tag
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: [v1]
        operations: [CREATE, UPDATE]
        resources: [pods]
  validations:
    - expression: "object.spec.containers.all(c, !c.image.endsWith(':latest'))"
      message: "Image tag ':latest' is forbidden."
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata:
  name: disallow-latest-tag-binding
spec:
  policyName: disallow-latest-tag
  validationActions: [Deny]
  matchResources:
    namespaceSelector:
      matchExpressions:
        - {key: kubernetes.io/metadata.name, operator: NotIn, values: [kube-system]}
```

Ventajas: cero webhook, cero HTTPS, latencia despreciable, sin componente que mantener. Desventajas: solo validación (no `mutate`, no `generate`, no `verifyImages`), CEL es menos expresivo que Rego o Kyverno para patrones complejos (data externa, firmas), y el testing *offline* es más limitado.

Patrón sano: usa VAP para las 4–6 reglas universales simples; Kyverno encima para lo que requiere mutate / verifyImages.

---

## 8. Workflow de excepciones

Toda policy sana necesita un camino para la excepción legítima. Sin él, los equipos abandonan la policy ("hoy no puedo deployar") o la saltan por detrás (quitan la policy "temporalmente" y nadie la vuelve a poner).

Kyverno ofrece `PolicyException`:

```yaml
apiVersion: kyverno.io/v2beta1
kind: PolicyException
metadata:
  name: payments-latest-exception
  namespace: payments
  annotations:
    exception.requested-by: "alice@acme.com"
    exception.approved-by: "bob@acme.com"
    exception.ticket: "SEC-1234"
    exception.expires-at: "2026-12-31"
spec:
  exceptions:
    - policyName: disallow-latest-tag
      ruleNames: [check-tag]
  match:
    any:
      - resources:
          kinds: [Pod]
          namespaces: [payments]
          names: [legacy-adapter-*]
```

Reglas organizativas (no las impone Kyverno, las impone el proceso):

1. **Ticket obligatorio** (`exception.ticket`) referenciando ADR o incidente.
2. **Approver distinto del solicitante** (`exception.approved-by`).
3. **TTL explícito** (`exception.expires-at`); un `CronJob` lista las vencidas y abre PR para removerlas.
4. **Auditoría**: los `PolicyReport` siguen generándose en modo Audit aunque la excepción permita la admisión → nunca pierdes visibilidad.

Sin esto, "excepción temporal" se vuelve permanente.

---

## 9. Performance y failurePolicy

Un webhook de admisión bloquea *cada* request `CREATE`/`UPDATE` de los recursos matched. Dos problemas:

- **Latencia**. Si el webhook responde en 500 ms, cada deploy sube 500 ms × N recursos.
- **Disponibilidad**. Si el webhook está caído y `failurePolicy: Fail`, nadie puede crear Pods — incluidos los Pods que arrancan el propio webhook (deadlock de bootstrap).

Mitigaciones:

- `matchConditions` / `matchExpressions` para que la policy solo evalúe los recursos relevantes.
- Excluir `kube-system` y el namespace del controller.
- `failurePolicy: Ignore` para policies no críticas, `Fail` para las que son contractuales.
- Mantener el webhook con HPA y PDB; medir p99 de admission latency (métricas del API server: `apiserver_admission_webhook_admission_duration_seconds`).

VAP evita el problema entero: corre in-process en el API server.

---

## 10. Cómo elegir — resumen operativo

- *"Solo quiero firmar imágenes."* → policy-controller (menos moving parts).
- *"Tengo 4 reglas universales simples."* → VAP.
- *"Necesito mutate + validate + verifyImages + generate uniformemente."* → Kyverno.
- *"Mi org ya mantiene Rego para IaC."* → Gatekeeper (reutiliza inversión).
- *"Necesito todo lo anterior."* → VAP para lo barato + Kyverno encima para lo que VAP no cubre. Convive bien.

La elección es local al equipo; el **contrato** (qué se exige, qué se audita, cómo se pide excepción) es organizacional y debe estar escrito en un ADR, no en la cabeza del platform lead.

→ Siguiente: `sec-12` — runtime: Falco y Tetragon detectan lo que la admisión no pudo prevenir.
