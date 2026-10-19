# Actividad 03 — Unit economics sobre export de Billing

## 1. Identificación

- **ID:** `gcp-10-03-finops-unit-economics`
- **Tecnología:** `gcp`
- **Módulo:** `gcp-10-devsecops-platform-wif-binauthz-finops`
- **Dificultad:** advanced
- **Duración estimada:** 80–100 min
- **Tipo:** independent

## 2. Contexto

Finance pregunta cada mes "¿cuánto nos cuesta `checkout`?" y Platform responde con la UI de Billing. La UI es útil para ver gasto total — es inútil para responder "¿cuánto nos cuesta **cada request** que servimos?" o "¿cuánto nos cuesta **cada customer activo mensual (MAC)**?".

Esas dos preguntas son **unit economics**. Son el salto de "sé qué cuesta la nube" a "sé qué cuesta una unidad de valor entregada". El dato normalmente vive en el **export de Billing a BigQuery**, cruzado con métricas de negocio.

Aquí vamos a trabajar contra un **CSV sintético** que imita el schema de ese export, sin tocar GCP ni BigQuery. Escribirás dos scripts Python que calculan los KPIs y un documento resumen.

**Importante**: nada se ejecuta contra GCP. Ningún coste.

## 3. Objetivos

- Parsear el CSV sintético respetando el signo de `credits`.
- Calcular coste **neto** por workload (filtrando por `label_workload`).
- Calcular coste por request y por MAC para el workload `checkout`.
- Documentar interpretación de los KPIs.

## 4. Prerrequisitos

- `gcp-01` (modelo de projects y billing).
- Herramientas: `bash`, `python3` (standard library, sin pandas).

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/gcp-10-03-finops
cp starter/synthetic-billing.csv starter/business-metrics.csv /tmp/gcp-10-03-finops/
cd /tmp/gcp-10-03-finops
```

### 5.2 Escribe `cost_per_request.py`

- Lee los dos CSV (billing y business metrics).
- Suma `cost + credits` por fila para todas las filas donde `label_workload == 'checkout'` e `invoice_month == '202610'` → coste neto del workload.
- Divide entre `requests_served` del workload `checkout` para el mes `202610`.
- Imprime **solo** el float con 6 decimales (p. ej. `0.002280`).

Firma: `python3 cost_per_request.py <billing_csv> <business_csv>`.

### 5.3 Escribe `cost_per_customer.py`

- Idéntico pero divide entre `active_customers`.
- Imprime float con 6 decimales (p. ej. `4.560000`).

### 5.4 Escribe `README-UNIT-ECONOMICS.md`

Secciones obligatorias (el validador las busca):

- `# Unit economics` (o similar en el H1).
- `## Metodología` o `## Methodology`.
- `## Cost per request`.
- `## Cost per MAC` o `## Cost per customer`.
- `## Interpretación` o `## Interpretation`.

Contenido mínimo:

- Explica qué es "coste neto" (y por qué sumar `credits`).
- Muestra los números concretos obtenidos de tus scripts.
- Describe **al menos un sesgo** del cálculo (p. ej. "atribuimos todo el coste de la DB a checkout aunque la comparta con otro workload") y cómo corregirlo.
- Menciona cómo este cálculo escala a BigQuery (el CSV es solo un stand-in).

> **No llames al archivo `ANALYSIS.md`.** Usa `README-UNIT-ECONOMICS.md`.

### 5.5 Entregables

```
/tmp/gcp-10-03-finops/
├── synthetic-billing.csv   (copiado del starter)
├── business-metrics.csv    (copiado del starter)
├── cost_per_request.py
├── cost_per_customer.py
└── README-UNIT-ECONOMICS.md
```

## 6. Validación

```bash
bash tests/validate.sh /tmp/gcp-10-03-finops
```

El validador:

1. Comprueba que los archivos existen.
2. Ejecuta cada script con los CSVs y verifica el número (tolerancia ±1e-5).
3. Comprueba las secciones del README.

## 7. Preguntas de reflexión

1. ¿Por qué sumar `credits` cambia la foto 10–30 %?
2. Si `analytics` empieza a servir dashboards de clientes, ¿tus KPIs cambian o siguen igual? ¿Cómo mides su unit economics?
3. ¿Qué labels adicionales facilitarían el análisis (p. ej. `tier`, `customer-segment`)?
4. ¿Cómo integrarías este cálculo en el ritual mensual de FinOps (quién lo corre, dónde publica el número, qué dispara una alerta)?

## 8. Limpieza

```bash
rm -rf /tmp/gcp-10-03-finops
```
