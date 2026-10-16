# Ejemplo 03 — Baggage encode / decode

## Concepto que demuestra

El header **W3C Baggage** se parsea trivialmente, pero su **tamaño total** suma por hop. Este ejemplo:

- Encodea un dict Python a header `baggage`.
- Decodea un header a dict.
- Mide el **overhead por hop**: cuántos bytes se añaden por request con N claves.

## Contexto

Baggage es tentador: "lo meto una vez y lo tengo en todos los servicios". El coste real es que viaja en **cada** request HTTP del trace. Entenderlo cuantitativamente es la diferencia entre usarlo bien o romper la red del cluster.

## Objetivo

- Entender el formato del header `baggage`.
- Medir el overhead por hop con 1, 5, 20 keys.
- Reconocer las claves que **nunca** deben ir en Baggage (PII, alta cardinalidad).

## Prerrequisitos

- `python3`. **SKIP si no está.**

## Ejecución

```bash
cd "$(git rev-parse --show-toplevel)/courses/opentelemetry/02-specification-semconv-and-context-propagation/examples/03-baggage-example"
bash run.sh
```

Salida esperada (abreviada):

```
== encode ==
{'userId': 'u-123', 'tenant': 'acme', 'experiment': 'checkout-v2'}
baggage: userId=u-123,tenant=acme,experiment=checkout-v2
bytes: 48

== decode ==
header: userId=u-123,tenant=acme,experiment=checkout-v2
dict: {'userId': 'u-123', 'tenant': 'acme', 'experiment': 'checkout-v2'}

== overhead per hop ==
 1 keys ->  18 bytes/header -> 10 hops =  180 bytes/request
 5 keys ->  ...
20 keys -> ...

== DO NOT put in Baggage ==
  - email, ssn, token (PII / secrets)
  - request_id (high cardinality, use trace_id instead)
  - timestamps (change every hop)
```

## Qué está pasando por debajo

El encoder hace `",".join(f"{k}={quote(v)}" for k, v in d.items())`. Nada más. El decoder hace lo contrario. La spec admite metadata opcional por par (`;sampled=true`), aquí se omite por simplicidad.

El cálculo de overhead multiplica por un número típico de hops (10) para hacer tangible que un Baggage de ~500 bytes y 10 hops = **5 KB por request** sólo en headers.

## Limpieza

Nada que limpiar.
