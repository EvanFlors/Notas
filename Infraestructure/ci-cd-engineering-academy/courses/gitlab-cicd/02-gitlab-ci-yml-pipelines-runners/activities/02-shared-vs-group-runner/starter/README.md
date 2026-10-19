# Starter — gl-02-02

## Qué hay aquí

Nada ejecutable. El trabajo es un **documento**: `ADR-RUNNERS.md` en `/tmp/gl-02-02/`.

## Guión mental sugerido

1. **Enumera criterios** antes de escribir prosa. Mínimo:
   - Coste (minutos SaaS vs infra propia).
   - Red (necesidad o no de VPC/VPN).
   - Secretos (quién puede exponerlos; cómo se montan).
   - Autoscaling (cuánta carga pico esperas).
   - Compliance (hay auditores pidiendo logs del runner).
   - Operación (0.5 FTE — ¿alcanza?).
2. **Aplica cada criterio a cada workload**:
   - `checkout` necesita Vault + Secrets Manager AWS vía red privada → shared no sirve bien.
   - `analytics` es 20 ejec/día de 2 min → shared cabe sobrado en Free (20 × 2 × 20 días ≈ 800 min, excede Free; recalcula o acepta overage; mejor: 20 × 2 × 20 = 800 min, excede 400 Free → considera group o Premium).
3. **Decide** por workload y escribe el ADR con el formato del README.
4. **Materializa en YAML**: incluye un bloque de código mostrando los `tags:` que ambos jobs usarían.

## Pistas que no son trampa

- Tags convencionales que podrías inventar: `acme-platform`, `vpc-prod`, `vault`, `saas-linux-small-amd64`.
- "Hybrid" es una respuesta válida: shared para `analytics`, group para `checkout`.
