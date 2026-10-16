# Starter — helm-03-02-add-values-schema

Esta actividad es **independent**: no se te da el schema. Trabaja sobre el
chart de la actividad anterior.

```bash
# Si ya tienes el chart:
cd /tmp/helm-03-01/fastapi-app

# Si no:
bash <REPO>/courses/helm/03-chart-anatomy/activities/01-chart-for-fastapi/solution/run-solution.sh
cd /tmp/helm-03-01/fastapi-app

# Crea aquí values.schema.json con tu propio diseño.
```

El validator (`tests/validate.sh`) espera el schema en
`$CHART_DIR/values.schema.json` (default: `/tmp/helm-03-01/fastapi-app/values.schema.json`).
