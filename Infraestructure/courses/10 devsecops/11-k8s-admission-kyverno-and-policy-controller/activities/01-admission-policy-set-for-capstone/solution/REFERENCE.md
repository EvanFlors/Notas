# REFERENCE — sec-11-01-admission-policy-set-for-capstone

> Modelo contra el que compararte. No es la única respuesta correcta.

## `POLICIES.md` (modelo)

### Contrato

El baseline del capstone exige, para todo `Pod`/`Deployment`/`StatefulSet` creado fuera de `kube-system`:

1. **Labels obligatorios** `owner` y `app` (require-labels).
2. **Prohibido** el tag `:latest` o la ausencia de tag (disallow-latest-tag).
3. **Prohibido** `securityContext.privileged: true` (disallow-privileged).

Namespaces excluidos: `kube-system`, `kyverno`.

### Rollout

- Semana 1: las 3 policies en `Audit`. Revisar `PolicyReport` y limpiar violaciones existentes.
- Semana 2: `require-labels` promovida a `Enforce`.
- Semana 3: `disallow-latest-tag` y `disallow-privileged` promovidas a `Enforce`.
- Semana 4: incorporar `verify-image-signatures` (fuera del scope de esta actividad; viene del ejemplo 01).

### Excepciones

Ver actividad `sec-11-02-exception-workflow`. Toda excepción vive como `PolicyException` con ticket, approver y TTL ≤ 90 días.

## `policies/01-require-labels.yaml` (modelo)

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-labels
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-owner-and-app
      match:
        any:
          - resources:
              kinds: [Pod, Deployment, StatefulSet]
      exclude:
        any:
          - resources:
              namespaces: [kube-system, kyverno]
      validate:
        message: "Labels 'owner' and 'app' are required."
        pattern:
          metadata:
            labels:
              owner: "?*"
              app: "?*"
```

## `policies/02-disallow-latest-tag.yaml` (modelo)

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: no-latest
      match:
        any:
          - resources:
              kinds: [Pod]
      exclude:
        any:
          - resources:
              namespaces: [kube-system, kyverno]
      validate:
        message: "Container image tag ':latest' (or missing tag) is forbidden."
        pattern:
          spec:
            containers:
              - image: "!*:latest | !*:latest"
                =(name): "*"
```

> Nota: en Kyverno el pattern anti-latest se expresa típicamente con `foreach` + regex. Variante robusta:

```yaml
      validate:
        message: "Container image tag ':latest' (or missing tag) is forbidden."
        foreach:
          - list: "request.object.spec.containers"
            deny:
              conditions:
                any:
                  - key: "{{ regex_match('.*:latest$', '{{ element.image }}') }}"
                    operator: Equals
                    value: true
                  - key: "{{ contains('{{ element.image }}', ':') }}"
                    operator: Equals
                    value: false
```

## `policies/03-disallow-privileged.yaml` (modelo)

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privileged
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: no-privileged
      match:
        any:
          - resources:
              kinds: [Pod]
      exclude:
        any:
          - resources:
              namespaces: [kube-system, kyverno]
      validate:
        message: "privileged containers are forbidden."
        pattern:
          spec:
            containers:
              - =(securityContext):
                  =(privileged): "false"
```

## Manifests

```yaml
# manifests/good-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: good-pod
  labels: {owner: "payments-team", app: "checkout"}
spec:
  containers:
    - name: app
      image: ghcr.io/my-org/checkout:v1.2.3
      securityContext: {privileged: false}
---
# manifests/bad-labels-pod.yaml
apiVersion: v1
kind: Pod
metadata: {name: bad-labels}
spec:
  containers:
    - {name: app, image: ghcr.io/my-org/checkout:v1.2.3}
---
# manifests/bad-latest-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: bad-latest
  labels: {owner: "payments-team", app: "checkout"}
spec:
  containers:
    - {name: app, image: nginx:latest}
---
# manifests/bad-privileged-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: bad-privileged
  labels: {owner: "payments-team", app: "checkout"}
spec:
  containers:
    - name: app
      image: ghcr.io/my-org/checkout:v1.2.3
      securityContext: {privileged: true}
```
