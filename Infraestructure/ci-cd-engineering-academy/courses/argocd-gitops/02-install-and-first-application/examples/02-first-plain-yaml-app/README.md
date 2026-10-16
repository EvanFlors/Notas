# Ejemplo 02 — Primera Application: `guestbook` (plain YAML)

## Concepto que demuestra

Cómo se ve la **mínima Application posible**: fuente plain YAML en un repo público, destino el mismo cluster, sync manual. Muestra la diferencia entre `sync status` y `health status` en tiempo real.

## Contexto

Partimos del ejemplo 01 ya hecho (Argo CD corriendo en kind, port-forward activo, admin logeado). Usamos el repo didáctico oficial `argoproj/argocd-example-apps`, que contiene un directorio `guestbook/` con un `Deployment` + `Service` plain YAML.

## Prerrequisitos

- Ejemplo 01 completo: cluster `kind-argo-02` con Argo CD corriendo y port-forward en 8080.
- `argocd` CLI (`brew install argocd`).

## Ejecución

```bash
mkdir -p /tmp/argo-02-ex02 && cd /tmp/argo-02-ex02

# 1. Login en la CLI contra el port-forward.
ARGO_PASS="$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d)"
argocd login localhost:8080 \
  --username admin \
  --password "$ARGO_PASS" \
  --insecure
#   'context 'localhost:8080' updated' → logeado.

# 2. Verificar que el "in-cluster" aparece registrado.
argocd cluster list
#   SERVER                          STATUS
#   https://kubernetes.default.svc  Successful  (o 'Unknown' hasta que haya una app)

# 3. Crear la Application 'guestbook'.
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --revision HEAD \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default
#   La Application se crea como CR en el namespace argocd.
#   Al principio su sync status será OutOfSync (nada se ha aplicado).

# 4. Ver el CR equivalente (hubieras podido 'kubectl apply' esto directamente).
kubectl -n argocd get application guestbook -o yaml | head -40

# 5. Estado antes de sync.
argocd app get guestbook
#   Sync Status:   OutOfSync
#   Health Status: Missing
#   Debajo verás 'Deployment default/guestbook-ui — OutOfSync — Missing'
#                'Service    default/guestbook-ui — OutOfSync — Missing'

# 6. Dispara el sync (apply) y espera.
argocd app sync guestbook
argocd app wait guestbook --health --timeout 180

# 7. Estado después del sync.
argocd app get guestbook
#   Sync Status:   Synced
#   Health Status: Healthy

# 8. Confirma en Kubernetes directamente.
kubectl -n default get deploy,svc -l app.kubernetes.io/instance=guestbook
#   deployment.apps/guestbook-ui   1/1
#   service/guestbook-ui           ClusterIP

# 9. Juega con el health: escala a 0 réplicas a mano y mira qué pasa.
kubectl -n default scale deploy guestbook-ui --replicas=0
sleep 3
argocd app get guestbook
#   Sync Status:   OutOfSync    (spec.replicas en Git = 1, live = 0)
#   Health Status: Degraded     (availableReplicas != spec.replicas)

#   Observa el app diff:
argocd app diff guestbook
#   -    replicas: 0
#   +    replicas: 1

# 10. Vuelve a Synced con un sync.
argocd app sync guestbook
```

## Observaciones clave

1. **`sync` ≠ `health`**: tras `scale --replicas=0`, la app queda `OutOfSync` + `Degraded`. Si en lugar de escalar hubieras cambiado el repo (bump de image tag) sin sync, estarías `OutOfSync` + `Healthy`.
2. **`https://kubernetes.default.svc`** no es una URL real; es el alias canónico para "este mismo cluster". No lo escribas con `curl`.
3. **El `app create` no sincroniza**. Hay que pedir el `sync` explícitamente. Esto es intencional en el flujo manual (`argo-05` cubre `syncPolicy.automated`).

## Limpieza

```bash
argocd app delete guestbook --cascade --yes
# O declarativamente:
# kubectl -n argocd delete application guestbook
rm -rf /tmp/argo-02-ex02
```
