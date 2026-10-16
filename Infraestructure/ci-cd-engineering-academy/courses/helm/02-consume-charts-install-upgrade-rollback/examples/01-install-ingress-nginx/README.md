# Ejemplo 01 — `helm install` real: ingress-nginx

## Concepto que demuestra

Qué pasa cuando corres `helm install`: cómo se añade el repo, cómo se renderiza el chart, qué recursos aparecen en el cluster, y **dónde queda almacenado el estado del release** (el Secret `sh.helm.release.v1.*`).

## Contexto

Usamos `ingress-nginx` porque es un chart maduro, popular y mantiene el mismo "shape" año tras año. Lo instalamos con `--namespace`, `--create-namespace` y `--version` explícitos — como lo harías en producción. Trabajamos en `/tmp/helm-02-ex01/`.

## Objetivo

Al terminar sabrás:

- Añadir y refrescar un repo HTTP de charts.
- Instalar un chart con una versión pinneada y en su propio namespace.
- Leer el `NOTES.txt` del chart (`helm get notes`).
- Encontrar el Secret donde Helm guarda el estado del release y decodificarlo.

## Prerrequisitos

- Un cluster local funcional (kind recomendado; `kubectl get nodes` responde Ready).
- `helm` ≥ 3.14, `kubectl` ≥ 1.28.
- Acceso a internet (para descargar el chart).

## Ejecución

Copia-pega bloque a bloque. **Lee la salida antes de pasar al siguiente.**

```bash
# 0. Entorno limpio.
mkdir -p /tmp/helm-02-ex01 && cd /tmp/helm-02-ex01

# 1. Repo.
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update ingress-nginx
#   Lo que pasó:
#     - helm bajó el index.yaml a ~/.cache/helm/repository/ (o la ruta XDG equivalente).
#     - A partir de ahora 'helm search repo ingress-nginx/ingress-nginx --versions'
#       te lista todas las versiones conocidas (del cache local).

# 2. Explorar el chart (sin instalar).
helm search repo ingress-nginx/ingress-nginx --versions | head -5
helm show chart ingress-nginx/ingress-nginx --version 4.11.3 | head -20
helm show values ingress-nginx/ingress-nginx --version 4.11.3 | head -40
#   'show values' imprime los defaults del chart — tu "contrato" para los overrides.

# 3. Dry-run: ver qué se instalaría SIN tocar el cluster.
helm install ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --version 4.11.3 \
  --set controller.service.type=ClusterIP \
  --dry-run --debug 2>&1 | sed -n '/^MANIFEST/,/^NOTES/p' | head -40

# 4. Install real.
helm install ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --version 4.11.3 \
  --set controller.service.type=ClusterIP \
  --wait --timeout 5m
#   --wait: no da OK hasta que todos los recursos estén Ready.
#   --create-namespace: crea 'ingress-nginx' si no existe.

# 5. Verificación básica.
helm list -n ingress-nginx
helm status ingress -n ingress-nginx
kubectl get all -n ingress-nginx

# 6. El NOTES.txt que el chart imprimió al final del install.
helm get notes ingress -n ingress-nginx

# 7. Los VALORES EFECTIVOS del release.
helm get values ingress -n ingress-nginx          # solo los que pasaste
helm get values ingress -n ingress-nginx --all | head -40   # con defaults

# 8. El MANIFEST final que se aplicó al cluster.
helm get manifest ingress -n ingress-nginx | head -30

# 9. AHORA, lo importante: dónde está el estado del release.
kubectl get secret -n ingress-nginx -l owner=helm
#   Verás: sh.helm.release.v1.ingress.v1  (type: helm.sh/release.v1)
#   Esa es la revisión 1 del release 'ingress'. El payload está dentro.

# 10. (Opcional) peek al payload serializado.
#     release serializado -> JSON -> gzip -> base64 -> base64 (porque es Secret).
kubectl get secret -n ingress-nginx sh.helm.release.v1.ingress.v1 \
  -o jsonpath='{.data.release}' \
  | base64 -d | base64 -d | gzip -d \
  | python3 -c 'import sys, json; r = json.load(sys.stdin); print(r["name"], r["version"], r["info"]["status"])'
#   Imprime algo como: ingress 1 deployed
```

## Resultado esperado

- `helm list -n ingress-nginx` lista `ingress` con `STATUS=deployed` y `REVISION=1`.
- `helm status ingress -n ingress-nginx` muestra `STATUS: deployed`.
- `kubectl get deploy -n ingress-nginx` muestra el controller con `READY 1/1`.
- Existe el Secret `sh.helm.release.v1.ingress.v1` en el namespace `ingress-nginx`.
- El peek del paso 10 imprime `ingress 1 deployed`.

## Limpieza

```bash
helm uninstall ingress -n ingress-nginx
kubectl delete namespace ingress-nginx --ignore-not-found
rm -rf /tmp/helm-02-ex01
```

## Preguntas de reflexión

1. ¿Qué pasa si corres el `helm install` del paso 4 por segunda vez? ¿Y si cambias `install` por `upgrade --install`?
2. En el paso 9, ¿por qué el Secret es `type: helm.sh/release.v1` y no `Opaque`? ¿Lo encontrarías con `kubectl get secret` sin el label selector?
3. Si tras el install borras `sh.helm.release.v1.ingress.v1`, ¿qué devolverá `helm status ingress -n ingress-nginx`? ¿Y qué pasa con el Deployment del controller?
4. Si en lugar de `--version 4.11.3` omites `--version`, ¿qué versión instala Helm? ¿Es reproducible mañana?
