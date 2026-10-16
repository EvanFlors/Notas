# Lesson — SLOs y burn-rate alerts

> Doce secciones. Prosa densa, código en inglés, decisiones de ingeniería explícitas.

## 1. Por qué SLOs (y no "alertas sobre todo")

El antipatrón más común en observabilidad madura es tener **miles de alertas basadas en umbrales de recursos** (`cpu > 80 %`, `queue_depth > 100`, `error_rate > 0`). Son ruido: la mayoría se dispara sin que un usuario haya notado nada, se silencian "por costumbre" y, cuando llega una verdadera degradación, se pierde entre otras 200 páginas.

Los **SLOs** invierten la pregunta: en vez de alertar sobre causas (síntomas internos), se alerta sobre **efectos observables por el usuario**. Si el usuario está bien, no hay que despertar a nadie. Si el usuario está mal, se despierta a quien debe arreglarlo, con un umbral que ya acordó la organización.

El SLO también sirve como **contrato operativo**: hay un budget finito de "incumplimiento permitido" (el error budget). Si no se gasta, el equipo puede desplegar con agresividad; si se gasta, debe reducir riesgo. Esto da una señal cuantitativa (no cualitativa) para la relación entre release velocity y reliability.

## 2. SLI — definición y familias

Un **SLI** (Service Level Indicator) es una métrica que cuantifica, en un instante o ventana, qué fracción del servicio es "buena". Las cuatro familias canónicas:

- **Availability** — fracción de peticiones no erróneas: `good / total`. Ejemplo: `sum(rate(http_requests_total{code!~"5.."}[5m])) / sum(rate(http_requests_total[5m]))`.
- **Latency** — fracción de peticiones por debajo de un umbral: `fast / total`. Con histogram, suele implementarse con `histogram_quantile()` o con un bucket específico (`le="0.3"`).
- **Correctness** — fracción con resultado correcto; requiere instrumentación de dominio (contadores de "respuestas aceptadas por un reconciliador").
- **Freshness** — para datos derivados, fracción de datos cuyo `age < X`: típico en pipelines y réplicas (`time() - data_timestamp_seconds`).

Dos reglas de diseño:
1. **El numerador debe ser siempre un subconjunto estricto del denominador.** `good <= total`.
2. **La métrica debe reflejar la experiencia del usuario**, no un detalle interno. "El CPU está al 80 %" no es un SLI; "el 99,8 % de las requests devuelve 2xx en < 300 ms" sí.

## 3. SLO — objetivo + ventana + política

Un **SLO** añade al SLI tres cosas:
- **Objetivo numérico** (`99.9 %`).
- **Ventana** (`rolling 30 days` es la más común; también `calendar month` o `rolling 28 days`).
- **Consecuencia** cuando se incumple (la *error budget policy*).

Ejemplo bien formado:

> "La API `payments` sirve el 99,9 % de las peticiones HTTP (excluyendo 4xx no 429) sin error 5xx y en menos de 300 ms end-to-end, medido en una ventana rolling de 30 días. Si el budget se agota, el equipo entra en freeze de features hasta recuperarlo."

Ejemplos mal formados: "la API es rápida" (sin umbral), "99,9 % de uptime" (sin definir qué es *up*), "latencia < 300 ms siempre" (sin ventana ni fracción).

## 4. Error budget — el único reloj que importa

Si el SLO es `99.9 %`, el **error budget** es `1 - 0.999 = 0.001` (0,1 %). En una ventana de 30 días:

```
budget_requests = 0.001 * total_requests_30d
budget_minutes_down = 0.001 * 30 * 24 * 60 ≈ 43.2 min
```

El budget se consume con **cualquier evento que resta**: un rollback fallido, un pico de 500s, una ventana de maintenance mal comunicada. No importa la causa, importa el consumo.

Ventajas:
- Es una métrica **absoluta** (minutos, peticiones) interpretable sin PhD.
- Es **finita**: todo el mundo entiende "nos quedan 10 minutos".
- Es **compartida**: dev y ops gastan del mismo pot.

## 5. Burn-rate — tasa relativa de consumo

El burn-rate no es más que una **normalización del error rate contra el error budget**:

```
burn_rate = (1 - current_sli) / (1 - SLO) = error_rate / error_budget
```

Interpretación:
- `burn_rate = 1` → al ritmo actual, el budget se agota justo al final de la ventana (lo "normal").
- `burn_rate = 2` → se gastaría todo el budget en media ventana.
- `burn_rate = 14.4` → se gastaría todo el budget en `30 / 14.4 ≈ 2.08 días`.

Alertar sobre burn-rate (y no sobre error-rate crudo) desacopla la definición del SLO del umbral de la alerta: cambiar el SLO de 99.9 % a 99.95 % no obliga a tocar las alertas (sólo la constante en la query).

## 6. Single-window: por qué no basta

La tentación es: `alert if error_rate_5m > X`. Dos problemas:

1. **Sensibilidad vs ruido** se vuelven un trade-off hostil:
   - Ventana corta (5 min) → detecta rápido pero genera falsos positivos con picos transitorios.
   - Ventana larga (6 h) → ignora microincidentes pero tarda horas en detectar un fallo total.
2. **La alerta sigue viva tras la recuperación.** Si el error rate baja a cero a los 10 min pero la ventana es 1 h, la alerta sigue "activa" otros 50 min — el on-call recibe páginas por un incidente ya resuelto.

Elegir una sola ventana implica elegir mal.

## 7. Multi-window multi-burn-rate (MWMBR) — la receta del SRE Workbook

**Dos ventanas, dos burn-rates, un `and`**. La fórmula canónica usa dos pares de ventanas, uno para severidad página y otro para severidad ticket:

