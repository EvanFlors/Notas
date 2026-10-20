# helm-02 — Lección: consumir charts y operar el lifecycle de releases

> 12 secciones. Lee con el cluster abierto en otra terminal — todo lo que se afirma aquí se verifica en segundos con `kubectl` o `helm`.

---

## 1. Qué es un *release* y por qué importa

En Helm 3, el objeto que operas en el día a día no es el **chart** (el paquete) sino el **release** (la instancia instalada). Un mismo chart se puede instalar `N` veces en el mismo cluster — cada vez produce un release distinto, con nombre único, en un namespace. Dos ejemplos realistas:

- `helm install nginx-public ingress-nginx/ingress-nginx -n public` y
- `helm install nginx-admin  ingress-nginx/ingress-nginx -n admin`

son dos releases independientes del mismo chart. Cada uno tiene su propia historia de revisiones, sus propios valores efectivos y sus propios recursos.

La implicancia práctica: casi todos los comandos de este módulo (`status`, `get`, `history`, `upgrade`, `rollback`, `uninstall`) operan sobre el *release*, no sobre el chart. Olvidar esta diferencia es la fuente más común de confusión en Helm.

---

## 2. Repositorios: `helm repo add/update`

Un **repositorio** HTTP tradicional es un servidor que publica un `index.yaml` con metadata (nombres, versiones, URLs de descarga) de los charts disponibles. Añadirlo es equivalente a añadir un repositorio de `apt`:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack      https://charts.jetstack.io
helm repo list
helm repo update                   # refresca TODOS
helm repo update ingress-nginx     # refresca uno
```

`helm repo update` descarga los `index.yaml` nuevos a `$XDG_CACHE_HOME/helm/repository/` (en macOS, `~/Library/Caches/helm/repository/`; en Linux, `~/.cache/helm/repository/`). Hasta que no corras `update`, `helm search repo` buscará en el índice *cacheado* — si acabas de añadir un repo y no ves una versión nueva, es porque el cache quedó viejo.

> En Helm 3.8+ existen **OCI registries** como alternativa (y preferencia moderna). No usan `helm repo add`; se consumen directamente con `oci://ghcr.io/<org>/<chart>`. Lo cubrimos en `helm-08`.

---

## 3. `helm install`: anatomía del comando

```bash
helm install <RELEASE> <CHART> [flags]
```

Flags que debes aprender de memoria:

| Flag | Qué hace | Cuándo omitirlo cuesta caro |
|------|----------|-----------------------------|
| `--namespace / -n` | Namespace donde se instala el release. | Si lo omites, va a `default`. Casi nunca es lo que quieres. |
| `--create-namespace` | Crea el namespace si no existe. | Sin esto, el install falla si el namespace no existe. |
| `--version` | Pinnea la versión del chart (SemVer). | Sin esto, Helm instala la *más nueva* del repo cacheado — reproducibilidad rota. |
| `--values / -f` | Archivo YAML con overrides. Repetible, ordenado. | Es la forma correcta de parametrizar; `--set` solo para toques puntuales. |
| `--set` | Override inline (`key=value`). | Útil para flags simples; peligroso para estructuras anidadas. |
| `--dry-run` | Renderiza y "simula" el install sin aplicar. | Para ver el YAML final antes de impactar el cluster. |
| `--debug` | Imprime los manifests renderizados y la info de release. | Combínalo con `--dry-run` para debugging. |
| `--wait` | Espera a que todos los recursos estén Ready antes de dar OK. | Clave en CI/CD para no "declarar éxito" prematuramente. |
| `--timeout` | Timeout para `--wait` (default 5m). | Ajústalo si el chart tarda (p. ej. Prometheus Operator). |
| `--atomic` | Si falla, hace rollback automático. | Lo veremos a fondo en `helm-07`. |

Ejemplo canónico:

```bash
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --version 4.11.3 \
  -f values-prod.yaml \
  --set controller.service.type=ClusterIP \
  --wait --timeout 5m
```

---

## 4. Precedencia de valores

Cuando mezclas defaults, `-f` y `--set`, el orden efectivo es:

1. **Defaults del chart** (`values.yaml` embebido).
2. **Cada `-f file.yaml`** en el orden que aparecen en la CLI (el último gana).
3. **Cada `--set key=value`** en el orden que aparecen en la CLI (el último gana).

