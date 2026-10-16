# Actividad 02 — Mapear los tres pilares en un postmortem narrado

## 1. Identificación

- **ID:** `obs-01-02-identify-pillars-in-a-scenario`
- **Tecnología:** `prometheus-grafana`
- **Módulo:** `obs-01-observability-pillars-and-pull-model`
- **Dificultad:** beginner
- **Duración estimada:** 40–50 min
- **Tipo:** independent

## 2. Contexto

Un sistema puede tener dashboards bonitos y seguir siendo **no observable**: cuando llega la pregunta "¿por qué?", nadie puede responderla sin desplegar código. Esta actividad usa un postmortem narrado real-ístico para que entrenes la decisión *"¿qué pilar responde esta pregunta?"* antes de tocar PromQL o Grafana.

El entregable es un documento `PILLARS.md` que mapea cada pregunta del postmortem al pilar correspondiente y propone **qué faltaba** para responderla.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Decir qué pilar (metrics / logs / traces) responde cada tipo de pregunta.
- Reconocer **lagunas de observabilidad** en un sistema real.
- Proponer una métrica, un log estructurado o un span de trace concreto que cerraría cada laguna.
- Distinguir operativamente *monitoring* de *observabilidad* con un ejemplo del postmortem.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (secciones 1–5 son suficientes).
- Haber recorrido `../../examples/01-metrics-logs-traces-mental-model/`.
- Herramientas: `bash` y un editor Markdown.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/obs-01-pillars
cd /tmp/obs-01-pillars
```

### 5.2 El postmortem (ficticio pero realista)

> **Incidente SEV-2 — `shop-api`, 2026-10-13, 10:12–10:34 UTC**
>
> **Resumen.** Entre las 10:12 y las 10:34 UTC, el checkout del e-commerce falló intermitentemente para un ~12 % de usuarios. El equipo tardó **18 minutos** en identificar la causa raíz y 4 minutos más en mitigarla.
>
> **Topología:**
>
> ```
> cliente ─▶ frontend (Next.js) ─▶ api-gateway ─▶ payments ─▶ bank-adapter ─▶ (banco externo "visa-sandbox")
>                                        │
>                                        └─▶ orders ─▶ postgres
> ```
>
> **Línea de tiempo:**
>
> - **10:10** — Deploy de `payments` v1.42 (feature flag "nuevo retry policy", activado al 100 %).
> - **10:12** — Primeras quejas por Slack. Dashboard "golden signals" muestra `5xx rate` en `api-gateway` saltando de 0.1 % a 11 %.
> - **10:14** — On-call entra, intenta "entender qué request falla". Los logs de `api-gateway` solo dicen "upstream error 502". No hay `trace_id` compartido entre servicios. Los logs de `payments` son millones de líneas y la búsqueda por timestamp es lenta.
> - **10:17** — On-call pide "cuántos requests por `acquirer` fallaron". Las métricas tienen `path` y `status` pero **no** `acquirer`. Ciegos.
> - **10:21** — On-call pide a dev de `payments` que grepee logs. Hay logs mezclando `visa` y `mastercard`; se detecta patrón: todos los fallos vienen con `acquirer=visa`.
> - **10:24** — Dev revisa el trace de un request fallido en Jaeger: el trace solo cubre `api-gateway → payments`. **El span de `bank-adapter` no está instrumentado**. No se ve qué pasó aguas abajo.
> - **10:27** — Dev abre el código de `bank-adapter`: el nuevo retry policy de v1.42 reintenta 5 veces con backoff exponencial sin budget total, acumulando ~8 s por request contra `visa-sandbox` que a su vez tiene timeout de 2 s.
> - **10:30** — Causa raíz confirmada: timeouts en cascada por retry mal configurado contra el acquirer visa.
> - **10:34** — Rollback de v1.42. Error rate vuelve a 0.1 %.
>
> **Preguntas que surgieron durante el incidente** (las usas más abajo):
>
> 1. "¿Hay un patrón temporal — está empeorando o estable?"
> 2. "¿Está pasando ahora o solo pasó?"
> 3. "¿Qué dijo exactamente `bank-adapter` cuando falló el request del cliente `X` a las 10:14:03?"
> 4. "¿Qué servicio en la cadena consumió más tiempo para el request `req_id=def456`?"
> 5. "¿Cuántos requests por `acquirer` fallaron en los últimos 10 min?"
> 6. "¿Esto coincide con el deploy de las 10:10?"
> 7. "¿Qué consume más CPU en `bank-adapter` desde el deploy?"
> 8. "¿Qué proporción de fallos tiene en común el header `User-Agent`?"

### 5.3 Entregable: `PILLARS.md`

Crea `/tmp/obs-01-pillars/PILLARS.md` con **estas tres secciones**:

#### A. Tabla de mapeo

Para las 8 preguntas, una fila con:

| # | Pregunta (resumen) | Pilar primario | Pilar de apoyo | Señal concreta que hace falta |
|---|--------------------|----------------|----------------|-------------------------------|

Los valores de "Pilar primario" / "Pilar de apoyo" deben ser alguno de: `metrics`, `logs`, `traces`, `events`, `profiling`. "Señal concreta" es ej.: *"métrica `payment_requests_total{acquirer=…}`"*, o *"span `bank-adapter.charge` con atributo `acquirer`"*, o *"log estructurado con `trace_id` y `req_id`"*.

#### B. Lagunas de observabilidad detectadas

Lista 5 lagunas concretas que el postmortem revela. Formato por laguna:

```
### Laguna N — <título>

