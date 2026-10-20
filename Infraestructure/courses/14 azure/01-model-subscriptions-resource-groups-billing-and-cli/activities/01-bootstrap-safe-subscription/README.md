# Actividad 01 — Bootstrap de subscription playground (ADR + script dry-run)

## 1. Identificación

- **ID:** `az-01-01-bootstrap-safe-subscription`
- **Tecnología:** `azure`
- **Módulo:** `az-01-model-subscriptions-resource-groups-billing-and-cli`
- **Dificultad:** beginner
- **Duración estimada:** 80–100 min
- **Tipo:** architecture (independiente — sin dependencia de la actividad 02)

## 2. Contexto

Entras a Azure por primera vez como ingeniero de una startup europea (20 personas, 10 ingenieros). Antes de montar nada, Platform te pide **documentar** cómo se va a arrancar la primera subscription "playground": qué tipo de subscription, qué Resource Group inicial, qué defaults de `az` CLI, qué budget con alerta y qué resource providers habilitar. El objetivo es que alguien pueda revisar la decisión y luego Fase 4 la materialice con Terraform.

**Importante**:

- **Sin subscription real** y **sin coste**. Trabajas 100% en papel + un script `bash` que invoca `az --help` / `az ... --dry-run` / comentarios.
- Usa **placeholder GUIDs** (`00000000-0000-0000-0000-000000000000`, `11111111-...`) para tenant y subscription. **Nunca** uses GUIDs reales de un tenant que conozcas.
- La región es **Europa** (compliance): elige `westeurope` o `northeurope`.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Dibujar la jerarquía Tenant → MG → Subscription → RG → Resource para una org pequeña y defender cada nivel.
- Elegir subscription type para una startup con razones y descartar al menos otro tipo.
- Nombrar el RG inicial siguiendo convención `rg-<workload>-<env>` y justificar por qué un RG = un ciclo de vida.
- Listar los resource providers que vas a registrar y por qué.
- Diseñar un Budget con alertas `Actual` y `Forecasted` escalonadas.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en especial §1–§5, §7, §9).
- Haber recorrido los tres `examples/` del módulo.
- Herramientas: `bash` y un editor Markdown. **Opcional**: la `az` CLI instalada, pero **solo** para `az --help` (jamás para `az login` contra un tenant real durante esta actividad).

**Costos**: ninguno. Todo es papel + un script bash local.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/az-01-bootstrap
cd /tmp/az-01-bootstrap
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-SUBSCRIPTION-BOOTSTRAP.md`

Formato ADR estándar (seis secciones obligatorias, el validador las busca):

1. **`# ADR`** (encabezado con la palabra "ADR").
2. **`## Estado`** (o `Status`).
3. **`## Contexto`** (o `Context`).
4. **`## Decisión`** (o `Decision`).
5. **`## Consecuencias`** (o `Consequences`).
6. **`## Alternativas`** (o `Alternatives` — al menos 2 descartadas).

Contenido mínimo obligatorio (el validador lo exige):

- **Diagrama ASCII** de la jerarquía Tenant → MG → Subscription → RG → Resource (en code fences).
- **Al menos 3 GUIDs placeholder** (p. ej. `00000000-0000-0000-0000-000000000000`, `11111111-...`, `22222222-...`) para tenant, management group y subscription.
- **Al menos 2 Resource Groups** nombrados (p. ej. `rg-sandbox-dev`, `rg-shared-logs`).
- **Elección explícita de subscription type** (Free, Pay-As-You-Go, Dev/Test, MCA, EA) con justificación.
- **Al menos 3 resource providers** nombrados (`Microsoft.Compute`, `Microsoft.Storage`, `Microsoft.KeyVault`, `Microsoft.ContainerService`...).
- **Budget** con amount, time grain y al menos 2 thresholds (uno `Actual`, uno `Forecasted`).
- Mención explícita de **Microsoft Entra ID** (o "Entra ID"), **Management Group** (o "MG") y de **región europea** (`westeurope`, `northeurope`, `europe`...).
- Mención explícita de **`az` CLI** y de la operación `az config set defaults`.

### 5.3 Escribe `bootstrap.sh`

Script bash **ejecutable** (`chmod +x`) con los comandos `az` que Fase 4 ejecutará. En este módulo los comandos van **comentados** o usan `--help` / `what-if`:

- Shebang `#!/usr/bin/env bash` en la primera línea.
- `set -eu` (o similar) — nota: **sin `pipefail`** para evitar falsos SIGPIPE en pipes con `grep -q`.
- Comentario explicando que ningún comando destructivo se ejecuta aquí.
- Secciones comentadas / `--help` para:
  - `az login` (al menos como comentario con las variantes),
  - `az account set --subscription <GUID-placeholder>`,
  - `az group create` (comentado o `--help`),
  - `az provider register` (comentado o `--help`) para al menos un provider,
  - `az consumption budget` (comentado o `--help`).

El validador verifica que el archivo **existe**, es **ejecutable** y contiene esas invocaciones.

### 5.4 Entregables

```
/tmp/az-01-bootstrap/
├── ADR-SUBSCRIPTION-BOOTSTRAP.md
└── bootstrap.sh                       (chmod +x)
```

## 6. Resultado esperado

- Los 2 archivos existen.
- `bootstrap.sh` es ejecutable (`-rwxr-xr-x`).
- El validador pasa en verde.
- Un ingeniero externo lee el ADR + script y entiende qué subscription se va a arrancar, con qué RG, qué budget y qué providers.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Seguridad**: ningún comando `az` destructivo se ejecuta; GUIDs son placeholders.
- **Reproducibilidad**: alguien en Fase 4 toma el ADR + script y lo convierte a Terraform o lo ejecuta tras adaptar GUIDs sin ambigüedades.
- **Mantenibilidad**: Markdown válido con fences; bash shebang + `set -eu` + comentario SIGPIPE.

## 8. Validación

```bash
bash tests/validate.sh /tmp/az-01-bootstrap
```

El validador comprueba **estructura y seguridad** (archivos, secciones ADR, mínimos de contenido, ejecutabilidad del script, ausencia de comandos destructivos activos). No comprueba semántica contra un tenant real.

Compara después con `solution/REFERENCE.md` para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Por qué eliges `Dev/Test` o `Free` en lugar de `PAYG` para una playground? ¿Qué pierdes?
2. Si tu RG se llama `rg-sandbox-dev` y mañana la startup tiene `checkout` en producción, ¿por qué **no** meterías `checkout-prod` en el mismo RG?
3. ¿Por qué `az provider register` es por-subscription y no por-tenant?
4. Si el Budget alerta al 80% pero no al 100%, ¿qué puede pasar?
5. ¿Dónde adjuntas el Budget: subscription, RG o Management Group? ¿Qué cambia?

## 10. Extensiones

- Añade al script una función `verify()` que corra `az account show` + `az group list` + `az provider list` (todos de lectura).
- Añade al ADR una sección **"Fase 2"** describiendo cómo crecerá la organización a 3 subscriptions (dev / stg / prod) colgadas de un MG `Landing Zones`.
- Añade un segundo budget a nivel subscription (no solo RG) con umbral de 50 USD.

## 11. Limpieza

```bash
rm -rf /tmp/az-01-bootstrap
```

No hay infraestructura real que detener. Nunca ejecutes el script `bootstrap.sh` contra una subscription real en este módulo.
