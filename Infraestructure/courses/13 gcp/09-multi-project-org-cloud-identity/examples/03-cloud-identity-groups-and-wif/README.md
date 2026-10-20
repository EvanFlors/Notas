# Ejemplo 03 — Cloud Identity Groups y conexión con WIF

> Lectura y análisis. Sin ejecución. Objetivo: ver el ciclo de vida de un grupo Cloud Identity, cómo se usa en bindings y cómo conecta con Workload Identity Federation en `gcp-10`.

## 1. Ciclo de vida de un grupo

```
1. Admin de Cloud Identity crea un grupo:
   gcloud identity groups create gcp-prod-sre@ejemplo.com \
       --organization=ejemplo.com \
       --display-name="GCP Prod SRE"

2. Admin añade miembros (humanos):
   gcloud identity groups memberships add \
       --group-email=gcp-prod-sre@ejemplo.com \
       --member-email=alice@ejemplo.com

3. Un IAM admin bindea el grupo a un rol en un recurso:
   gcloud projects add-iam-policy-binding checkout-prod \
       --member=group:gcp-prod-sre@ejemplo.com \
       --role=roles/compute.admin

4. Alice se autentica con `gcloud auth login`. GCP:
   - Verifica su identidad en Cloud Identity.
   - Expande sus grupos (Alice ∈ gcp-prod-sre@).
   - Evalúa bindings; encuentra la binding → le concede el rol.

5. Bob entra al equipo. Admin lo añade al grupo:
   gcloud identity groups memberships add \
       --group-email=gcp-prod-sre@ejemplo.com \
       --member-email=bob@ejemplo.com
   → Bob tiene el mismo acceso que Alice, sin tocar un solo binding.

6. Alice cambia de equipo. Admin la saca del grupo:
   gcloud identity groups memberships delete \
       --group-email=gcp-prod-sre@ejemplo.com \
       --member-email=alice@ejemplo.com
   → Alice pierde el acceso, sin tocar un solo binding.
```

## 2. Catálogo mínimo de grupos para una org pequeña

| Grupo | Miembros típicos | Rol principal | Alcance |
|-------|------------------|---------------|---------|
| `gcp-org-admins@ejemplo.com` | 2–3 personas (CTO, head of platform). MFA obligatorio. | `roles/resourcemanager.organizationAdmin` | Organization. |
| `gcp-billing-admins@ejemplo.com` | Finance lead + head of platform. | `roles/billing.admin` | Billing Account. |
| `gcp-security@ejemplo.com` | Equipo de seguridad. | `roles/iam.securityReviewer`, `roles/logging.viewer` | Organization. |
| `gcp-platform@ejemplo.com` | Ingenieros de plataforma. | Custom role sobre `Shared/`. | Folder Shared. |
| `gcp-dev-engineers@ejemplo.com` | Developers de aplicaciones. | `roles/editor` | Folder `Workloads/Dev`. |
| `gcp-prod-sre@ejemplo.com` | SREs on-call. | Custom role de SRE | Folder `Workloads/Prod`. |
| `gcp-breakglass-checkout@ejemplo.com` | Vacío por defecto. | `roles/owner` sobre `checkout-prod`, con `Condition` de tiempo. | Project crítico, uso excepcional. |

## 3. Patrón "break-glass con binding condicional"

Caso: necesitas que un SRE pueda convertirse en owner de `checkout-prod` solo durante un incidente, no permanentemente.

```yaml
# Binding en checkout-prod
bindings:
  - role: roles/owner
    members:
      - group:gcp-breakglass-checkout@ejemplo.com
    condition:
      title: "Only during 2026-W42 incident window"
      expression: |
        request.time >= timestamp("2026-10-19T00:00:00Z") &&
        request.time <  timestamp("2026-10-26T00:00:00Z")
```

Durante el incidente, un admin añade a Alice al grupo `gcp-breakglass-checkout@`. Al terminar la ventana, la condición se evalúa `false` y la binding deja de aplicar — no hace falta ni sacar a Alice del grupo (aunque se recomienda hacerlo igual, por higiene).

## 4. Mapping grupos × roles × folders — tabla de assignments

```
┌───────────────────────────┬────────────────────────────┬──────────────────────────┐
│ Grupo                     │ Rol                        │ Alcance                  │
├───────────────────────────┼────────────────────────────┼──────────────────────────┤
│ gcp-org-admins@           │ organizationAdmin          │ Organization             │
│ gcp-billing-admins@       │ billing.admin              │ BillingAccount           │
│ gcp-security@             │ iam.securityReviewer       │ Organization             │
│ gcp-platform@             │ custom/platform-engineer   │ Folder Shared            │
│ gcp-dev-engineers@        │ editor                     │ Folder Workloads/Dev     │
│ gcp-dev-engineers@        │ viewer                     │ Folder Workloads/Stg     │
│ gcp-prod-sre@             │ custom/prod-sre            │ Folder Workloads/Prod    │
│ gcp-breakglass-checkout@  │ owner (cond. tiempo)       │ Project checkout-prod    │
│ gcp-sandbox-users@        │ editor                     │ Folder Sandbox           │
└───────────────────────────┴────────────────────────────┴──────────────────────────┘
```

**Nunca** aparece un `user:` directo. **Siempre** la membresía está en Cloud Identity, no en bindings.

## 5. Conexión con Workload Identity Federation (preview de `gcp-10`)

Los grupos de Cloud Identity son para **humanos**. Las cargas no humanas (CI/CD, workloads) nunca deben llevar una SA key descargada. En `gcp-10` verás **Workload Identity Federation (WIF)**: un **Workload Identity Pool** que confía en un IdP OIDC externo (GitHub Actions, GitLab, cualquier IdP OIDC), mapea claims del token (`sub`, `repository`, `ref`) a un **service account** GCP, y permite al workload *impersonar* ese SA sin credenciales estáticas.

Boceto mental:

```
GitHub Actions pipeline (repo=acme/checkout, ref=refs/heads/main)
        │
        │   token OIDC con claim sub=repo:acme/checkout:ref:refs/heads/main
        ▼
Workload Identity Pool: pool-github
Workload Identity Pool Provider: provider-github-oidc
        │   attribute mapping: google.subject = assertion.sub
        │   attribute condition: assertion.repository == "acme/checkout"
        ▼
Service Account: ci-deployer@tools-shared.iam
        │   roles/iam.workloadIdentityUser otorgado al principal del pool
        ▼
gcloud/terraform corre con credenciales efímeras del SA.
```

Puntos clave del encaje con este módulo:

1. El pool y los providers viven en `org-admin` o `tools-shared`, no en el project de la workload.
2. El SA que se impersona vive en el project donde actúa (p. ej. `checkout-prod` para desplegar la app).
3. Para los humanos: **grupos de Cloud Identity + binding condicional**. Para los pipelines: **WIF + impersonation**. **Nunca** SA keys para humanos ni pipelines.

## 6. Chequeo rápido antes de pasar a actividades

- [ ] Entiendes por qué nunca se bindea `user:` directo.
- [ ] Puedes nombrar al menos 5 grupos del catálogo y a qué folder bindea cada uno.
- [ ] Diferencias "grupo Cloud Identity" vs "SA" vs "principal WIF".
- [ ] Entiendes qué quiere decir `inheritFromParent: false` en una Org Policy.
- [ ] Reconoces el patrón de `break-glass` con `Condition` de tiempo.
