# Ejemplo 02 — DFD del capstone con trust boundaries

> Lectura y análisis. Sin ejecución. Objetivo: traducir un stack realista (el capstone del programa) a un DFD mínimo útil, marcando trust boundaries.

## 1. El capstone (recordatorio)

El capstone del programa es una aplicación FastAPI desplegada en Kubernetes, con:

- **FastAPI** (API HTTP), **Postgres** (datos), **Redis** (cache + rate limit), **MinIO/S3** (object storage).
- **Observabilidad**: Prometheus + Grafana + OTel Collector + Loki/Tempo.
- **CI/CD**: GitHub Actions → image registry (GHCR) → ArgoCD → Kubernetes.
- **IaC**: Terraform para infra base; Helm charts para la app.

## 2. DFD completo (ASCII)

```
                             INTERNET
                                │
                                │  HTTPS
   ═════════════════════════════│══════════════════════════════════════
                                │              TB-1  internet ↔ ingress
                                ▼
                        ( Ingress / TLS )
                                │  HTTP interno
   ─────────────────────────────│──────────────────────────────────────
                                │              TB-2  ingress ↔ app ns
                                ▼
                        ( FastAPI pod )
                       /         │        \
                      / SQL/TLS  │ cache   \  s3 api
                     ▼           ▼          ▼
               [[ Postgres ]] [[ Redis ]]  [[ MinIO/S3 ]]
   ─────────────────────────────────────────────────────────────────────
                                                   TB-3  data stores

   ──────────────── observability plane ────────────────────────────────
         FastAPI ──► OTLP ──► ( OTel Collector )
                                     │
                              ┌──────┼──────┐
                              ▼      ▼      ▼
                        Prometheus Tempo  Loki ──► Grafana  (UI, SSO)
   ─────────────────────────────────────────────────────────────────────
                                                   TB-4  obs plane

   ──────────────── delivery plane ─────────────────────────────────────
       [ Developer ] ──► [[ GitHub repo ]] ──► ( GitHub Actions )
                                                      │ build + push
                                                      ▼
                                              [[ GHCR registry ]]
                                                      │  pull (ArgoCD)
                                                      ▼
                                              ( ArgoCD ) ──► Kubernetes
   ─────────────────────────────────────────────────────────────────────
                                                   TB-5  supply chain

   ──────────────── infra plane ────────────────────────────────────────
       [ Platform engineer ] ──► ( Terraform ) ──► Cloud API
                                        │
                                        └──► remote state (S3 + lock)
   ─────────────────────────────────────────────────────────────────────
                                                   TB-6  infra plane
```

## 3. Inventario de trust boundaries

| # | Boundary | Qué separa | Decisión clave en el cruce |
|---|----------|------------|----------------------------|
| **TB-1** | Internet ↔ Ingress | Red pública ↔ VPC | TLS; WAF opcional; rate limit global. |
| **TB-2** | Ingress ↔ Namespace de la app | Red "DMZ" ↔ app pods | NetworkPolicy que solo acepta tráfico del ingress controller; autenticación/autorización por request. |
| **TB-3** | App ↔ Data stores | App pod ↔ Postgres/Redis/MinIO | Credenciales dedicadas por servicio; TLS si cruza nodos; NetworkPolicy por puerto. |
| **TB-4** | App ↔ Observability plane | Datos de telemetría salen del app ns | Sanitización de PII; OTLP con mTLS en multi-tenant; retención de Loki/Tempo según sensibilidad. |
| **TB-5** | Supply chain (dev → repo → CI → registry → cluster) | Múltiples actores con autoridad distinta en cada paso | Protected branches; required reviews; `permissions:` mínimos en Actions; firma de imagen; verificación en admisión (`sec-09`, `sec-11`). |
| **TB-6** | Infra plane (platform ↔ cloud API) | Humano/CI ↔ control plane cloud | OIDC federation (sin long-lived keys); state cifrado y con lock; audit logs CloudTrail/equivalente. |

## 4. Observaciones (lo que un DFD revela)

- **TB-5 es el más complejo**: hay 4 actores (dev, repo, CI, registry, cluster) y una cadena de confianza que es tan fuerte como el eslabón más débil. Es exactamente la cadena que SolarWinds y tj-actions atacaron.
- **TB-4 es fácil de olvidar**: la telemetría *sale* del boundary de la app y a menudo viaja sin cifrar en clusters pequeños.
- **TB-3 interna frecuentemente mal protegida**: muchos despliegues ponen Redis sin password porque "está en la VPC" — eso ignora que un pod comprometido en otro namespace puede llegar sin NetworkPolicy.
- **Lo que *no* se ve en el DFD también importa**: no hay un boundary explícito para "backups" ni para "logs". Añadir esos boundaries en una iteración posterior es sano.

## 5. Mapa STRIDE × trust boundary (resumen)

Qué letras **suelen** destacar en cada boundary (no exhaustivo):

| Boundary | S | T | R | I | D | E |
|----------|---|---|---|---|---|---|
| TB-1 Internet↔Ingress | X |   |   |   | X |   |
| TB-2 Ingress↔App | X |   |   | X |   |   |
| TB-3 App↔Data | X | X |   | X | X | X |
| TB-4 App↔Obs |   |   |   | X |   |   |
| TB-5 Supply chain | X | X | X | X |   | X |
| TB-6 Infra plane | X | X | X | X |   | X |

La tabla no es un veredicto; es una **invitación a mirar**.

## 6. Para discutir

- ¿Qué boundary **falta** en este DFD que añadirías para tu organización concreta?
- ¿Qué pieza del DFD maneja datos más sensibles y por tanto merece el threat model más detallado?
- Si tuvieras que eliminar **un** boundary (porque es demasiado costoso de mantener), ¿cuál sería menos malo? Pista: ninguno es gratis.
