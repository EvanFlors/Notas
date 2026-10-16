# Starter — sec-11-02-exception-workflow

Esta actividad es **independiente**. Produces `ADR.md`, `TEMPLATE.yaml`, `PROCESS.md`.

## Pasos

1. Lee `../README.md`.
2. Prepara el scratch:
   ```bash
   mkdir -p /tmp/sec-11-exception
   cd /tmp/sec-11-exception
   ```
3. Escribe `ADR.md` (contexto / decisión / alternativas rechazadas / consecuencias).
4. Escribe `TEMPLATE.yaml` (una `PolicyException` con anotaciones de auditoría).
5. Escribe `PROCESS.md` (solicitud / aprobación / TTL / expiración / auditoría).
6. Valida:
   ```bash
   bash <repo>/courses/devsecops/11-k8s-admission-kyverno-and-policy-controller/activities/02-exception-workflow/tests/validate.sh /tmp/sec-11-exception
   ```
7. Compara con `../solution/REFERENCE.md`.

## Limpieza

```bash
rm -rf /tmp/sec-11-exception
```
