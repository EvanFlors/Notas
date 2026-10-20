# Actividad 02 — Dashboard FinOps con unit economics y anomalía

## 1. Identificación

- **ID:** `aws-17-02-finops-dashboard-and-anomaly`
- **Tecnología:** `aws`
- **Módulo:** `aws-17-platform-finops-and-well-architected`
- **Dificultad:** advanced
- **Duración estimada:** 90–120 min
- **Tipo:** mini-project

## 2. Contexto

El equipo FinOps acaba de recibir el export de **Cost & Usage Report (CUR)** en forma de CSV sintético, con **6 meses** de datos por `service` y `env`. Negocio adjunta las métricas de uso por servicio (MAU y requests mensuales). La pregunta:

> *"¿Cuánto cuesta cada MAU y cada request por servicio? ¿Hay algún mes raro que explicar?"*

Tu tarea: procesar los CSV con Python stdlib, calcular `$/MAU` y `$/req`, detectar el mes anómalo y escribir un reporte con acciones concretas.

**No** se usa `pandas`. Solo `csv`, `statistics` y `collections` de la stdlib. Esto deja claro que **FinOps no es un problema de big data**: cabe en memoria.

## 3. Objetivos

Al terminar deberías poder:

- Leer un CSV de costes y uno de uso y hacer el `join` por `(month, service)`.
- Calcular **`$/MAU`** y **`$/req`** por servicio por mes.
- Detectar un mes anómalo con una regla simple (p. ej. `>= media + 2*stdev` o `>= 1.5 × mediana`).
- Articular **acciones FinOps concretas** (rightsizing, Savings Plan, Spot, Graviton, revisar NAT, revisar data transfer).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md`, §3 (FinOps) y §4 (unit economics).
- Haber recorrido `../../examples/02-savings-plan-estimation/`.
- Python 3.9+ (solo stdlib).
- Herramientas: `bash`, `python3`, editor Markdown.

**Costos**: ninguno. Todo el trabajo es local con CSVs sintéticos.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/aws-17-finops
cd /tmp/aws-17-finops
```

### 5.2 Copiar los datos sintéticos

Desde la raíz del repo:

```bash
cp courses/aws/17-platform-finops-and-well-architected/activities/02-finops-dashboard-and-anomaly/starter/costs.csv /tmp/aws-17-finops/
cp courses/aws/17-platform-finops-and-well-architected/activities/02-finops-dashboard-and-anomaly/starter/usage.csv /tmp/aws-17-finops/
cp courses/aws/17-platform-finops-and-well-architected/activities/02-finops-dashboard-and-anomaly/starter/compute_unit_economics.py /tmp/aws-17-finops/
```

### 5.3 Formato de los datos

**`costs.csv`** (por mes, por servicio, con tag `env=prd`):

```
month,service,cost_usd
2025-05,checkout,4120.50
2025-05,catalog,2015.30
...
```

**`usage.csv`** (métricas de negocio alineadas al mismo mes y servicio):

```
month,service,mau,requests
2025-05,checkout,120000,8450000
2025-05,catalog,250000,15600000
...
```

Hay **6 meses** (`2025-05` a `2025-10`) y **3 servicios** (`checkout`, `catalog`, `search`).

> El dataset tiene un **mes anómalo plantado** en uno de los servicios. Tu análisis debe detectarlo.

### 5.4 Ejecutar el script base

```bash
cd /tmp/aws-17-finops
python3 compute_unit_economics.py costs.csv usage.csv > unit_economics.csv
```

El script produce `unit_economics.csv`:

```
month,service,cost_usd,mau,requests,cost_per_mau,cost_per_req
2025-05,checkout,4120.50,120000,8450000,0.034337,0.000488
...
```

También imprime a `stderr` las anomalías detectadas por servicio:

```
ANOMALY: service=checkout month=2025-08 cost_per_req=0.000912 (median=0.000497, ratio=1.83x)
```

### 5.5 Escribir `FINOPS-REPORT.md`

Con **5 secciones**:

