# Starter — aws-17-02-finops-dashboard-and-anomaly

## Qué contiene este starter

- `costs.csv` — 6 meses × 3 servicios de costes AWS atribuidos (sintético).
- `usage.csv` — mismas filas, con `mau` y `requests` por servicio y mes.
- `compute_unit_economics.py` — script Python stdlib que hace el join y detecta anomalías.

## Pasos

1. Prepara el directorio y copia los archivos:
   ```bash
   mkdir -p /tmp/aws-17-finops
   cp costs.csv usage.csv compute_unit_economics.py /tmp/aws-17-finops/
   cd /tmp/aws-17-finops
   ```
2. Ejecuta:
   ```bash
   python3 compute_unit_economics.py costs.csv usage.csv > unit_economics.csv
   ```
   Verás anomalías por `stderr` (si existen) y el CSV en `stdout`.
3. Escribe `FINOPS-REPORT.md` siguiendo las 5 secciones del `../README.md`.
4. Valida:
   ```bash
   bash <ruta-repo>/courses/aws/17-platform-finops-and-well-architected/activities/02-finops-dashboard-and-anomaly/tests/validate.sh /tmp/aws-17-finops
   ```

## Nota sobre el dataset

Es **sintético**. Un mes de un servicio tiene un `cost_per_req` elevado respecto a la mediana de ese servicio — el script lo marca como `ANOMALY`. Tu reporte debe recoger ese hallazgo con una hipótesis razonada.

**Ningún dato aquí es real** ni corresponde a cuentas AWS existentes.
