# Actividad 02 — PR previews end-to-end (guided-lab)

## 1. Identificación

- **ID:** `argo-12-02-pr-previews-end-to-end`
- **Tecnología:** `argocd-gitops`
- **Módulo:** `argo-12-platform-patterns-promotion-previews-observability`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** guided-lab

## 2. Contexto

Montar PR previews reales requiere GitHub + token + webhook + DNS. Para aislar el aprendizaje del *mecanismo* (ApplicationSet descubre un item nuevo → crea Application → levanta namespace; item desaparece → prune) usamos el **List generator** como stand-in del PR generator: añadir/quitar items simula abrir/cerrar PRs. El contrato de nombrado, quota, limpieza y métricas es idéntico.

Si tienes GitHub+token, al final hay una extensión para migrar a `pullRequest` generator real.

## 3. Objetivos

- Montar un `ApplicationSet` con **List generator** simulando PRs numerados.
- Levantar previews con nombre determinista (`pr-{{number}}`) y host `pr-{{number}}.preview.local`.
- "Abrir" un PR nuevo (añadir item) y verificar que aparece el namespace + Application en < 60s.
- "Cerrar" un PR (quitar item) y verificar `prune` automático.
- Aplicar `ResourceQuota` en el namespace preview.
- Observar `argocd_app_info` y `argocd_app_sync_total` reflejando el ciclo.

## 4. Prerrequisitos

- `kind` ≥ 0.20, `kubectl` ≥ 1.28, `argocd` CLI ≥ 2.9, `yq`, `curl`, `jq`.
- 2–3 GB RAM libres.
- Puerto 8080 y 8082 locales libres (port-forward).
- Argo CD habrá sido instalado por el `bootstrap.sh`.

**Costos**: 0 (todo local).

## 5. Instrucciones

### 5.1 Levantar entorno

```bash
cd starter
chmod +x bootstrap.sh pr-open.sh pr-close.sh
./bootstrap.sh
```

El script:

1. Crea cluster `kind` llamado `argo-12-ex`.
2. Instala Argo CD estable.
3. Aplica `appset.yaml` (ApplicationSet con List generator vacío).
4. Aplica `project.yaml` (AppProject `previews`).
5. Deja listo `kubectl` para ver recursos.

Espera a que Argo CD esté `Ready` (el script lo chequea).

### 5.2 Simular "abrir PR #123"

```bash
./pr-open.sh 123
kubectl -n argocd get applicationset previews -o yaml | yq '.spec.generators[0].list.elements'
kubectl -n argocd get applications
kubectl get ns | grep pr-
```

Esperado: una Application `preview-pr-123`, un namespace `pr-123`, un `Deployment` nginx dentro.

### 5.3 Simular "abrir PR #124" (segunda preview coexistiendo)

```bash
./pr-open.sh 124
sleep 15
kubectl get ns pr-123 pr-124
```

### 5.4 ResourceQuota

Está incluido en el template del ApplicationSet; se aplica al namespace al crearse. Verifica:

```bash
kubectl -n pr-123 get resourcequota
kubectl -n pr-123 describe resourcequota preview-quota
```

### 5.5 Métricas de Argo CD durante el ciclo

```bash
kubectl -n argocd port-forward svc/argocd-metrics 8082:8082 >/tmp/pf.log 2>&1 &
PF=$!
sleep 2
curl -s http://localhost:8082/metrics | grep -E '^argocd_app_info|^argocd_app_sync_total' | head
kill $PF 2>/dev/null || true
```

Observa cómo `argocd_app_info` emite ahora series para `preview-pr-123` y `preview-pr-124`.

### 5.6 "Cerrar" PR #123

```bash
./pr-close.sh 123
sleep 20
kubectl -n argocd get applications
kubectl get ns pr-123 || echo "namespace eliminado"
```

Esperado: la Application `preview-pr-123` desaparece; `prune: true` + finalizer eliminan los recursos; el namespace también (lo manejamos como recurso del chart; sin `prune` quedaría huérfano).

### 5.7 Validar automáticamente

```bash
bash ../tests/validate.sh
```

### 5.8 Repite el ciclo (smoke test)

Para verificar reproducibilidad:

```bash
./pr-close.sh 124
./pr-open.sh 200
sleep 20
./pr-close.sh 200
bash ../tests/validate.sh
```

## 6. Resultado esperado

- `bootstrap.sh` deja cluster + Argo CD + ApplicationSet operativos.
- `pr-open.sh N` levanta `preview-pr-N` + namespace `pr-N` + ResourceQuota.
- `pr-close.sh N` destruye todo lo asociado al PR N en < 30s.
- `validate.sh` termina con `exit 0` tras el ciclo descrito.

## 7. Criterios de aceptación

- Dos previews coexistiendo sin pisarse.
- Namespace eliminado al cerrar el PR (no namespace huérfano).
- `ResourceQuota` presente en cada namespace preview.
- Al menos una serie de `argocd_app_info` corresponde a una Application `preview-pr-*` durante el pico.

## 8. Validación

```bash
bash tests/validate.sh
```

Checks (ver script):

- Cluster `argo-12-ex` existe.
- Argo CD running.
- ApplicationSet `previews` existe.
- No quedan namespaces `pr-*` al final (tras el ciclo open/close).

## 9. Preguntas de reflexión

- Si quitas `prune: true`, ¿qué recursos quedan huérfanos al cerrar un PR? Prueba.
- Si quitas el `finalizer`, ¿qué pasa con la Application al borrarse el ApplicationSet-item?
- ¿Cómo evitarías que un PR malicioso añada un recurso `ClusterRole`? (Pista: `AppProject.clusterResourceWhitelist`.)
- Con 40 previews activos, `argocd_app_info` emite 40+ series. ¿Dónde empieza a doler y qué `metricRelabelings` propondrías?
- Migra el `List` generator a `pullRequest` generator contra tu propio fork. ¿Qué cambia en el template?

## 10. Extensiones

- Añadir **DNS** real con `*.preview.<domain>` (requiere ingress-nginx + external-dns).
- Migrar al `pullRequest` generator con un token de GitHub de solo lectura.
- Añadir `CronJob` que detecte previews con última actividad > 7 días y las cierre.
- Añadir **notificaciones-controller** mandando un mensaje a webhook al abrir/cerrar previews.
- Integrar **ESO** leyendo secretos de un path `previews/*`.

## 11. Limpieza

```bash
cd starter
./bootstrap.sh --clean
# o explícito:
kind delete cluster --name argo-12-ex
rm -rf /tmp/argo-12-prprev
```
