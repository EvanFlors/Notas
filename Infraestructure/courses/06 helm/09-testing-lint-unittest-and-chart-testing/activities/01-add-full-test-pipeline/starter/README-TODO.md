# TODO — pipeline de testing

Partes a añadir (en orden):

1. `charts/demo-app/tests/*_test.yaml` con al menos 3 tests `helm-unittest`.
2. `ct.yaml` en el root con `chart-dirs: [charts]` y `target-branch: main`.
3. `.github/workflows/chart-ci.yaml` con 3 jobs: `lint`, `unittest`, `install` (matriz ≥ 2 K8s).
4. Sección `## Supported Kubernetes versions` en `charts/demo-app/README.md`.

Valida con:

```bash
bash tests/validate.sh /tmp/helm-09-01
```