**Síntoma durante el incidente:** <qué sucedió por culpa de esta laguna>

**Pilar afectado:** metrics | logs | traces | events | profiling

**Propuesta concreta:**
- qué métrica/log/span añadir, con nombre
- dónde (qué servicio)
- qué cardinalidad esperable (si aplica)
```

#### C. Síntesis — monitoring vs observabilidad

Responde en prosa breve:

1. ¿Qué parte del incidente fue **monitoring** (ya se medía lo correcto)?
2. ¿Qué parte fue **falta de observabilidad** (había que desplegar código para responder la pregunta)?
3. Si solo pudieras añadir **una señal nueva** antes del próximo incidente, ¿cuál sería y por qué?

### 5.4 Entregable final

```
/tmp/obs-01-pillars/PILLARS.md
```

## 6. Resultado esperado

- `PILLARS.md` existe.
- La tabla cubre las 8 preguntas numeradas.
- Hay al menos 5 lagunas numeradas.
- Hay una síntesis con las 3 preguntas respondidas.
- `bash tests/validate.sh /tmp/obs-01-pillars` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada mapeo pilar/pregunta está defendido en una frase.
- **Reproducibilidad**: cualquiera que lea tu documento sabe qué faltaba en el stack.
- **Mantenibilidad**: Markdown válido, tabla legible.

## 8. Validación

```bash
bash tests/validate.sh /tmp/obs-01-pillars
```

El validador comprueba **estructura**, no semántica. Después, compara con `solution/REFERENCE.md` para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Puede una métrica responder la pregunta 3 ("qué dijo exactamente ... a las 10:14:03")? Si tu respuesta es "no", explica por qué estructuralmente.
2. ¿Por qué el equipo tardó 18 minutos aunque "tenía dashboard"?
3. ¿Qué cambiaría si cada log hubiera llevado `trace_id` desde el principio?
4. ¿Qué label habría sido útil pero peligroso por cardinalidad en la pregunta 8?
5. Para la pregunta 7 (profiling), ¿por qué métricas de CPU "normales" no son suficientes?

## 10. Extensiones

- Dibuja un diagrama ASCII de la topología y marca con asteriscos los puntos donde falta instrumentación.
- Propone una **alerta** que habría disparado antes de las 10:12 (predictiva, basada en el deploy + burn rate).
- Si tuvieras OpenTelemetry desde el día 1, ¿qué 3 cambios concretos tendría el postmortem?

## 11. Limpieza

```bash
rm -rf /tmp/obs-01-pillars
```

No hay procesos ni contenedores que detener.
