# Actividad 01 — ADR de operación a escala

## 1. Identificación

- **ID:** `jk-08-01-operate-at-scale-adr`
- **Tecnología:** `jenkins`
- **Módulo:** `jk-08-operate-at-scale-and-migration-to-modern`
- **Dificultad:** advanced
- **Duración estimada:** 80–100 min
- **Tipo:** architecture (independent — no depende de la actividad 02)

## 2. Contexto

Una fintech regulada opera un **Jenkins LTS** desde hace 4 años en una VM EC2 con `JENKINS_HOME` en un volumen EBS. Características:

- **120 pipelines** activos (80 declarative, 40 freestyle que nadie se atreve a tocar).
- **15 agents** permanentes en EC2 (mix de amd64 y arm64).
- **40 ingenieros** usan la UI; picos de 60 builds/hora los lunes por la mañana.
- Compliance exige **retención 7 años** de logs de builds de pipelines marcados "prod".
- SLA interno acordado: **99.5%** disponibilidad en horario laboral; downtime fuera de horario tolerable.
- **No hay presupuesto** para CloudBees CI (lo pidieron, no se aprobó). Hay presupuesto para Kubernetes managed (EKS) ya existente usado por otros equipos.

Tu encargo: **diseñar y documentar la estrategia operacional** (HA, backup, upgrade cadence, capacity, observabilidad) en un ADR que un equipo de 5 personas pueda ejecutar en Fase 4.

**Importante**: no hay cluster real. No se provisiona nada. El entregable es un **documento**.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Elegir y defender un patrón de HA razonable para el contexto (presupuesto, SLA, infra disponible).
- Describir qué incluye el backup del `JENKINS_HOME`, dónde se guarda y cada cuánto se prueba el restore.
- Definir la cadencia de upgrade de Jenkins LTS y plugins.
- Dimensionar controller vs agents y nombrar las métricas que deben alertar.
- Escribir un ADR legible y accionable.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§1 HA, §2 backup, §3 upgrade, §4 capacity, §5 observabilidad).
- Haber recorrido `../../examples/01-jenkins-ha-pattern/`.
- Haber completado `jk-06` (JCasC) y `jk-07` (seguridad).
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno. Todo es papel.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/jk-08-01
cd /tmp/jk-08-01
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-OPERATE-AT-SCALE.md`

Formato ADR estándar:

```
# ADR 001 — Operación a escala del Jenkins corporativo

## Estado
Propuesto | Aceptado | Reemplazado por ADR XXX

## Contexto
(2-4 párrafos: qué problema resuelves, qué constraints hay)

## Decisión
(La estrategia que eliges, concreta: HA, backup, upgrade, capacity, observabilidad.)

## Consecuencias
(Qué ganas, qué pierdes, qué se vuelve más fácil, qué más caro.)

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

- **Diagrama ASCII** del patrón HA elegido (con fences de código).
- Mención explícita de **al menos uno** de: `activo-pasivo`, `CloudBees`, `Operator`.
- Mención explícita de **`JENKINS_HOME`** y de **`backup`** / `restore`.
- Mención de la carpeta `secrets/` o del archivo `master.key` (si no apareces, el que restaure no podrá descifrar credentials).
- Mención de **Velero** o **snapshot** o **S3** como destino del backup.
- Mención explícita de **LTS** y una **cadencia** de upgrade (semanas o meses).
- Mención de **capacity planning** diferenciando **controller** y **agents**.
- Al menos **3 métricas** nombradas que deben alertar (p. ej. `queue_depth`, `executor`, `heap`, o nombres de Prometheus concretos).
- Mención de **`JCasC`** o `jenkins.yaml` como vehículo de reproducibilidad del controller.
- Mención del **SLA 99.5%** del contexto (o justificación explícita si eliges otro).
- Mención de **compliance** o **retención 7 años** de logs.

### 5.3 Entregable

Un archivo:

```
/tmp/jk-08-01/ADR-OPERATE-AT-SCALE.md
```

con las 6 secciones y el contenido mínimo listado.

## 6. Resultado esperado

- `ADR-OPERATE-AT-SCALE.md` existe y es coherente.
- El validador pasa en verde.
- Un ingeniero de guardia puede leer el ADR y saber **qué hacer el día que el controller caiga**.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada decisión está justificada (no solo listada).
- **Reproducibilidad**: alguien podría tomar este ADR y convertirlo en runbooks + Terraform.
- **Mantenibilidad**: Markdown válido, diagramas en code fences.

## 8. Validación

```bash
bash tests/validate.sh /tmp/jk-08-01
```

El validador comprueba **estructura**, no semántica. Compara tu ADR con `solution/REFERENCE.md` después para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Puedes anunciar SLA 99.9% con tu diseño? ¿Qué sería lo máximo honesto?
2. Si olvidas incluir `secrets/master.key` en el backup, ¿qué pasa en el restore?
3. ¿Cómo detectas que una LTS trajo un breaking change antes de que paralice producción un lunes?
4. Si Finance de repente aprueba CloudBees CI, ¿tu plan permite migrar a él sin rehacer todo? ¿Qué pieza del plan ya es portable?
5. Un auditor pregunta "muéstrame el procedimiento de restore y el último ensayo". ¿Dónde está?

## 10. Extensiones

- Añade una sección **"Runbooks"** con los 3 procedimientos operativos clave (restore, upgrade, scale-out de agents).
- Dibuja un **diagrama de observabilidad** (métrica → alerta → acción).
- Añade un plan de **chaos drill** mensual (p. ej. apagar el controller un viernes a las 15:00 en staging).

## 11. Limpieza

```bash
rm -rf /tmp/jk-08-01
```

No hay procesos ni infraestructura que detener.