| Severidad | Burn-rate | Ventana larga | Ventana corta | % budget consumido |
|-----------|-----------|---------------|---------------|--------------------|
| página    | 14.4      | 1 h           | 5 min         | 2 % en 1 h         |
| página    | 6         | 6 h           | 30 min        | 5 % en 6 h         |
| ticket    | 3         | 24 h          | 2 h           | 10 % en 24 h       |
| ticket    | 1         | 72 h          | 6 h           | 10 % en 72 h       |

La condición es: `burn_rate_long >= X AND burn_rate_short >= X`. La ventana larga confirma la sostenibilidad del problema; la ventana corta garantiza que el problema sigue ocurriendo ahora.

Beneficios combinados:
- **Tiempo-a-detectar bajo**: ventana corta reacciona en minutos.
- **Pocos falsos positivos**: ventana larga filtra picos.
- **Auto-resolución rápida**: cuando el error cesa, la ventana corta cae y la alerta se desactiva en minutos sin esperar a que la larga drene.

## 8. Recording rules como "ingredientes SLO"

Cada regla de alerta MWMBR evalúa varias ratios (5m, 30m, 1h, 6h). Si cada regla recalcula desde `http_requests_total`, el coste es cuadrático. La práctica estándar es:

```yaml
# ingredient recording rules
groups:
  - name: slo-ingredients-payments
    interval: 30s
    rules:
      - record: sli:http_requests:ratio_rate5m
        expr: |
          sum(rate(http_requests_total{job="payments", code!~"5.."}[5m]))
          /
          sum(rate(http_requests_total{job="payments"}[5m]))
      - record: sli:http_requests:ratio_rate1h
        expr: |
          sum(rate(http_requests_total{job="payments", code!~"5.."}[1h]))
          /
          sum(rate(http_requests_total{job="payments"}[1h]))
```

Las alertas luego consumen `sli:...` por nombre, sin lógica embebida. Convenciones de naming útiles:
- Prefijo `sli:` para ingredientes.
- Sufijo `:ratio_rateXh` para distinguir ventana.
- Un grupo por servicio o por SLO.

## 9. Herramientas — Sloth y OpenSLO

Escribir MWMBR a mano es tedioso y fácil de equivocar. Dos ecosistemas:

**Sloth** (Spotify / Slok): CLI que lee un YAML con la spec del SLO y emite `PrometheusRule` con ingredientes + MWMBR siguiendo el Workbook. Minimal:

```yaml
version: prometheus/v1
service: payments
slos:
  - name: availability
    objective: 99.9
    description: Payments availability SLO
    sli:
      events:
        error_query: sum(rate(http_requests_total{job="payments",code=~"5.."}[{{.window}}]))
        total_query: sum(rate(http_requests_total{job="payments"}[{{.window}}]))
    alerting:
      name: PaymentsAvailabilityHighBurn
      page_alert:
        labels: {severity: page}
      ticket_alert:
        labels: {severity: ticket}
```

`sloth generate -i slo.yaml -o rules.yaml` produce ~15 recording rules + 2 alertas por SLO.

**OpenSLO**: spec declarativa, agnóstica de implementación (hay generadores para Prometheus, Datadog, etc.). Útil cuando se quieren SLOs portables entre backends.

Regla práctica: usa Sloth para generar y commitea el output al repo (no sólo el input), así `promtool test rules` corre en CI sin dependencia de la herramienta.

## 10. Error budget policy — del YAML al proceso

Un SLO sin política es decorativo. La política responde:

- **¿Qué pasa cuando el budget cae a 25 %?** → Revisión en el weekly, se priorizan tickets de reliability.
- **¿Y a 10 %?** → Freeze de features. Sólo bugfixes y mejoras de reliability.
- **¿Y a 0 %?** → Rollback de la última release si procede; postmortem obligatorio.
- **¿Quién puede autorizar un deploy durante el freeze?** → Nombre y rol (típicamente ingeniería + producto).
- **¿Cuándo se renegocia el SLO?** → Si el budget nunca se consume → quizá el objetivo es muy laxo. Si se agota todos los meses → objetivo irreal o sistema insuficiente, hay que invertir o bajar expectativas.

Esta política suele vivir en un README junto al `slo.yaml`.

## 11. SLOs del capstone — ejemplos concretos

Para la API del capstone (`payments`, `orders`):

- **Availability SLO**: 99.9 % de requests `code!~"5.."` sobre total `code!~"4.."` (excluyendo errores de cliente genuinos, pero contando 429 como "no es culpa del cliente, es del sistema").
- **Latency SLO**: 99 % de requests con `latency < 300 ms` medido con `histogram_quantile(0.99, ...)` sobre bucket `le="0.3"`.
- **Freshness SLO** (si hay cache o réplica): 99.9 % del tiempo `data_age_seconds < 60`.

Ventana: 30 días rolling. Budget: 43 min de downtime permitido (en requests, ~43.2 K requests sobre 43 M).

## 12. Checklist antes de hacer merge de un SLO

Antes de aceptar un `PrometheusRule` SLO en main:

- [ ] El SLI está documentado con query exacta y justificación de inclusiones/exclusiones.
- [ ] El objetivo y la ventana son explícitos.
- [ ] Existen al menos dos pares MWMBR (página y ticket).
- [ ] Las reglas pasan `promtool check rules` y `promtool test rules` con fixtures que ejercitan: condición normal (no dispara), fast burn (dispara página), slow burn (dispara ticket), recuperación (apaga).
- [ ] Existe la *error budget policy* en el repo del servicio.
- [ ] Hay un dashboard con: SLI actual, SLO target, budget restante, burn-rate 1h / 6h.
- [ ] El runbook asociado a cada alerta responde "qué revisar primero" en < 2 min.

Si cualquier casilla falla, el SLO no está listo para producción.
