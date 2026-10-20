# Ejemplo 03 — Post-renderer con Kustomize

Un chart mínimo (`my-chart`) + un post-renderer que mete un sidecar vía Kustomize **sin tocar los templates del chart**. Es la vía oficial para parchear charts de terceros cuando `values` no llega.

## Prerrequisitos

- `helm` ≥ 3.13
- `kubectl` ≥ 1.28 (traemos `kustomize` embebido vía `kubectl kustomize`). Si tienes `kustomize` standalone también vale.

```bash
helm version --short
kubectl kustomize --help | head -1
```

## Qué hay aquí

```
examples/03-post-renderer-with-kustomize/
├── my-chart/                 (chart mínimo con un Deployment)
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/deployment.yaml
├── kustomization.yaml        (overlay que añade un label y un patch)
├── patch.yaml                (inyecta un sidecar via strategic merge)
├── kustomize-postrender.sh   (post-renderer: stdin -> kustomize -> stdout)
└── run.sh                    (smoke script)
```

## Pasos

```bash
cd /Users/efloresp06/Desktop/Courses/Python/Notas/Infraestructure/ci-cd-engineering-academy/courses/helm/10-platform-patterns-library-charts-argo-flux-and-kustomize-boundary/examples/03-post-renderer-with-kustomize

# 1. Render puro — sin post-renderer. No hay sidecar, no hay label extra.
helm template demo ./my-chart

# 2. Render pipado — `helm template` seguido por `kustomize build`.
#    Es el "patron 1" de la lección: pipe de shell.
helm template demo ./my-chart > /tmp/helm-10-ex03-base.yaml
bash kustomize-postrender.sh < /tmp/helm-10-ex03-base.yaml

# 3. Render con --post-renderer — vía oficial.
#    Nota: Helm 3 acepta `--post-renderer /ruta/al/script`.
#    Helm 4 cambió el contrato: `--post-renderer` espera el nombre de un
#    plugin tipo `postrenderer/v1` instalado via `helm plugin install`.
#    Para la lección y los ejemplos nos quedamos con el patrón (a) — pipe —
#    que funciona con cualquier versión y es idéntico semánticamente.
# Helm 3:
#   chmod +x kustomize-postrender.sh
#   helm template demo ./my-chart --post-renderer "$(pwd)/kustomize-postrender.sh"
# Helm 4:
#   helm plugin install https://github.com/.../helm-postrender-kustomize   # ejemplo
#   helm template demo ./my-chart --post-renderer kustomize

# 4. Smoke script integral (usa el pipe que funciona en ambos Helm 3 y 4)
bash run.sh
```

## Lectura mental

- Un **post-renderer** es solo un binario que lee YAML por stdin y escribe YAML por stdout. Exit 0 = Helm sigue; exit != 0 = Helm aborta.
- `kustomize-postrender.sh` copia el stdin a disco (porque `kustomize build` quiere un directorio) y corre `kubectl kustomize .` en ese directorio.
- Esto permite **patches corporativos uniformes** sin tocar los charts upstream. Útil para charts de terceros (ingress-nginx, cert-manager) donde el override deseado no es un `value` expuesto.

## Qué comprueba el smoke

- Que el output *sin* post-renderer **no** contiene el sidecar.
- Que el output *con* post-renderer **sí** contiene el sidecar y el label corporativo.

## Limpieza

```bash
rm -f /tmp/helm-10-ex03-base.yaml
rm -rf /tmp/helm-10-ex03-work
```
