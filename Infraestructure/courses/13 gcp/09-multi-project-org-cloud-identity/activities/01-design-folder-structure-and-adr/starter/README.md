# Starter — gcp-09-01-design-folder-structure-and-adr

Esta actividad es **independiente**: no hay código ni plantilla que ejecutar. Tu entregable es un ADR Markdown escrito por ti.

## Pasos

1. Lee `../README.md` completo y recorre los tres `examples/` del módulo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/gcp-09-folder-adr
   cd /tmp/gcp-09-folder-adr
   ```
3. Crea `ADR-ORG-STRUCTURE.md` con las 6 secciones requeridas:
   - Estado, Contexto, Decisión, Consecuencias, Alternativas (y el encabezado ADR).
4. Incluye en la Decisión:
   - Un diagrama ASCII de la jerarquía Organization → Folders → Projects (dentro de un code fence).
   - Al menos 4 projects nombrados.
   - Al menos 3 Org Policies del baseline (por su constraint ID).
   - Al menos 3 grupos de Cloud Identity.
   - Decisión por workload (`checkout`, `analytics`) sobre "un project por app" vs "un project por app × ambiente".
   - Mención de Cloud Identity, Organization/Resource Manager, VPC Service Controls y de la restricción de regiones a Europa.
5. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/gcp/09-multi-project-org-cloud-identity/activities/01-design-folder-structure-and-adr/tests/validate.sh /tmp/gcp-09-folder-adr
   ```
6. Compara tu ADR con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** el validador comprueba estructura, no semántica. La corrección conceptual la revisas tú contra la referencia.

## Plantilla sugerida (opcional)

Puedes arrancar con esto y rellenar:

```markdown
# ADR 001 — Estructura inicial de la organización GCP

## Estado
Propuesto

## Contexto
<por qué, qué constraints: compliance Europa, PCI-light en checkout, 25 personas, etc.>

## Decisión

### 1. Jerarquía Organization → Folders → Projects

```text
Organization: ejemplo.com
├── Folder: Security
│   ├── Project: logging-prod
│   └── Project: security-audit
├── Folder: Shared
│   └── Project: shared-vpc-host
├── Folder: Workloads
│   ├── Folder: Prod
│   │   ├── Project: checkout-prod
│   │   └── Project: analytics-prod
│   ├── Folder: Stg
│   └── Folder: Dev
├── Folder: Sandbox
│   └── Project: sandbox-shared
└── Project: org-admin
```

### 2. Patrón por workload
- `checkout`: ...
- `analytics`: ...

### 3. Org Policies del baseline
- `iam.disableServiceAccountKeyCreation` adjunta a ...
- `compute.vmExternalIpAccess` adjunta a ...
- `storage.publicAccessPrevention` adjunta a ...

### 4. Grupos de Cloud Identity y bindings
- `gcp-org-admins@ejemplo.com` → ...
- `gcp-prod-sre@ejemplo.com` → ...
- `gcp-dev-engineers@ejemplo.com` → ...

### 5. Perímetro VPC Service Controls
<qué envuelve, qué servicios restringe, qué access level>

## Consecuencias
### Positivas
- ...
### Negativas
- ...

## Alternativas descartadas
### Alternativa 1 — Un único project por workload (dev/stg/prod juntos)
...
### Alternativa 2 — Replicar OU AWS 1:1 (una cuenta ↔ un project)
...
```
