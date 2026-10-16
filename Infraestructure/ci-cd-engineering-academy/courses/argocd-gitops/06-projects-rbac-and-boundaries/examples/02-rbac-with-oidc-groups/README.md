# Ejemplo 02 — Argo CD RBAC con grupos OIDC

Muestra el patrón `argocd-rbac-cm` donde los **grupos** del IdP se mapean a **roles de Argo CD**, y esos roles tienen policies por project.

## Qué demuestra

- Policies CSV con `p` (permit) y `g` (grant / asignación de role).
- Grupos de ejemplo (`acme:payments-team`, `acme:checkout-team`, `acme:security-readonly`) mapeados a roles.
- `policy.default: role:readonly` como fallback seguro.
- Opcionalmente, cómo se configuraría Dex o un IdP externo en `argocd-cm` (no lo instalamos realmente; es la referencia).

## Archivos

- `argocd-rbac-cm.yaml` — el ConfigMap de policies (puedes aplicarlo tal cual sobre un Argo CD ya instalado; sustituye el default).
- `argocd-cm-oidc-snippet.yaml` — fragmento ilustrativo de `argocd-cm` con `oidc.config` para Keycloak. **No lo apliques si no tienes un IdP real** — romperás el login.
- `apply.sh` — aplica solo el `argocd-rbac-cm`.
- `cleanup.sh` — restaura un `argocd-rbac-cm` mínimo (default readonly).

## Uso

```bash
cd examples/02-rbac-with-oidc-groups
bash apply.sh
# Inspecciona:
kubectl -n argocd get cm argocd-rbac-cm -o yaml
bash cleanup.sh
```

## Verificar sin IdP real

Puedes crear un **usuario local** con el role deseado y simular. En `argocd-cm`:

```yaml
accounts.alice: apiKey, login
```

Luego:

```bash
argocd account update-password --account alice
# añade a argocd-rbac-cm:
#   g, alice, role:payments-admin
argocd login --username alice <server>
argocd app list   # verás solo las apps del project team-payments
```

## Lectura clave

- Las líneas `g, acme:payments-team, role:payments-admin` asumen que el IdP enviará ese grupo en el claim `groups`. Si no, el role no se asigna.
- `role:readonly` es un role **built-in** de Argo CD; `role:payments-admin` es custom.
- Los roles **custom** se definen *con policies `p`*, no con una sección especial — el role existe por el mero hecho de aparecer como sujeto en una `p` line.
