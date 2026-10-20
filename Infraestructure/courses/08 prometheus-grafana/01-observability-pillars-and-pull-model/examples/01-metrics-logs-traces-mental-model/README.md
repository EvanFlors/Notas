# Ejemplo 01 — Modelo mental de metrics, logs y traces

> **Tipo:** lectura y análisis. No corre nada. No requiere infra.
> **Duración:** 15–20 min.

## Objetivo

Fijar el modelo mental de los tres pilares viendo **la misma incidencia** desde cada uno. Al terminar, deberías poder decidir qué pilar atacar primero según la pregunta que te hagan.

## La incidencia

Entre las **10:12 y las 10:17** del `2026-10-13`, el equipo recibe quejas de que el *checkout* del e-commerce falla "a veces". Hay 4 servicios:

```
      cliente ─▶ frontend ─▶ api-gateway ─▶ payments ─▶ bank-adapter ─▶ (banco externo)
                                     │
                                     └──▶ orders ─▶ postgres
```

A continuación, cómo **cada pilar** ve esos 5 minutos.

---

## 1. Metrics — qué dicen las métricas

Series en Prometheus (ficticias, formato narrativo):

```
http_requests_total{service="payments", path="/charge", status="200"}   rate 5m: 120/min
http_requests_total{service="payments", path="/charge", status="402"}   rate 5m:  18/min  ← 15 % de errores
http_request_duration_seconds{service="payments", path="/charge"}       p99:    2.1 s    ← alto
up{instance="bank-adapter-0"}                                           = 1              ← vivo
up{instance="bank-adapter-1"}                                           = 0 (desde 10:11) ← CAIDO
```

Lo que te dicen:

- **Cuánto** y **cuándo**: ratio de errores saltó al 15 %, p99 subió a 2.1 s, un pod de `bank-adapter` lleva 6 min caído.
- Qué **no** te dicen: *por qué* el banco rechaza, *qué request concreto* falló, *si fue el mismo usuario quien reintentó*.

Pregunta que las métricas responden bien: **"¿está pasando algo anormal?"** → sí.
Pregunta que **no** responden: **"¿por qué este request falló?"**.

---

## 2. Logs — qué dicen los logs

Fragmento de los logs de `bank-adapter` entre 10:14 y 10:15:

```
2026-10-13T10:14:02Z INFO  svc=bank-adapter req_id=abc123 user=42 charging $85.00 via acquirer=visa
2026-10-13T10:14:04Z WARN  svc=bank-adapter req_id=abc123 user=42 acquirer response 402 code=card_declined
2026-10-13T10:14:04Z INFO  svc=payments     req_id=abc123 user=42 returning 402 to api-gateway
2026-10-13T10:14:11Z ERROR svc=bank-adapter req_id=def456 user=77 upstream timeout after 2000ms acquirer=mastercard
2026-10-13T10:14:11Z ERROR svc=bank-adapter req_id=def456 user=77 circuit breaker opened for acquirer=mastercard
```

Lo que te dicen:

- Qué dijo el proceso textualmente en ese instante.
- Que algunos 402 son legítimos (`card_declined`), otros no (`upstream timeout`).
- Que a las 10:14:11 abrió un **circuit breaker** contra `mastercard` — eso explica la cascada.

Qué **no** te dicen bien:

- *Cuántos* 402 hubo en total (podrías contarlos, pero es caro: full scan de texto).
- Correlacionar con otros servicios: ves lo que ocurrió en `bank-adapter`, pero no automáticamente qué pasaba en `payments` al mismo tiempo salvo que compartan `req_id`.

Pregunta que los logs responden bien: **"¿qué dijo el proceso?"**, **"¿qué pasó con este request específico?"**.
Pregunta que **no** responden bien: tendencias agregadas sin pre-cómputo.

---

## 3. Traces — qué dice un trace

Un trace del request `req_id=def456`, visualizado como timeline:

```
req_id=def456  user=77  POST /checkout
├─[frontend]       0 ─────────────────────────────── 2050 ms  (TOTAL)
├─[api-gateway]        5 ─────────────────────────── 2045 ms
├─[orders]                12 ──── 48 ms              (OK)
├─[payments]                      55 ──────── 2042 ms
│   ├─[http: bank-adapter/charge]  60 ──────── 2040 ms
│   │   └─[http: visa-sandbox]       65 ──── 2037 ms   ← timeout del upstream (2000 ms)
│   └─[retry policy]                                  (no reintenta: timeout > budget)
└─ response: 504
```

Lo que te dice:

- **Dónde** se perdió el tiempo: 2 s en el upstream `visa-sandbox`.
- **La cadena causal** del fallo: `frontend → api-gateway → payments → bank-adapter → upstream` — el error nace fuera de tu sistema.
- Qué servicios *no* fueron el problema: `orders` tardó 36 ms y respondió `200`.

Qué **no** te dicen bien:

- Cuántos requests parecidos hubo (necesitarías agregarlos — eso es métrica).
- El mensaje de error textual completo (los logs lo tienen).

Pregunta que los traces responden bien: **"¿dónde se perdió el tiempo en este request?"**, **"¿qué servicio en la cadena falló?"**.

---

## 4. Pilares emergentes

**Events**: anotación en Grafana que dice "deploy `payments` v1.42 a las 10:10". Sin events, no sospechas de la correlación "deploy a las 10:10 → errores desde 10:12". Con events, es la primera hipótesis.

**Continuous profiling**: perfil de CPU/memoria de `payments` muestra que una función nueva (`validate_card()` introducida en v1.42) consume 300 ms extra por request. Explica parte de la latencia. Sin profiling, lo buscas a ciegas.

---

## 5. La tabla a interiorizar

| Pregunta | Pilar primario | Pilar de apoyo |
|----------|----------------|----------------|
| ¿Está pasando algo anormal? | Metrics | — |
| ¿Hay un patrón temporal? | Metrics | Events |
| ¿Qué dijo el servicio a las 10:14:03? | Logs | — |
| ¿Qué pasó con este request concreto? | Traces | Logs (por `req_id`) |
| ¿Dónde se perdió el tiempo? | Traces | Metrics (p99) |
| ¿Esto empezó con el último deploy? | Events + Metrics | — |
| ¿Qué consume CPU extra en este servicio? | Profiling | Metrics |

---

## 6. Mensaje para llevar

- **No elijas un pilar: elige una pregunta y vas al pilar que la responde.**
- Un sistema observable **tiene los tres** correlacionables (labels comunes, `trace_id` en logs, `exemplars` en métricas).
- Intentar responder "¿por qué falló `req_id=def456`?" solo con métricas es imposible por diseño — métricas agregan. Para eso están los traces (y los logs).
- Intentar responder "¿cuántos 5xx en la última hora?" solo con logs es carísimo. Para eso están las métricas.

Siguiente: `../02-pull-vs-push-tradeoffs/` compara el modelo de recolección pull vs push con la misma profundidad.
