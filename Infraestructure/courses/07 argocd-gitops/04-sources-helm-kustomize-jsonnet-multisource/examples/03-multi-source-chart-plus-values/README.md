# Ejemplo 03 — Multi-source: chart upstream + values en otro repo

Patrón canónico cuando quieres usar un chart público (Bitnami, Prometheus, ingress-nginx, cert-manager) **sin forkearlo** y **sin wrapper chart**, manteniendo tus `values.yaml` en tu propio repo.

## El patrón

```yaml
spec:
  sources:
    - repoURL: https://charts.bitnami.com/bitnami    # chart upstream
      chart: postgresql
      targetRevision: 16.0.3                         # pin del chart (inmutable)
      helm:
        releaseName: pg
        valueFiles:
          - $values/apps/postgresql/values.yaml      # viene del segundo source

    - repoURL: https://github.com/acme/infra         # tu repo con los values
      targetRevision: main                           # mutable: aquí se promociona
      ref: values                                    # alias usado en $values arriba
```

Dos cosas que tienen que coincidir:

- `ref: values` ← → `$values/...` (mismo nombre).
- El `path` dentro del `valueFile` es **relativo a la raíz del repo de values**, no al chart.

## Archivos

- [`application.yaml`](application.yaml) — multi-source Application lista para adaptar.
- [`values.yaml`](values.yaml) — ejemplo de archivo que viviría en el repo de values.

## Validación de sintaxis

```bash
python3 -c "import yaml,sys; list(yaml.safe_load_all(open('application.yaml'))); print('OK: valid YAML')"
python3 -c "import yaml; yaml.safe_load(open('values.yaml')); print('OK: valid values')"
```

## Reglas finas

1. El source con `ref:` **no genera manifests**. Es solo un contenedor de archivos.
2. Si tu versión de Argo CD < 2.6, multi-source no está GA. Verifica con `argocd version`.
3. Dos `targetRevision` a seguir: pin el del chart (SemVer), mueve el del repo de values para promocionar.
4. `argocd app get` muestra los dos sources — si uno está out-of-sync, el status refleja ambos.

## Si tienes Argo CD

```bash
# Edita repoURL del segundo source para apuntar a tu repo real.
kubectl apply -n argocd -f application.yaml
argocd app sync pg-multi
argocd app get pg-multi -o yaml | yq '.spec.sources'
```

## Limpieza

Nada local que limpiar (es documental).
