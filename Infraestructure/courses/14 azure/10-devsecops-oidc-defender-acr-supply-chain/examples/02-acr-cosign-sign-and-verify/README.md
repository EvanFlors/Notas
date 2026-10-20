# Ejemplo 02 — Firmar y verificar imagenes con cosign keyless + ACR

> Lectura y analisis. Sin ejecucion. Objetivo: entender el flujo keyless de sigstore con ACR como almacen y como verificar la firma desde CI y desde el cluster.

## 1. Flujo completo (end-to-end)

```
+-----------------+                                    +---------------------+
| GHA runner      |                                    | Fulcio CA (sigstore)|
|  OIDC enabled   | --- OIDC id_token (sub=workflow) ->|                     |
+-----------------+                                    | emite cert X.509    |
                                                       | (10 min TTL)        |
         <----- cert + ephemeral priv key -------------+---------------------+
                                                                 
cosign sign --yes acrcheckoutprod.azurecr.io/checkout:<sha>
    |
    |  firma con la priv key efimera; publica:
    |    - firma binaria (cosign.sig)
    |    - cert publico
    |    - hash de la imagen
    v
+---------------------+                        +---------------------+
| ACR (acr...prod)    | <-- OCI artifact ----- | cosign              |
| checkout:<sha>      |     tag <sha>.sig      |                     |
| checkout:<sha>.sig  |                        +----------+----------+
+---------------------+                                   |
                                                          |
                                                          v
                                              +---------------------+
                                              | Rekor transparency  |
                                              | log (append-only)   |
                                              +---------------------+
```

## 2. Pre-requisitos del runner

```yaml
permissions:
  id-token: write     # OIDC a Fulcio Y a Azure
  contents: read

steps:
  - uses: actions/checkout@v4
  - uses: azure/login@v2
    with:
      client-id: ${{ vars.AZURE_CLIENT_ID }}
      tenant-id: ${{ vars.AZURE_TENANT_ID }}
      subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
  - run: az acr login --name acrcheckoutprod
  - uses: sigstore/cosign-installer@v3
    with:
      cosign-release: v2.4.0
```

## 3. Build + push + sign

```yaml
  - name: Build and push
    uses: docker/build-push-action@v6
    with:
      context: .
      push: true
      tags: acrcheckoutprod.azurecr.io/checkout:${{ github.sha }}

  - name: Sign (keyless)
    env:
      COSIGN_EXPERIMENTAL: "1"
    run: |
      cosign sign --yes \
        acrcheckoutprod.azurecr.io/checkout:${{ github.sha }}
```

Lo que `cosign sign` hace detras:

1. Pide OIDC token al runner (`$ACTIONS_ID_TOKEN_REQUEST_URL` con `audience=sigstore`).
2. Envia el token a **Fulcio**, que valida la firma del issuer y emite un cert X.509 cuyo SAN contiene la identidad del workflow (`https://github.com/acme/checkout/.github/workflows/build.yml@refs/heads/main`).
3. Firma el **digest** de la imagen con la priv key efimera asociada al cert.
4. Hace `PUT` a ACR del OCI artifact de firma (`<digest>.sig` con media type `application/vnd.dev.cosign.artifact.sig.v1+json`).
5. Registra la firma en **Rekor** (hash + cert + timestamp). Lo hace **publico** (Rekor es append-only y mundial).

## 4. Verificar desde CLI local

```bash
cosign verify \
  --certificate-identity "https://github.com/acme/checkout/.github/workflows/build.yml@refs/heads/main" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  acrcheckoutprod.azurecr.io/checkout:abcdef1234
```

Si pasa, imprime el payload de la firma. Si falla:

- `error: no signatures found` -> la imagen no esta firmada o apuntas al tag equivocado.
- `error: certificate identity ... does not match` -> alguien firmo pero desde otro workflow (p. ej. desde una rama de feature). Confirmas que el deploy intenta usar una imagen construida desde la rama **y** firmada por el workflow correcto.

## 5. Verificar desde el cluster (admission)

Dos opciones oficiales (ver seccion §8 de la leccion):

**Ratify**:

```yaml
apiVersion: config.ratify.deislabs.io/v1beta1
kind: Verifier
metadata:
  name: verifier-cosign
spec:
  name: cosign
  artifactTypes: application/vnd.dev.cosign.artifact.sig.v1+json
  parameters:
    certificate-identity: "https://github.com/acme/checkout/.github/workflows/build.yml@refs/heads/main"
    certificate-oidc-issuer: "https://token.actions.githubusercontent.com"
```

**Kyverno** (`verifyImages`):

```yaml
apiVersion: kyverno.io/v2beta1
kind: ClusterPolicy
metadata:
  name: require-signed-images
spec:
  validationFailureAction: Enforce
  rules:
    - name: verify-cosign
      match:
        any:
          - resources: { kinds: [Pod] }
      verifyImages:
        - imageReferences: ["acrcheckoutprod.azurecr.io/*"]
          attestors:
            - entries:
                - keyless:
                    subject: "https://github.com/acme/checkout/.github/workflows/build.yml@refs/heads/main"
                    issuer: "https://token.actions.githubusercontent.com"
                    rekor:
                      url: https://rekor.sigstore.dev
```

Ambos operan como admission webhook: el apiserver llama al webhook, el webhook llama a Rekor + Fulcio, y responde Allow/Deny.

## 6. Preguntas clave

### 6.1 ¿Que impide que un atacante firme con otra identidad?

El `certificate-identity` del verificador es un **string literal**. Si un atacante consigue correr otro workflow (o fork), su firma tendra un `SAN` distinto y el verify fallara. Resiste typosquatting dentro del propio repo si pinneas `job_workflow_ref` concreto.

### 6.2 ¿Que pasa si Rekor esta caido?

Verify falla por defecto (consulta Rekor). Hay flags para operar en modo "no-rekor" (solo cert) pero sacrifica la propiedad de transparencia. Para orgs con requerimiento air-gapped se despliega Rekor privado.

### 6.3 ¿Y si queremos firmar con una clave propia (no keyless)?

```bash
cosign generate-key-pair                          # genera cosign.key / cosign.pub
cosign sign --key cosign.key <image>
cosign verify --key cosign.pub <image>
```

Pros: funciona offline. Contras: ahora tienes **un secret** (la priv key) que custodiar. En Azure, la almacenes en Key Vault y la referencies via `azurekms://...`. Para la mayoria de equipos, keyless es la opcion correcta (menos custody).

## 7. Preguntas de autocomprobacion

1. Si rotas el nombre del workflow de `build.yml` a `build-and-sign.yml`, ¿que falla y donde?
2. ¿Que informacion queda publica en Rekor cuando firmas? ¿Es un problema para codigo propietario?
3. ¿Como se expresa en el verificador la aceptacion de **varios** workflows legitimos (p. ej. `build-main.yml` y `build-release.yml`)?
4. ¿Puede un pod no privilegiado hacer `cosign verify` por su cuenta y rechazarse si no verifica, sin admission controller? ¿Que riesgos tiene?
5. Si tu ACR tiene Private Link habilitado, ¿puede el runner publico de GHA pullear la firma para `cosign verify`? ¿Como lo resuelves?
