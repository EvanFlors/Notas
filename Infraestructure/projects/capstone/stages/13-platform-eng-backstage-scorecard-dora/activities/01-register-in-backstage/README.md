# Actividad 01 — Registrar la app FastAPI en Backstage

Escribe el `catalog-info.yaml` del capstone y deja al Scorecard un contrato
limpio para evaluarlo.

## Pasos

1. Crea `/tmp/cap-13-01/` y copia `starter/catalog-info.yaml` dentro.
2. Edita el archivo para que contenga **4 documentos YAML** separados por `---`:
   - `Component` con `metadata.name: capstone-app`.
   - `API` con `metadata.name: capstone-api`.
   - `Resource` con `metadata.name: capstone-db`.
   - `System` con `metadata.name: capstone`.
3. En el `Component`, anota como mínimo: `slo_url`, `runbook_url`,
   `oncall_rotation`, `image_signed`, `cves_critical`, `last_deploy_days`,
   `k8s_psa`. Deben ser valores no vacios (strings dummy válidos).
4. Guarda el resultado en `/tmp/cap-13-01/catalog-info.yaml`.

## Entregable

- `/tmp/cap-13-01/catalog-info.yaml` con 4 docs y las 7 anotaciones del
  Scorecard presentes en el Component.

## Validar

```bash
bash tests/validate.sh /tmp/cap-13-01
```

Si no tienes `python3` + `PyYAML`, la validación hace SKIP y no falla.
