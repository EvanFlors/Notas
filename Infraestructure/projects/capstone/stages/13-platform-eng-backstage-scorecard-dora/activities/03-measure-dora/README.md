# Actividad 03 — Reparar events.json y clasificar en DORA

El `starter/events.broken.json` tiene varios problemas. Tu trabajo es
dejarlo tal que `compute_dora.py` lo procese y clasifique `capstone-app`
en un bucket consistente.

## Fallos sembrados (al menos)

- Un trailing comma rompe el JSON (invalido).
- Una fecha usa `/` en vez de `-` (no es ISO 8601).
- Un `deploy` apunta a un `commit_sha` inexistente (lead time no computa).
- Un `incident` apunta a un `caused_by_deploy_id` que no existe.

## Pasos

1. Copia `starter/events.broken.json` a `/tmp/cap-13-03/events.json`.
2. Repara el JSON hasta que `python3 -c "import json; json.load(open('/tmp/cap-13-03/events.json'))"` salga sin error.
3. Corrige las fechas no ISO (`YYYY-MM-DDTHH:MM:SSZ`).
4. Alinea los `commit_sha` entre `commit_merged` y `deploy`.
5. Alinea los `caused_by_deploy_id` entre `deploy` e `incident`.
6. Corre:

   ```bash
   python3 ../../backstage/dora/compute_dora.py /tmp/cap-13-03/events.json \
     --service capstone-app --json > /tmp/cap-13-03/report.json
   ```

## Entregable

- `/tmp/cap-13-03/events.json` valido con al menos **3 deploys exitosos**
  de `capstone-app` y **1 incident** con `caused_by_deploy_id` existente.
- `/tmp/cap-13-03/report.json` con `bucket` en `{ELITE,HIGH,MEDIUM,LOW}`.

## Validar

```bash
bash tests/validate.sh /tmp/cap-13-03
```
