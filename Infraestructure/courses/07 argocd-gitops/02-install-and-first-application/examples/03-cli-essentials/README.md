# Ejemplo 03 — Tour de la CLI `argocd`

## Concepto que demuestra

Los comandos de `argocd` que vas a usar el 90% del tiempo: `login`, `app create`, `app list`, `app get`, `app sync`, `app diff`, `app history`, `app rollback`. Breve pero suficiente para operar sin consultar la docs.

## Contexto

Reutilizamos la Application `guestbook` de los ejemplos 01 y 02. Si no la tienes, créala con el `argocd app create` del ejemplo 02.

## Prerrequisitos

- Argo CD corriendo, port-forward activo, logeado (`argocd context` debe listar `localhost:8080`).
- Application `guestbook` creada y sincronizada al menos una vez.

## Ejecución

```bash
mkdir -p /tmp/argo-02-ex03 && cd /tmp/argo-02-ex03

# ------- SESIÓN Y CONTEXTOS -------

argocd context
#   Lista contextos conocidos (como kubectl config get-contexts).

argocd cluster list
#   Clusters registrados (al menos el in-cluster).

argocd repo list
#   Repos registrados. argocd 'conoce' un repo cuando has creado una
#   Application contra él, o cuando lo añades explícitamente con 'argocd repo add'.

# ------- APP CRUD (dry-run) -------

#   El flag mágico para aprender: --dry-run -o yaml imprime el CR
#   que crearías, sin tocar el cluster. Léelo entero una vez.
argocd app create demo-dry \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --dry-run -o yaml > /tmp/argo-02-ex03/app-rendered.yaml
cat /tmp/argo-02-ex03/app-rendered.yaml
#   Ese YAML es un CR 'Application' listo para kubectl apply.

# ------- INSPECCIÓN -------

argocd app list
#   NAME       CLUSTER                         NAMESPACE  PROJECT  STATUS  HEALTH
#   guestbook  https://kubernetes.default.svc  default    default  Synced  Healthy

argocd app get guestbook
#   Muestra: project, source (repo, path, revision), destination,
#            sync status, health status, árbol de recursos y su estado.

argocd app resources guestbook
#   Tabla de recursos manejados por la app.

argocd app manifests guestbook
#   Imprime los manifests renderizados (desired state). Equivalente al
#   diff de 'app diff' pero sin comparación.

# ------- DIFF -------

#   Introduce drift y mira el diff.
kubectl -n default set image deploy/guestbook-ui guestbook-ui=gcr.io/heptio-images/ks-guestbook-demo:0.1
sleep 2
argocd app diff guestbook
#   Mostrará el diff en 'spec.template.spec.containers[0].image'.
#   Exit code 1 cuando hay diff (útil en CI).
echo "exit was: $?"

# ------- SYNC Y HISTORY -------

argocd app sync guestbook
argocd app history guestbook
#   ID  DATE                      REVISION
#   0   ...                       <SHA>
#   1   ...                       <SHA>  <-- esta es la de ahora

argocd app history guestbook -o wide

# ------- ROLLBACK -------

#   argocd app rollback <NAME> <ID> vuelve a aplicar la revisión del
#   history ID indicado. NO modifica Git. Si tienes auto-sync activado,
#   la próxima reconciliación revertirá tu rollback.
argocd app rollback guestbook 0
argocd app wait guestbook --health --timeout 120
argocd app get guestbook

# ------- LOGS Y EVENTS -------

argocd app logs guestbook --tail 20
#   Agrega los logs de los Pods de la Application en una sola salida.

# ------- BORRAR -------

#   --cascade elimina también los recursos en el cluster.
#   Sin --cascade, solo borra el CR Application pero deja los recursos
#   huérfanos — útil para "entregar" una app a su equipo final.
# argocd app delete guestbook --cascade --yes
```

## Observaciones clave

1. **`--dry-run -o yaml`** es la mejor pedagogía: cada flag se convierte en un campo del CR. Lo que te enseñan los docs en 10 minutos de prosa, el `-o yaml` te lo enseña en 10 segundos.
2. **`app diff` sale con código `1`** cuando hay diff. Perfecto para gates de CI (`argocd app diff $APP || exit 1`).
3. **`app rollback` no toca Git**. Es un parche temporal mientras preparas el `git revert`. Para rollback "de verdad" en GitOps: revert en Git → Argo CD sincroniza.

## Limpieza

```bash
rm -rf /tmp/argo-02-ex03
```
