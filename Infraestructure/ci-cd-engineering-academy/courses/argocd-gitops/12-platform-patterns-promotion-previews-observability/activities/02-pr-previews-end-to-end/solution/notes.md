# Notas de solución — PR previews end-to-end

## Flujo esperado

```bash
./bootstrap.sh                 # kind + argocd + appset
./pr-open.sh 123               # +namespace pr-123, +Application preview-pr-123, +quota
./pr-open.sh 124               # coexiste con pr-123
./pr-close.sh 123              # prune, delete ns pr-123
./pr-close.sh 124              # prune, delete ns pr-124
bash ../tests/validate.sh      # 6 OK
```

## Puntos clave

1. **List generator** actúa como stand-in del `pullRequest` generator. El mecanismo (añadir/quitar un item ⇒ crear/eliminar una Application) es idéntico; cambia solo la fuente del item.
2. **Namespace delete** no es automático con Argo CD cuando el namespace fue creado via `CreateNamespace=true`. Soluciones:
   - Modelar el namespace como recurso del chart (lo gestiona `prune`).
   - CronJob que detecta namespaces `pr-*` sin Application viva y los borra.
   - En este lab, `pr-close.sh` hace el delete explícito.
3. **Finalizer** `resources-finalizer.argocd.argoproj.io/background` asegura que al borrar la Application se eliminen sus hijos. Sin él, prune de recursos puede quedar incompleto si el ApplicationSet-controller elimina la Application antes de que termine la cascada.
4. **ResourceQuota** se aplica desde `pr-open.sh` (fuera del chart) porque el chart de `guestbook` no la contiene. En plataforma real, pondría la quota como recurso del chart de preview (una sola fuente de verdad).
5. **Cardinalidad de métricas**: con 10 previews activos, `argocd_app_info` emite 10+ series. En clusters grandes aplicar `metricRelabelings` para dropear labels poco útiles (p.ej. `dest_server`).

## Migrar a pullRequest generator real

Reemplazar `generators[0]` por:

```yaml
generators:
  - pullRequest:
      github:
        owner: tu-usuario
        repo: tu-fork-del-guestbook
        tokenRef: { secretName: github-token, key: token }
      requeueAfterSeconds: 60
```

Y en template reemplazar `{{.number}}` por `{{number}}` (sin `.` porque pullRequest generator **no usa Go templates por defecto**; o mantener `goTemplate: true` con `{{.number}}`).

## Trampas vistas

- `kind` sin internet no puede clonar `argoproj/argocd-example-apps`; se queda esperando. Verificar conectividad antes del bootstrap.
- Primer sync tarda 30–60s por el `helm template` / git clone. El script espera hasta 60s.
- Si `yq` es la variante de Python (`kislyuk/yq`), la sintaxis difiere. Usar `mikefarah/yq` (Go) ≥ v4.