Es decir: `--set` siempre gana sobre `-f`, y entre dos `-f` el *último* gana. Prueba trivial:

```bash
helm install demo bitnami/nginx \
  -f base.yaml      \   # replicaCount: 1
  -f prod.yaml      \   # replicaCount: 3
  --set replicaCount=5
# resultado efectivo: 5
```

Dos consecuencias operativas:

- La convención común es `values.yaml` (base, versionado) + `values-<env>.yaml` (overrides por entorno).
- `--set` es para parámetros *dinámicos* del pipeline (tag de imagen, SHA del commit), nunca para configurar la aplicación.

---

## 5. `helm upgrade --install`: el idiom de CI/CD

En un pipeline, no sabes si estás corriendo el deploy por primera o por centésima vez. Dos comandos "normales" fallan en el caso opuesto:

- `helm install foo chart/foo` → falla si `foo` ya existe (`cannot reuse a name`).
- `helm upgrade foo chart/foo` → falla si `foo` *no* existe (`release: not found`).

La forma correcta es un solo comando idempotente:

```bash
helm upgrade --install foo chart/foo -f values.yaml --wait
```

Si no existe, se instala. Si existe, se actualiza. **Esta debería ser tu única forma de deploy en CI/CD.** Nunca escribas `helm install || helm upgrade` como "atajo" — el `||` oculta errores reales.

Comportamiento de valores en upgrade:

- **Default**: se usan los valores que pases ahora; los de la revisión anterior se **ignoran** salvo que no los sobrescribas con `-f`/`--set` (en cuyo caso vuelven a los defaults del chart).
- `--reuse-values`: hereda los valores de la revisión anterior y aplica tus overrides encima.
- `--reset-values`: ignora lo que había y empieza desde los defaults del chart + tus overrides.

En CI/CD lo normal es pasar explícitamente los `-f` cada vez (sin `--reuse-values`): el pipeline *es* la fuente de verdad.

---

## 6. `helm uninstall`: qué se va, qué se queda

```bash
helm uninstall <release> -n <ns>
helm uninstall <release> -n <ns> --keep-history   # conserva los Secrets de release
```

Lo que se va:

- Los recursos renderizados en el último `helm install/upgrade` (Deployments, Services, Ingress, etc.).
- Los Secrets `sh.helm.release.v1.<release>.vN` (salvo `--keep-history`).

Lo que **no** se va automáticamente (gotchas):

- **PVCs** creados por StatefulSets o por Jobs — por diseño: no borrar datos.
- **CRDs** instaladas desde el directorio `crds/` del chart — por diseño: no romper otros usuarios de la CRD.
- Objetos creados por hooks con delete-policy `before-hook-creation` (p. ej. ciertos Secrets de TLS).
- Namespaces: `helm` nunca borra el namespace, aunque haya hecho `--create-namespace` para crearlo.

Si no limpias eso y reinstalas, puedes recibir errores confusos (`immutable`, `AlreadyExists`). Patrón de limpieza completa:

```bash
helm uninstall mychart -n mychart
kubectl delete pvc -n mychart --all
kubectl delete namespace mychart       # solo si estás seguro
# si el chart trajo CRDs y las quieres fuera:
kubectl get crd -o name | grep <group> | xargs kubectl delete
```

---

## 7. Inspección: `helm list`, `status`, `get`

```bash
helm list                        # releases del namespace actual
helm list -A                     # TODOS los namespaces
helm list -A --output json       # scriptable

helm status ingress-nginx -n ingress-nginx
helm status ingress-nginx -n ingress-nginx --revision 2    # snapshot de una revisión pasada

helm get values   ingress-nginx -n ingress-nginx           # user-supplied values
helm get values   ingress-nginx -n ingress-nginx --all     # defaults + user
helm get manifest ingress-nginx -n ingress-nginx           # YAML final aplicado
helm get notes    ingress-nginx -n ingress-nginx           # NOTES.txt
helm get hooks    ingress-nginx -n ingress-nginx           # hooks declarados
```

Dos consejos operativos:

- `helm get manifest > current.yaml && helm get manifest --revision N > prev.yaml && diff -u prev.yaml current.yaml` → tu *diff* real entre revisiones.
- `helm get values --all` es útil cuando una gotcha del chart viene de un *default* que no sabías que estaba activo.

