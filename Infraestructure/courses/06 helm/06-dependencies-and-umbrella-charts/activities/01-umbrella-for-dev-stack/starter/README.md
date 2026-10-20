# Starter — helm-06-01

Chart `fastapi-app` mínimo **sin dependencias**. Tu tarea (ver `../README.md`):

1. Declarar `bitnami/postgresql` como dependencia condicional.
2. Generar `Chart.lock`.
3. Crear `values-dev.yaml` y `values-prod.yaml`.

Para empezar:

```bash
cd /tmp
rm -rf helm06-act01
mkdir helm06-act01 && cd helm06-act01
cp -R <ruta-starter>/fastapi-app .
cd fastapi-app
```

Luego sigue las instrucciones de la actividad.
