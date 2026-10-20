# Actividad 02 — Estimación de costo: mantener Jenkins vs migrar

## 1. Identificación

- **ID:** `jk-01-02-jenkins-cost-estimate`
- **Tecnología:** `jenkins`
- **Módulo:** `jk-01-why-still-jenkins-and-when-not`
- **Dificultad:** beginner (fundamentos)
- **Duración estimada:** 50–70 min
- **Tipo:** independent (análisis financiero — independiente de la actividad 01)

## 2. Contexto

Las decisiones de tooling de CI/CD se defienden con **dinero y horas**, no con "me gusta más". Un ADR sin cifras es una opinión; con cifras es una propuesta. Esta actividad entrena el reflejo de **cuantificar** mantener vs migrar antes de recomendar.

Escenario: **Nordhaus Insurance** (mismo del `01`, pero puedes resolver esta actividad en frío sin haber hecho la anterior). Datos de partida:

- **1.400 jobs** en Jenkins on-prem.
- **2 personas** de plataforma dedicadas hoy; se asume un **coste cargado de 100 USD/h** (salario + overhead + beneficios, cifra media europea para rol senior).
- **3 CVEs críticos** en el último año (parcheados tarde).
- **1 caída/mes** del controller bajo release nocturna.
- **~800 ejecuciones de pipeline / día** entre todas las workloads.
- **Infra actual**: controller (1 VM 8 vCPU/32 GB), ~30 agents on-prem (fluctúa).
- **Compliance**: GDPR + Solvency II (logs 7 años).

El objetivo: producir una **estimación anual** con dos columnas (mantener vs migrar), un **break-even** en meses, y una **recomendación**. **No** se piden cifras exactas de proveedor; se piden **estimaciones defendibles** con rangos razonables y supuestos explícitos.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Nombrar las **5 categorías** de costo recurrente de operar Jenkins: **personas**, **licencias** (CloudBees opcional), **infra** (controller + agents), **CVE lifecycle** (parcheo + auditoría), **incidentes** (caídas, re-runs, debugging).
- Nombrar las **4 categorías** de costo one-off de migrar: **inventario y clasificación**, **re-escritura de pipelines**, **dual-run** (duplicación temporal de cómputo), **aprendizaje y archivado histórico**.
- Calcular un **break-even** en meses y entender qué pasa si el coste hora sube o baja.
- Entender por qué el coste "oculto" (incidentes, deuda que se acumula) es a menudo mayor que el coste "visible" (licencias).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (en particular §3, §4, §5, §8, §9).
- Haber recorrido los dos `examples/` del módulo.
- Herramientas: `bash`, un editor Markdown, calculadora (o `python3 -c '...'`). Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/jk-01-cost
cd /tmp/jk-01-cost
```

Puedes usar otro directorio y pasarlo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `COST-ESTIMATE.md`

Formato libre pero con secciones obligatorias. El validador busca:

1. **`# Cost Estimate`** (o `# Estimación`) en el encabezado.
2. **`## Supuestos`** (o `## Assumptions`) — tabla o lista de los supuestos de cálculo (coste hora, horas/semana por persona, duración de la migración, etc.).
3. **`## Mantener`** (o `## Keep`, `## Stay`) — categorías de costo recurrente, tabla con horas/año y USD/año.
4. **`## Migrar`** (o `## Migrate`, `## Migration`) — categorías de costo one-off, tabla con horas y USD totales.
5. **`## Break-even`** (o `## Break even`, `## Payback`) — cuántos meses tarda la migración en pagarse sola.
6. **`## Recomendación`** (o `## Recommendation`) — qué recomiendas basado en los números.

Contenido mínimo obligatorio (el validador lo exige):

- Al menos **2 tablas** en Markdown (una para mantener, una para migrar — ambas con pipe tables, es decir, con cabecera `| ... |` y separador `|---|`).
- Mención explícita de **USD** o **EUR** o **€** o **$** como moneda.
- Mención explícita de **horas** / **hour** / **h/año** / **hrs** como unidad de esfuerzo.
- Al menos **3 categorías** nombradas de la columna "mantener": **personas**, **plugin** / **CVE**, **infra**, **agents**, **incidentes**, **licencias**.
- Al menos **3 categorías** nombradas de la columna "migrar": **inventario**, **dual-run**, **re-escritura** / **port**, **aprendizaje** / **learning**, **archivado** / **archive**, **OIDC**.
- Un **cálculo explícito de break-even** (número en meses o años, con fórmula o razonamiento).
- Mención de un **análisis de sensibilidad**: qué pasa si el coste hora sube o baja (p. ej. `+/- 20%`), o si la migración se extiende más de lo previsto.
- Una **recomendación final** clara.

### 5.3 Entregable

Un archivo:

```
/tmp/jk-01-cost/COST-ESTIMATE.md
```

con las 6 secciones y el contenido mínimo.

## 6. Resultado esperado

- `COST-ESTIMATE.md` existe, cuantifica ambos lados y recomienda con criterio.
- Validador en verde.
- Un CFO podría leerlo y decidir si financia la migración.

## 7. Criterios de aceptación

- **Cuantitativo**: hay números, no solo prosa.
- **Supuestos explícitos**: cualquier cifra tiene su supuesto declarado.
- **Sensibilidad**: no es un número único, es un rango.
- **Honestidad**: el coste de migrar está estimado al alza, no "optimista".

## 8. Validación

```bash
bash tests/validate.sh /tmp/jk-01-cost
```

El validador comprueba **estructura y presencia de términos clave**, no corrección numérica. Compara tus números con `solution/REFERENCE.md` para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Qué pasa con el break-even si el coste hora cambia de 100 USD/h a 150 USD/h?
2. ¿Qué partida de "mantener" tiene **más incertidumbre**? ¿Cómo la mitigas?
3. Si el CFO exige break-even ≤ 12 meses, ¿se puede lograr? ¿A costa de qué?
4. ¿Qué partida del "migrar" subestima la mayoría de la gente la primera vez?
5. ¿Cómo cambia la recomendación si descubres que **no** hay 1.400 jobs sino 400 (muchos duplicados)?

## 10. Extensiones

- Incluye un **gráfico ASCII** del break-even (coste acumulado por mes para ambas opciones).
- Añade un escenario "nothing changes": qué cuesta a 5 años mantener sin migrar.
- Añade una tabla de **riesgos financieros no capturados** (p. ej. multa Solvency II por auditoría fallida).

## 11. Limpieza

```bash
rm -rf /tmp/jk-01-cost
```
