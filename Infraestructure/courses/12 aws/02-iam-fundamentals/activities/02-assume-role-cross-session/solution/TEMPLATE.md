# TEMPLATE — SESSION.md scaffolding

> Copia este esqueleto a `/tmp/aws-02-chain/SESSION.md` y rellena las secciones. No es la solución; es un andamio.

## Cadena

```
   <actor humano>
       │  <como se obtiene la sesion inicial>
       ▼
   <permission set / rol intermedio>  (cuenta <id>)
       │  <llamada STS>
       ▼
   <rol final>                        (cuenta <id>)
       │
       ▼
   <operaciones S3 reales>
```

## Qué hace STS en cada salto

- Salto 1 (… → OperatorRole): …
- Salto 2 (OperatorRole → ProdS3Admin): …

## Trazas en CloudTrail

- Evento 1: …
- Evento 2: …
- `userIdentity.arn` tras cada salto: …

## Por qué este diseño y no "S3FullAccess a Alice"

- …
- …

## Rol del ExternalId

<párrafo con el ataque del confused deputy y cómo lo mitiga>
