# Actividad 01 — ADR de gobernanza de la plataforma

## 1. Identificación

- **ID:** `plat-12-01-governance-adr`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-12-governance-at-scale-multi-tenant-deprecations-platform-slos`
- **Dificultad:** advanced
- **Duración estimada:** 80–100 min
- **Tipo:** architecture (independiente de la actividad 02)

## 2. Contexto

Trabajas como *tech lead* del platform team de **AcmeCorp**:

- 180 ingenieros de producto, repartidos en **8 equipos** (checkout, catalog, search, payments, data-platform, ml, mobile, web-frontend).
- **~120 servicios** en producción, desplegados en **3 clusters K8s** (us-east-1, eu-west-1, ap-southeast-1) y **1 cluster** no-prod.
- Backstage adoptado hace 10 meses; **catalog** con 70 % de servicios registrados.
- Argo CD con un único `default` AppProject (**antipatrón** que arrastras).
- Scaffolder con **12 templates**, 3 de ellos deprecated **de facto** (nadie los usa) pero aún publicados.
- Sin **SLOs formales** para Backstage o el scaffolder — recibes quejas por **lentitud del scaffolder** sin saber si están dentro de lo esperado.
- Platform team: **4 personas** (incluyéndote). No habrá más en 2 trimestres.

Liderazgo te pide un **ADR de gobernanza** que fije las reglas de operación de la plataforma para el próximo año. El ADR debe ser **concreto, defendible y publicable** (cualquier ingeniero de la empresa debe poder leerlo y entender las reglas).

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Modelar el **multi-tenancy** en los 4 planos (K8s, cloud, Argo CD, Backstage) con fronteras claras y defensibles para AcmeCorp.
- Definir una **deprecation policy** con TTLs explícitos y clasificación supported/maintenance/legacy aplicable a los 12 templates existentes.
- Escribir **al menos 4 SLOs** con SLI, objetivo, error budget y burn-rate pensado.
- Fijar la **release cadence** (continuo con flags vs trimestral) y el criterio para elegir una u otra.
- Fijar el **modelo de versionado** de XRDs, templates y APIs internas (SemVer + changelog obligatorios).
- Fijar el **modelo inner-source** con CODEOWNERS, SLA de review y escala trusted-committer.
- Enumerar **consecuencias** y **alternativas consideradas** del ADR.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo.
- Haber recorrido los **tres** `examples/` del módulo.
- Haber completado `plat-09`, `plat-10` y `plat-11`.
- Herramientas: `bash` y un editor Markdown. Nada más.

**Costos**: ninguno. **Infraestructura**: ninguna.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/plat-12-governance
cd /tmp/plat-12-governance
```

Si usas otro directorio, pásalo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `GOVERNANCE-ADR.md` con las 9 secciones siguientes

Usa formato ADR estándar (ADR = *Architecture Decision Record*). Cada sección tiene su encabezado `##`.

#### Sección 1 — Contexto

Describe la situación de AcmeCorp (resumen de §2) y por qué este ADR existe **ahora**. 150–300 palabras.

#### Sección 2 — Decisión: multi-tenancy

Formato por **plano**. Para cada uno de los 4 planos:

- **Decisión** concreta (p. ej. "un namespace por servicio por entorno").
- **Fronteras** (qué protege, qué no).
- **Patrón de nombres** (p. ej. `<team>-<service>-<env>`).

Mínimo: 4 sub-decisiones (una por plano).

#### Sección 3 — Decisión: deprecation policy

- Los **3 estados** (supported / maintenance / legacy) con qué garantiza cada uno.
- **TTLs explícitos** por tipo de pieza (template, XRD, API, librería).
- **Cadencia de comunicación** mínima.
- Qué pasa en **hard-remove** si queda un consumidor sin migrar.

#### Sección 4 — Decisión: platform SLOs

**Al menos 4 SLOs** con, para cada uno:

- **SLI** (cómo se mide).
- **Objetivo** numérico + ventana.
- **Error budget** derivado.
- **Burn-rate alerts** esperadas (fast / slow).

#### Sección 5 — Decisión: release cadence

- **Continuo con feature flags** para X tipos de cambio.
- **Trimestral** para Y tipos de cambio.
- **Freeze por error budget**: cuándo se dispara, cómo se levanta.
- Criterios de elegibilidad entre las dos cadencias.

