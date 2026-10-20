# Reference solution — otel-03-02

> Reference answers for self-grading only. Many defensible variants exist.

## Escenario 1 — checkout-api

Decisión: **auto + manual**.

- SDK Python maduro, framework (FastAPI) con instrumentation library oficial.
- `opentelemetry-instrument uvicorn app:app` cubre HTTP, DB, Redis gratis.
- Añade spans manuales para `apply_coupon`, `reserve_inventory`, `charge_card` — son fronteras de negocio con atributos no obvios desde el perímetro HTTP.
- eBPF aquí sería ruido: ya ves la red, lo que falta es *intent* de dominio.

## Escenario 2 — legacy-pricing

Decisión: **eBPF (Grafana Beyla o Pixie)**.

- No hay fuente → no puedes instalar SDK ni paquete `*-instrumentation-*`.
- Beyla a nivel de nodo detecta HTTP/gRPC vía uprobes y emite OTLP sin tocar el binario.
- Trade-off: solo verás RED básico y atributos de red; nada de lógica interna.
- Alternativa de medio plazo: pedir rebuild con SDK Go OTel + instrumentation `net/http`. Beyla cubre el *gap* mientras tanto.

## Escenario 3 — payments-worker

Decisión: **auto + manual (fuerte)**.

- `opentelemetry-instrumentation-celery` propaga el context entre el caller y el worker — crítico para que el trace del cobro no se corte.
- Manual: 1 span por fase del cobro ("charge.authorize", "charge.capture"), con atributos no sensibles (`payment.gateway`, `payment.amount_cents`, nunca PAN ni email).
- eBPF insuficiente aquí: la pasarela externa es HTTPS y la correlación requiere propagar `traceparent` en headers, lo que solo hace el SDK.

## Escenario 4 — cron-sync-bash

Decisión: **ninguna / eBPF opcional a nivel nodo**.

- No merece instalar un SDK en Bash para un job de 30 s cada 15 min.
- Si el host ya tiene Beyla/Pixie, el tráfico HTTP del `curl` aparece automáticamente.
- Si quieres duración/éxito, basta exportar un `Counter` + `Histogram` desde el wrapper que lanza el cron (p. ej. systemd timer + unit script que emite métrica a Pushgateway o OTLP vía `curl`). Pero *no* es manual-span en Bash.

## Síntesis — 5 criterios

1. Si tengo el código y el SDK está maduro para el lenguaje: **auto + manual**. Punto.
2. Si no tengo el código o el SDK está inmaduro: **eBPF (Beyla/Pixie)** para dar RED básico y planificar rebuild.
3. Los spans manuales se justifican por **fronteras de dominio** (operaciones nombradas), no por profundidad arbitraria.
4. **Context propagation** cross-proceso (celery, Kafka, gRPC) exige SDK + instrumentation library — eBPF no inyecta `traceparent`.
5. Procesos **efímeros muy cortos** (sub-minuto, pocos invocados por hora) pueden quedar fuera; mide primero su RED agregada vía Beyla a nivel nodo antes de instrumentar código.
