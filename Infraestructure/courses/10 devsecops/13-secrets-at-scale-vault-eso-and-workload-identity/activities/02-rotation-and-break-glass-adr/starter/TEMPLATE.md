# ADR-00X — Política de rotación de secretos y procedimiento de break-glass

## Status

Accepted

## Context

<Describe en 1–2 párrafos la organización ficticia (tamaño, cloud, nº servicios, nº clusters), qué está rompiendo hoy (secrets vivos N años, sin audit, rotación olvidada) y qué constraints no negociables tienes (SOC2 en 90 días, presupuesto, equipo).>

## Decision

### A. Tabla de rotación por tipo de secreto

| Secreto | Familia | Trigger | TTL / Frecuencia | Mecanismo | Zero-downtime | Blast radius de fuga |
|---------|---------|---------|------------------|-----------|---------------|----------------------|
| DB password (Postgres propio)   | dynamic                        | TTL vencido | 60 min | Vault `database/` + pool rotation en app | sí | ≤ 60 min |
| API key externa (<servicio>)    | estatico-rotado-automatizado   | <...>       | <...>  | <...>                                    | <...> | <...>  |
| Cert TLS <wildcard/public>      | <familia>                      | <...>       | <...>  | <...>                                    | <...> | <...>  |
| OAuth client secret (<idp>)     | <familia>                      | <...>       | <...>  | <...>                                    | <...> | <...>  |
| SSH host key del bastion        | <familia>                      | <...>       | <...>  | <...>                                    | <...> | <...>  |

Notas (opcional, justifica las familias ambiguas):

- <...>

### B. Procedimiento de break-glass

1. **Autenticación fuerte:** <describe cómo el on-call se autentica — ej. SSO corporativo + hardware key YubiKey + MFA push>.
2. **Scope mínimo:** <qué policy Vault se activa — ej. `break-glass-datadog` que solo permite `read` sobre `kv/data/datadog/*`>.
3. **TTL explícito:** <el token de break-glass vive X minutos y se auto-revoca>.
4. **Rastro inmutable:** <el audit log Vault va a <sink append-only con retention Y>; los campos registrados son <identity, path, operation, timestamp, source_ip, request_id>>.
5. **Review post-mortem:** <en < 24 h el equipo de seguridad revisa la entrada; si no se justifica, se abre un incidente>.

## Consequences

<1–2 párrafos. Qué ganas, qué pierdes, qué asumes.>

- **Ganamos:** <...>.
- **Perdemos:** <...>.
- **Asumimos:** <...>.
- **Pendiente para la próxima iteración:** <...>.
