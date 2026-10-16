# REFERENCE — sec-01-01-threat-model-exercise

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## Sección 1 — Scope

- **Cubre:** `POST /shorten`, `GET /{code}` (redirección), dashboard de métricas por link, autenticación JWT.
- **Fuera de scope (esta iteración):** panel de administración interno, exportación bulk de analytics, SSO (se verá cuando se integre), backups de Postgres.

Motivo del scope: 3 endpoints es el mínimo útil para dejar emerger las 6 letras de STRIDE sin ceremonia.

## Sección 2 — DFD

```
   [Usuario web] ═══╗
                    ║   HTTPS
   ─ ─ ─ ─ ─ ─ ─ ─ ─╬─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ trust boundary TB-1
                    ▼
                ( Ingress / TLS )
                    │  HTTP interno
   ─ ─ ─ ─ ─ ─ ─ ─ ─│─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ trust boundary TB-2
                    ▼
                ( FastAPI pod: shortener )
                    │                \
                    │ SQL/TLS         \ Redis
                    ▼                  ▼
             [[ Postgres ]]        [[ Redis (rate limit) ]]

   [GitHub Actions] ──► [[ GHCR ]] ──► ArgoCD ──► Kubernetes
   ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  trust boundary TB-3 (supply chain)
```

## Sección 3 — Trust boundaries

- **TB-1 — Internet ↔ Ingress.** Red pública con usuarios no identificados; aquí vive el WAF (si lo hay), TLS y rate limit global. Trust boundary porque todo input entra como no confiable.
- **TB-2 — Ingress ↔ App ns.** NetworkPolicy acepta solo tráfico del ingress controller. Autenticación por request (JWT). Trust boundary porque la autoridad del request se decide aquí.
- **TB-3 — Supply chain (dev → repo → CI → registry → cluster).** Varios actores con permisos distintos; firma de imagen + verificación en admisión. Trust boundary porque un compromiso en cualquier eslabón acaba corriendo en el cluster.

## Sección 4 — Tabla STRIDE priorizada

| ID  | Letra | Amenaza concreta | Likelihood | Impact | Mitigación |
|-----|-------|------------------|------------|--------|------------|
| T01 | S     | JWT firmado con secreto débil → tokens forjados por un atacante. | M | H | Secreto de >=32 bytes random; rotación cada 90 d; algoritmo RS256 cuando se añada SSO. |
| T02 | S     | Credential stuffing contra login (fase 2). | H | M | Rate limit por IP + por email; HIBP check en password; MFA opcional. |
| T03 | T     | Mutación de la imagen en GHCR por un action comprometido (tipo tj-actions). | M | H | Pin de actions por SHA; `permissions:` mínimo; firma de imagen con cosign; verificación en admisión. |
| T04 | T     | Modificación de URLs en la DB por un pod comprometido con credenciales de app. | L | H | Credenciales de app con `UPDATE` limitado al propio owner; audit log en Postgres. |
| T05 | R     | Un usuario crea un link malicioso y niega haberlo hecho (sin audit log). | M | M | Append-only audit log con `user_id`, `trace_id`, `created_at`; retención 1 año. |
| T06 | I     | Stack trace en respuesta HTTP revela estructura interna y versiones de librerías. | M | M | `debug=False`; middleware de error estándar; logs internos con detalle. |
| T07 | I     | Enumeración de códigos cortos (`GET /aaa`, `/aab`, ...) revela destinos privados. | H | M | Códigos de 7+ chars con alfabeto grande; rate limit 404 por IP; opción de link "privado" con auth. |
| T08 | D     | `/shorten` sin rate limit → bot crea millones de links y satura la DB. | H | H | Rate limit por IP (anónimos muy agresivo) y por token; límite de links por user/day. |
| T09 | D     | URL de entrada con esquema `data:` o `javascript:` que explota un parser mal hecho. | L | M | Allow-list de esquemas (`http`, `https`); validación con librería estándar. |
| T10 | E     | El código de generación de códigos cortos usa SQL con f-string → SQLi → RCE. | L | H | ORM parametrizado; Semgrep rule que prohíbe f-string con `execute`; code review. |
| T11 | E     | ServiceAccount del pod con RBAC excesivo (p. ej. list secrets). | M | H | SA dedicado, RBAC mínimo (solo acceso a sus propios secrets); auditar con `kubectl who-can`. |

Leyenda: Likelihood/Impact en `H/M/L`.

## Sección 5 — Assumptions

1. El Ingress termina **TLS** y pasa `X-Forwarded-For` correctamente.
2. Existe un **secret manager** (Vault / Secrets Manager / Sealed Secrets) para el JWT secret y las credenciales de DB.
3. **NetworkPolicy** por defecto deny-all en el cluster, con excepciones explícitas por namespace.
4. **ArgoCD** verifica la firma de la imagen antes de aplicar (configurado como admission).
5. Postgres y Redis **no están expuestos** fuera del cluster; viven en una subnet privada.

Cada assumption es una invitación a un nuevo threat model si cambia (p. ej. si Redis se mueve a managed con endpoint público, TB-2 se mueve).

## Lo que *no* está en esta iteración (open questions)

- **Backups** (dónde, cifrados, quién puede restaurar).
- **Analytics bulk export**: cuando aparezca, re-visitar `I` (information disclosure).
- **Custom domain por user**: cuando aparezca, re-visitar `S` (DNS hijack / cert mis-issuance) y `T` (routing).

## Punto a repetir hasta que suene aburrido

> Un threat model útil cabe en una página, tiene **fecha**, enumera **todas las letras de STRIDE** aunque algunas estén marcadas como "N/A por X", y produce **mitigaciones que son tickets**, no eslóganes.
