# Actividad 02 — Identificación de antipatterns de platform team

## 1. Identificación

- **ID:** `plat-01-02-antipattern-identification`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-01-principles-team-topologies-and-cognitive-load`
- **Dificultad:** beginner
- **Duración estimada:** 50–70 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Montar un platform team sin cuidado es la vía más rápida para construir, en 12 meses, un **cuello de botella con nombre bonito**. Los antipatterns se repiten en empresa tras empresa — ivory tower, ticketing, dumping ground, enabling eterno — y suelen pasar desapercibidos porque **cada uno se defiende** con un argumento razonable ("tenemos que mantener la calidad", "si no revisamos, se les escapa cualquier cosa", "nadie más quiere ese sistema").

Esta actividad entrena el ojo clínico. Para **4 situaciones** descritas en prosa, vas a nombrar el antipattern dominante, explicar su daño medible y proponer el **movimiento correctivo accionable en 90 días**.

El entregable es un análisis técnico en Markdown. **No hay** cluster, ni `kubectl`, ni código. Es puramente conceptual.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Reconocer los 4–6 antipatterns más comunes de platform team y nombrarlos con precisión.
- Articular, para cada antipattern, su **causa raíz** y su **daño concreto** (cognitive load, DORA, platform NPS, riesgo de incidentes).
- Proponer un **movimiento correctivo** concreto, acotado en el tiempo (90 días) y medible.
- Explicar por qué un **"platform ticket queue"** degrada estructuralmente la propuesta de valor de la plataforma.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §5, §7, §8).
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/plat-01-anti
cd /tmp/plat-01-anti
```

Puedes usar otro directorio, pero entonces debes pasárselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Las 4 situaciones

Para cada una, escribe una sección en `ANTIPATTERNS.md` con el formato que ves más abajo.

#### Situación 1 — "La forma correcta"

> El platform team de **AlfaCorp** (empresa de 400 ingenieros) publicó hace 6 meses un conjunto de 32 "architectural decision records" (ADRs) con "la forma correcta" de construir servicios: lenguaje recomendado, framework recomendado, forma de logging, forma de deployment, forma de tests. Los ADRs son excelentes técnicamente. Sin embargo, en una encuesta reciente, **solo el 18 % de los stream-aligned teams** siguen las recomendaciones; el resto las ignora o las aplica parcialmente. El platform team se queja de que "nadie los sigue". Sus métricas públicas son "nº de ADRs publicados" y "cobertura de linting".

#### Situación 2 — "Abre un ticket"

> En **BetaCorp**, cualquier solicitud de infra (nuevo namespace K8s, abrir un puerto en una NetworkPolicy, crear un bucket S3, rotar un secret) requiere **abrir un ticket a Jira al "Platform team"**. El platform team son 6 ingenieros. Reciben ~250 tickets/mes. El lead-time medio por ticket es **3 días**. Los stream-aligned se quejan de que "cualquier cambio chico tarda una semana". El tech lead del platform team argumenta: "si no revisamos manualmente, se les escapa cualquier cosa".

#### Situación 3 — "Lo que nadie quiere"

> El platform team de **GammaCorp** mantiene, además del CI/CD moderno y el IDP, los siguientes sistemas **heredados**: un cluster Jenkins viejo (3 equipos lo siguen usando), un servidor Nexus con artefactos de 2015, un servicio de "notifications" interno escrito en PHP sin owner original, y 4 "data warehouses" distintos de iniciativas antiguas que nunca se migraron. El 65 % del tiempo del equipo se va en mantener estos sistemas. El 35 % restante lo pelean para construir el IDP nuevo. En revisiones, aparecen propuestas de "pasamos esto también al platform team porque nadie más lo quiere".

#### Situación 4 — "El enabling que nunca termina"

