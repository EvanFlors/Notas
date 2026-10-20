# Starter — az-04-01-choose-compute-and-adr

Esta actividad es **independiente**: produces un unico archivo Markdown.

## Pasos

1. Lee `../README.md` completo y recorre los tres `../../examples/`.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/az-04-01
   cd /tmp/az-04-01
   ```
3. Escribe `ADR-COMPUTE-CHOICE.md` siguiendo el formato ADR de 6 secciones.
4. Valida:
   ```bash
   bash <ruta-repo>/courses/azure/04-compute-vm-vmss-container-apps-functions-app-service/activities/01-choose-compute-and-adr/tests/validate.sh /tmp/az-04-01
   ```
5. Compara con `../solution/REFERENCE.md` para autoevaluarte.

## Esqueleto minimo

```markdown
# ADR 001 — Eleccion de compute Azure para checkout-api, etl-nightly y billing-worker

## Estado
Propuesto

## Contexto
...

## Decision

### Tabla comparativa

| Opcion | Cold start | Portabilidad | Coste tipico | Operabilidad |
|--------|------------|--------------|---------------|---------------|
| VM | ... | ... | ... | ... |
| VMSS | ... | ... | ... | ... |
| App Service | ... | ... | ... | ... |
| Container Apps | ... | ... | ... | ... |
| Functions | ... | ... | ... | ... |

### checkout-api
Eleccion: ...

### etl-nightly
Eleccion: ...

### billing-worker
Eleccion: ...

## Consecuencias
...

## Alternativas descartadas

### Alternativa 1 para checkout-api: ...
### Alternativa 2 para etl-nightly: ...
```

## Checklist mental antes de validar

- [ ] Las 6 secciones del ADR estan.
- [ ] Al menos 5 familias de compute en la tabla.
- [ ] Los 3 workloads (`checkout-api`, `etl-nightly`, `billing-worker`) nombrados.
- [ ] Mencion de **cold-start**, **coste** y **portabilidad**.
- [ ] Mencion de **Managed Identity** y de **Europa**.
- [ ] Al menos 2 alternativas descartadas.
- [ ] Al menos un code fence.
- [ ] Al menos una comparacion AWS <-> Azure.
