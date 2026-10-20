# Ejemplo 01 — OIDC con GitHub (vía Dex)

Configura login SSO en Argo CD usando GitHub como IdP. GitHub no implementa OIDC estándar, así que lo federamos con **Dex** (el componente que viene incluido en la instalación default).

Al terminar: entras a la UI de Argo CD con tu usuario GitHub, y el claim `groups` trae tus GitHub teams, que luego usas en `argocd-rbac-cm` (Ejemplo 02).

## Qué contiene

- `argocd-cm.yaml` — ConfigMap con `url`, `dex.config` que define un connector `github`.
- `argocd-secret.patch.yaml` — merge-patch que añade `dex.github.clientSecret` al Secret `argocd-secret` (sin tocar las keys existentes).
- `README.md` — este archivo.

## Requisitos

- Argo CD instalado en un cluster (`argo-02` o `kind create cluster && kubectl apply -k …`).
- Acceso a crear una **GitHub OAuth App** en una org (Settings → Developer settings → OAuth Apps). Si no tienes org, sirve una cuenta personal — el `orgs:` del connector se degrada a *allow any*.
- Argo CD alcanzable por el **callback URL**: GitHub debe poder llamar a `https://<argocd-host>/api/dex/callback`. En local con kind + port-forward esto **no funciona** — necesitas:
  - un Ingress con DNS público + TLS, o
  - un túnel (`cloudflared`, `ngrok`), o
  - al menos un hostname que resuelva al port-forward (Dex no acepta IP cruda en algunos flujos).

Si no tienes nada de lo anterior, **salta a la variante Dex mock** al final (el ejemplo sigue siendo didácticamente útil).

**Costo**: $0. Solo recursos del cluster local.

## Paso 1 — Crear la OAuth App en GitHub

1. GitHub → Settings → Developer settings → OAuth Apps → **New OAuth App**.
2. **Homepage URL**: `https://argocd.example.com` (o el que uses).
3. **Authorization callback URL**: `https://argocd.example.com/api/dex/callback`.
4. Crear. Copia el **Client ID**.
5. **Generate a new client secret**. Copia el **Client Secret** — solo lo verás una vez.

## Paso 2 — Inyectar el secret en `argocd-secret`

Nunca pongas el secret en un archivo versionado en Git. Usa stdin:

```bash
read -s GITHUB_OAUTH_SECRET
# pega el secret y Enter

kubectl -n argocd patch secret argocd-secret \
  --type merge \
  -p "{\"stringData\":{\"dex.github.clientSecret\":\"$GITHUB_OAUTH_SECRET\"}}"
unset GITHUB_OAUTH_SECRET
```

Verifica (sin ver el valor):

```bash
kubectl -n argocd get secret argocd-secret \
  -o jsonpath='{.data.dex\.github\.clientSecret}' | base64 -d | wc -c
# debe imprimir >0
```

## Paso 3 — Aplicar `argocd-cm`

Edita `argocd-cm.yaml`:

- `url:` → tu URL pública de Argo CD.
- `dex.config.connectors[0].config.clientID` → el Client ID de la OAuth App.
- `dex.config.connectors[0].config.orgs[0].name` → tu org GitHub.

```bash
kubectl apply -f argocd-cm.yaml
```

Argo CD recarga el ConfigMap en caliente (sin reiniciar). Verifica el `dex-server`:

```bash
kubectl -n argocd rollout restart deploy/argocd-dex-server
kubectl -n argocd rollout status deploy/argocd-dex-server --timeout=60s
kubectl -n argocd logs deploy/argocd-dex-server | grep -i "listening\|connector"
```

Debe reportar `listening (http) on 0.0.0.0:5556` y mencionar el connector `github`.

## Paso 4 — Login desde la UI

Abre `https://argocd.example.com/`. Debe aparecer un botón **LOG IN VIA GITHUB** debajo del formulario local.

- Click → GitHub pide confirmar la OAuth App → autorizas → vuelves a Argo CD autenticado como `<tuuser>@github`.
- `argocd account get-user-info` desde el CLI (tras `argocd login --sso …`) muestra tus `groups` (= `<org>:<team>`).

## Paso 5 — Verificar claims

Esto es lo que luego usas en RBAC:

```bash
argocd login argocd.example.com --sso
argocd account get-user-info
# Expected: Username: <you>, Issuer: argocd, Groups: [acme-org:platform, acme-org:team-a, ...]
```

Si los `groups` vienen vacíos, revisa:

- En la OAuth App de GitHub, scope `read:org` concedido durante el consent.
- `loadAllGroups: true` en el connector (incluido en `argocd-cm.yaml`).

## Variante Dex *mock* (sin GitHub real)

Si no puedes exponer Argo CD a internet, cambia el connector por el **mock** de Dex y verifica el flujo:

```yaml
# en dex.config:
connectors:
- type: mockCallback
  id: mock
  name: Mock
```

El flujo OIDC funcionará y entrarás como el usuario `kilgore@kilgore.trout` con grupos `["authors"]`. Didácticamente igual de válido para después testear el CSV del Ejemplo 02.

## Qué aprendiste

- Argo CD delega el flujo OAuth2/OIDC a Dex cuando el IdP no es OIDC estándar.
- La separación **`argocd-cm` (config pública) vs `argocd-secret` (secretos)** es estricta — nunca mezcles.
- Los `groups` del ID token son el pegamento con `argocd-rbac-cm` → Ejemplo 02.
- Dex se recarga vía rollout; `argocd-server` lee `argocd-cm` en caliente.

## Limpieza

```bash
# Vuelve a login local
kubectl -n argocd patch cm argocd-cm --type merge -p '{"data":{"dex.config":""}}'
kubectl -n argocd patch secret argocd-secret --type json \
  -p '[{"op":"remove","path":"/data/dex.github.clientSecret"}]' 2>/dev/null || true
# Borra la OAuth App en GitHub si no la vas a reutilizar.
```