#### Sección 1 — Resumen ejecutivo

2–3 párrafos. Qué se analizó, qué ventana, cuáles son los 2–3 hallazgos clave.

#### Sección 2 — Unit economics por servicio

Para cada servicio, una tabla con `month`, `cost_per_mau`, `cost_per_req`. Comenta la tendencia en 1 línea por servicio.

#### Sección 3 — Anomalía detectada

- Qué servicio, qué mes.
- Métrica usada para detectar (ratio vs mediana o z-score).
- **Hipótesis** de causas (al menos 3: p. ej. instancia mal dimensionada, NAT caro por mal diseño, data transfer cross-AZ, cold start de Lambda, query no indexada en RDS, snapshot runaway).
- **Qué métricas pedirías para confirmar** (CloudWatch, Container Insights, VPC Flow Logs, Performance Insights).

#### Sección 4 — Acciones FinOps priorizadas

**Al menos 5 acciones**, cada una con:

- Palanca (rightsizing / Savings Plan / RI / Spot / Graviton / data transfer / almacenamiento).
- Servicio al que aplica.
- Esfuerzo estimado (bajo / medio / alto).
- Ahorro estimado (banda, no cifra exacta).
- Dependencias (p. ej. "requiere game day", "requiere Compute Optimizer habilitado 2 semanas").

#### Sección 5 — Walkthrough de Cost Explorer (textual)

Describe en 8–10 pasos qué filtros, group-bys y vistas usarías en Cost Explorer para confirmar los hallazgos **si tuvieras acceso real** (no lo tienes; es textual).

### 5.6 Entregables

```
/tmp/aws-17-finops/
├── costs.csv                 (del starter)
├── usage.csv                 (del starter)
├── compute_unit_economics.py (del starter)
├── unit_economics.csv        (generado)
└── FINOPS-REPORT.md          (escrito por ti)
```

## 6. Resultado esperado

- `unit_economics.csv` existe y tiene las columnas requeridas.
- `FINOPS-REPORT.md` existe con las 5 secciones.
- El reporte **identifica el servicio y mes anómalos** y propone al menos 3 hipótesis.
- Al menos 5 acciones FinOps con palanca + ahorro + esfuerzo.
- `bash tests/validate.sh /tmp/aws-17-finops` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: el script corre sin error y genera el CSV; validador pasa.
- **Calidad**: la detección de anomalía usa una regla documentada (mediana o media+stdev), no "a ojo".
- **Reproducibilidad**: el reporte permite a otro ingeniero re-ejecutar el pipeline y llegar a lo mismo.
- **Realismo**: las acciones son concretas, con palanca y servicio, no genéricas ("optimizar costes").

## 8. Validación

```bash
bash tests/validate.sh /tmp/aws-17-finops
```

Comprueba estructura del CSV generado y las secciones del reporte. **No** evalúa semántica.

## 9. Preguntas de reflexión

1. ¿Por qué `$/MAU` puede bajar mientras `$/req` sube (o viceversa)? ¿Qué dice cada métrica?
2. Si la anomalía estuviera en `cost_per_mau` pero NO en `cost_per_req`, ¿qué cambió en el negocio y qué en la infra?
3. ¿Por qué un Savings Plan comprado antes de analizar unit economics puede empeorar la factura?
4. ¿Qué palancas aquí requieren cambio de código (no solo config) y cuáles no?
5. Si el equipo de datos no te da MAU exacto, ¿qué proxy usarías y qué sesgo introduces?

## 10. Extensiones

- Añade **forecast** del siguiente mes extrapolando los últimos 3 (promedio móvil simple).
- Añade detección de **cambio de régimen** (dos medias distintas antes/después del mes 4).
- Genera un **gráfico ASCII** por servicio en el reporte (barras simples por mes).
- Agrupa por **cost_center** si tuvieras el tag (reflexión: ¿cómo cambiaría el reporte?).

## 11. Limpieza

```bash
rm -rf /tmp/aws-17-finops
```

No hay procesos ni recursos AWS que destruir.