---

## 8. Revisiones, `helm history` y `helm rollback`

Cada operación exitosa (`install`, `upgrade`, `rollback`) incrementa un contador de **revisiones** del release.

```bash
helm history ingress-nginx -n ingress-nginx
```

```text
REVISION   UPDATED                   STATUS       CHART                  APP VERSION   DESCRIPTION
1          Thu Oct 15 10:00:00 2026  superseded   ingress-nginx-4.11.3   1.11.3        Install complete
2          Thu Oct 15 10:05:12 2026  superseded   ingress-nginx-4.11.3   1.11.3        Upgrade complete
3          Thu Oct 15 10:07:40 2026  deployed     ingress-nginx-4.11.3   1.11.3        Rollback to 1
```

- `deployed`: la revisión activa.
- `superseded`: revisión histórica correcta en su día; otra la reemplazó.
- `failed`: upgrade que falló (p. ej. `--atomic` + algo roto).
- `pending-upgrade` / `pending-install` / `pending-rollback`: operación en curso o abortada bruscamente.

### `helm rollback`

```bash
helm rollback ingress-nginx 1 -n ingress-nginx --wait
```

Qué pasa internamente:

1. Helm lee el Secret `sh.helm.release.v1.ingress-nginx.v1` (el "snapshot" de la revisión 1).
2. Deserializa el chart, los values y el manifest que había en ese momento.
3. **Crea una revisión nueva** (N+1), con status `deployed`, cuyo contenido es copia de la revisión target.
4. Aplica el manifest al cluster y marca la anterior como `superseded`.

Puntos importantes:

- Rollback **no borra la historia**. La historia solo crece.
- Un rollback puede fallar por las mismas razones que un upgrade (campos inmutables, validación del API server, hooks fallidos).
- `helm rollback <release>` sin número → revierte a la revisión anterior (`N-1`).
- `--max 20` en varios comandos controla cuántas revisiones conservar; el default global es 10 (`helm upgrade --history-max`).

---

## 9. Dónde vive el estado del release (el Secret)

Esto es la pregunta de evaluación del módulo. En Helm 3, el **storage backend por default es un Secret por revisión en el namespace del release**:

```bash
kubectl get secret -n ingress-nginx -l owner=helm
```

```text
NAME                                   TYPE                 DATA   AGE
sh.helm.release.v1.ingress-nginx.v1    helm.sh/release.v1   1      10m
sh.helm.release.v1.ingress-nginx.v2    helm.sh/release.v1   1      7m
sh.helm.release.v1.ingress-nginx.v3    helm.sh/release.v1   1      3m
```

Qué contiene cada Secret (campo `data.release`):

1. Toma el objeto Release (metadata + chart embebido + values + manifest renderizado).
2. Lo serializa a JSON.
3. Lo comprime con **gzip**.
4. Lo codifica en **base64** (doble: una porque es un Secret, otra interna).

Puedes mirar el payload (es educativo, no lo hagas en prod sin razón):

```bash
kubectl get secret -n ingress-nginx sh.helm.release.v1.ingress-nginx.v1 \
  -o jsonpath='{.data.release}' | base64 -d | base64 -d | gzip -d | jq '.name, .version, .info.status'
```

Alternativas (controladas por `HELM_DRIVER` o `--driver`):

- `configmap` (legado, pre-Helm 3 default).
- `sql` (postgres) — para operadores grandes que gestionan cientos de releases.
- `secret` (default y recomendado).

### Qué pasa si borras el Secret

Si corres `kubectl delete secret sh.helm.release.v1.ingress-nginx.v3 -n ingress-nginx`:

- Para Helm, la revisión 3 deja de existir. `helm history` ya no la muestra.
- Si era la única `deployed`, el release aparece como si estuviera en el estado de la última revisión que quede (una `superseded` pasa a ser lo que Helm cree que está "vivo", lo cual puede divergir del cluster real).
- Si borras **todos** los Secrets `sh.helm.release.v1.<release>.*`, Helm cree que el release no existe. Los recursos en el cluster siguen vivos (son objetos K8s normales), pero quedan **huérfanos** desde el punto de vista de Helm. No puedes `helm upgrade` ni `helm rollback`; el único camino limpio es `helm install` con el mismo nombre, pero eso falla porque los recursos ya existen con otro `managedFields` / annotations.

