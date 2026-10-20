# Actividad 01 — Planear el bootstrap seguro de un project GCP

## 1. Identificacion

- **ID:** `gcp-01-01-bootstrap-safe-project`
- **Tecnologia:** `gcp`
- **Modulo:** `gcp-01-model-projects-billing-and-cli`
- **Dificultad:** beginner
- **Duracion estimada:** 80-100 min
- **Tipo:** architecture (**independent** — sin dependencia de la actividad 02)

## 2. Contexto

Entras a trabajar en `acme.io`. Hay una Organization GCP ya creada (`folders/prod`, `folders/dev`, `folders/shared`) y una Billing Account corporativa (`billingAccounts/XXXXXX-XXXXXX-XXXXXX`). El equipo de Platform te pide un **plan de bootstrap** para un nuevo project de desarrollo para la app `checkout`: `checkout-dev` (placeholder: `my-project-123`).

El plan sera consumido por Terraform en Fase 4; pero **hoy** quieren verlo en forma de **documento + scripts** para revisarlo antes de hacer nada en GCP real.

Reglas:

- Compliance: datos deben vivir en `europe-west1` o `europe-west4`.
- Budget inicial: 100 USD/mes con alerta por Slack a 50%, 90% y 100% (actual) y 100% (forecasted).
- Labels obligatorios: `env`, `app`, `owner`, `cost-center`, `data-classification`.
- Autenticacion humana: MFA ya aplicada en Cloud Identity (fuera del scope de esta actividad).
- APIs: habilitar solo las necesarias para arrancar (identidad, billing, logging, monitoring, service usage). **No** habilitar `compute`, `run`, `storage`, etc. — eso lo decide cada equipo al añadir el servicio.
- **No se crea nada en GCP**. Todo son archivos locales.
- **No usar un `projectId` real** — usar siempre el placeholder `my-project-123`.

Tu encargo: producir **3 archivos** que un revisor pueda leer en 10 minutos y aprobar.

## 3. Objetivos

Al terminar deberias poder, **sin consultar la leccion**:

- Enumerar la jerarquia Org/Folder/Project y donde encaja un project nuevo.
- Nombrar el set minimo de APIs que todo project nuevo necesita.
- Enlazar un project a una Billing Account via comando `gcloud` (en texto, no ejecucion).
- Diseñar labels obligatorios con criterio y defender por que cada uno.
- Escribir un budget YAML con thresholds razonables y canal de notificacion.

## 4. Prerrequisitos

- Haber leido `../../theory/lesson.md` entero (en particular §2 jerarquia, §5 billing, §6 APIs, §9 labels, §10 budgets).
- Haber recorrido los tres `examples/` del modulo.
- Herramientas: `bash`, `python3` (para validar YAML), un editor Markdown. **No** se requiere `gcloud` instalado.

**Costos:** ninguno. Todo es papel y archivos locales.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/gcp-01-bootstrap
cd /tmp/gcp-01-bootstrap
```

Puedes usar otro directorio; entonces pasalo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `bootstrap-plan.md`

Un documento con las siguientes **secciones obligatorias** (el validador las busca por encabezado):

- `## Contexto`
- `## Jerarquia`
- `## Project`
- `## APIs`
- `## Billing`
- `## Budget`
- `## Labels`
- `## Siguientes pasos`

Contenido minimo (el validador lo exige):

- Mencion a **AWS -> GCP** (al menos una vez): project ~= account, folder ~= OU.
- Mencion a `europe-west1` o `europe-west4` (region europea).
- Mencion a **Cloud Identity** o **MFA** (acceso humano seguro).
- Mencion a **impersonation** o `iamcredentials` (patron sin keys).
- Uso del placeholder `my-project-123` (**no** un projectId real).
- Al menos 3 de los **labels obligatorios** nombrados: `env`, `app`, `owner`, `cost-center`, `data-classification`.
- Mencion a `billingAccounts/XXXXXX-XXXXXX-XXXXXX` (placeholder de BA — formato aceptado).

### 5.3 Escribe `enable-apis.sh`

Script shell que un operador podra correr (en Fase 4) para habilitar las APIs minimas. Requisitos:

- Shebang `#!/usr/bin/env bash`.
- `set -eu` (sin `pipefail` para evitar SIGPIPE con `grep -q`).
- Variable `PROJECT_ID="${PROJECT_ID:-my-project-123}"` (parametrizable, default placeholder).
- Al menos **estas 6 APIs** habilitadas (string literal exacto):
  - `cloudresourcemanager.googleapis.com`
  - `iam.googleapis.com`
  - `iamcredentials.googleapis.com`
  - `serviceusage.googleapis.com`
  - `cloudbilling.googleapis.com`
  - `logging.googleapis.com`
  - `monitoring.googleapis.com`
- Debe usar `gcloud services enable` (string literal).
- **No** debe usar `--project=my-project-` seguido de digitos distintos a `123` (placeholder correcto).
- Debe pasar `bash -n enable-apis.sh` (sintaxis valida).
- Debe estar `chmod +x` (ejecutable).

### 5.4 Escribe `budget.yaml`

YAML consumible por `gcloud alpha billing budgets create --budget-from-file=budget.yaml`. Requisitos (el validador los chequea):

- YAML valido parseable por Python `yaml.safe_load`.
- Clave `displayName` (string).
- Clave `budgetFilter.projects` conteniendo `projects/my-project-123`.
- Clave `amount.specifiedAmount.currencyCode == "USD"`.
- Clave `amount.specifiedAmount.units == "100"`.
- Clave `thresholdRules` con **al menos 3** elementos.
- Al menos una regla con `spendBasis: CURRENT_SPEND` y al menos una con `spendBasis: FORECASTED_SPEND`.
- Clave `notificationsRule.pubsubTopic` con string tipo `projects/my-project-123/topics/...`.

### 5.5 Entregables

```
/tmp/gcp-01-bootstrap/
├── bootstrap-plan.md
├── enable-apis.sh      (chmod +x)
└── budget.yaml
```

## 6. Resultado esperado

- Los 3 archivos existen con el contenido pedido.
- El validador pasa en verde.
- Un revisor externo puede leer `bootstrap-plan.md` y entender **que** vas a abrir y **por que** sin ambiguedades.

## 7. Criterios de aceptacion

- **Funcionalidad**: validador estructural + semantico pasa.
- **Correctitud**: APIs minimas presentes, YAML parseable, placeholder consistente.
- **Mantenibilidad**: Markdown valido; script sin `pipefail`; YAML indentado consistentemente.
- **Reproducibilidad**: un operador en Fase 4 podria tomar el script y el YAML y usarlos (reemplazando el placeholder) sin reescribir.

## 8. Validacion

```bash
bash tests/validate.sh /tmp/gcp-01-bootstrap
```

El validador comprueba **estructura + presencia de claves/strings clave**. No conecta a GCP ni ejecuta `gcloud`. Compara tu entregable con `solution/REFERENCE.md` para autoevaluacion semantica.

## 9. Preguntas de reflexion

1. ¿Por que la region esta restringida a `europe-west*` y no simplemente "usa la region mas barata"?
2. ¿Que pasaria si olvidas habilitar `iamcredentials.googleapis.com` y luego configuras impersonation en ADC?
3. ¿Por que un `projectId` deberia incluir un hash final (`checkout-dev-7a3f`) y no solo `checkout-dev`?
4. Si el budget alerta al 50%, ¿que hace el equipo? ¿Y al 100%? ¿Que automatizarias (si algo)?
5. ¿Que labels **anadirias** para una app regulada por PCI? ¿Y para una interna no sensible?

## 10. Extensiones

- Añade una seccion "Fase 2" al plan con que APIs se habilitaran al introducir Cloud Run (`run.googleapis.com`, `artifactregistry.googleapis.com`, `secretmanager.googleapis.com`).
- Escribe `verify-plan.sh` que corra `python3 -c "import yaml; yaml.safe_load(open('budget.yaml'))"` y `bash -n enable-apis.sh` como pre-check.
- Añade un budget **adicional** a nivel BA (fallback) en un segundo YAML.

## 11. Limpieza

```bash
rm -rf /tmp/gcp-01-bootstrap
```

No hay infraestructura que detener (nunca se creo nada en GCP).