> **DeltaCorp** creó hace 2 años un equipo "Observability Enabling" con mandato explícito de **capacitar temporalmente** a cada stream-aligned en OTel + SLOs. Dos años después, el equipo lleva **18 meses embedded con el stream Checkout**, hace prácticamente todas las PRs de instrumentación de Checkout, mantiene sus dashboards, define sus SLOs, e investiga sus incidentes. El equipo Checkout no sabe operar su propia observabilidad. El Observability Enabling nunca ha rotado a Catalog ni a Pricing (tienen una lista de espera). El manager del enabling argumenta: "si rotamos, Checkout se queda sin cobertura".

### 5.3 Formato de cada sección

Repite para las 4 situaciones:

```
## Situacion N — <titulo corto>

**Antipattern dominante:** <uno de: ivory tower platform team | ticketing-driven ops |
   platform as a dumping ground | DevOps-as-role | platform sin product mindset |
   enabling team eterno>

**Causa raíz (1–3 líneas):** <por qué pasa, no solo qué pasa>

**Daño concreto (3–5 bullets):**
- impacto medible en cognitive load, DORA, platform NPS, incidentes, retention…
- ...

**Movimiento correctivo en 90 días (3–6 acciones concretas):**
- accion 1 (quién, qué, cuándo verificar éxito)
- accion 2
- ...

**Métrica de éxito a los 90 días:**
- 1 o 2 métricas que, si mueven en la dirección correcta, indican que el movimiento funcionó
```

### 5.4 Síntesis final

Añade al final de `ANTIPATTERNS.md` una sección:

```
## Síntesis

**Por qué un "platform ticket queue" degrada la propuesta de valor** (3–5 líneas, con tus palabras):
...

**6 criterios para distinguir un platform team sano de un antipattern:**
1. ...
2. ...
3. ...
4. ...
5. ...
6. ...
```

Las 6 preguntas-criterio deben ser **tuyas**, cortas, operables. Ejemplos de forma (no las copies literalmente):

- "¿Puede un stream-aligned onboarding un servicio nuevo sin abrir un ticket al platform team?"
- "¿Las métricas públicas del platform team incluyen al menos una de adopción o NPS?"

### 5.5 Entregable

Un archivo:

```
/tmp/plat-01-anti/ANTIPATTERNS.md
```

con las 4 secciones de situación + la síntesis.

## 6. Resultado esperado

- `ANTIPATTERNS.md` existe y es coherente.
- Cada situación tiene antipattern nombrado, causa raíz, daño, movimiento correctivo y métrica.
- La síntesis incluye la explicación del "ticket queue" y los 6 criterios numerados.
- `bash tests/validate.sh /tmp/plat-01-anti` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada diagnóstico defendido con criterio técnico (métrica medible, no un slogan).
- **Reproducibilidad**: alguien que lea tu análisis sabe exactamente qué proponer.
- **Mantenibilidad**: Markdown válido.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-01-anti
```

El validador comprueba **estructura**, no semántica. Compara tu análisis con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. En la **situación 1**, el platform team tiene la razón **técnica** y los stream-aligned "equivocados". ¿Por qué eso no cambia el diagnóstico?
2. En la **situación 2**, el argumento "si no revisamos, se les escapa cualquier cosa" **no es falso**. ¿Cómo se resuelve ese riesgo sin ser cuello de botella?
3. En la **situación 3**, ¿cuál es el **primer** sistema legacy que **sacarías** del platform team, y a dónde lo moverías?
4. En la **situación 4**, si rotar significa "Checkout queda temporalmente peor cubierto", ¿cómo defiendes la rotación ante el manager de Checkout?
5. ¿Cuál de los 4 antipatterns es el más **difícil de ver desde dentro** y por qué?

## 10. Extensiones

- Añade una **5.ª situación** inspirada en tu organización real (sin NDA) y analízala con el mismo formato.
- Para la situación 2, diseña una **ladder de servicios self-service** (3 tiers): bajo riesgo auto-aprobado, medio riesgo con policy, alto riesgo con review manual acotada.
- Para la situación 3, dibuja un **plan de deprecation** a 12 meses con comunicación por fases y migración por sistema.

## 11. Limpieza

Como es puramente conceptual:

```bash
rm -rf /tmp/plat-01-anti
```

No hay procesos ni contenedores que detener.
