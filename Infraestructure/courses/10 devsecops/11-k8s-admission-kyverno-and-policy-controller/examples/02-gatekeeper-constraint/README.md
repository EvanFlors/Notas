# Ejemplo 02 — OPA/Gatekeeper: `ConstraintTemplate` + `Constraint`

> Lectura y análisis. Si tienes `kind` puedes desplegarlo; si no, lee el flujo.

## 1. Qué muestra

Gatekeeper separa:

- **`ConstraintTemplate`**: define el *tipo* de regla en Rego (la lógica).
- **`Constraint`**: instancia esa regla con parámetros (los datos).

Equivalente conceptual al par `class` + `instance`. Aquí: "los recursos deben tener los labels X, Y, Z" como *template* y "en producción exijo `owner` y `team`" como *constraint*.

## 2. El `ConstraintTemplate`

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
              items:
                type: string
  targets:
    - target: admission.k8s.gatekeeper.sh
      rego: |
        package k8srequiredlabels

        violation[{"msg": msg}] {
          required := input.parameters.labels
          provided := {k | input.review.object.metadata.labels[k]}
          missing := required[_]
          not provided[missing]
          msg := sprintf("missing required label %q", [missing])
        }
```

## 3. El `Constraint`

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: K8sRequiredLabels
metadata:
  name: pods-must-have-owner-and-team
spec:
  enforcementAction: deny   # or dryrun / warn
  match:
    kinds:
      - apiGroups: [""]
        kinds: [Pod]
    namespaces: [production]
  parameters:
    labels: ["owner", "team"]
```

## 4. Flujo en cluster (kind)

```bash
kind create cluster --name sec11-ex02
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.17/deploy/gatekeeper.yaml
kubectl apply -f constrainttemplate.yaml
kubectl apply -f constraint.yaml
kubectl create ns production

# Fail (missing labels):
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: {name: bad, namespace: production}
spec: {containers: [{name: c, image: nginx:1.27}]}
EOF
# -> admission webhook denies: missing required label "owner"

kind delete cluster --name sec11-ex02
```

## 5. Qué llevarte

- Gatekeeper hace a Rego ciudadano de primera en admisión.
- La separación `Template` ↔ `Constraint` promueve una **librería compartida**: el template se escribe una vez (seguridad / platform team), cada equipo instancia el constraint con sus parámetros.
- Compárese con Kyverno: la misma regla "require labels" en Kyverno son ~10 líneas de YAML directo, sin Rego. Elige según dónde esté la inversión del equipo.
