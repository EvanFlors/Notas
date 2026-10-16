# Starter — plat-10-01-scorecard-for-capstone

## Qué hay aquí

- `catalog/` — 5 servicios sintéticos del "capstone" como JSON. Cada archivo representa lo que, en Backstage real, serían los facts persistidos tras pasar por los collectors.
- `scripts/evaluate.py` — evaluador local en Python 3. Lee tu `scorecard.yaml` y el catálogo, aplica las reglas y produce `results.json` + `REPORT.md`.
- `scorecard.yaml.template` — plantilla con los 8 chequeos canónicos ya listos. Cópialo a `scorecard.yaml` y edítalo para dejar entre **5 y 8** chequeos.

## Flujo esperado

```bash
mkdir -p /tmp/plat-10-scorecard
cp -R . /tmp/plat-10-scorecard/     # desde el directorio del starter
cd /tmp/plat-10-scorecard

cp scorecard.yaml.template scorecard.yaml
# edita scorecard.yaml hasta tener entre 5 y 8 chequeos

python3 scripts/evaluate.py --scorecard scorecard.yaml --catalog catalog/ --out .

# produce results.json y REPORT.md
# luego escribe NOTES.md a mano con las 3 secciones (A, B, C)

bash <ruta-repo>/courses/platform-engineering/10-scorecards-and-service-maturity/activities/01-scorecard-for-capstone/tests/validate.sh /tmp/plat-10-scorecard
```

## Si `python3` o `pyyaml` no están disponibles

El validador detecta la ausencia y marca la parte de ejecución como `SKIP`. La actividad se puede completar leyendo el starter y entregando `scorecard.yaml` + `NOTES.md` a mano (sin `results.json`/`REPORT.md`). En ese caso el validador cuenta como OK la parte estructural y como SKIP la de ejecución.
