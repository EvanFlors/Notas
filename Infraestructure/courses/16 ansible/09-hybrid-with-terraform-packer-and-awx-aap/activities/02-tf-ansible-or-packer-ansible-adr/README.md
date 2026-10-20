# Actividad 02 — ADR: mutable (TF+Ansible) vs immutable (Packer+Ansible) por workload

## 1. Identificación

- **ID:** `ans-09-02-tf-ansible-or-packer-ansible-adr`
- **Tecnología:** `ansible`
- **Módulo:** `ans-09-hybrid-with-terraform-packer-and-awx-aap`
- **Dificultad:** advanced
- **Duración estimada:** 70–80 min
- **Tipo:** architecture (independent — sin dependencia de la actividad 01)

## 2. Contexto

Tu equipo de plataforma debe cerrar un debate que lleva semanas: ¿todas las workloads deben migrar al patrón inmutable (Packer + Ansible → AMI → TF), o seguimos usando el patrón mutable (TF + Ansible converge) para algunas? Hay tres workloads sobre la mesa:

- **`legacy-billing`** — monolito Java corriendo en 4 VMs on-prem (VMware). Última release hace 11 meses. Config evoluciona por tickets manuales. Pico de carga predecible (día 1 y 15 de cada mes). No se puede recrear sin coordinación con el equipo que lo mantiene.
- **`checkout-api`** — API HTTP nueva en EC2 detrás de un ALB, autoscaling 2–10 instancias. Despliega 3–5 veces por semana. SLA 99.9%. Equipo backend de 4 personas que iteran rápido. Secretos ya en Secrets Manager; estado en RDS y DynamoDB.
- **`analytics-platform`** — procesado batch en EKS (pods + CronJobs). Imágenes Docker gestionadas por el equipo de datos. Scheduling vía Argo Workflows.

Tu encargo: **decidir patrón por workload** (mutable, inmutable o "ninguno, Ansible no aplica aquí") y documentarlo en un ADR que un equipo de 10 personas pueda leer y ejecutar.

**Importante**: no hay infra que tocar. El entregable es un **documento**.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Elegir mutable vs inmutable vs "no-Ansible" para cada uno de los 3 workloads y defender cada decisión con 3+ criterios.
- Construir una tabla de trade-offs sobre dimensiones concretas: drift, blast radius, build time, secretos, estado en disco local, velocidad de iteración, rollback.
- Explicar en qué workloads AWX/AAP aporta sobre un pipeline de CI simple, y en cuáles no.
- Escribir un ADR legible por un ingeniero que no estuvo en la discusión.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (secciones 2, 3, 6 y 8).
- Haber recorrido los tres `examples/` del módulo.
- Haber completado `ans-04` y `ans-07`.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno. Todo es papel.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/ans-09-02
cd /tmp/ans-09-02
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-MUTABLE-VS-IMMUTABLE.md`

Un **ADR** (Architecture Decision Record) corto y versionado. Formato que debes seguir:

```
# ADR 001 — Mutable (TF+Ansible) vs immutable (Packer+Ansible)

## Estado
Propuesto | Aceptado | Reemplazado por ADR XXX

## Contexto
(2-4 párrafos: los 3 workloads, el problema, los constraints)

## Decisión
(Patrón elegido para cada workload. Debe incluir una tabla de trade-offs.)

## Consecuencias
(Qué ganas, qué pierdes, cuántos pipelines diferentes mantienes, etc.)

## Alternativas descartadas
(Al menos 2 alternativas consideradas y por qué no.)
```

Secciones obligatorias (el validador las busca):

1. **`# ADR`** (encabezado con la palabra "ADR").
2. **`## Estado`** (o `Status`).
3. **`## Contexto`** (o `Context`).
4. **`## Decisión`** (o `Decision`).
5. **`## Consecuencias`** (o `Consequences`).
6. **`## Alternativas`** (o `Alternatives` — al menos 2 descartadas).

Contenido mínimo obligatorio (el validador lo exige):

- Mencionar los **tres workloads** por nombre: `legacy-billing`, `checkout-api`, `analytics-platform`.
- Mencionar **mutable** y **immutable** (o `inmutable`) como vocabulario explícito.
- Mencionar **Packer**, **Terraform** y **Ansible**.
- Mencionar **AWX** o **AAP**.
- **Tabla de trade-offs** (code fence o tabla Markdown con `|`) que cubra al menos: *drift*, *blast radius*, *rollback*, *build time* / *velocidad* / *iteración*.
- Mención explícita a **secretos** (y a Secrets Manager o Vault).
- **Mencionar EKS o Kubernetes** y por qué Ansible pierde relevancia ahí (sección breve).

### 5.3 Entregable

Un archivo:

```
/tmp/ans-09-02/ADR-MUTABLE-VS-IMMUTABLE.md
```

con las 6 secciones y el contenido mínimo listado.

## 6. Resultado esperado

- `ADR-MUTABLE-VS-IMMUTABLE.md` existe y es coherente.
- El validador pasa en verde.
- Un ingeniero externo puede leerlo y entender **qué patrón** aplicas en cada workload y **por qué**.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada decisión está justificada (no solo listada).
- **Reproducibilidad**: alguien podría tomar este ADR y arrancar la implementación en Fase 4 sin ambigüedades mayores.
- **Mantenibilidad**: Markdown válido, tablas bien formadas.

## 8. Validación

```bash
bash tests/validate.sh /tmp/ans-09-02
```

El validador comprueba **estructura**, no semántica. Compara tu ADR con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. Si mañana `legacy-billing` necesita 20 instancias nuevas por un pico, ¿tu decisión cambia? ¿Por qué?
2. Si `checkout-api` sufre un bug crítico en producción, ¿cuánto tarda el rollback con el patrón que elegiste?
3. ¿Hay algún workload para el que elegirías *ni mutable ni inmutable*, directamente *no-Ansible*? Defiéndelo.
4. ¿En qué workload de los tres AWX/AAP aporta más valor? ¿Por qué?
5. Si el equipo crece de 10 a 30 personas, ¿tu ADR aguanta o lo tienes que revisar?

## 10. Extensiones

- Añade una sección **"Fase 2"** describiendo cuándo revisarías el ADR y qué métricas lo gatillarían.
- Añade una tabla **"Boundaries"** que liste qué tipo de cambios van por cada patrón y cuáles **no** van por Ansible en absoluto.
- Añade una sección **"Riesgos conocidos"** por workload (p. ej. `legacy-billing`: coordinación manual; `checkout-api`: AMI sprawl).

## 11. Limpieza

```bash
rm -rf /tmp/ans-09-02
```

No hay procesos ni infraestructura que detener.
