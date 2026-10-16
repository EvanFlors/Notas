# 02 — Propagate via Kafka headers (sin broker)

Simula el patrón productor/consumidor de Kafka **sin broker**: una cola `multiprocessing.Queue` reemplaza al broker. Lo importante es el patrón de **inject en headers** y **extract en el consumer**.

En Kafka real los headers son `List[Tuple[str, bytes]]`; aquí los representamos como `dict[str, str]` por brevedad. El código del inject/extract es idéntico al que escribirías con `kafka-python` o `confluent-kafka`.

## Cómo correrlo

```bash
bash run.sh
```

El script arranca un consumer en background, el producer publica un mensaje, el consumer lo procesa y ambos imprimen sus spans. Deben compartir `trace_id`.

## Puntos clave en el código

- Productor: abre un `SpanKind.PRODUCER` y hace `inject(carrier)` **dentro** del span (para que el carrier serialice ese span como parent).
- Consumidor: hace `extract(carrier)` y abre su propio span con `kind=SpanKind.CONSUMER` **usando** ese context como parent.
- En Kafka real, la relación "productor → consumidor" se modela mejor con **span link** (`add_link`) que con parent/child, porque el productor normalmente ya cerró su span. Aquí usamos parent/child por simplicidad didáctica; el ejercicio real está en el carrier.
