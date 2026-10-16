# Ejemplo 01 — `traceparent` walkthrough

## Concepto que demuestra

Descomponer el header **W3C Trace Context** `traceparent` byte a byte usando sólo **Python stdlib** (sin dependencias). Al terminar sabes leer un `traceparent` como lees una fecha ISO.

## Contexto

Cada vez que un servicio HTTP instrumentado con OTel hace una llamada saliente, inyecta este header. Entender su contenido es imprescindible para:

- Debuggear traces rotos ("¿por qué el servicio B empezó un trace nuevo?").
- Verificar manualmente que la propagación funciona (sin backend).
- Correlacionar un log con `trace_id` concreto a un trace en Tempo.

## Objetivo

Al terminar:

- Reconoces las 4 partes del `traceparent`.
- Extraes `trace_id`, `span_id`, flag `sampled` manualmente.
- Entiendes por qué la longitud es siempre **55 caracteres**.

## Prerrequisitos

- `python3` disponible en el PATH. **SKIP el ejemplo si `python3` no está instalado.**
- Un terminal.

## Ejecución

```bash
cd "$(git rev-parse --show-toplevel)/courses/opentelemetry/02-specification-semconv-and-context-propagation/examples/01-traceparent-walkthrough"
bash run.sh
```

Salida esperada (abreviada):

```
== traceparent decoder ==
header: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
length: 55 chars (expected 55)
version   : 00  (W3C v1)
trace_id  : 4bf92f3577b34da6a3ce929d0e0e4736  (128 bits)
span_id   : 00f067aa0ba902b7  (64 bits — parent span of the next hop)
flags     : 01  -> sampled=True
...
```

## Qué está pasando por debajo

El script simplemente hace:

1. Verifica la longitud total (55).
2. Divide por `-`.
3. Valida que cada campo tiene longitud y charset esperados (`[0-9a-f]`).
4. Interpreta el byte de flags: bit 0 = sampled.

No necesita `opentelemetry-api` ni nada: la spec W3C es **suficientemente simple** para parsearse a mano. Esto es, en el fondo, lo que un `TextMapPropagator` hace en el `extract`.

## Variantes para experimentar

Ejecuta de nuevo con un header propio:

```bash
bash run.sh "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01"
```

Prueba un header **inválido** (verás que falla con mensaje claro):

```bash
bash run.sh "00-TOO-SHORT-01"
```

## Limpieza

Nada que limpiar: el script no toca disco fuera de `stdout`.
