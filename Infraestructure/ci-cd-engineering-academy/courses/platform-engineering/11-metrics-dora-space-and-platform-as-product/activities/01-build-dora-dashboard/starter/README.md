# Starter — plat-11-01-build-dora-dashboard

Scripts para la actividad. Pure Python stdlib.

## Archivos

- `generate_events.py` — genera `events.json` sintético para 2 servicios (checkout-api, legacy-billing) con perfiles distintos.
- `compute_dora.py` — calcula las 4 DORA metrics para un servicio dado.

## Pasos

```bash
mkdir -p /tmp/plat-11-dora
cd /tmp/plat-11-dora
cp <ruta-repo>/courses/platform-engineering/11-metrics-dora-space-and-platform-as-product/activities/01-build-dora-dashboard/starter/*.py .

# 1. Generar eventos
python3 generate_events.py --out events.json

# 2. Computar DORA por servicio
python3 compute_dora.py events.json --service checkout-api  > dora_checkout.txt
python3 compute_dora.py events.json --service legacy-billing > dora_billing.txt

# 3. Leer los dos .txt y escribir DORA.md con las 4 secciones (A, B, C, D)

# 4. Validar
bash <ruta-repo>/courses/platform-engineering/11-metrics-dora-space-and-platform-as-product/activities/01-build-dora-dashboard/tests/validate.sh /tmp/plat-11-dora
```

> **Importante:** el validador solo revisa estructura. La corrección conceptual la comparas tú con `../solution/REFERENCE.md` después de haber hecho tu propio análisis.

## Si falta `python3`

El validador degrada con `SKIP` las comprobaciones que requieren Python; aún así espera `events.json` y `DORA.md` que puedes generar en otra máquina si fuera necesario. En la práctica, `python3` ≥ 3.9 está disponible en Linux/macOS por defecto.
