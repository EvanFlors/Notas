# Ejemplo 01 — Kyverno `verifyImages` con cosign keyless

> Lectura y análisis. **Ejecutable offline** si tienes `kyverno-cli` (CLI, no requiere cluster). Si no lo tienes, lee la salida esperada abajo.

## 1. Qué muestra este ejemplo

Una `ClusterPolicy` de Kyverno que admite Pods **solo** si la imagen `ghcr.io/my-org/*` está firmada con cosign keyless **y** la identidad del firmante coincide con un workflow concreto de GitHub Actions.

Cerramos el loop del módulo `sec-09`: si allí firmaste la imagen, aquí la admisión del cluster rechaza cualquier imagen que no venga de ese pipeline.

## 2. La policy

Archivo conceptual (ver también `/tmp/sec-11-ex01/policy.yaml` tras los pasos de abajo):

```yaml
apiVersion: kyverno.io/v2beta1
kind: ClusterPolicy
metadata:
  name: verify-signed-images
spec:
  validationFailureAction: Enforce
  webhookTimeoutSeconds: 30
  rules:
    - name: check-ghcr-signature
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

Puntos clave:

- `subject` + `issuer` **son la política de identidad**. Sin ellos, Kyverno acepta cualquier firma válida — equivale a no verificar.
- `validationFailureAction: Enforce` rechaza en admisión. Para rollout seguro empieza en `Audit`.

## 3. Qué prueba (offline, sin cluster)

Un buen manifest usa una imagen que *sí* viene de ese pipeline; uno malo usa `nginx:latest`.

```yaml
# good-pod.yaml
apiVersion: v1
kind: Pod
metadata: {name: good-pod}
spec:
  containers:
    - name: app
      image: ghcr.io/my-org/my-repo:v1.2.3
---
# bad-pod.yaml
apiVersion: v1
kind: Pod
metadata: {name: bad-pod}
spec:
  containers:
    - name: app
      image: nginx:latest
```

Con `kyverno-cli` sobre el bad:

```
$ kyverno apply policy.yaml --resource bad-pod.yaml
...
policy verify-signed-images -> resource default/Pod/bad-pod failed:
  1. check-ghcr-signature: image "nginx:latest" is not matched or not signed by expected attestor
```

El good pod no se "verifica de verdad" sin red (la CLI resuelve firmas contra Rekor). Para el ejemplo, interesa ver que la **estructura** de la policy se evalúa y que el bad falla.

## 4. En cluster (kind) — opcional

Si tienes `kind` + `kubectl`:

```bash
kind create cluster --name sec11-ex01
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
kubectl apply -f policy.yaml
kubectl apply -f bad-pod.yaml   # debe ser rechazado por el webhook
kubectl apply -f good-pod.yaml  # pasa solo si la imagen está firmada por ESE workflow
kind delete cluster --name sec11-ex01
```

## 5. Qué llevarte

- La identidad (`subject`+`issuer`) **es** la política. Omitirla es seguridad teatral.
- `kyverno apply` + `kyverno test` permiten testear policies **sin cluster**: ideal para CI.
- Esta policy es el consumidor directo de `sec-09`: sin firma, sin admisión.
