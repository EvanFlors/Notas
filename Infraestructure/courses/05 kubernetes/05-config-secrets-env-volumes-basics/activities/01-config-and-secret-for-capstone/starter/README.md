# Starter — k8s-05-01

Este starter trae **solo el script de la app** (`app.py`). Tu trabajo es:

1. Crear el ConfigMap `app-config` y el Secret `db` en el namespace `capstone` (ver README de la actividad).
2. Escribir el Deployment `app` (puedes basarte en `../solution/deployment.yaml`, pero intenta primero sin mirar).
3. Aplicar todo y validar.

El `app.py` está pensado para ejecutarse **inline** en el `args:` del container, pero puedes también montarlo como ConfigMap si prefieres.

Lee el script antes de pegarlo: entiende qué espera leer.
