# Solución de referencia — gl-02-02

> Usa esta referencia **después** de intentar la actividad. El validador comprueba estructura, no identidad textual.

## ADR propuesto

```
# ADR 002 — Estrategia de runners para acme/

## Estado
Aceptado

## Contexto
acme/ es un group recién creado en gitlab.com (plan Free, 400 min CI/CD/mes).
Dos proyectos entran a CI/CD en semana 1:
- acme/checkout: API de pagos; sus pipelines deben leer credenciales desde
  HashiCorp Vault (interno, accesible solo desde VPC) y asumir un rol en
  AWS para desplegar.
- acme/analytics: lint + pytest de notebooks; ~20 ejecuciones/día de ~2 min;
  sin secretos externos.
Operación: 0.5 FTE de platform engineering disponible.

## Decisión
- acme/checkout usa un group runner propio en la VPC de la startup
  (`tags: [acme-platform, vpc-prod, docker]`). Permite acceso de red a
  Vault y mantener el token de AWS a mano (vía ID Token/OIDC — ver gl-03).
- acme/analytics usa shared SaaS runners (`tags: [saas-linux-small-amd64]`
  o sin tags). Carga baja; no necesita red privada.
- Los runners se registran con **authentication tokens** (no registration
  tokens, que están deprecados).

Ejemplo mínimo en checkout/.gitlab-ci.yml:

```yaml
default:
  tags: [acme-platform, vpc-prod, docker]
```

Ejemplo mínimo en analytics/.gitlab-ci.yml:

```yaml
default:
  tags: [saas-linux-small-amd64]
```

## Consecuencias
Positivas:
- checkout aisla sus secretos y accede a Vault sin exponer tokens.
- analytics no consume capacidad del runner privado (lo deja libre para
  checkout).
- 0.5 FTE basta para operar 1 runner propio (K8s pod o VM pequeña).

Negativas:
- Mantener el runner privado implica actualizar gitlab-runner, parchar la
  VM/pod, rotar el auth token.
- Si analytics crece a 500 ejec/día (800+ min/mes), rebasa la cuota Free
  y hay que migrar a group runner o pasar a Premium.

Criterios aplicados: coste (minutos SaaS vs infra); red (VPC); secretos
(Vault); autoscaling (shared es elástico); operación (0.5 FTE).

## Alternativas descartadas

1. Shared SaaS para los dos proyectos.
   Rechazada: checkout no puede alcanzar Vault desde SaaS; abrir Vault
   a internet rompe el modelo de seguridad.

2. Group runner propio para los dos proyectos.
   Rechazada: innecesario para analytics (gasto de infra sin beneficio) y
   consume capacidad que checkout podría necesitar.

3. Project runner dedicado a checkout.
   Rechazada: equivalente operacionalmente al group runner pero sin
   compartir con futuros proyectos del group (p. ej. acme/billing). El
   group runner escala mejor.

## Fase 2 (opcional)
Cuando el group crezca a 5+ proyectos, considerar migrar a 2 group runners
(uno con acceso a VPC, otro general) y usar tags para enrutar.
```

## Puntos clave de la decisión

1. **Hybrid gana**. Mezclar shared + group es idiomático y refleja la realidad: cada workload tiene sus restricciones.
2. **El criterio decisivo es la red privada**. Si Vault es local a VPC, shared SaaS *estructuralmente* no puede. Es un veto, no un trade-off.
3. **Group > Project** cuando el group ya existe. Project runners son para aislamientos extremos.
4. **Authentication tokens** (no registration tokens) es la vía 2026.

## Autoevaluación

- [ ] ¿Mencionaste shared y group explícitamente?
- [ ] ¿Nombraste al menos 3 criterios y los aplicaste?
- [ ] ¿Nombraste 2 alternativas con razones?
- [ ] ¿Incluiste un bloque YAML con `tags:`?
- [ ] ¿Mencionaste `checkout` y `analytics` por nombre?
- [ ] ¿Mencionaste `gitlab.com` / SaaS?
