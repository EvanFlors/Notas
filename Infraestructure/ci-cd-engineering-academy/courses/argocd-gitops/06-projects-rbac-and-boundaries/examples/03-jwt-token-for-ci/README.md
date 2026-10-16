# Ejemplo 03 — JWT token de un project role para CI

Muestra cómo un pipeline de CI puede obtener permiso **mínimo** (solo `sync` en Applications de un project) sin usar `admin` ni un usuario humano.

## Qué demuestra

- Definir un role `ci-syncer` dentro de un `AppProject`.
- Emitir un JWT de ese role con `argocd proj role create-token`.
- Usar el JWT para hacer `argocd app sync` desde una shell que simula el CI.
- Listar y revocar tokens.

## Prerrequisitos

- Argo CD corriendo en el cluster.
- `argocd` CLI logueado como `admin` (solo para la **emisión** del token; el pipeline *no* necesita admin).
- El `AppProject` del ejemplo 01 (`team-payments`) o aplica `project-with-ci-role.yaml` incluido aquí.

## Archivos

- `project-with-ci-role.yaml` — `AppProject` con el role `ci-syncer`.
- `issue-token.sh` — emite el JWT y lo guarda en `/tmp/argocd-ci-token`.
- `simulate-ci-sync.sh` — ejecuta `argocd app sync` usando **solo** el JWT (sin otras credenciales).
- `revoke-token.sh` — revoca el token.

## Uso

```bash
cd examples/03-jwt-token-for-ci
kubectl apply -f project-with-ci-role.yaml
bash issue-token.sh                   # guarda JWT en /tmp/argocd-ci-token
bash simulate-ci-sync.sh payments-guestbook
bash revoke-token.sh
```

## Lectura clave

- El JWT **no expira automáticamente** salvo que lo pidas con `--expires-in`. Usa siempre un TTL corto en CI (24 h — 7 d máximo).
- El `subject` del token es `proj:team-payments:ci-syncer`. Aparece en los logs de auditoría de Argo CD. **No es un usuario humano**: perfecto para trazabilidad.
- Si el role en el project cambia (quitas `sync`), el token **sigue existiendo** pero deja de poder sync-ear. No hay que re-emitir.
- Para rotar: `argocd proj role delete-token team-payments ci-syncer <id>` + `issue-token.sh` de nuevo.

## Anti-patrones

- Usar el token del role `admin` en `AppProject default` "para no complicarse". Es equivalente a `cluster-admin`.
- Guardar el JWT en el repo (incluso encriptado con `git-crypt`). Métele un `--expires-in` corto y guárdalo en el secret manager del CI.
- No listar tokens emitidos. Un token "huérfano" de hace un año que nadie recuerda haber creado es un hallazgo típico de auditoría.
