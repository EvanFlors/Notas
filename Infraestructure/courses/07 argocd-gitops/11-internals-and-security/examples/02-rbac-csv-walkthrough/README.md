# Ejemplo 02 — Recorrido anotado del `argocd-rbac-cm` (CSV estilo Casbin)

Toma un `argocd-rbac-cm` *deny-by-default* real, lo aplica, y verifica qué puede y qué no puede hacer un usuario con `argocd account can-i`.

## Qué contiene

- `argocd-rbac-cm.yaml` — ConfigMap con `policy.csv` comentado línea a línea.
- `test-can-i.sh` — script que ejecuta `argocd account can-i` sobre matrices (user × verb × resource) y reporta pass/fail.

## Requisitos

- Argo CD instalado (`argo-02`).
- `argocd` CLI logueado (`argocd login` como admin para aplicar el CM; luego logueado como usuario de prueba para verificar).
- 2 projects de prueba: `team-a` y `team-b` (`argocd proj create team-a` y `argocd proj create team-b`).
- 2 Applications dummy: `team-a/web` y `team-b/web`. Si no las tienes:

```bash
argocd proj create team-a --description "Team A"
argocd proj create team-b --description "Team B"
argocd app create team-a-web \
  --project team-a \
  --repo https://github.com/argoproj/argocd-example-apps \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace team-a-web \
  --sync-option CreateNamespace=true
argocd app create team-b-web \
  --project team-b \
  --repo https://github.com/argoproj/argocd-example-apps \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace team-b-web \
  --sync-option CreateNamespace=true
```

**Costo**: $0.

## Paso 1 — Aplicar el ConfigMap

```bash
kubectl apply -f argocd-rbac-cm.yaml
# El rbac-cm se recarga en caliente; argocd-server no necesita restart.
```

## Paso 2 — Lectura comentada

El CSV define:

| Role | Permisos |
|------|----------|
| `role:readonly` | `get` sobre todo (apps, projects, clusters, repos, logs). |
| `role:platform-admin` | `*` sobre todo. Reservado al equipo de plataforma. |
| `role:team-a-dev` | `get` + `sync` sobre `team-a/*`. **Deny** explícito a `delete`. |
| `role:team-b-dev` | `get` + `sync` sobre `team-b/*`. **Deny** explícito a `delete`. |

Bindings (asume el claim `groups` del OIDC):

- `platform-sre@acme.com` → `role:platform-admin` (binding por email).
- `acme-org:team-a` → `role:team-a-dev`.
- `acme-org:team-b` → `role:team-b-dev`.

`policy.default: ""` → **deny-by-default**: cualquier action no explícitamente permitida se rechaza.

## Paso 3 — Verificar con `can-i`

Como admin, puedes impersonar roles con el flag `--auth-token` o loguearte como usuarios distintos. Más simple: usar `argocd account can-i` con el usuario actual y verificar vía UI (menú User Info).

```bash
bash test-can-i.sh
```

El script asume que `argocd` está logueado como un usuario miembro de `acme-org:team-a` y espera:

```
TEST: team-a user can sync team-a/web   -> OK (yes)
TEST: team-a user can delete team-a/web -> OK (no, denied)
TEST: team-a user can sync team-b/web   -> OK (no, deny-by-default)
TEST: team-a user can get  team-b/web   -> OK (no, deny-by-default)
```

## Paso 4 — Experimento: romper deny-by-default

Comenta la línea `policy.default: ""` en el CM (déjalo sin valor explícito). Argo CD aplica el default *implícito* `role:readonly`. Vuelve a correr `test-can-i.sh`: `get` sobre `team-b/web` ahora pasa — lo cual **puede ser deseable** (visibilidad global) o **puede ser una fuga** (ver nombres de apps de otro equipo). Ese es el trade-off.

## Qué aprendiste

- El orden importa: `deny` gana sobre `allow` en el mismo matching.
- `policy.default` es la red de seguridad — ponerlo vacío es "estricto".
- `g, <group>, role:<name>` es cómo pegas OIDC groups a roles.
- Hay dos niveles de identidad: `user` (del claim `sub` o `preferred_username`) y `group` (del claim `groups`). Los `scopes: '[groups]'` elige cuál se evalúa en los `g, ...`.

## Limpieza

```bash
# Vuelve al default permisivo (NO recomendado en prod — solo para no dejar config rara):
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata: { name: argocd-rbac-cm, namespace: argocd }
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:admin, *, *, */*, allow
  scopes: '[groups]'
EOF

# Opcional: borrar apps/projects de prueba
argocd app delete team-a-web --yes
argocd app delete team-b-web --yes
argocd proj delete team-a
argocd proj delete team-b
```
