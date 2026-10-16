# helm-02-01 — Instalar cert-manager con Helm

## 1. Identificación

- **ID:** `helm-02-01-install-cert-manager`
- **Tecnología:** helm
- **Módulo:** `02-consume-charts-install-upgrade-rollback`
- **Dificultad:** beginner
- **Duración estimada:** 45 min
- **Tipo:** guided-lab

## 2. Contexto

Vas a instalar **cert-manager** (chart de Jetstack) en tu cluster local. Es el chart "de verdad" que cualquier cluster real tiene: instala sus CRDs, varios Deployments y un webhook. Usa flags que son obligatorios en producción: `--namespace`, `--create-namespace`, `--version` pinneado, y `--wait` para que no "declare éxito" antes de tiempo.

Al terminar vas a tener el release en `helm list -A`, el namespace creado por Helm, el controller en `Ready`, y el Secret `sh.helm.release.v1.cert-manager.v1` en el namespace.

El validador verifica el estado final: release presente con revisión 1, namespace existente, pods del controller Ready, CRDs instaladas, y el Secret del release en su sitio.

## 3. Objetivos

Al terminar deberías poder:

- Añadir y refrescar un repo HTTP de charts.
- Instalar un chart con `--version`, `--namespace`, `--create-namespace`.
- Usar `--wait --timeout` para no completar antes de que los recursos estén Ready.
- Encontrar el Secret donde Helm guarda el estado del release.
- Explicar qué pasaría si borras ese Secret.

## 4. Prerrequisitos

- Un cluster local kind corriendo (`kubectl get nodes` Ready).
- `helm` ≥ 3.14, `kubectl` ≥ 1.28, `kind` ≥ 0.20, Docker.
- Acceso a internet para descargar el chart.
- Sin costo monetario (todo local).

Si falta `helm`, `kubectl`, `kind` o Docker, el validador imprime `SKIP` con instrucciones. Si no hay cluster, también.

## 5. Instrucciones

Trabaja en `/tmp/helm-02-01/`.

### Paso 1 — preparación

Si aún no tienes cluster:

```bash
kind create cluster --name helm-02
```

Verifica contexto:

```bash
kubectl config current-context    # debe ser kind-helm-02 (o el que creaste)
kubectl get nodes                 # al menos uno Ready
```

### Paso 2 — repo de charts

Añade el repo de Jetstack y refresca:

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update jetstack
```

### Paso 3 — install

Instala cert-manager con **estos requisitos exactos** (el validador los verifica):

- release name: `cert-manager`
- namespace: `cert-manager` (crear con `--create-namespace`)
- versión del chart: `v1.16.2`
- CRDs instaladas por el chart (`--set crds.enabled=true`)
- `--wait --timeout 5m`

Comando sugerido:

```bash
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.16.2 \
  --set crds.enabled=true \
  --wait --timeout 5m
```

### Paso 4 — inspección

```bash
helm list -A
helm status cert-manager -n cert-manager
helm get notes cert-manager -n cert-manager
kubectl get deploy -n cert-manager
kubectl get crd | grep cert-manager.io
```

### Paso 5 — localizar el Secret del release

```bash
kubectl get secret -n cert-manager -l owner=helm
#   Debe aparecer sh.helm.release.v1.cert-manager.v1 con type helm.sh/release.v1.
```

### Paso 6 — snapshot

Guarda `/tmp/helm-02-01/snapshot.md` con **estas secciones** (el validador busca los encabezados):

```markdown
# snapshot helm-02-01

## release
<salida de: helm list -n cert-manager>

## status
<salida de: helm status cert-manager -n cert-manager>

## release-secret
<salida de: kubectl get secret -n cert-manager -l owner=helm>

## crds
<salida de: kubectl get crd | grep cert-manager.io>
```

### Paso 7 — validar

```bash
bash courses/helm/02-consume-charts-install-upgrade-rollback/activities/01-install-cert-manager/tests/validate.sh
```

## 6. Resultado esperado

- `helm list -A` muestra `cert-manager` en namespace `cert-manager`, revisión `1`, status `deployed`.
- `kubectl get deploy -n cert-manager` muestra 3 Deployments (`cert-manager`, `cert-manager-webhook`, `cert-manager-cainjector`) todos `READY`.
- `kubectl get crd` incluye al menos `certificates.cert-manager.io`.
- Existe el Secret `sh.helm.release.v1.cert-manager.v1` en `cert-manager`.
- `/tmp/helm-02-01/snapshot.md` existe con las 4 secciones.

## 7. Criterios de aceptación

- `tests/validate.sh` imprime `RESULT: PASS`.
- Usaste `--version v1.16.2` explícito (no "la más nueva").
- No creaste el namespace a mano antes del install (dejaste que `--create-namespace` lo hiciera; es parte de la competencia).
- El snapshot tiene las 4 secciones (no basta con el título).

## 8. Validación

```bash
bash courses/helm/02-consume-charts-install-upgrade-rollback/activities/01-install-cert-manager/tests/validate.sh
```

## 9. Preguntas de reflexión

1. ¿Qué pasa si corres el mismo `helm upgrade --install ...` dos veces seguidas? ¿Cambia la revisión?
2. ¿Qué habría pasado si hubieras usado `helm install` (sin `--install`)? ¿Y `helm upgrade` (sin `--install`)?
3. Mira el Secret del release: `kubectl get secret -n cert-manager sh.helm.release.v1.cert-manager.v1 -o yaml | head -20`. ¿Qué labels tiene? ¿Qué pasaría si lo borras con `kubectl delete`? ¿Qué devuelve `helm status` entonces? ¿Y los Pods del controller?
4. Instalaste con `crds.enabled=true`. Si mañana haces `helm uninstall cert-manager -n cert-manager`, ¿se van las CRDs? ¿Por qué (o por qué no)?
5. Si en `--version` hubieras puesto `*` o lo hubieras omitido, ¿tu cluster quedaría igual al que arme un compañero mañana?

## 10. Extensiones

- Haz `helm get values cert-manager -n cert-manager --all | wc -l` y compáralo con `helm get values cert-manager -n cert-manager | wc -l`. Explica la diferencia.
- Hazle un `helm upgrade` cambiando `--set replicaCount=2` en el controller y verifica con `helm history` que apareció la revisión 2.
- Instala un ClusterIssuer self-signed:
  ```yaml
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: selfsigned
  spec:
    selfSigned: {}
  ```
  y pide un Certificate con él para confirmar que cert-manager está vivo end-to-end.

## 11. Limpieza

```bash
helm uninstall cert-manager -n cert-manager
kubectl delete namespace cert-manager --ignore-not-found
# Las CRDs NO se van con el uninstall. Si quieres purgar también:
kubectl get crd -o name | grep cert-manager.io | xargs -r kubectl delete
rm -rf /tmp/helm-02-01
# Si creaste el cluster solo para esto:
# kind delete cluster --name helm-02
```
