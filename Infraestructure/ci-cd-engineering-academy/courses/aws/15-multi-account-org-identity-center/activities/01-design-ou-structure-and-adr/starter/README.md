# Starter — aws-15-01-design-ou-structure-and-adr

Esta actividad es **independiente**: no hay código ni plantilla que ejecutar. Tu entregable es un ADR Markdown escrito por ti.

## Pasos

1. Lee `../README.md` completo y recorre los tres `examples/` del módulo.
2. Prepara el directorio:
   ```bash
   mkdir -p /tmp/aws-15-ou-adr
   cd /tmp/aws-15-ou-adr
   ```
3. Crea `ADR-ORG-STRUCTURE.md` con las 6 secciones requeridas:
   - Estado, Contexto, Decisión, Consecuencias, Alternativas (y el encabezado ADR).
4. Incluye en la Decisión:
   - Un diagrama ASCII de la OU structure (dentro de un code fence).
   - Al menos 4 cuentas nombradas.
   - Al menos 3 SCPs del baseline.
   - Al menos 3 Permission Sets.
   - Decisión por workload (`checkout`, `analytics`) sobre "una app = una cuenta" vs "una app = N cuentas".
   - Mención de IAM Identity Center, AWS Organizations y de la restricción de regiones a Europa.
5. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/aws/15-multi-account-org-identity-center/activities/01-design-ou-structure-and-adr/tests/validate.sh /tmp/aws-15-ou-adr
   ```
6. Compara tu ADR con `../solution/REFERENCE.md` para autoevaluarte.

> **Importante:** el validador comprueba estructura, no semántica. La corrección conceptual la revisas tú contra la referencia.

## Plantilla sugerida (opcional)

Puedes arrancar con esto y rellenar:

```markdown
# ADR 001 — Estructura inicial de la organización AWS

## Estado
Propuesto

## Contexto
<por qué, qué constraints: compliance Europa, PCI-light en checkout, 20 personas, etc.>

## Decisión

### 1. Estructura de OUs y cuentas

```text
Root
├── Security OU
│   ├── log-archive
│   └── audit
├── Workloads OU
│   ├── Workloads/Prod
│   │   └── checkout-prod
│   ├── Workloads/Stg
│   │   └── checkout-stg
│   ├── Workloads/Dev
│   │   ├── checkout-dev
│   │   └── analytics
...
```

### 2. Patrón por workload
- `checkout`: ...
- `analytics`: ...

### 3. SCPs del baseline
- ...
- ...
- ...

### 4. Permission Sets
- ...
- ...

### 5. Acceso humano: IAM Identity Center
<cómo integras IdP, cómo asignas>

## Consecuencias
### Positivas
- ...
### Negativas
- ...

## Alternativas descartadas
### Alt A: una sola cuenta para todo
- Por qué no: ...
### Alt B: una cuenta por entorno (no por workload)
- Por qué no: ...
```
