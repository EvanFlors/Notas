# REFERENCE — gcp-10-03-finops-unit-economics

> Referencia razonada.

## Archivos de solución

- `cost_per_request.py` — script Python standard library (sin pandas).
- `cost_per_customer.py` — idéntico pero divide por `active_customers`.
- `README-UNIT-ECONOMICS.md` — resumen humano con metodología, resultados, sesgos.

## Números esperados (CSV del starter)

- Coste neto `checkout` 202610: **2280.00 EUR**.
- Requests: 1,000,000 → **cost per request = 0.002280 EUR**.
- MAC: 500 → **cost per customer = 4.560000 EUR**.

## Trampas comunes

1. Olvidar sumar `credits` → infla la cifra ~10 %.
2. Filtrar por `invoice_month` como int, no string. El export real usa string `YYYYMM`.
3. Dividir por `requests_served` cuando vale 0 (ocurre en workloads que no sirven HTTP, p. ej. `analytics`): el script debe salir con error, no imprimir `inf`.
4. Imprimir texto extra alrededor del número. El validador toma solo la última línea.
