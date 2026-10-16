# Starter — helm-03-01-chart-for-fastapi

El workspace real de la actividad es `/tmp/helm-03-01/` (ver README.md
principal). Este directorio es solo un marcador: **no necesitas copiarlo**.

```bash
# Punto de entrada:
rm -rf /tmp/helm-03-01 && mkdir -p /tmp/helm-03-01 && cd /tmp/helm-03-01
helm create fastapi-app
# Sigue las instrucciones.
```

El validator (`tests/validate.sh`) toma `CHART_DIR` como variable de entorno
o primer argumento, con default `/tmp/helm-03-01/fastapi-app`.
