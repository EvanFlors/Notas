# REFERENCE — sec-02-02-rotation-policy-adr

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

---

## Status

Status: Accepted (2026-10-16)

## Context

El capstone del curso (FastAPI + Postgres + Redis + Stripe + Datadog, desplegado en EKS vía GitHub Actions + Argo CD) opera con una colección heterogénea de secretos (ver `INVENTORY.md` de la actividad `01`). Hoy no existe política escrita: cada equipo rota — o no — a su criterio. El próximo paso de madurez es fijar un **TTL por familia**, un **mecanismo de rotación por familia**, y un **procedimiento de break-glass** con separation of duties. Esta decisión debe:

- Reducir el blast radius de los secretos long-lived (ver §6 y §8 de la lección).
- Ser **operable**: lo que no es automático se salta.
- Ser auditable (todas las rotaciones y break-glass dejan registro inmutable).

## Decision

### (a) TTL por familia

| familia       | TTL objetivo | mecanismo de rotacion                      | detectability | owner      |
|---------------|--------------|--------------------------------------------|---------------|------------|
| api-key       | 90d          | reemplazo atomico via secret manager       | medio         | platform   |
| db-cred       | 1h           | TTL expiration (Vault dynamic DB engine)   | alto          | data       |
| oauth-access  | 15m          | TTL expiration (IdP)                       | alto          | platform   |
| oauth-refresh | 30d          | reemplazo atomico (IdP)                    | medio         | platform   |
| cert          | 60d          | ACME auto-renew (cert-manager)             | alto          | platform   |
| ssh           | 24h          | SSH CA + certificado efimero firmado       | medio         | platform   |
| signing       | 10m          | sigstore keyless (certificado efimero)     | alto          | security   |
| encryption    | 1 año        | dual-write + KMS key versioning            | n/a           | data       |

**Justificación por familia**:

- `api-key` (SaaS como Stripe, Datadog): 90 d es el punto donde el coste operativo (rotación manual coordinada con el proveedor) cruza al beneficio marginal. Los proveedores que soportan OAuth o STS no entran aquí; esos migran a `oauth-access`.
- `db-cred`: Vault emite usuario+password on-demand con TTL 1 h. La "rotación" es simplemente el vencimiento del lease. Esto elimina de raíz la pregunta "¿rotamos hoy?".
- `oauth-access` / `oauth-refresh`: se adoptan los TTLs recomendados por el IdP (15 m / 30 d). No se custodian; se renuevan.
- `cert`: ACME con cert-manager renueva automáticamente ~30 d antes de la expiración; se fija el TTL del cert en 60 d para dar margen.
- `ssh`: no se usan `~/.ssh/id_*` long-lived. Se emite un **cert SSH** firmado por una CA interna con TTL 24 h; el usuario autentica a la CA con SSO.
- `signing`: cosign keyless. Cada firma usa un certificado efímero de Fulcio (TTL ~10 min) ligado al OIDC claim del workflow. No hay signing key custodiada.
- `encryption` (KMS CMKs y KEKs): la clave **no sale** del módulo. La rotación es `KMS key versioning` anual + dual-write durante el periodo de solape.

### (b) Proceso de break-glass

Objetivo: habilitar acceso de emergencia a secretos de producción cuando el canal normal (Vault / IdP) está caído, **sin crear long-lived latentes**.

- **Credencial break-glass** (BG-cred) custodiada **wrapping-encrypted en KMS** con política que requiere **2-persona approval** vía ticket (quorum).
- **Mecanismo separado**: la BG-cred no vive en Vault (el que puede estar caído); vive en un bucket con object-lock + KMS key en una cuenta distinta.
- **Separation of duties (SoD)**: el que **aprueba** el unwrap no es el que lo **ejecuta**. Platform-lead aprueba; on-call ejecuta.
- **TTL del uso**: la BG-cred, una vez desenvuelta, se usa durante ≤15 min y se **rota inmediatamente** al cerrar el incidente (automatizado por el runbook).
- **Audit**: cada unwrap dispara alerta al SIEM, deja log en CloudTrail + Vault audit log, y abre un ticket de post-mortem obligatorio.
- **Ensayo trimestral**: se practica el procedimiento en staging; si no se ha ejecutado en 90 d, se abre acción.

## Consequences

**Beneficios**:

- Blast radius de todas las familias cae en ≥1 orden de magnitud. En particular `db-cred` y `signing` pasan de "secret custodiado" a "sin secret estático".
- Rotación de 3 familias (db, oauth, signing) deja de ser trabajo humano (**pasa a TTL expiration**).
- Las alertas se concentran en 2 familias (`api-key`, `oauth-refresh`), que es lo humano puede sostener.

**Costes**:

- Infra Vault + mantenimiento (upgrades, backups, break-glass trimestral): aprox. **0.3 FTE** sostenido.
- Setup de SSH CA + emisión de certs: ~2 semanas iniciales + onboarding de personas (training).
- cosign keyless requiere `fulcio` y `rekor` accesibles desde CI; la indisponibilidad de Sigstore paraliza nuevos releases (ver §Alternatives).
- Mayor latencia percibida al "pedir acceso" en incidentes (break-glass con quorum). Mitigado por ensayo trimestral.

**Riesgos residuales aceptados**:

- La BG-cred es un single-point-of-trust por diseño. Lo mitigamos con wrapping KMS + separation of duties + SIEM alerting.
- Si el IdP de OIDC se compromete, todos los tokens short-lived son emitibles por el atacante. Fuera del scope de esta política — se cubre en `sec-11`/plataforma.

## Alternatives considered

1. **"Rotar todo cada 90 días" (política plana).** Descartada: ignora que algunas familias **no** necesitan rotación manual (db dynamic, keyless signing) y otras requieren TTL mucho más corto (oauth access). Convertiría ambos extremos en placebo.
2. **"No rotar nada, confiar en secret scanning + alerting".** Descartada: scanning detecta exposiciones **tras** la fuga, no reduce la ventana. Sin rotación, cualquier filtración es permanente hasta descubrimiento.
3. **"Vault para todo, con TTL manual por secret".** Descartada: aunque técnicamente posible, convierte Vault en una `cron` ritualista. Prefiero mecanismos que *excluyen* la posibilidad de secret long-lived (dynamic DB, keyless) frente a políticas que *desaconsejan* uno.
4. **"Externalizar la custodia a un servicio comercial (Doppler/1Password Secrets Automation)".** Descartada **de momento**: operar Vault + KMS internos es coste conocido; añadir un cuarto vendor crítico a la supply chain es coste nuevo. Reevaluar en 12 meses.

## References

- Lección `../../theory/lesson.md`, §5 (principios), §6 (short-lived), §9 (rotación), §10 (SoD), §11 (break-glass).
- Ejemplo `../../examples/02-long-lived-vs-short-lived/README.md`.
- NIST SP 800-57 Part 1 — Recommendation for Key Management (claves y periodos criptográficos).
- OWASP Secrets Management Cheat Sheet.
- HashiCorp Vault — Dynamic Secrets, DB Secrets Engine.
- AWS — IAM Roles for Service Accounts (IRSA), STS AssumeRole.
- Sigstore — Fulcio + Rekor, keyless signing.
- GitHub Docs — About security hardening with OpenID Connect.

---

## Punto a repetir hasta que suene aburrido

> La política correcta **no es un número único**; es un número **por familia**, defendido por el blast radius y respaldado por un mecanismo que haga la rotación **inevitable** (TTL expiration > reemplazo atómico > runbook manual).
