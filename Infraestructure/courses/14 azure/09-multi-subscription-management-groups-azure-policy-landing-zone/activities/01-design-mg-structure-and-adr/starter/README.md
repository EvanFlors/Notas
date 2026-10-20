# Starter — az-09-01

Esta actividad **no** tiene starter de código. Es un ejercicio de diseño en papel.

## Pasos

1. Crea el directorio de trabajo:

   ```bash
   mkdir -p /tmp/az-09-mg-adr
   cd /tmp/az-09-mg-adr
   ```

2. Escribe `ADR-MG-STRUCTURE.md` siguiendo el formato de la actividad (README principal, sección 5.2).

3. Valida:

   ```bash
   bash <ruta-al-modulo>/activities/01-design-mg-structure-and-adr/tests/validate.sh /tmp/az-09-mg-adr
   ```

4. Compara con `solution/REFERENCE.md` para autoevaluación semántica.

## Plantilla sugerida (opcional)

Puedes empezar copiando este skeleton en `/tmp/az-09-mg-adr/ADR-MG-STRUCTURE.md`:

```markdown
# ADR 001 — Estructura de Management Groups y Landing Zone en Azure

## Estado
Propuesto

## Contexto
<2-4 párrafos>

## Decisión

### Jerarquía de Management Groups

\`\`\`
Tenant Root Group
└── contoso
    ├── Platform
    │   ├── ...
    ├── Landing Zones
    │   ├── Corp
    │   └── Online
    ├── Sandbox
    └── Decommissioned
\`\`\`

### Subscriptions

<lista>

### Azure Policies (baseline)

<tabla policy × MG × justificación>

### Role assignments con PIM

<tabla grupo × role × scope × eligible/active>

### Patrón por workload

- `checkout`: ...
- `analytics`: ...

## Consecuencias
<positivas y negativas>

## Alternativas descartadas

### Alternativa A — jerarquía plana
<por qué no>

### Alternativa B — una app = una subscription para todo
<por qué no>
```

Recuerda: debes **mencionar** CAF/ALZ/Enterprise Scale, PIM, Entra ID, Management Groups, Europa, los dos workloads y 3+ policies / 3+ roles / 4+ subscriptions.
