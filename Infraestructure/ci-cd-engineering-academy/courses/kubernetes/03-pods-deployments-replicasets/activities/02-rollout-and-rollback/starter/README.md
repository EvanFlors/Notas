# Starter — k8s-03-02-rollout-and-rollback

Es una actividad **independiente**: no se incluye YAML preparado.

Trabaja en `/tmp/k8s-03-02/`:

```bash
mkdir -p /tmp/k8s-03-02 && cd /tmp/k8s-03-02
kubectl create namespace k8s-03-02 --dry-run=client -o yaml | kubectl apply -f -
```

Objetivos verificables al final (ver `README.md` del enunciado):

- Deployment `rollout-demo` en namespace `k8s-03-02`.
- Imagen actual del contenedor `web`: `nginx:1.26-alpine`.
- Historial con ≥ 4 revisiones.
- El estado final debe venir de un `kubectl rollout undo --to-revision=N`.

Si no sabes por dónde empezar, mira `examples/03-undo-with-rollout/` del módulo.

**No consultes `solution/` hasta haber intentado y validado con tus manos.**
