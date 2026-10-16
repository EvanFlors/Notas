# Actividad 01 — Análisis: cuándo Prometheus NO es la respuesta

## 1. Identificación

- **ID:** `obs-01-01-when-not-prometheus`
- **Tecnología:** `prometheus-grafana`
- **Módulo:** `obs-01-observability-pillars-and-pull-model`
- **Dificultad:** beginner
- **Duración estimada:** 40–50 min
- **Tipo:** independent

## 2. Contexto

El entusiasmo por Prometheus en la industria es tal que a menudo se adopta **antes de pensar si encaja**. Esta actividad entrena el músculo contrario: para 4 escenarios distintos, decidir con criterio si Prometheus es la elección correcta y, cuando no lo sea, nombrar la alternativa adecuada y defender la decisión.

El entregable es un análisis técnico breve en Markdown. No hay cluster, ni `kubectl`, ni cloud. Es puramente conceptual y de criterio.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Articular **cuándo** Prometheus encaja y cuándo no, con criterios **medibles** (duración del proceso, alcance de red, cardinalidad, retención requerida, costo).
- Nombrar **al menos una alternativa concreta** por escenario donde Prometheus no encaje.
- Explicar el rol del **Pushgateway** como excepción documentada.
- Escribir un análisis corto, defendible y revisable por un peer.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo.
- Haber recorrido los dos `examples/` del módulo.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/obs-01-when-not
cd /tmp/obs-01-when-not
```

Puedes usar otro directorio, pero entonces debes pasárselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Los 4 escenarios

Para cada uno, escribe una sección en `ANALYSIS.md` con el formato que ves más abajo.

#### Escenario 1 — Microservicios FastAPI en EKS

> Startup con 12 microservicios Python/FastAPI corriendo en EKS, 60 pods en total. Equipo plataforma de 3 personas. Quieren métricas RED, dashboards por servicio y alertas sobre latencia y errores.

#### Escenario 2 — Job de ETL que corre cada hora

> `CronJob` nocturno que corre cada hora, dura ~90 segundos, procesa facturas y publica "procesadas: N, fallidas: M". El equipo quiere ver histórico y alertar si falla la ejecución o si fallan > 5 % de facturas.

#### Escenario 3 — Flota IoT de 500 000 dispositivos

> Empresa de medidores inteligentes de agua: ~500 000 dispositivos distribuidos por el país, cada uno detrás del NAT del hogar del cliente. Envían 1 muestra cada 10 minutos vía MQTT. Quieren dashboards agregados por zona y alertas sobre caídas masivas.

#### Escenario 4 — Base histórica de 7 años para analítica de producto

> Equipo de producto quiere consultar métricas de uso (events, DAUs, eventos de funnel) con retención de **7 años** para análisis de cohortes, correlaciones con lanzamientos y reporting a Dirección.

### 5.3 Formato de cada sección

Repite para los 4 escenarios:

```
## Escenario N — <nombre>

**Decisión:** Prometheus SÍ | Prometheus NO | Prometheus parcial

**Justificación (3–6 bullets):**
- criterio 1 (duración de los procesos, cardinalidad, red, retención, costo…)
- criterio 2
- …

**Alternativa / complemento:**
- herramienta/pattern concreto y por qué encaja

**Riesgo si lo haces mal:**
- un impacto concreto (ej.: "alertas falsas por `up == 0`", "coste de storage de 10 TB/año", …)
```

### 5.4 Síntesis final

Añade al final de `ANALYSIS.md` una sección:

```
## Síntesis

**Regla pull-first que me llevo:** <una frase>

**Rol del Pushgateway:** <2–3 frases explicando cuándo SÍ y cuándo NO>

**7 preguntas-criterio para decidir Prometheus vs alternativas:**
1. ...
2. ...
3. ...
4. ...
5. ...
6. ...
7. ...
```

Las 7 preguntas deben ser **tuyas**, cortas, operables (que un lead pueda contestar en una reunión). Ejemplos de forma (no las copies literalmente):

- "¿Los procesos viven más que mi `scrape_interval`?"
- "¿Puedo alcanzarlos por red desde el scraper?"

### 5.5 Entregable

Un archivo:

```
/tmp/obs-01-when-not/ANALYSIS.md
```

con las 4 secciones + la síntesis.

## 6. Resultado esperado

- `ANALYSIS.md` existe y es coherente.
- Cada escenario tiene decisión, justificación, alternativa y riesgo.
- La síntesis tiene las 7 preguntas numeradas.
- `bash tests/validate.sh /tmp/obs-01-when-not` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada decisión está defendida con criterios técnicos (no "porque sí").
- **Reproducibilidad**: cualquiera que lea tu análisis sabe por qué decidiste eso.
- **Mantenibilidad**: formato limpio, Markdown válido.

## 8. Validación

```bash
bash tests/validate.sh /tmp/obs-01-when-not
```

El validador comprueba **estructura**, no semántica. Compara tu análisis con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. Para el escenario 1, ¿cambiaría tu decisión si fueran 1 200 microservicios en vez de 12? ¿Por qué?
2. En el escenario 2, el equipo pregunta "¿y si simplemente convertimos el cron en un servicio que exponga una métrica gauge?". ¿Qué respondes?
3. ¿Por qué el escenario 3 **no se arregla** poniendo un Pushgateway?
4. En el escenario 4, ¿qué le dirías a un ingeniero que propone "subir el `retention` de Prometheus a 7 años"?
5. ¿Cuál de los 4 escenarios es el más "obvio" y cuál el más "trampa"? Argumenta.

## 10. Extensiones

- Añade un 5.º escenario propio (de tu trabajo real si puedes). Analízalo con el mismo formato.
- Dibuja (ASCII) la topología de cada escenario y marca dónde está el límite de red del scraper.
- Para el escenario 4, propone un diseño con Prometheus **sólo para alerting operativo** y otra herramienta (data warehouse) para analítica histórica.

## 11. Limpieza

Como es puramente conceptual:

```bash
rm -rf /tmp/obs-01-when-not
```

No hay procesos ni contenedores que detener.
