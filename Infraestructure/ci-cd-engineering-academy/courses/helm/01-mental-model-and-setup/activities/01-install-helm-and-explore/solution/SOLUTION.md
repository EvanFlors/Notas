# NOTES.md (reference) — helm-01-01

> Autoevaluación. **No** es una respuesta única — es *una* respuesta correcta y profesional. Las versiones exactas serán distintas en tu máquina.

## Helm version

```
version.BuildInfo{Version:"v3.14.0", GitCommit:"3fc9f4b2638e76f26739cd77c7017139be81d0ea", GitTreeState:"clean", GoVersion:"go1.21.5"}
```

Instalado vía `brew install helm` en macOS. En Linux probaría `curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash`.

## Helm env

```
HELM_BIN="helm"
HELM_CACHE_HOME="/Users/me/Library/Caches/helm"
HELM_CONFIG_HOME="/Users/me/Library/Preferences/helm"
HELM_DATA_HOME="/Users/me/Library/helm"
HELM_DEBUG="false"
HELM_KUBEAPISERVER=""
HELM_KUBEASGROUPS=""
HELM_KUBEASUSER=""
HELM_KUBECAFILE=""
HELM_KUBECONTEXT=""
HELM_KUBEINSECURE_SKIP_TLS_VERIFY="false"
HELM_KUBETLS_SERVER_NAME=""
HELM_KUBETOKEN=""
HELM_MAX_HISTORY="10"
HELM_NAMESPACE="default"
HELM_PLUGINS="/Users/me/Library/helm/plugins"
HELM_REGISTRY_CONFIG="/Users/me/Library/Preferences/helm/registry/config.json"
HELM_REPOSITORY_CACHE="/Users/me/Library/Caches/helm/repository"
HELM_REPOSITORY_CONFIG="/Users/me/Library/Preferences/helm/repositories.yaml"
```

**`HELM_REPOSITORY_CONFIG`** apunta al archivo YAML (`repositories.yaml`) donde Helm persiste los repos que has añadido con `helm repo add`. Si lo borras, pierdes la lista — tendrías que volver a añadir cada repo. No contiene secretos (los repos públicos se identifican solo por URL).

## Repository añadido

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm repo list
```

Salida:

```
NAME            URL
ingress-nginx   https://kubernetes.github.io/ingress-nginx
```

`helm repo update` descarga el `index.yaml` del repo al cache local (`HELM_REPOSITORY_CACHE`).

## Charts encontrados en Artifact Hub

Comandos usados: `helm search hub ingress-nginx`, `helm search hub cert-manager`, `helm search hub prometheus` (y en los repos locales: `helm search repo ingress-nginx --versions`).

| Chart | URL | Chart ver | App ver | Descripción |
|-------|-----|-----------|---------|-------------|
| ingress-nginx/ingress-nginx | <https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx> | 4.10.0 | 1.10.0 | Ingress controller for Kubernetes using NGINX |
| jetstack/cert-manager | <https://artifacthub.io/packages/helm/cert-manager/cert-manager> | v1.14.4 | v1.14.4 | Certificate automation for Kubernetes |
| prometheus-community/kube-prometheus-stack | <https://artifacthub.io/packages/helm/prometheus-community/kube-prometheus-stack> | 58.0.0 | v0.72.0 | Stack completo Prometheus + Grafana + Alertmanager |
| bitnami/postgresql | <https://artifacthub.io/packages/helm/bitnami/postgresql> | 15.0.0 | 16.2.0 | PostgreSQL packaged by Bitnami |
| argo/argo-cd | <https://artifacthub.io/packages/helm/argo/argo-cd> | 7.0.0 | v2.11.0 | GitOps continuous delivery for Kubernetes |
| external-secrets/external-secrets | <https://artifacthub.io/packages/helm/external-secrets-operator/external-secrets> | 0.9.19 | v0.9.19 | External Secrets Operator |

(Las versiones exactas cambian con el tiempo.)

## Metadata del chart ingress-nginx

Obtenido con `helm show chart ingress-nginx/ingress-nginx` (y además `helm show values` + `helm show readme` para la API y la documentación del autor).

```yaml
apiVersion: v2
appVersion: 1.10.0        # ← versión del BINARIO nginx empaquetado
description: Ingress controller for Kubernetes using NGINX as a reverse proxy and load balancer
home: https://github.com/kubernetes/ingress-nginx
kubeVersion: '>=1.21.0-0'
name: ingress-nginx
sources:
  - https://github.com/kubernetes/ingress-nginx
type: application
version: 4.10.0           # ← versión del CHART (puede cambiar sin cambiar appVersion)
```

**Clave:** `version: 4.10.0` es la versión del **chart** (plantilla); `appVersion: 1.10.0` es la versión del **software** (nginx). Son independientes: puedo publicar una nueva versión del chart (4.10.1) con el mismo `appVersion` si solo corrijo un helper, y viceversa.

## values.yaml como API

`values.yaml` es el **único punto por donde el consumidor del chart puede influir en el YAML renderizado**. Es, por tanto, la **API pública** del chart. Añadir, renombrar o eliminar una key sin bumpear la versión *major* rompe a los consumidores que la estaban pasando. Dos ejemplos del chart `ingress-nginx`:

- **`controller.replicaCount`** (int, default `1`): cuántas réplicas del Deployment del controller levantar. Lo tocaría en producción (3 mínimo, con PDB).
- **`controller.service.type`** (string, default `LoadBalancer`): tipo del Service del controller. En cloud managed suele quedarse `LoadBalancer`; en bare-metal se cambia a `NodePort` + `externalIPs`, o se usa `hostNetwork: true`.

Si el chart tiene `values.schema.json`, esta API queda **formalizada** (JSON Schema valida tipos y requeridos antes de renderizar). Sin schema, la API existe igual pero es solo documentación informal.

## Conclusión

Entorno listo: `helm` v3.14 instalado, repo `ingress-nginx` añadido, un chart popular descrito (metadata + 450+ líneas de `values.yaml`). El flujo exploratorio (`search hub → search repo → show chart → show values → show readme`) es la **lectura obligatoria** antes de considerar `helm install`. Nada tocó un cluster.
