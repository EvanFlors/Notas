# Ejemplo 02 — `helm upgrade -f values-prod.yaml`

## Concepto que demuestra

Qué pasa cuando corres `helm upgrade`: cómo se mezcla el nuevo values file con lo que había, qué revisión queda registrada en la historia, y cómo inspeccionar la diferencia entre revisiones.

## Contexto

Partimos de un `helm install` básico de `ingress-nginx`. Luego aplicamos un `values-prod.yaml` con cambios realistas (más réplicas, resources, podAntiAffinity). Trabajamos en `/tmp/helm-02-ex02/`.

## Objetivo

Al terminar sabrás:

- Mantener un `values.yaml` versionado y hacer upgrades reproducibles con `-f`.
- Leer `helm history` y entender qué significa `superseded` vs `deployed`.
- Comparar valores entre revisiones con `helm get values --revision N`.
- Entender por qué `helm upgrade --install` (el "idiom CI/CD") es un solo comando y no dos.

## Prerrequisitos

- Cluster local y repo `ingress-nginx` ya añadidos (o repite los pasos 1-2 del ejemplo 01).
- `helm` ≥ 3.14, `kubectl` ≥ 1.28.

## Ejecución

```bash
# 0. Entorno limpio.
mkdir -p /tmp/helm-02-ex02 && cd /tmp/helm-02-ex02

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
helm repo update ingress-nginx >/dev/null

# 1. Install inicial MINIMALISTA (una réplica, defaults).
helm upgrade --install nginx ingress-nginx/ingress-nginx \
  --namespace nginx-ex02 --create-namespace \
  --version 4.11.3 \
  --set controller.service.type=ClusterIP \
  --wait --timeout 5m

helm history nginx -n nginx-ex02
#   Debe haber UNA fila: revision 1, deployed.

# 2. Archivo de valores de "producción".
cat > /tmp/helm-02-ex02/values-prod.yaml <<'YAML'
controller:
  replicaCount: 2
  service:
    type: ClusterIP
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi
  podAnnotations:
    env: "production"
    managed-by: "helm"
YAML

# 3. UPGRADE con el values file.
helm upgrade --install nginx ingress-nginx/ingress-nginx \
  --namespace nginx-ex02 \
  --version 4.11.3 \
  -f /tmp/helm-02-ex02/values-prod.yaml \
  --wait --timeout 5m

helm history nginx -n nginx-ex02
#   Ahora hay DOS filas:
#     1: superseded (lo que había)
#     2: deployed   (lo que acabas de aplicar)

# 4. Verificar que las réplicas subieron a 2.
kubectl get deploy -n nginx-ex02 -o custom-columns=NAME:.metadata.name,DESIRED:.spec.replicas

# 5. Comparar VALORES entre revisiones.
helm get values nginx -n nginx-ex02 --revision 1
echo "---"
helm get values nginx -n nginx-ex02 --revision 2
#   Revision 1 solo tiene {controller.service.type: ClusterIP}.
#   Revision 2 tiene lo del values-prod.yaml.

# 6. Comparar MANIFESTS renderizados entre revisiones.
helm get manifest nginx -n nginx-ex02 --revision 1 > /tmp/helm-02-ex02/rev1.yaml
helm get manifest nginx -n nginx-ex02 --revision 2 > /tmp/helm-02-ex02/rev2.yaml
diff -u /tmp/helm-02-ex02/rev1.yaml /tmp/helm-02-ex02/rev2.yaml | head -40
#   El diff real que Helm envió al API server.

# 7. ¿Dónde están los Secrets de release ahora?
kubectl get secret -n nginx-ex02 -l owner=helm
#   sh.helm.release.v1.nginx.v1   (superseded)
#   sh.helm.release.v1.nginx.v2   (deployed)
```

## Resultado esperado

- `helm history nginx -n nginx-ex02` muestra 2 filas, revisión 2 en `deployed`.
- `kubectl get deploy -n nginx-ex02` muestra `DESIRED=2`.
- Existen DOS Secrets `sh.helm.release.v1.nginx.v{1,2}` en `nginx-ex02`.
- `diff` del paso 6 muestra las anotaciones `env: production` y `managed-by: helm` añadidas, además de `replicas: 2`.

## Limpieza

```bash
helm uninstall nginx -n nginx-ex02
kubectl delete namespace nginx-ex02 --ignore-not-found
rm -rf /tmp/helm-02-ex02
```

## Preguntas de reflexión

1. En el paso 3, si pasas también `--reuse-values` ¿qué pasaría con `controller.service.type` que estaba en el `--set` de la revisión 1? Haz el experimento comparando `helm get values --revision 2 --all`.
2. ¿Por qué `helm upgrade --install` (en vez de `helm install` y luego `helm upgrade`) es la convención en CI/CD? Imagina el pipeline corriendo por primera vez vs por centésima.
3. En el paso 6, el `diff` solo muestra las diferencias del manifest. ¿Por qué eso puede *no* capturar un cambio real? Pista: campos defaulteados por el API server.
4. Si en el `values-prod.yaml` haces un typo (`replicaCont: 2`), ¿Helm te lo detecta? ¿Qué chart tendría que haber escrito para que sí?
