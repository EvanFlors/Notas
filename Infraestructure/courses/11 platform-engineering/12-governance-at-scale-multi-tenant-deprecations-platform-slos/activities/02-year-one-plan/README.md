# Actividad 02 — Plan de año uno de la plataforma

## 1. Identificación

- **ID:** `plat-12-02-year-one-plan`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-12-governance-at-scale-multi-tenant-deprecations-platform-slos`
- **Dificultad:** advanced
- **Duración estimada:** 80–100 min
- **Tipo:** independent (independiente de la actividad 01)

## 2. Contexto

Mismo escenario base que `01-governance-adr` (AcmeCorp: 180 ingenieros, 8 equipos, 120 servicios, 10 meses con Backstage, 4 personas en platform team).

Diferencia: aquí la tarea no es **la gobernanza** sino el **plan operativo** de los próximos 12 meses — qué entrega el platform team por trimestre, con qué métricas, bajo qué riesgos. Y, crítico, **cómo responde** si la realidad cambia bruscamente en 3 escenarios adversariales que exploraremos.

El plan es público interno. Equipos de producto lo leen para saber qué esperar. Liderazgo lo lee para asignar presupuesto. Platform team lo usa como brújula.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Redactar un **plan trimestral** (Q1-Q4) con objetivos, SLO targets, scope, riesgos y capacity.
- Elegir y defender **métricas de éxito** de la plataforma ancladas en **DORA, scorecard adoption, SLO burn** y **satisfaction**.
- Priorizar nuevas features **y deprecations** con criterio público defensible.
- Mostrar **cómo pivota el plan** ante 3 escenarios adversariales:
  1. **Crecimiento rápido** (ingeniería ×2 en 12 meses).
  2. **Hiring freeze** (sin contratación 6+ meses).
  3. **Consolidación post-merger** (adquisición trae un IDP rival).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §11 — Defender el plan).
- Haber recorrido los **tres** `examples/` del módulo.
- Haber completado `plat-09`, `plat-10` y `plat-11`.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno. **Infraestructura**: ninguna.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/plat-12-year-one
cd /tmp/plat-12-year-one
```

Si usas otro directorio, pásalo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `YEAR-ONE-PLAN.md` con las siguientes secciones

#### Sección — Resumen ejecutivo

Un párrafo (120-200 palabras) con **qué entregamos este año, qué sacrificamos, qué pedimos**.

#### Sección — Q1

Sub-secciones mínimas:

- **Objetivos del trimestre** (3-5 bullets concretos).
- **Platform SLO targets** (qué SLO instrumentamos, con qué objetivo inicial).
- **Scope** (qué incluimos; qué excluimos explícitamente).
- **Riesgos** y mitigaciones.
- **Hiring / capacity** (cuánta gente, cuánto esfuerzo, dónde).

#### Sección — Q2

Mismas sub-secciones. Debe **construir sobre** Q1 (no empezar de cero).

#### Sección — Q3

Mismas sub-secciones.

#### Sección — Q4

Mismas sub-secciones. Debe incluir **revisión del año** y **semilla del año siguiente**.

#### Sección — Escenarios

Para cada uno de los 3 escenarios adversariales:

1. **Crecimiento rápido** (ingeniería ×2 en 12 meses).
2. **Hiring freeze** (2+ trimestres sin contratación).
3. **Consolidación post-merger** (adquisición con IDP rival).

Para cada escenario responde:

- Qué **cambia** en el plan.
- Qué **objetivos** se mantienen (no negociables) y cuáles se **sacrifican**.
- Qué **SLOs** se re-ajustan (si procede) y por qué.
- Qué **comunicación** necesitas hacer en < 2 semanas desde que el escenario se materializa.

Mínimo: 3 sub-secciones (una por escenario).

#### Sección — Métricas de éxito

Al menos **5 métricas** categorizadas, con la fuente de datos y la cadencia de reporte:

- **DORA** (deployment frequency, lead time, change failure rate, MTTR).
- **Scorecard adoption** (fracción de servicios en Gold o Silver).
- **SLO burn** (presupuesto de error consumido por SLO).
- **Satisfaction** (encuesta trimestral de developer experience).
- **Platform-specific** (adopción de templates, nº de PRs inner-source, tiempo de onboarding).

#### Sección — Roadmap resumen

Timeline ASCII o tabla **trimestre × iniciativa** que resuma Q1-Q4 en un pantallazo.

### 5.3 Entregable

Un archivo:

```
/tmp/plat-12-year-one/YEAR-ONE-PLAN.md
```

con las secciones listadas.

## 6. Resultado esperado

- `YEAR-ONE-PLAN.md` existe y es coherente.
- Las 4 secciones trimestrales (Q1, Q2, Q3, Q4) están presentes con encabezados claros.
- La sección "Escenarios" cubre los 3 escenarios nombrados.
- La sección "Métricas de éxito" lista ≥ 5 métricas con fuente y cadencia.
- Vocabulario mínimo presente: SLO (≥2), DORA, roadmap, platform, scorecard o adopción.
- `bash tests/validate.sh /tmp/plat-12-year-one` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: el plan es **defensible** — no es wishful thinking; cada trimestre justifica su carga de trabajo con el tamaño real del equipo.
- **Realismo**: hay al menos un "**no vamos a X**" explícito en cada trimestre (platform team maduro admite límites).
- **Trazabilidad**: cada métrica de éxito se mapea a un objetivo del plan.
- **Resiliencia**: la sección Escenarios demuestra que has pensado en el plan **no** como una línea recta.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-12-year-one
```

El validador comprueba **estructura** (secciones Q1-Q4, Escenarios, Métricas, keywords), no **semántica**. Compara tu plan con `solution/REFERENCE.md` para autoevaluarte.

## 9. Preguntas de reflexión

1. Si tuvieras que **borrar un trimestre entero** del plan por recorte, ¿cuál y qué dejas en los otros tres?
2. ¿Qué métrica de la sección "Métricas de éxito" es la que **menos** te gustaría enseñar al CFO? ¿Por qué? ¿Cómo la mejoras?
3. En el escenario **hiring freeze**, ¿qué pieza de la plataforma pasarías a **maintenance** la primera semana? Nombra una y defiende.
4. En el escenario **crecimiento rápido**, ¿cómo evitas que la plataforma se vuelva **jaula** (cuellode-botella por review centralizado)?
5. En el escenario **consolidación post-merger**, ¿cómo decides entre fusionar los 2 IDPs o mantenerlos en paralelo durante N trimestres?

## 10. Extensiones

- Añade una **matriz RACI** por iniciativa trimestral (quién es responsable, aprobador, consultado, informado).
- Añade **estimaciones de coste** (persona-mes por iniciativa) y un total trimestral.
- Añade una **sección "cómo mediremos cada iniciativa"** vinculando iniciativa → métrica concreta.
- Añade un **anti-roadmap** explícito: lista de 5-10 cosas que te han pedido y que **no** vas a hacer este año, con razón.

## 11. Limpieza

Como es puramente conceptual:

```bash
rm -rf /tmp/plat-12-year-one
```

No hay procesos, contenedores, ni recursos cloud que detener.
