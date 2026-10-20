# Starter — gcp-03-01-shared-vpc-host-and-service

Esta actividad es **independiente**: no hay código ni plantilla que ejecutar. Los entregables son un ADR Markdown y un JSON de firewall rules escritos por ti.

## Pasos

1. Lee `../README.md` completo y recorre los tres `examples/` del módulo (especialmente `02-firewall-by-service-account/`).
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gcp-03-shared-vpc
   cd /tmp/gcp-03-shared-vpc
   ```
3. Crea `ADR-SHARED-VPC.md` con las 6 secciones requeridas (ADR, Estado, Contexto, Decisión, Consecuencias, Alternativas).
4. Crea `firewall-rules.json` con al menos 3 reglas, al menos una con `targetServiceAccounts`, al menos una con los rangos de health checks (`35.191.0.0/16`, `130.211.0.0/22`) y al menos una `direction: EGRESS`.
5. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/gcp/03-vpc-global-and-networking/activities/01-shared-vpc-host-and-service/tests/validate.sh /tmp/gcp-03-shared-vpc
   ```
6. Compara con `../solution/REFERENCE.md`.

> **Importante:** el validador comprueba estructura, no semántica. La corrección conceptual la revisas tú contra la referencia.

## Plantilla sugerida para el ADR

```markdown
# ADR 001 — Shared VPC para la organizacion GCP

## Estado
Propuesto

## Contexto
<por qué, qué constraints: Europa, 2 workloads, platform operando red, etc.>

## Decisión

### 1. Projects

- `net-host-prod` (host de la Shared VPC)
- `checkout-prod` (service project)
- `analytics-prod` (service project)

### 2. VPC y subnets

```text
Shared VPC: vpc-prod   (global, custom)
10.10.0.0/16
├── europe-west1  10.10.0.0/20   privateIpGoogleAccess=true
└── europe-west4  10.10.16.0/20  privateIpGoogleAccess=true
```

### 3. Service accounts

- `app-sa@checkout-prod.iam.gserviceaccount.com`
- `db-sa@checkout-prod.iam.gserviceaccount.com`
- `analytics-sa@analytics-prod.iam.gserviceaccount.com`

### 4. Firewall rules del baseline
- allow-health-checks (ingress, 80/443, source: 35.191.0.0/16 + 130.211.0.0/22)
- allow-app-to-db-5432 (ingress, sourceServiceAccounts=[app-sa], targetServiceAccounts=[db-sa])
- deny-all-egress (egress, prio 65534)
- allow-egress-google-apis (egress, destino restricted.googleapis.com)

### 5. Cloud NAT y PGA
<una NAT por region, PGA on en subnets>

### 6. IAM Shared VPC
<xpnAdmin en folder, networkUser por service project sobre subnets concretas>

## Consecuencias
### Positivas
- ...
### Negativas
- ...

## Alternativas descartadas
### Alt A: VPCs separadas por workload + peering
- Por qué no: ...
### Alt B: VPC auto con /9 default
- Por qué no: ...
```

## Plantilla sugerida para `firewall-rules.json`

Ver `../../../examples/02-firewall-by-service-account/README.md` para la forma. Adapta nombres, projects y SAs a los que elijas en tu ADR.
