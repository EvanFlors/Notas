# REFERENCE — sec-13-02-rotation-and-break-glass-adr

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## Status

Accepted

## Context (modelo)

Organización ficticia **Acme Payments**: 25 microservicios en Python/Go, 2 clusters EKS (`prod` y `staging`), 1 cuenta AWS, 15 ingenieros. Hoy los secretos viven en `GITHUB_SECRETS` + `Secret` K8s escritos a mano (base64); la última rotación de la password del Postgres principal fue hace **18 meses**. SOC2 Type I en 90 días; auditor pedirá demostrar rotación demostrable y audit log de accesos. Equipo de seguridad = 1 persona a tiempo parcial. Vault se desplegará auto-gestionado en EKS (HA 3 nodos, auto-unseal con KMS).

## Decision

### A. Tabla de rotación (modelo)

| Secreto | Familia | Trigger | TTL / Frecuencia | Mecanismo | Zero-downtime | Blast radius de fuga |
|---------|---------|---------|------------------|-----------|---------------|----------------------|
| DB password (Postgres principal) | **dynamic** | TTL vencido | 60 min | Vault `database/` emite role por app; app usa cliente que renueva al 2/3 del lease | sí (pool deja drenar y reconecta) | ≤ 60 min |
| API key Stripe (SaaS externo) | **estatico-rotado-automatizado** | cron 90 días | 90 días | Script serverless llama a Stripe API `rotateKey`, nuevo valor va a Vault `kv/stripe`, ESO refresca `Secret` K8s, reloader hace rolling | sí (ventana de "doble key" 24h) | hasta rotación (90d) o detección |
| Cert TLS wildcard `*.acme.io` | **estatico-rotado-automatizado** | 1/3 TTL (ACME) | 90 días emitido, renew a 60d | cert-manager + Vault PKI (o Let's Encrypt para público); ingress reload graceful | sí | hasta expiración |
| OAuth client secret (Okta) | **estatico-rotado-humano** | compromiso o cambio de app | años (política Okta) | Humano con 2FA en consola Okta → `vault kv put oidc/<app>` → ESO refresca | no (requiere reinicio controlado) | hasta rotación manual |
| SSH host key del bastion | **n/a — no rotable** | reemplazo físico/reinstall | nunca | Protección: `AuthorizedKeysCommand` con Vault SSH signer; los *clientes* usan certificados SSH efímeros emitidos por Vault (TTL 15 min) | n/a | n/a (si se compromete, se reinstala el host) |
| Encryption key column-level (PII) | **dynamic (transit)** | rotación de versión | manual trimestral | `vault write -f transit/keys/pii/rotate`; ciphertexts viejos siguen descifrando (v1), nuevos usan v2 | sí (sin tocar datos) | mínimo (clave nunca sale de Vault) |

Observa: el SSH host key **no entra** en el modelo "rotación periódica" porque rotarlo es desinstalar y reinstalar el host. La respuesta correcta es cambiar la pregunta: **no rotes el host key, elimina las claves SSH estáticas de los clientes** y emite certificados SSH efímeros desde Vault. El problema se evapora.

### B. Procedimiento de break-glass (modelo)

**Contexto de uso:** on-call necesita leer un secreto fuera del flujo normal (típicamente, un SaaS externo expiró de madrugada y hay que pegar la nueva API key en un endpoint caliente).

1. **Autenticación fuerte** — el on-call hace `vault login -method=oidc` contra Okta corporativo, que requiere SSO + YubiKey (hardware FIDO2). No existe un `root token` compartido; no hay password escrita.
2. **Scope mínimo** — tras el login, el on-call ejecuta `vault write auth/token/create -policy=break-glass -ttl=15m -explicit-max-ttl=15m -orphan=true`. La policy `break-glass` **solo** permite `read` sobre `kv/data/break-glass/*`. **Nunca** `root`, **nunca** `sudo`.
3. **TTL explícito** — el token vive 15 min. Vault lo revoca automáticamente. Un segundo intento requiere nuevo login SSO+YubiKey (así se registra una segunda entrada en el audit log).
4. **Rastro inmutable** — Vault audit device apunta a S3 con Object Lock (compliance mode, retention 7 años). Campos registrados: `timestamp`, `request_id`, `identity (OIDC sub)`, `path`, `operation`, `source_ip`, `token_ttl`, `hmac(response)`. El bucket **no es writable** por los admins de Vault (separation of duty con el equipo de seguridad).
5. **Review post-mortem obligatorio** — Pager llama a `#security-oncall` automáticamente cada vez que un token con policy `break-glass` se emite. En < 24 h, el equipo de seguridad valida la entrada; si no se justifica (p. ej. no hay ticket incident abierto), se abre un `SEV-3` para investigar.

Propiedades extra (no exigidas, recomendadas):

- **Doble autenticación de 2** para accesos a `kv/data/root-of-trust/*` (p. ej. unseal keys, cert raíz PKI): dos on-calls distintos deben autorizar, Vault enforced con `control_group`.
- **Dry-run anual** del procedimiento (gameday): se simula una expiración y se cronometra tiempo total `page → secret-in-hand`. Objetivo < 10 min.

## Consequences (modelo)

**Ganamos:**

- Rotación demostrable: para los secretos *dynamic* es automática y auditada; para los estáticos-automatizados, el log del cron script lo prueba.
- Audit log centralizado responde a las preguntas del auditor en 1 query.
- Blast radius colapsado para la DB (de 18 meses a 60 min) y para la encryption key (nunca sale de Vault).
- Eliminación del `root token` compartido como vector de ataque interno.

**Perdemos:**

- Curva de aprendizaje: el equipo tiene que aprender Vault policies, ESO CRDs y cert-manager. 2–3 sprints de ramp-up.
- Nueva dependencia operativa: si Vault se cae, los Pods que piden *dynamic* creds nuevas no arrancan. Se mitiga con HA (3 nodos) + auto-unseal + playbook "DR Vault" probado trimestralmente.
- Costo de infraestructura: 3 nodos Vault + S3 Object Lock. Marginal frente al costo de un breach.

**Asumimos:**

- La API externa de Stripe soporta "doble key" durante la ventana de rotación. Si no, aceptamos reinicio controlado (ventana de mantenimiento).
- El procedimiento de break-glass se practica. Un procedimiento no ejercitado es un procedimiento ficticio.

**Pendiente para la próxima iteración:**

- Añadir IRSA a los Pods para eliminar las últimas credenciales AWS estáticas que aún llegan vía `Secret`.
- Migrar los secretos de CI (GitHub Actions) a Vault vía auth JWT/OIDC (ya no `GITHUB_SECRETS`).
- Column-level encryption de PII con `transit` (hoy el schema expone email en claro).

## Punto a repetir hasta que suene aburrido

> **Rotar** un secreto no es un evento operativo: es la **propiedad** del TTL. Si rotas con cron, estás un paso por detrás; si rotas con TTL, el atacante lo está.
