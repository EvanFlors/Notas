# REFERENCE — plat-04-02-k8s-deploy-via-helm

> Modelo razonado. No es la única respuesta correcta.

## Sección A — Instalación del chart

```bash
# Añadir el repo oficial del chart (una vez)
helm repo add backstage https://backstage.github.io/charts
helm repo update

# Dry-run (siempre primero)
helm template my-backstage backstage/backstage \
  --namespace backstage \
  --values values.yaml > rendered.yaml

# Install
helm install my-backstage backstage/backstage \
  --namespace backstage --create-namespace \
  --values values.yaml

# Upgrades
helm upgrade my-backstage backstage/backstage \
  --namespace backstage \
  --values values.yaml \
  --atomic --timeout 10m
```

Flags clave:

- `--values` acepta múltiples archivos (base + overlay por entorno).
- `--atomic` revierte si el upgrade falla.
- `--create-namespace` crea el ns en primer install.

## Sección B — Anatomía del `values.yaml`

| Bloque | Qué controla | Por qué importa |
|--------|--------------|-----------------|
| `backstage.image` | Imagen que corre: `registry/repo:tag` | Tú construyes el contenedor desde tu monorepo. El chart no trae imagen. El tag debe ser inmutable (SHA o versión). |
| `backstage.replicas` | Nº de pods | Backstage escala horizontal; requiere Postgres compartido. Mínimo 2 en prod. |
| `backstage.extraEnvVars` | Env vars inyectadas al container | Puente entre K8s Secrets y `app-config.yaml` (que lee `${VAR}`). **Único lugar** donde declaras cómo llegan los secretos. |
| `backstage.resources` | Requests/limits CPU y memoria | Backstage es Node + React build cache; sin limits puede comerse un worker entero en builds de TechDocs. |
| `backstage.readinessProbe` / `livenessProbe` | `/healthcheck` en 7007 | Rolling updates sin downtime; sin readiness el ingress envía tráfico a pods aún iniciando. |
| `ingress` | Entrada HTTPS | GitHub OAuth exige HTTPS en dominio público. `cert-manager` + Let's Encrypt es el stack típico. |
| `postgresql.enabled: false` | Desactiva el subchart | Usamos **managed** PG (RDS, Cloud SQL). El subchart Bitnami sirve para demos, no para prod. |
| `serviceMonitor.enabled` | Scrape de Prometheus Operator | Observability desde el día uno. Sin métricas, upgrades son a ciegas. |
| `podDisruptionBudget` | Mínimo pods durante drain | Garantiza SLO durante node upgrades. |

## Sección C — Cadena de secretos

```
                    ┌────────────────────────────┐
                    │ Vault / AWS Secrets Manager│
                    └──────────────┬─────────────┘
                                   │
                        External Secrets Operator
                                   │
                                   ▼
          ┌────────────────────────────────────────────┐
          │ K8s Secret: backstage-pg                   │
          │  keys: host, port, user, password          │
          ├────────────────────────────────────────────┤
          │ K8s Secret: backstage-gh                   │
          │  keys: client-id, client-secret, pat       │
          └──────────────────────┬─────────────────────┘
                                 │
                         secretKeyRef in extraEnvVars
                                 │
                                 ▼
          ┌────────────────────────────────────────────┐
          │ Backstage pod (env vars)                   │
          │  POSTGRES_HOST, POSTGRES_PASSWORD, ...     │
          │  AUTH_GITHUB_CLIENT_ID, _SECRET, ...       │
          │  GITHUB_TOKEN                              │
          └──────────────────────┬─────────────────────┘
                                 │
                                 ▼
          ┌────────────────────────────────────────────┐
          │ app-config.yaml reads ${VAR}               │
          │  backend.database.connection.password      │
          │  auth.providers.github.production.clientId │
          │  integrations.github.token                 │
          └────────────────────────────────────────────┘
```

**Garantía**: en todo este flujo, el único lugar con valores literales de secretos es el **backend KV** (Vault / Secrets Manager), auditado y rotable. El `values.yaml`, el repo del chart y el repo de Backstage **nunca** los ven.

Placeholders usados en los ejemplos:

- `ghp_xxxx_placeholder_do_not_use` (GitHub PAT ficticio).
- `Iv1.xxxx_placeholder` (OAuth client id ficticio).

## Sección D — Decisiones productivas

### `postgresql.enabled=false` + managed PG

- Backups, HA, point-in-time recovery, versión upgrades: resueltos por el provider.
- Backstage es un consumer de PG, no es su trabajo operarlo.
- Si usas el subchart Bitnami en prod, acabas con PG stateful en el mismo cluster, sin HA real y con upgrades manuales.
- Excepción justificable: entorno de staging / sandbox donde la pérdida de datos es aceptable.

### Ingress TLS obligatorio

- GitHub OAuth **rechaza callbacks a HTTP** en dominios públicos.
- Cookies de sesión deben llevar `Secure`.
- Compliance (PCI, SOC2) exige TLS en cualquier endpoint auth.
- Pattern: `cert-manager` + `letsencrypt-prod` ClusterIssuer, DNS gestionado por External DNS.

### Observabilidad

- `serviceMonitor` para métricas (ver cursos `prometheus-grafana`).
- Logs estructurados (JSON) → Loki / Elastic.
- Traces via OTel (ver curso `opentelemetry`).
- Alertas mínimas: pod restart, 5xx > X, PG latency, cert expiration.

### Política de upgrade

- **Chart**: `helm search repo backstage/backstage --versions`, leer release notes antes de bumpear.
- **Framework Backstage**: `yarn backstage-cli versions:bump` dentro del repo + upgrade-helper.
- Mantener semanalmente el framework, mensualmente el chart.
- Equipos que no mantienen cadencia acumulan deuda que se vuelve una migración de un trimestre.

## Puntos a repetir

- La imagen la construyes tú; el chart no la trae.
- Los secretos jamás viven en `values.yaml` — solo `secretKeyRef`.
- `postgresql.enabled=false` + managed = default productivo.
- HTTPS no es opcional cuando usas OAuth.
- Upgradar es parte del trabajo, no un proyecto.
