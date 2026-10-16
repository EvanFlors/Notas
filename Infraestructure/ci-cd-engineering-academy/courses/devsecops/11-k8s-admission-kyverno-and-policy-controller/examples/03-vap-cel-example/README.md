# Ejemplo 03 — `ValidatingAdmissionPolicy` nativo con CEL

> Lectura y análisis. Requiere K8s **≥ 1.30** (donde VAP es GA). Ejecutable con `kind` si usas una imagen reciente.

## 1. Qué muestra

**VAP** (ValidatingAdmissionPolicy) corre dentro del API server, no requiere webhook externo, no requiere HTTPS, no requiere componente que mantener. El precio: **solo validación**, **solo CEL**.

Aquí: una policy que prohíbe el tag `:latest` en cualquier container de un Pod.

## 2. La `ValidatingAdmissionPolicy`

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
      message: "Image tag ':latest' is forbidden by VAP 'disallow-latest-tag'."
    - expression: "object.spec.initContainers.orValue([]).all(c, !c.image.endsWith(':latest'))"
      message: "Image tag ':latest' is forbidden in initContainers."
```

## 3. El `ValidatingAdmissionPolicyBinding`

El binding es lo que *activa* la policy en namespaces concretos:

```yaml
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
        - key: kubernetes.io/metadata.name
          operator: NotIn
          values: [kube-system, kube-public]
```

`validationActions` admite `Deny`, `Warn`, `Audit` (combinables). Igual que Kyverno Audit/Enforce: `Audit` para rollouts suaves, `Deny` para enforcement.

## 4. Qué llevarte

- Sin webhook externo → **cero latencia extra** y cero componente que mantener.
- CEL es menos potente que Rego o Kyverno para patrones complejos (no accede a datos externos, no muta, no verifica firmas).
- Patrón recomendado: VAP para las 4–6 reglas universales simples (no `:latest`, no `hostPath`, no `privileged`), Kyverno encima para `verifyImages` y mutaciones. **Conviven bien**.
- CEL se puede probar con `kubectl alpha validate` o directamente con la expresión en el playground CEL.
