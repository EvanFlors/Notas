# Ejemplo 02 — cert-manager overview

Walkthrough **de lectura** (y opcionalmente de ejecución) de cert-manager como caso de operador que casi todo cluster termina usando.

## Qué es cert-manager

Operador que gestiona **certificados X.509** declarativamente:
- CRDs: `Issuer`, `ClusterIssuer`, `Certificate`, `CertificateRequest`, `Order`, `Challenge`.
- Soporta ACME (Let's Encrypt, ZeroSSL), Vault, Venafi, CA interna, CA auto-firmada.
- Materializa Secrets `kubernetes.io/tls` que Ingress / Gateway consumen.

Modelo mental: `Certificate` (lo que quiero) → `CertificateRequest` → `Order` (ACME) → `Challenge` (HTTP-01/DNS-01) → `Secret` TLS listo.

## Instalación de referencia

```bash
# 1. CRDs + manifests (versión fijada; verificar la vigente al momento de usar).
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml

# 2. Esperar a que todos los Deployments del namespace cert-manager estén Ready.
kubectl -n cert-manager rollout status deploy/cert-manager
kubectl -n cert-manager rollout status deploy/cert-manager-webhook
kubectl -n cert-manager rollout status deploy/cert-manager-cainjector
```

Alternativa: `helm install cert-manager jetstack/cert-manager --set installCRDs=true`.

## ClusterIssuer de ejemplo (ACME staging)

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: platform@example.com
    privateKeySecretRef:
      name: letsencrypt-staging-account
    solvers:
      - http01:
          ingress:
            class: nginx
```

**Siempre** desarrollar contra staging; el rate limit de Let's Encrypt producción es duro.

## Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: api-tls
  namespace: default
spec:
  secretName: api-tls
  issuerRef:
    name: letsencrypt-staging
    kind: ClusterIssuer
  commonName: api.example.com
  dnsNames:
    - api.example.com
  duration: 2160h       # 90 días
  renewBefore: 360h     # renueva con 15 días de anticipación
```

cert-manager:
1. Crea `CertificateRequest`.
2. Crea `Order` ACME y uno o más `Challenge` HTTP-01.
3. Monta un Pod efímero que responde el challenge vía Ingress.
4. Deposita el Secret `api-tls` con `tls.crt` + `tls.key`.
5. Programa renovación automática.

## Qué observar como estudiante

- El operador **no** espera que lleves certs a mano: todo es declarativo.
- Las condiciones en `.status.conditions` del `Certificate` cuentan la historia (`Issuing`, `Ready`).
- El controller **sabe** que un Secret TLS necesita rotación → encaja perfecto con el operator pattern.
- RBAC: cert-manager tiene permisos para crear Secrets a nivel cluster. Es un *operador privilegiado*: entra en el inventario de componentes críticos del cluster.

## Qué NO hace cert-manager

- No instala Ingress controller — lo asume existente.
- No gestiona CA roots internos en sentido PKI corporativo (para eso hay Venafi, Vault PKI).
- No rota passwords de DB, SSH keys, etc. (eso es `external-secrets`).

## Lectura recomendada

- Docs oficiales: https://cert-manager.io/docs/
- Troubleshooting: https://cert-manager.io/docs/troubleshooting/
- CNCF project page: https://www.cncf.io/projects/cert-manager/
