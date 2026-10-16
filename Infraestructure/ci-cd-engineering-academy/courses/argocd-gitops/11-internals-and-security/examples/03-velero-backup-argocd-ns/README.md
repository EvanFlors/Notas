# Ejemplo 03 — Backup y Restore del ns `argocd` con Velero

Instala Velero en el cluster, lo configura contra un bucket **MinIO** local (sin AWS real), hace un **Backup** del namespace `argocd` + CRDs de argoproj, borra parte del estado, y lo **restaura**. Al terminar: entiendes que el DR de Argo CD es un ejercicio de 10 minutos cuando el estado está bien delimitado.

## Qué contiene

- `install-velero.sh` — instala MinIO en-cluster y Velero apuntándolo a él.
- `backup.sh` — crea un `Backup` del ns `argocd` + los CRs de argoproj.
- `simulate-disaster.sh` — borra una `Application` y el `argocd-cm` (lo justo para notar que algo se rompió).
- `restore.sh` — ejecuta el `Restore` y verifica.
- `cleanup.sh` — desinstala todo y limpia `/tmp/argo-11-ex03`.

Scripts simplificados — leen bien, pero no cubren todos los edge-cases de Velero prod (ver docs oficiales).

## Requisitos

- `kind` + `kubectl` + `helm` + `velero` CLI instalados.
- Un cluster kind activo con Argo CD en el ns `argocd` (del `argo-02`).
- Al menos 1 `Application` en Argo CD para que el restore sea observable.

**Costo**: $0. MinIO corre dentro del cluster.

## Paso 1 — Instalar Velero + MinIO

```bash
bash install-velero.sh
```

Esto:

1. Despliega MinIO en namespace `velero` con un bucket `velero`.
2. Instala el plugin provider `aws` de Velero (compatible con MinIO vía S3 API).
3. Configura `BackupStorageLocation` apuntando al MinIO interno (`http://minio.velero.svc:9000`).
4. Verifica `kubectl -n velero get backupstoragelocation default` → `Available`.

## Paso 2 — Crear el Backup

```bash
bash backup.sh
```

Internamente:

```bash
velero backup create argocd-ns-$(date +%s) \
  --include-namespaces argocd \
  --include-cluster-resources=true \
  --include-resources '*,applications.argoproj.io,appprojects.argoproj.io,applicationsets.argoproj.io' \
  --wait
velero backup describe <name> --details
```

Resultado esperado: `Phase: Completed`, `Errors: 0`, `Items backed up: N` donde N incluye tus Applications, ConfigMaps, Secrets, el Deployment/StatefulSet de Argo CD, etc.

## Paso 3 — Simular desastre

```bash
bash simulate-disaster.sh
```

Esto borra una `Application` y hace un patch destructivo a `argocd-cm`. Comprueba:

```bash
kubectl -n argocd get applications
kubectl -n argocd get cm argocd-cm -o yaml | head
```

Debe faltar la Application borrada y el `url:` del CM debe ser otro.

## Paso 4 — Restore

```bash
bash restore.sh
```

Internamente:

```bash
velero restore create --from-backup <name> --wait
velero restore describe <restore-name> --details
```

Verifica:

```bash
kubectl -n argocd get applications       # vuelve la que borraste
kubectl -n argocd get cm argocd-cm -o yaml | grep '^  url:'   # restaurado
```

**Observación clave**: Velero por default **no sobrescribe** recursos existentes (`existingResourcePolicy: none`). Para forzar overwrite de ConfigMaps que ya existen, se usa `--existing-resource-policy update`. El script lo activa.

## Paso 5 — Verificar que Argo CD sigue reconciliando

```bash
# Las apps restauradas deben pasar a Synced/Healthy sin intervención.
kubectl -n argocd get applications -o wide
# Si alguna quedó OutOfSync tras el restore, un hard-refresh basta:
argocd app get <name> --hard-refresh
```

## Qué aprendiste

- El estado de Argo CD **es** el ns `argocd` + CRs. Un `Backup` del ns es suficiente.
- Velero gestiona CRDs y CRs sin tratamiento especial — pero debes incluirlos vía `--include-cluster-resources` (los CRDs son cluster-scoped) y `--include-resources` si quieres asegurar un GVK específico.
- `redis` NO necesita restore: tras el restart, Argo CD lo repuebla.
- Un `argocd admin export` + `kubectl get secret -o yaml` logra lo mismo sin Velero — útil si no tienes object storage.

## Limpieza

```bash
bash cleanup.sh
```
