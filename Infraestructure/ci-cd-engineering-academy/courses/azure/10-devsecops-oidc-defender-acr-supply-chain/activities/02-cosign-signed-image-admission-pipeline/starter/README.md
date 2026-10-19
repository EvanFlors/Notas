# Starter — az-10-02-cosign-signed-image-admission-pipeline

Actividad **independiente**. Entregable: 1 workflow YAML + 1 policy YAML + 1 README-INTENT.md.

## Pasos

1. Lee `../README.md` completo y recorre `../../examples/02-acr-cosign-sign-and-verify/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/az-10-02/.github/workflows
   mkdir -p /tmp/az-10-02/admission
   cd /tmp/az-10-02
   ```
3. Escribe `.github/workflows/build-sign-push.yml` siguiendo §5.2 del README.
4. Elige Kyverno o Ratify y escribe la policy en `admission/` siguiendo §5.3.
5. Escribe `README-INTENT.md` siguiendo §5.4.
6. Valida:
   ```bash
   bash <ruta-repo>/courses/azure/10-devsecops-oidc-defender-acr-supply-chain/activities/02-cosign-signed-image-admission-pipeline/tests/validate.sh /tmp/az-10-02
   ```
7. Compara con `../solution/` para autoevaluar.

## Esqueletos sugeridos (opcional)

### `.github/workflows/build-sign-push.yml`

```yaml
name: build-sign-push
on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    environment: prod
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
      - run: az acr login --name acrcheckoutprod
      - uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: acrcheckoutprod.azurecr.io/checkout:${{ github.sha }}
      - uses: sigstore/cosign-installer@v3
      - name: Sign image (keyless)
        env:
          COSIGN_EXPERIMENTAL: "1"
        run: |
          cosign sign --yes \
            acrcheckoutprod.azurecr.io/checkout:${{ github.sha }}
```

### `admission/kyverno-verify-signature.yaml`

```yaml
apiVersion: kyverno.io/v2beta1
kind: ClusterPolicy
metadata:
  name: require-signed-checkout-images
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: verify-cosign-signature
      match:
        any:
          - resources:
              kinds: [Pod]
              namespaces: [checkout-prod]
      verifyImages:
        - imageReferences:
            - "acrcheckoutprod.azurecr.io/checkout*"
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/acme/checkout/.github/workflows/build-sign-push.yml@refs/heads/main"
                    issuer: "https://token.actions.githubusercontent.com"
                    rekor:
                      url: https://rekor.sigstore.dev
```

### `README-INTENT.md`

```markdown
# Intent — supply chain pipeline for checkout

## Pipeline de firma
<explica keyless, Rekor, por que sin secret>

## Policy de admission
<explica Enforce vs Audit, por que pinnear al workflow concreto>

## Excepciones y rollout
<como arrancar, imagenes existentes, roles de BreakGlass>
```
