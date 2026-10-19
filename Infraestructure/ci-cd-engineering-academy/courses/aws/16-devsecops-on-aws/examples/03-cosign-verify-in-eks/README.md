# Ejemplo 03 — Firma con cosign y verificación en EKS

> Lectura y análisis. **No se despliega**. Objetivo: entender el flujo end-to-end firmar en CI → verificar en admisión, y la diferencia entre `policy-controller` y Kyverno.

## 1. El flujo

```
┌───────────────────────────────────────────────────────────────────────┐
│ CI (GitHub Actions con OIDC)                                          │
│                                                                       │
│   1. docker build -t ECR/app:$SHA .                                   │
│   2. docker push  ECR/app:$SHA                                        │
│   3. cosign sign --yes ECR/app:$SHA                                   │
│        (keyless, usa OIDC JWT de GHA)                                 │
│        │                                                              │
│        └──► publica firma + certificado efimero + entrada Rekor       │
└──────────────────────────────────┬────────────────────────────────────┘
                                   │
                                   │  (artefactos en el mismo registry
                                   │   que la imagen, como refs OCI)
                                   ▼
┌───────────────────────────────────────────────────────────────────────┐
│ ECR                                                                   │
│   app:$SHA           (imagen)                                         │
│   sha256-....sig     (signature manifest)                             │
│   sha256-....att     (attestations — SBOM, provenance)                │
└──────────────────────────────────┬────────────────────────────────────┘
                                   │
                                   │  kubectl apply deployment ──► image: ECR/app:$SHA
                                   ▼
┌───────────────────────────────────────────────────────────────────────┐
│ EKS — admission controller                                            │
│                                                                       │
│   policy-controller (sigstore) O Kyverno                              │
│     │                                                                 │
│     ├─► pide firma del image digest                                   │
│     ├─► verifica contra identidad OIDC esperada                       │
│     │     issuer: https://token.actions.githubusercontent.com         │
│     │     subject: repo:miorg/mirepo:ref:refs/heads/main              │
│     ├─► chequea Rekor (opcional, defensa en profundidad)              │
│     ▼                                                                 │
│   admit / deny                                                        │
└───────────────────────────────────────────────────────────────────────┘
```

## 2. Policy ejemplo — sigstore `policy-controller`

```yaml
apiVersion: policy.sigstore.dev/v1beta1
kind: ClusterImagePolicy
metadata:
  name: require-gha-signed
spec:
  images:
    - glob: "111122223333.dkr.ecr.us-east-1.amazonaws.com/mirepo/*"
  authorities:
    - keyless:
        url: https://fulcio.sigstore.dev
        identities:
          - issuer: https://token.actions.githubusercontent.com
            subject: "repo:miorg/mirepo:ref:refs/heads/main"
      ctlog:
        url: https://rekor.sigstore.dev
```

## 3. Policy ejemplo — Kyverno

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-gha-signed
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: check-sig
      match:
        any:
          - resources:
              kinds: [Pod]
      verifyImages:
        - imageReferences:
            - "111122223333.dkr.ecr.us-east-1.amazonaws.com/mirepo/*"
          attestors:
            - entries:
                - keyless:
                    issuer: https://token.actions.githubusercontent.com
                    subject: "repo:miorg/mirepo:ref:refs/heads/main"
                    rekor:
                      url: https://rekor.sigstore.dev
```

## 4. Comparación operativa

| Dimensión | sigstore policy-controller | Kyverno |
|-----------|---------------------------|---------|
| Scope del tool | Solo verificación de firmas | Policy engine general (mutar, validar, generar) |
| Curva de aprendizaje | Baja (una API) | Media (CRD rico) |
| Si tu cluster **no** tiene policy engine | Instala policy-controller | Instala Kyverno (abres camino para otras policies) |
| Si tu cluster **ya** tiene Kyverno | — | **Reutiliza** |
| Dry-run / audit mode | Sí (`mode: warn`) | Sí (`validationFailureAction: Audit`) |

**Recomendación práctica**:
- Si no tienes nada: **policy-controller** por simplicidad.
- Si ya tienes Kyverno para otras policies: **Kyverno**.
- Si ya tienes OPA/Gatekerper: ambos coexisten mal con Gatekeeper para esto; evalúa migrar las policies de firma a uno de los dos de arriba.

## 5. Modo audit antes de enforce

Siempre encender el admission controller en **audit** (loguear qué sería denegado) antes de pasar a **enforce**. La ruptura típica: una imagen `init-container` tercera no firmada que estaba pasando sin que nadie lo mirara.

## 6. Preguntas

1. ¿Qué pasa si el admission controller está caído? ¿Qué modo de failure es más seguro: `fail-open` o `fail-closed`?
2. ¿Por qué keyless + Rekor es más auditable que key-based?
3. Si cambias el repo a `otraorg/mirepo` (migración de org), ¿qué parte de la policy hay que actualizar?
4. ¿Tiene sentido verificar también la firma de la base image (p. ej. `distroless`)? ¿Cómo lo expresas en policy?
