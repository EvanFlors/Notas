# Actividad 01 — ADR de selección de IDP

## 1. Identificación

- **ID:** `plat-03-01-tool-choice-adr`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-03-idp-landscape-backstage-port-cnoe`
- **Dificultad:** beginner
- **Duración estimada:** 50–70 min
- **Tipo:** independent (sin dependencia de la actividad 02)

## 2. Contexto

Tu nuevo equipo plataforma (3 ingenieros, perfiles mixtos K8s/Go/TS) debe elegir **una** herramienta IDP para una organización de **~250 developers** distribuidos en **40 microservicios** (mayoría Go y Python), operando sobre **EKS multi-tenant**. El CTO pidió una decisión en 2 semanas y advirtió que *Vendor X* (ponle Port, OpsLevel o Humanitec) ya está presionando con una demo para "cerrar antes de fin de trimestre".

Tienes que redactar un **ADR (Architecture Decision Record)** que:

1. Enuncie la decisión en una línea.
2. Documente el contexto, las fuerzas en juego, las alternativas evaluadas y las razones por las que **no** se eligieron.
3. Explicite consecuencias (positivas y negativas) y acciones de seguimiento.
4. Sobreviva a presión comercial de un vendor sin romperse.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Redactar un ADR formal (secciones estándar: Status, Context, Decision, Alternatives, Consequences, Follow-ups).
- Articular **al menos 3 criterios no-tecnológicos** (financiamiento, hiring, deprecations, adopción interna) que pesan tanto como los tecnológicos.
- Descartar **al menos 3 alternativas** con una razón específica (no "no nos convenció") cada una.
- Nombrar **al menos 2 consecuencias negativas** aceptadas con la decisión y cómo las mitigas.
- Defender la decisión en 2–3 frases ante un vendor que presiona por "todas las features".

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §2, §8, §9).
- Haber recorrido los tres `examples/` del módulo.
- Haber completado `plat-01` y `plat-02`.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno. Sin cloud, sin SaaS trials, sin contenedores.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/plat-03-adr
cd /tmp/plat-03-adr
```

Puedes usar otro directorio, pero entonces debes pasárselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR.md` con las secciones requeridas

Formato ADR mínimo (ver `starter/TEMPLATE.md`):

```
# ADR-001: Selección de IDP para <nombre de la organización ficticia>

## Status
Proposed | Accepted | Deprecated | Superseded

## Context
<por qué estamos tomando esta decisión; situación organizacional,
tamaño del equipo, stack, presupuesto, horizonte>

## Decision
<herramienta elegida, en una línea clara>

## Alternatives considered
- **<alternativa 1>** — razón de descarte específica.
- **<alternativa 2>** — razón de descarte específica.
- **<alternativa 3>** — razón de descarte específica.
(mínimo 3)

## Consequences
### Positivas
- ...

### Negativas (aceptadas)
- ...

## Follow-ups
- Acciones concretas con dueño y horizonte (ej.: "medir platform NPS en 90 días — PE lead").
```

### 5.3 Reglas de contenido

El validador comprobará **estructura**. La **calidad** la revisas tú contra `solution/REFERENCE.md`. Reglas que debe cumplir tu ADR:

- Menciona explícitamente **al menos 4** de las herramientas del módulo: Backstage, Port, OpsLevel, Cortex, Humanitec, CNOE.
- Nombra la decisión (herramienta elegida) de forma inequívoca.
- Incluye **al menos 3 alternatives considered** con razón de descarte.
- Incluye **al menos 2 consequences negativas aceptadas** (no solo positivas).
- Incluye **al menos 1 follow-up** con dueño/responsable y horizonte temporal.
- Menciona **al menos 2 criterios no-tecnológicos** (presupuesto, hiring, adopción, financiamiento, deprecations, lock-in).
- Menciona la noción de **TCO** o **coste total** (capex vs opex).
- Menciona **vendor** o **lock-in** al menos una vez.

### 5.4 Entregable

Un archivo:

```
/tmp/plat-03-adr/ADR.md
```

con todas las secciones.

## 6. Resultado esperado

- `ADR.md` existe y es coherente.
- Status, Context, Decision, Alternatives, Consequences, Follow-ups presentes.
- `bash tests/validate.sh /tmp/plat-03-adr` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada alternativa descartada tiene razón específica, no genérica.
- **Reproducibilidad**: otro ingeniero que lea el ADR puede defender la misma decisión.
- **Mantenibilidad**: Markdown válido, headings consistentes.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-03-adr
```

El validador comprueba **estructura**, no semántica. Compara tu ADR con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. Si el equipo plataforma pasara de 3 a 10 ingenieros en 12 meses, ¿cambiaría tu decisión? ¿Por qué?
2. El CTO insiste: *"Port es más barato porque no requiere ingeniería interna"*. ¿Qué le respondes **sin** descalificar Port ni la pregunta?
3. ¿Qué 2 señales operativas (métricas, feedback) activarían una revisión del ADR en 12 meses?
4. ¿Cuál es el escenario en el que tu decisión sería **inequívocamente mala**? Nombra ese riesgo explícitamente en el ADR.
5. Si tuvieras que ir solo con dos finalistas a un PoC de 3 semanas, ¿cuáles elegirías y qué medirías?

## 10. Extensiones

- Añade una **matriz comparativa** (tabla Markdown) con 4 columnas (herramienta × 4 criterios ponderados) y los puntajes que llevaron a la decisión.
- Redacta un **mensaje de 5 líneas** para enviar al vendor que presionaba, explicando por qué no se eligió — profesional y defendible.
- Diseña una **métrica de éxito** medible a 6 meses para evaluar objetivamente si la elección fue correcta.

## 11. Limpieza

Como es puramente conceptual:

```bash
rm -rf /tmp/plat-03-adr
```

No hay procesos ni contenedores que detener.
