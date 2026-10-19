# Actividad 01 — Elegir compute Azure para 3 workloads y escribir ADR

## 1. Identificacion

- **ID:** `az-04-01-choose-compute-and-adr`
- **Tecnologia:** `azure`
- **Modulo:** `az-04-compute-vm-vmss-container-apps-functions-app-service`
- **Dificultad:** intermediate
- **Duracion estimada:** 80-100 min
- **Tipo:** architecture (independent — no depende de la actividad 02)

## 2. Contexto

Un equipo plataforma del capstone evalua tres workloads nuevos que entraran en Azure:

- **`checkout-api`**: API HTTP sincronica de pagos. SLA p99 < 300 ms. Trafico medio 20 rps en horario, picos a 150 rps en Black Friday. Compliance PCI-light. Equipo backend de 4 personas.
- **`etl-nightly`**: job batch Python que corre a las 02:00 UTC cada dia, procesa 2 GB de CSV y escribe en Azure SQL. Duracion 15-25 min. Fuera de ese rango no hace nada.
- **`billing-worker`**: worker que consume mensajes de una **Service Bus Queue** (eventos de facturacion), 500k mensajes/dia distribuidos irregularmente. Cada mensaje tarda 200 ms de CPU y hace una escritura en Cosmos DB.

Mas:

- Todo debe correr en **Europa** (`westeurope` o `northeurope`).
- Compliance exige **Managed Identity** (no secretos en env vars).
- Finance mira el coste mensual: la propuesta debe estimarlo (orden de magnitud).
- La org ya tiene AKS para otros workloads, pero **no quieren meter mas servicios en AKS si no es necesario**.

Tu encargo: **elegir compute para cada workload**, defender la eleccion contra alternativas, y documentarlo en un ADR.

**Importante**: no hay suscripcion Azure. No se provisiona nada. El entregable es un **documento**.

## 3. Objetivos

Al terminar deberias poder, sin consultar la leccion:

- Nombrar al menos 5 familias de compute Azure y una regla heuristica para elegir entre ellas.
- Decidir compute por workload y defender el criterio (cold-start, portabilidad, coste, operabilidad).
- Escribir un ADR legible para un ingeniero externo al debate.

## 4. Prerrequisitos

- Haber leido `../../theory/lesson.md` completo.
- Haber recorrido los tres `examples/` del modulo.
- Haber completado `az-01`, `az-02`, `az-03`.
- Herramientas: `bash` y un editor Markdown. Nada mas.

**Costos**: ninguno. Todo es papel.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/az-04-01
cd /tmp/az-04-01
```

Puedes usar otro directorio, pero entonces pasaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-COMPUTE-CHOICE.md`

Formato ADR que debes seguir:

```
# ADR 001 — Eleccion de compute Azure para 3 workloads

## Estado
Propuesto | Aceptado | Reemplazado por ADR XXX

## Contexto
(2-4 parrafos: constraints de los 3 workloads, Europa, MI, coste.)

## Decision
(La eleccion por workload, con razones. Incluye una tabla comparativa
de VM / VMSS / App Service / Container Apps / ACI / Functions.)

## Consecuencias
(Trade-offs: que ganas y que pierdes por cada eleccion.)

## Alternativas descartadas
(Al menos 2 alternativas evaluadas para al menos uno de los workloads
y por que no.)
```

Secciones obligatorias (el validador las busca):

1. `# ADR` (encabezado con la palabra "ADR").
2. `## Estado` (o `Status`).
3. `## Contexto` (o `Context`).
4. `## Decision` (o `Decision` / `Decisi[oó]n`).
5. `## Consecuencias` (o `Consequences`).
6. `## Alternativas` (o `Alternatives`, al menos 2 descartadas).

Contenido minimo obligatorio (el validador lo exige):

- **Tabla comparativa** (fence Markdown de tabla, `|`) nombrando al menos **5 familias de compute**: `VM`, `VMSS`, `App Service`, `Container Apps`, `Functions` (ACI opcional pero recomendado).
- **Los 3 workloads nombrados**: `checkout-api`, `etl-nightly`, `billing-worker`.
- **Decision explicita** por workload (una familia de compute elegida).
- **Mencion de trade-offs**: al menos **cold-start**, **coste** y **portabilidad**.
- **Mencion de Managed Identity** (compliance).
- **Mencion de Europa** / `westeurope` / `northeurope`.
- **Al menos 2 alternativas descartadas** (sub-encabezados o items numerados en la seccion Alternativas).
- **Al menos un bloque de codigo con fence** (puede ser el skeleton de un `azurerm_container_app`, una tabla, o un diagrama ASCII).
- **Comparacion con AWS**: al menos 1 mapping (`Container Apps <-> ECS/Fargate`, `Functions <-> Lambda`, `VM <-> EC2`, etc.).

### 5.3 Entregable

Un archivo:

```
/tmp/az-04-01/ADR-COMPUTE-CHOICE.md
```

con las 6 secciones y el contenido minimo.

**No llames al archivo `ANALYSIS.md`** — otros validadores del repo tratan ese nombre con convenciones especiales.

## 6. Resultado esperado

- `ADR-COMPUTE-CHOICE.md` existe y es coherente.
- El validador estructural pasa en verde.
- Un ingeniero externo puede leerlo y defender la decision.

## 7. Criterios de aceptacion

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada decision esta justificada (no solo listada).
- **Reproducibilidad**: alguien en Fase 4 podria tomar este ADR y convertirlo a Terraform para los 3 workloads.
- **Mantenibilidad**: Markdown valido, tabla parseable, codigo en fences.

## 8. Validacion

```bash
bash tests/validate.sh /tmp/az-04-01
```

El validador comprueba **estructura**, no semantica. Compara tu ADR con `solution/REFERENCE.md` despues de haberlo escrito para autoevaluarte.

## 9. Preguntas de reflexion

1. Para `checkout-api`, por que `min_replicas = 0` seria una mala idea? Que valor usarias y por que?
2. Para `etl-nightly`, por que **Functions Timer trigger** y **Container Apps Jobs** son opciones distintas pero validas? Que decanta la eleccion?
3. Para `billing-worker`, cual seria el escalador KEDA que usarias en Container Apps? Que valor concreto le darias a `queueLength`?
4. Si Finance te dice "quiero bajar el coste 50%", en cual de los 3 workloads mirarias primero? Por que?
5. Si la org pivota a estrategia multi-cloud en 18 meses, cual de tus 3 elecciones costaria mas migrar? Por que?

## 10. Extensiones

- Anade una tabla de **coste estimado mensual** por workload (orden de magnitud).
- Dibuja un **diagrama ASCII** del flujo de los 3 workloads (quien ingresa trafico, quien pasa a quien).
- Anade un **plan de instrumentacion** (que metricas vas a mirar para validar la eleccion en 90 dias).

## 11. Limpieza

```bash
rm -rf /tmp/az-04-01
```

No hay infraestructura que detener.
