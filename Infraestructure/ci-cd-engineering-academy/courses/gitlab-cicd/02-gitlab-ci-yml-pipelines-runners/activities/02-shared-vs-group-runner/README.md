# Actividad 02 — ADR: shared SaaS runner vs group runner

## 1. Identificación

- **ID:** `gl-02-02-shared-vs-group-runner`
- **Tecnología:** `gitlab-cicd`
- **Módulo:** `gl-02-gitlab-ci-yml-pipelines-runners`
- **Dificultad:** beginner
- **Duración estimada:** 50–70 min
- **Tipo:** architecture (independent — no depende de la actividad 01)

## 2. Contexto

La misma startup de 20 personas que vimos en `aws-15` acaba de abrir su primer grupo en `gitlab.com`: `acme/`. Dos equipos quieren empezar a usar CI/CD *ya*:

- **`acme/checkout`** — API HTTP crítica, procesa pagos, los pipelines necesitan credenciales a una cuenta AWS (Secrets Manager) y a un Vault interno accesible solo desde VPC.
- **`acme/analytics`** — pipeline de notebooks + lint + pytest; sin secretos externos, workloads cortos (<2 min cada uno), ejecución esporádica (unas 20 veces/día).

Están en el **plan Free** (400 minutos CI/CD/mes de shared SaaS runners). Y hay un *platform engineer* (0.5 FTE) que podría operar runners propios si hace falta.

Tu encargo: **decidir y documentar** qué runner usa cada proyecto (shared SaaS runner, group runner propio, o combinación) y plasmarlo en un ADR que un ingeniero externo pueda leer y ejecutar.

**Importante**: no hay runners reales que registrar. El entregable es un **documento**.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Enumerar al menos 3 criterios para elegir entre shared/group/project runner.
- Decidir por workload y defender cada elección (no una respuesta genérica).
- Identificar qué `tags:` tocarías en el `.gitlab-ci.yml` para materializar la decisión.
- Nombrar 2 alternativas que descartaste y por qué.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (en particular §6 "Tipos de runner" y §7 "Registration vs authentication tokens").
- Haber recorrido `examples/01-first-pipeline/` y `examples/02-stages-and-jobs/`.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno. Todo es papel.

## 5. Instrucciones

### 5.1 Prepara el directorio

```bash
mkdir -p /tmp/gl-02-02
cd /tmp/gl-02-02
```

### 5.2 Escribe `ADR-RUNNERS.md`

Formato obligatorio:

```
# ADR 002 — Estrategia de runners para acme/

## Estado
Propuesto | Aceptado | ...

## Contexto
(2-4 párrafos: la startup, los dos workloads, el plan Free, el 0.5 FTE)

## Decisión
(Qué runner para cada proyecto; qué tags; cómo se registra; a quién le pertenece.)

## Consecuencias
(Positivas y negativas de la decisión.)

## Alternativas descartadas
(Al menos 2, con razones.)
```

Secciones obligatorias (el validador las busca):

1. `# ADR` (encabezado con la palabra "ADR").
2. `## Estado` (o `Status`).
3. `## Contexto` (o `Context`).
4. `## Decisión` (o `Decision`).
5. `## Consecuencias` (o `Consequences`).
6. `## Alternativas` (o `Alternatives`).

Contenido mínimo obligatorio (el validador lo exige):

- Mención explícita de **shared** y **group** (y, si decides así, **project**).
- Mención de **`gitlab.com`** o **SaaS** (contexto del plan Free).
- Mención de **`tags:`** o `tag` (cómo se materializa la elección en el YAML).
- Mención de ambos workloads: **`checkout`** y **`analytics`**.
- Mención de al menos **3 criterios de decisión** (coste/minutos; red/VPC; secretos; autoscaling; compliance; operación/FTE).
- Al menos **2 alternativas** listadas (sub-encabezado o item numerado).
- Mención de un **ejemplo de bloque YAML** con `tags:` (bloque de código con *code fences*).

### 5.3 Entregable

```
/tmp/gl-02-02/ADR-RUNNERS.md
```

## 6. Resultado esperado

- `ADR-RUNNERS.md` existe, tiene las 6 secciones, menciona ambos workloads, 3+ criterios y 2+ alternativas.
- Un ingeniero externo lee el ADR y entiende **qué runners vas a usar y por qué**.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada criterio está *aplicado* a los workloads, no listado abstractamente.
- **Reproducibilidad**: alguien en `platform` puede tomar este ADR y crear los runners (si corresponde) y actualizar los `.gitlab-ci.yml` sin ambigüedad.

## 8. Validación

```bash
bash tests/validate.sh /tmp/gl-02-02
```

El validador comprueba **estructura**, no semántica. Compara con `solution/REFERENCE.md` para autoevaluación.

## 9. Preguntas de reflexión

1. Si el budget cambiara a plan Premium (minutos ilimitados pero más caros), ¿tu decisión cambia?
2. ¿Qué pasa si `analytics` crece a 500 ejecuciones/día? ¿Mueves a group runner?
3. ¿Por qué un **project runner** rara vez es la mejor opción cuando ya tienes el group abierto?
4. ¿Qué tag convencional usarías para distinguir runners que acceden al Vault interno?

## 10. Extensiones

- Añade un diagrama ASCII mostrando qué runner recoge qué job.
- Añade una tabla con 3 KPIs que medirías para revisar la decisión en 3 meses (p. ej. `queue_time_p95`, `job_duration_p95`, `minutes_consumidos`).
- Añade una sección "Fase 2" describiendo cuándo migrarías `analytics` también a group runner.

## 11. Limpieza

```bash
rm -rf /tmp/gl-02-02
```
