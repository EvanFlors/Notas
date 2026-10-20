# Ejemplo 02 — Kustomize con override de imagen, prefix y labels

Un `Application` de Argo CD que apunta a un overlay Kustomize y usa `source.kustomize.images`, `namePrefix` y `commonLabels` desde el CR (no desde `kustomization.yaml`). Esto permite que el *mismo* overlay sirva a dos Applications distintas sin editarlo.

## Qué aprender aquí

- Diferencia entre poner `images:` en `kustomization.yaml` vs. en `spec.source.kustomize.images` del Application.
- Peligro de `commonLabels` sobre deployments existentes (selector es inmutable).
- Que `kustomize build` corre dentro del `repo-server` — se puede reproducir local.

## Estructura

```
.
├── application.yaml      # Application de Argo CD
├── base/                 # base reusable
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/dev/
    └── kustomization.yaml
```

## Validar

```bash
python3 -c "import yaml,sys; list(yaml.safe_load_all(open('application.yaml'))); print('OK: valid YAML')"
```

## Reproducir el rendering local (sin cluster)

```bash
bash build.sh
```

Escribe el YAML a `/tmp/argo-ex02-rendered.yaml`. Es lo que vería el `application-controller`.

## Si tienes Argo CD

```bash
# Primero sube este directorio a un repo accesible por Argo CD y
# ajusta spec.source.repoURL + path en application.yaml.
kubectl apply -n argocd -f application.yaml
argocd app sync kustomize-example
```

## Limpieza

```bash
rm -f /tmp/argo-ex02-rendered.yaml
```
