# REFERENCE — cap-13-03-measure-dora

## Los 4 fallos sembrados y su fix

| # | Sintoma | Causa | Fix |
|---|---|---|---|
| 1 | `json.load` lanza `JSONDecodeError` | Trailing comma antes del `]` | Quitar la coma final del ultimo objeto. |
| 2 | `parse_iso` falla con `ValueError` | `2026/10/05 10:00:00` no es ISO 8601 | Cambiar a `2026-10-05T10:00:00Z`. |
| 3 | Lead time del deploy-002 no se cuenta | `commit_sha: "cc002-TYPO"` no existe en commits | Corregir el sha a `cc002`. |
| 4 | CFR = 0 pese a tener un `incident` | `caused_by_deploy_id` apunta a un id inexistente | Apuntarlo a `dep-003`. |

## Reporte esperado tras el fix

Con los 3 deploys exitosos de `capstone-app` (10, 5, 10 dias atras aprox.)
y 1 incident vinculado a `dep-003`, con ventana por defecto de 28 dias:

- Deployment Frequency ~= 0.11/dia (3 / 28).
- Lead Time median ~= 1 h.
- CFR = 1/3 ~= 0.33.
- FDRT median = 30 min = 0.5 h.
- Bucket = `LOW` por el CFR alto (> 0.30 es LOW en el umbral del script).

> Nota: el bucket depende de la ventana. Si pasas `--window-days 14`, la
> frecuencia sube y puede saltar a `MEDIUM`.

## Que *no* refactorizar

- No "ajustes" los umbrales de `classify_bucket` para que capstone-app
  "suba" a HIGH. El punto de DORA es ser incomodo cuando el servicio no
  llega — no es un juguete de autobombo.
- No borres el `incident`: un CFR alto en un servicio joven con pocos
  deploys es *verdad*, no ruido. Se repara con mas pruebas pre-deploy,
  no con menos eventos en el reporte.

## Punto a repetir

> DORA se calcula sobre **eventos reales**. Si editas los eventos para
> maquillar el reporte, estas midiendo al editor, no al servicio.