#### Sección 6 — Decisión: versionado de contratos

- **SemVer** aplicado a XRDs, templates, APIs internas, librerías.
- **Changelog** obligatorio con formato *Keep a Changelog*.
- Estrategia de **convivencia** durante breaking changes (dual-run, shim, migration script).
- Qué cuenta como "contrato" y qué no.

#### Sección 7 — Decisión: inner-source

- **Qué se acepta** y **qué no** como contribución externa.
- Modelo de **CODEOWNERS** (quién revisa qué).
- **SLA de review** público.
- **Escala trusted-committer** con criterios de promoción objetivos.
- Qué **retiene** el platform team (visión, veto, oncall, arquitectura).

#### Sección 8 — Consecuencias

Qué cambia a partir de este ADR:

- **Positivas**: qué mejora.
- **Negativas** / costes: qué sacrificas.
- **Riesgos**: qué puede salir mal.
- **Impacto operacional** inmediato (próximas 2 semanas).

Al menos **4 ítems numerados** entre las tres sub-secciones.

#### Sección 9 — Alternativas consideradas

Al menos **3 alternativas** evaluadas y descartadas, con razón:

- Alternativa A (p. ej. "un AppProject global" vs "uno por equipo") — descartada porque…
- Alternativa B (p. ej. "99.9 % uptime en vez de 99.5 %") — descartada porque…
- Alternativa C (p. ej. "release-train trimestral puro, sin continuo") — descartada porque…

### 5.3 Entregable

Un archivo:

```
/tmp/plat-12-governance/GOVERNANCE-ADR.md
```

con las 9 secciones.

## 6. Resultado esperado

- `GOVERNANCE-ADR.md` existe y es coherente.
- Las 9 secciones están presentes con encabezados claros.
- Al menos 6 "Decisión" marcadores (uno por plano multi-tenant, uno por sección 3-7, más los que añadas).
- Al menos 4 SLOs definidos con SLI + objetivo + budget.
- Al menos 4 ítems numerados en consecuencias y alternativas.
- Vocabulario mínimo presente: multi-tenancy, deprecation, SLO, error budget, inner-source, SemVer, AppProject, changelog, scaffolder.
- `bash tests/validate.sh /tmp/plat-12-governance` sale en verde.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada decisión está **defendida** con 1–3 líneas de porqué, no solo enunciada.
- **Reproducibilidad**: alguien que lea el ADR puede operar la plataforma siguiendo esas reglas.
- **Mantenibilidad**: Markdown válido, encabezados consistentes, tablas legibles cuando aplican.
- **Honestidad**: incluye al menos un "**no vamos a hacer X todavía**" explícito (ningún equipo hace todo bien a la vez).

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-12-governance
```

El validador comprueba **estructura** (secciones, keywords, counts), no **semántica**. Compara tu ADR con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. Si AcmeCorp **duplicara** su ingeniería en 12 meses, ¿qué sección de tu ADR cambiaría primero y por qué?
2. ¿Por qué el `default` AppProject es un antipatrón incluso en equipos pequeños? Nombra 2 problemas concretos que evita salir de él.
3. Si el SLO de uptime de Backstage se incumpliera **dos meses seguidos**, ¿qué prefieres: (a) bajar el SLO al 99 %, (b) congelar features y arreglar, (c) subir el oncall? Defiende la elección y los sacrificios.
4. ¿Qué contribución **no aceptarías** como inner-source aunque la PR fuera técnicamente perfecta? ¿Por qué?
5. ¿Cuál es la decisión del ADR que **menos** vas a disfrutar comunicando? ¿Cómo la comunicas?

## 10. Extensiones

- Añade una **sección 10 — Revisión**: en qué fecha se revisará el ADR y bajo qué triggers (crecimiento ×2, caída de SLO, hiring freeze, etc.).
- Añade una **tabla de ownership** por área (quién mantiene templates Python, quién mantiene XRDs, etc.) al estilo CODEOWNERS pero narrada.
- Dibuja un **diagrama ASCII** del modelo multi-tenant mostrando los 4 planos y cómo se relacionan.
- Redacta un **tweet-length summary** (280 caracteres) del ADR para difundir en el canal de anuncios.

## 11. Limpieza

Como es puramente conceptual:

```bash
rm -rf /tmp/plat-12-governance
```

No hay procesos, contenedores, ni recursos cloud que detener.
