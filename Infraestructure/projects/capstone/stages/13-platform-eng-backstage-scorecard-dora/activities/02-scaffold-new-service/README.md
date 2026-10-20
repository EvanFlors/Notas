# Actividad 02 — Scaffoldear un microservicio nuevo

Usa el template `fastapi-microservice` del stage para generar un servicio
nuevo, `svc-reports`, con un `catalog-info.yaml` que nace limpio.

## Pasos

1. Crea `/tmp/cap-13-02/` y copia dentro `starter/render.py` + el skeleton
   del template (`../../backstage/template-microservice/skeleton/`).
2. Ejecuta el renderer con los siguientes `values`:

   ```bash
   python3 /tmp/cap-13-02/render.py \
     --src ../../backstage/template-microservice/skeleton \
     --dst /tmp/cap-13-02/svc-reports \
     --name svc-reports \
     --description "Reporting service for capstone" \
     --owner team-capstone \
     --tier tier-2
   ```

3. Verifica a mano que `/tmp/cap-13-02/svc-reports/catalog-info.yaml`
   referencia `name: svc-reports`, `owner: team-capstone`, `tier: tier-2`.
4. Corre `evaluate.py` del stage pasandole el catalog recien generado
   y confirma que `svc-reports` queda en nivel **bronze** (porque trae
   owner pero sin slo_url / runbook_url / etc.).

## Entregable

- Directorio `/tmp/cap-13-02/svc-reports/` con `catalog-info.yaml` renderizado
  (sin `${{ ... }}` sin resolver) y `app/main.py` referenciando el nuevo
  servicio.

## Validar

```bash
bash tests/validate.sh /tmp/cap-13-02
```
