# Actividad 01 — Mapeo del panorama OTel ↔ backends

## 1. Identificación

- **ID:** `otel-01-01-landscape-mapping`
- **Tecnología:** `opentelemetry`
- **Módulo:** `otel-01-what-and-why-signals-and-maturity`
- **Dificultad:** beginner
- **Duración estimada:** 40–50 min
- **Tipo:** independent (sin dependencia de la actividad 02)

## 2. Contexto

Una organización típica llega a OTel con un stack ya montado: puede tener **Prometheus + Grafana** (porque siguió el curso previo), **Jaeger** o **Zipkin** para traces, **Loki** o **Elastic** para logs, un **vendor APM** (Datadog, New Relic, Honeycomb) encima de todo, y agentes variados (`node_exporter`, `cadvisor`, `fluentbit`). La pregunta que surge siempre es la misma:

> *"Si adopto OTel, ¿qué tiro, qué dejo y qué cambio?"*

Esta actividad entrena esa clasificación. El entregable es un análisis técnico breve en Markdown. **No hay** cluster, ni `kubectl`, ni código. Es puramente conceptual.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Clasificar cada herramienta de un stack típico como **reemplazada por OTel**, **convive con OTel** o **fuera del scope de OTel**.
- Articular, con un diagrama ASCII, cómo se ve el stack **antes** y **después** de adoptar OTel.
- Explicar en una frase por qué OTel **no** es un backend ni reemplaza a Prometheus/Jaeger/Loki.
- Nombrar los **receivers** del Collector que permiten que herramientas pre-OTel (Jaeger, Zipkin, Prometheus scrape) sigan funcionando mientras se migra.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §7 y §8).
- Haber recorrido los dos `examples/` del módulo.
- Haber completado el curso `prometheus-grafana` ≥ Nivel 2 (`obs-02`).
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/otel-01-landscape
cd /tmp/otel-01-landscape
```

Puedes usar otro directorio, pero entonces debes pasárselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `LANDSCAPE.md` con tres secciones

#### Sección A — Tabla de clasificación

Rellena esta tabla con **al menos 5 piezas** de las listadas. Para cada una, decide una categoría y justifica en 1–2 líneas.

```
## Clasificación

| Pieza                | Categoría                          | Justificación |
|----------------------|------------------------------------|---------------|
| Prometheus (storage) | reemplazada | convive | fuera-de-scope | ...           |
| Jaeger (storage+UI)  | ...                                | ...           |
| Zipkin               | ...                                | ...           |
| Loki                 | ...                                | ...           |
| Vendor APM           | ...                                | ...           |
| Grafana              | ...                                | ...           |
| Fluentbit / Vector   | ...                                | ...           |
```

Reglas:

- **reemplazada**: OTel ocupa el rol que tenía esa pieza.
- **convive**: la pieza sigue viva; OTel se enchufa delante o al lado.
- **fuera-de-scope**: OTel ni la toca ni la reemplaza.

La justificación debe nombrar **qué parte** de OTel juega el papel (API/SDK, OTLP, Collector, exporter específico, receiver específico).

#### Sección B — Diagrama antes/después

Dibuja (ASCII) tu stack **antes** de OTel y tu stack **después**. Marca:

- Por dónde entra la telemetría.
- Dónde está el Collector (si procede).
- Qué receiver(s) y exporter(s) usas para que las piezas pre-OTel sigan funcionando.
- A qué backend va cada signal.

Ejemplo (plantilla; **no la copies literal, adáptala**):

```
### Antes (stack hoy)

   App ──► prometheus_client ──► Prometheus
   App ──► jaeger-client     ──► Jaeger
   App ──► logging           ──► Fluentbit ──► Loki

### Despues (con OTel)

   App ──► OTel SDK ──► OTLP ──► OTel Collector ──► Prometheus
                                              └──► Tempo (o Jaeger)
                                              └──► Loki
   (apps viejas con jaeger-client ──► receiver/jaeger del Collector)
```

#### Sección C — 5 afirmaciones a defender o refutar

Para cada una, responde **De acuerdo / En desacuerdo / Depende** y justifica en 1–3 líneas:

1. *"OTel va a reemplazar a Prometheus."*
2. *"Si adopto OTel tengo que tirar Jaeger."*
3. *"Grafana queda obsoleta con OTel."*
4. *"Puedo migrar de Datadog a Grafana Cloud sin tocar código si uso OTel."*
5. *"Fluentbit queda sin sentido si uso el OTel Collector."*

### 5.3 Entregable

Un archivo:

```
/tmp/otel-01-landscape/LANDSCAPE.md
```

con las tres secciones A, B y C.

## 6. Resultado esperado

- `LANDSCAPE.md` existe y es coherente.
- La tabla tiene **al menos 5 filas** con categoría y justificación.
- El diagrama ASCII muestra antes/después y menciona `collector`, `receiver` o `exporter` al menos una vez.
- Las 5 afirmaciones están respondidas.
- `bash tests/validate.sh /tmp/otel-01-landscape` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada clasificación está defendida nombrando la pieza concreta de OTel.
- **Reproducibilidad**: alguien que lea tu documento puede dibujar el mismo stack después.
- **Mantenibilidad**: Markdown válido, tabla legible.

## 8. Validación

```bash
bash tests/validate.sh /tmp/otel-01-landscape
```

El validador comprueba **estructura**, no semántica. Compara tu análisis con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Por qué el `prometheusreceiver` del Collector es un puente de migración y no una solución definitiva?
2. Si una organización **solo** usa un vendor APM (p. ej. Datadog) y lo paga, ¿qué gana clasificando ese vendor como "convive" en vez de "reemplazada"?
3. Fluentbit y el Collector hacen cosas parecidas con logs. ¿En qué escenario tiene sentido mantener ambos y en cuál colapsarlos en uno?
4. ¿Qué pieza del stack típico es la que **nunca** entra en conflicto con OTel? ¿Por qué?
5. Si tuvieras que convencer a un lead escéptico en 3 bullets de que "OTel ≠ reemplazar lo que tengo", ¿qué bullets usarías?

## 10. Extensiones

- Añade una **sexta** fila a la tabla con una pieza propia de tu organización (si aplica).
- Dibuja un tercer diagrama "fase intermedia": apps viejas con jaeger-client coexistiendo con apps nuevas OTLP durante la migración.
- Marca en el diagrama **dónde** está el límite de responsabilidad de OTel (línea punteada entre "generación/transporte" y "storage/consulta").

## 11. Limpieza

Como es puramente conceptual:

```bash
rm -rf /tmp/otel-01-landscape
```

No hay procesos ni contenedores que detener.
