# Actividad 03 — ADR: eleccion de nube gestionada (architecture)

## Objetivo

Escribir `ADR-001-managed-k8s.md` en esta carpeta usando el formato
MADR (Context, Decision, Consequences). Elige **una** opcion entre
EKS, GKE Autopilot o AKS para llevar el capstone al stage 9+.

Minimo exigido en el ADR:

- Context: 1 parrafo describiendo el stage y el estado actual.
- Decision: 1 opcion elegida, 1 frase.
- Rationale: minimo 3 criterios comparados (costo, madurez, ergonomia,
  integracion con el pipeline, workload identity, etc.).
- Consequences: que se gana, que se pierde, que decisiones futuras
  quedan condicionadas.

Longitud: 300-600 palabras. Breve y defendible.

## Validacion

```bash
bash tests/validate.sh
```