**Mantra**: los Secrets `sh.helm.release.v1.*` son infraestructura. Trátalos como etcd — no los borres a mano.

---

## 10. Dry-run y debugging

Antes de un upgrade dudoso:

```bash
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.16.2 -f values.yaml \
  --dry-run --debug | less
```

Lo que verás:

- Los valores computados (`COMPUTED VALUES:`).
- Los manifests renderizados (`HOOKS:` + `MANIFEST:`).
- El resumen del release que *se habría* creado.

Esto es la mejor forma de responder "¿qué me va a cambiar este upgrade?" sin impactar el cluster.

Combinación poderosa para diff manual:

```bash
helm get manifest cert-manager -n cert-manager > /tmp/before.yaml
helm upgrade cert-manager jetstack/cert-manager --version v1.16.2 \
  -f values.yaml --dry-run | sed -n '/^---/,$p' > /tmp/after.yaml
diff -u /tmp/before.yaml /tmp/after.yaml
```

Hay un plugin oficial `helm-diff` (`helm plugin install https://github.com/databus23/helm-diff`) que hace exactamente esto con mejor UX.

---

## 11. Convenciones de nombres y namespaces

Para no acabar con un `helm list -A` ilegible:

- **Un release = un propósito claro**. `nginx-public` y `nginx-admin` es mejor que `nginx-1` y `nginx-2`.
- **Un namespace por release de software base**: `ingress-nginx` en `ingress-nginx`, `cert-manager` en `cert-manager`, `prometheus` en `monitoring`, etc.
- **Los nombres de release deben ser DNS-1123** (minúsculas, dígitos, `-`, 53 chars máx — por el límite del label `app.kubernetes.io/instance`).
- **No pongas la versión en el release name** (`cert-manager-v116`). La versión está en el chart; el release name es la *identidad* del release.
- Para apps internas en varios entornos, el nombre del release suele ser `<app>-<env>` o el entorno se infiere del namespace (`foo` en `foo-prod`).

Y para el `--namespace` del CLI: aprende a usar `kubens` o `kubectl config set-context --current --namespace=X`; nunca escribas el namespace en una variable global del shell que luego olvides.

---

## 12. Checklist operativo (lo que llevas a producción)

Resumen portátil que puedes imprimir y pegar al monitor.

- `helm repo update` *antes* de cualquier install/upgrade reproducible.
- Nunca `install`/`upgrade` sin `--version` explícito en pipelines.
- `helm upgrade --install` siempre, nunca `install || upgrade`.
- `-f values-<env>.yaml` como fuente de verdad, `--set` solo para datos del pipeline.
- `--namespace` + `--create-namespace` explícitos; nunca dependas de `default`.
- `--wait --timeout 10m` en CI/CD; sin esto, `helm` da éxito mientras los Pods aún arrancan.
- `--atomic` cuando el riesgo justifica el rollback automático (lo veremos en `helm-07`).
- Antes de `uninstall`: ¿hay PVCs que preservar? ¿hay CRDs que compartirás con el siguiente release?
- Después de un upgrade raro: `helm history` + `helm get manifest --revision N` para forense.
- Jamás `kubectl delete secret sh.helm.release.v1.*`. Jamás.

---

## Preguntas para auto-evaluación

1. Tienes un release `foo` con historia `1 (superseded), 2 (deployed)`. Corres `helm rollback foo 1`. ¿Cuál es el nuevo `helm history`? ¿Cuál es el `deployed`?
2. Borras `kubectl delete secret sh.helm.release.v1.foo.v2 -n foo`. ¿Qué muestra `helm history foo -n foo`? ¿Qué muestra `helm status foo`? ¿Y `kubectl get deploy -n foo`?
3. En un pipeline corres `helm upgrade --install foo chart -f prod.yaml` y luego, por error, `helm upgrade --install foo chart` (sin `-f`). ¿Qué pasa con los valores que tenía `prod.yaml`?
4. ¿Por qué `--version` es más importante en Helm que en un `apt install`?
5. Diseña un workflow de 10 líneas que: añada el repo, instale `cert-manager` v1.16.2 con `--create-namespace`, verifique con `helm status`, haga upgrade a v1.16.3, muestre `helm history`, y rollback a la revisión 1.
