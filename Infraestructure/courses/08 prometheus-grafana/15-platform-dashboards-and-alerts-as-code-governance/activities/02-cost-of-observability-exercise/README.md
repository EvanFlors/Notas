# obs-15-02 — Cost of observability exercise — independiente

## 1. Identificación
- **ID:** `obs-15-02-cost-of-observability-exercise`
- **Tecnología:** prometheus-grafana
- **Módulo:** `15-platform-dashboards-and-alerts-as-code-governance`
- **Dificultad:** advanced
- **Duración estimada:** 90 min
- **Tipo:** independent

## 2. Contexto
El CFO pregunta: *"¿por qué nuestra factura de observabilidad subió 2.5× este trimestre?"*. Como ingeniero de plataforma te toca responder — con números.

Recibes un `profile.yaml` con 12 servicios de una org ficticia (tier, series activas, GB de logs/día, spans/s, sampling, egress). Tu trabajo:

1. Computar la factura mensual estimada (métricas + logs + trazas + egress) usando precios dados.
2. Identificar los 3 principales contribuyentes al costo.
3. Proponer **2 optimizaciones concretas y cuantificadas** (p. ej. "bajar sampling de catalog de 10 % a 2 % ahorra $X/mes").
4. Entregar el análisis como `COST-ANALYSIS.md` con estructura precisa.

Es un ejercicio **independiente**. Puedes basarte en el script `examples/03-observability-bill-analysis/bill.py` o rehacerlo. La aritmética es lo de menos; la claridad del razonamiento es lo que se evalúa.

## 3. Objetivos
- Calcular una factura mensual de observabilidad desde un perfil técnico.
- Identificar y justificar los top-3 contribuyentes al costo.
- Proponer 2 optimizaciones con *delta* cuantificado.
- Separar causas estructurales (muchos servicios tier gold) de bugs (`user_id` como label).

## 4. Prerrequisitos
- Haber leído `theory/lesson.md` §8 (costo de observabilidad).
- Haber corrido el ejemplo `examples/03-observability-bill-analysis/`.
- Herramientas: `python3` con `pyyaml`, `bash`. Sin costos reales.

## 5. Instrucciones

```bash
# 1) Scratch dir
mkdir -p /tmp/obs15-02
cp starter/profile.yaml starter/prices.yaml /tmp/obs15-02/

# 2) Computa la factura. Dos caminos válidos:
#    (a) Usar el script del ejemplo:
#        python3 ../../../examples/03-observability-bill-analysis/bill.py \
#          /tmp/obs15-02/profile.yaml /tmp/obs15-02/prices.yaml
#    (b) Rehacer el cálculo (hoja de cálculo, script propio, lo que prefieras).

# 3) Escribe tu análisis en /tmp/obs15-02/COST-ANALYSIS.md
```

El documento `COST-ANALYSIS.md` **debe** tener exactamente estas secciones (headers de nivel 2, en orden):

```markdown
## Resumen de la factura
## Top-3 contribuyentes
## Causa raíz
## Optimización 1
## Optimización 2
## Ahorro total estimado
```

Qué va en cada sección (mínimo):

- **Resumen de la factura**: total mensual (`$`), desglose por categoría (métricas, logs, trazas, egress).
- **Top-3 contribuyentes**: 3 servicios con su costo y breakdown.
- **Causa raíz**: ¿por qué el top-3 es caro? Estructural (gold, mucho tráfico) o bug (cardinalidad, logs excesivos)?
- **Optimización 1 y 2**: cada una con descripción + delta $ ahorrado/mes + riesgo.
- **Ahorro total estimado**: suma de los dos deltas, con % respecto al total.

## 6. Resultado esperado
- `/tmp/obs15-02/COST-ANALYSIS.md` existe y pasa `tests/validate.sh`.
- Las dos optimizaciones son accionables (no "optimizar más") y traen una cifra `$` concreta.

## 7. Criterios de aceptación
- Las 6 secciones existen con header exacto.
- La sección "Resumen de la factura" contiene al menos una cifra `$`.
- Las dos secciones "Optimización" cada una menciona un delta `$`.
- Se nombran al menos 3 servicios del profile en el top-3.
- Documento con mínimo 25 líneas no vacías.

## 8. Validación

```bash
bash tests/validate.sh
```

## 9. Preguntas de reflexión
- Si un servicio tier `gold` consume 5× lo presupuestado por que su RED tiene buenos labels, ¿cómo decides: subir el cap, bajar a `silver`, o dropear labels?
- ¿Cuál sería la señal temprana para detectar una cardinality explosion antes de ver la factura?
- Si el equipo A rechaza bajar su sampling de trazas de 10 % a 2 % "porque pierde debuggability", ¿qué contraoferta técnica tienes?

## 10. Extensiones
- Añade al script el cálculo de `ingest_rate` (samples/s = series × 1/scrape_interval) y su contribución al write path.
- Añade una proyección a 12 meses asumiendo crecimiento del 20 %/trimestre.
- Añade una métrica Prometheus (`observability_cost_usd_month_estimate{service,tier}`) emitida por este script como recording rule para meta-observability.

## 11. Limpieza

```bash
rm -rf /tmp/obs15-02
```
