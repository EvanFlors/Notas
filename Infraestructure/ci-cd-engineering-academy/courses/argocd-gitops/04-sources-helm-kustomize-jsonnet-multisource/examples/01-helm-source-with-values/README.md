# Ejemplo 01 — Helm source con `values`, `valueFiles` y `parameters`

Muestra un `Application` que apunta a un chart público (Bitnami `nginx`) y aplica configuración por los tres mecanismos: `valueFiles` (dentro del chart), `values` inline, y `parameters` (equivalente a `--set`).

## Qué aprender aquí

- Dónde se resuelven los `valueFiles` (relativos **al chart**, no a tu repo).
- Precedencia: `valueFiles` → `values` inline → `parameters`.
- Por qué `releaseName` es importante.
- Que no hay Secret `sh.helm.release.*`: lo verificamos con `kubectl`.

## Archivos

- [`application.yaml`](application.yaml) — el manifiesto a aplicar.
- [`render.sh`](render.sh) — reproduce localmente lo que haría el `repo-server`.

## Validar sintaxis sin cluster

```bash
python3 -c "import yaml,sys; list(yaml.safe_load_all(open('application.yaml'))); print('OK: valid YAML')"
```

## Reproducir el rendering localmente (sin Argo CD)

```bash
bash render.sh
```

Esto corre `helm template` con los mismos inputs y escribe el YAML a `/tmp/argo-ex01-rendered.yaml`. Es exactamente lo que vería el `application-controller`.

## Si tienes Argo CD en `kind`

```bash
kubectl apply -n argocd -f application.yaml
argocd app sync nginx-example
kubectl get all -n nginx-example

# Y para confirmar que Helm NO ve este release:
helm list -n nginx-example   # vacío
```

## Limpieza

```bash
kubectl delete -f application.yaml -n argocd --ignore-not-found
rm -f /tmp/argo-ex01-rendered.yaml
```
