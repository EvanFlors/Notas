# REFERENCE — plat-12-02-year-one-plan

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

## Resumen ejecutivo

AcmeCorp platform team (4 personas, sin contratación en Q1-Q2) entrega este año: (1) **gobernanza publicada** y adoptada (ADR + SLOs + deprecation policy); (2) **4 SLOs instrumentados** con error budget operativo; (3) **8 AppProjects** Argo CD migrados fuera del `default`; (4) **12 → 6 templates** limpiados y bajo SemVer con inner-source habilitado; (5) **scorecard adoption** del 50 % de servicios en Silver o Gold. Sacrificamos: nuevos plugins Backstage grandes (los diferimos a Q4 o año 2), auto-provisioning de nuevos dominios cloud (lo mantenemos manual con ticket). Pedimos: 2 personas más desde Q3 (si el *freeze* se levanta) y presupuesto para LaunchDarkly interno + Pyrra como herramienta SLO.

## Q1 — Fundamentos y SLOs

### Objetivos del trimestre

1. **Publicar ADR de gobernanza** (actividad `01-governance-adr`) y presentarlo en all-hands.
2. **Instrumentar los 4 SLOs mínimos** (Backstage uptime, scaffolder p95, catalog freshness, MTTR).
3. **Auditoría del catalog**: completar ownership del 100 % de servicios en producción (hoy 70 %).
4. **Lanzar `#platform-help` y `#platform-announcements`** separados; cerrar canales legacy.
5. **Primer office hour** quincenal.

### Platform SLO targets (iniciales)

- Backstage uptime: **99.0 %** (objetivo stretch 99.5 % para Q2).
- Scaffolder p95: **< 90 s** (stretch 60 s para Q2).
- Catalog freshness p99: **< 10 min** (stretch 5 min para Q2).
- MTTR P1/P2 p90: **< 3 h** (stretch 2 h para Q3).

Baja ambición en Q1 porque **no hay baseline aún**; mejor publicar algo defendible y subir que lo contrario.

### Scope

- **Incluido**: SLO instrumentation, ADR, catalog audit, deprecation de 3 templates ya muertos.
- **Excluido**: nuevos plugins, nuevos XRDs, migración de autenticación.

### Riesgos

- Catalog audit puede destapar más de 50 servicios sin owner → **mitigación**: proceso de "asignación por default al equipo más probable + 30 d para disputar".
- Oncall sin runbooks → **mitigación**: cada SLO viene con runbook mínimo en TechDocs.

### Hiring / capacity

- 4 personas × 12 semanas × 70 % foco plataforma (resto oncall + overhead) = ~34 persona-semanas.
- Reparto aproximado: 10 ADR + comms, 12 SLO instrumentation, 8 catalog audit, 4 limpieza templates.

## Q2 — Multi-tenancy y versionado

### Objetivos del trimestre

1. **Migración `default` AppProject** a 8 AppProjects (uno por equipo).
2. **Backstage permissions** habilitadas con policy por owner.
3. **SemVer + CHANGELOG** obligatorio en el repo platform-core (CI falla si no se actualiza).
4. **Templates `v2`** de los top-3 lenguajes (Python, Go, Node) con observabilidad OTel incluida.
5. **Subir SLOs** a objetivos stretch (uptime 99.5, scaffolder 60s, freshness 5min).

### Platform SLO targets

Suben a objetivo definitivo. Si al día 60 del trimestre un SLO va rojo, revisar objetivo (no al revés).

### Scope

- **Incluido**: multi-tenant Argo CD + Backstage, versionado, templates v2.
- **Excluido**: inner-source abierto (eso es Q3 cuando el repo esté más limpio).

### Riesgos

- La migración AppProject puede romper despliegues si alguna app estaba enganchada al `default` por URL hard-codeada → **mitigación**: inventario previo + dry-run por equipo.
- Backstage permissions puede bloquear flujos legítimos si la ownership tiene errores → **mitigación**: deploy en modo *warn-only* 2 semanas antes de enforce.

### Hiring / capacity

- 4 personas × ~34 persona-semanas. Reparto: 14 AppProjects + permissions, 10 templates v2, 6 SemVer/CI, 4 buffer.

## Q3 — Inner-source y deprecations

### Objetivos del trimestre

1. **Lanzar inner-source formal**: CONTRIBUTING.md, CODEOWNERS por área, SLA de review, canal `#platform-contribute`.
2. **Nominar primeros 3 trusted committers** (ya identificados desde Q2 por volumen de PRs externas).
3. **Deprecations activas**: deprecar formalmente 6 piezas (3 templates v1, 1 XRD v1 de postgres, 2 librerías legacy).
4. **Hiring**: onboarding de **2 personas más** si el freeze se ha levantado (si no → aplicar escenario Hiring Freeze).
5. **Primer dashboard "Platform Status"** público interno con los 4 SLOs.

### Platform SLO targets

Mantener objetivos de Q2. Añadir **5º SLO opcional**: deployment success rate del scaffolder (fracción de ejecuciones que terminan en PR mergeable, > 95 %).

### Scope

- **Incluido**: inner-source, deprecations formales, dashboard, onboarding si procede.
- **Excluido**: nuevo plugin Backstage grande (se diseña ADR en Q4 para implementar en año 2).

### Riesgos

- Trusted committers pueden tardar más de un trimestre en estabilizarse → **mitigación**: fallback de review por platform team queda disponible.
- Si no hay hiring, la carga crece → **mitigación**: inner-source compensa; si no basta, se activa plan "Hiring Freeze" de Escenarios.

### Hiring / capacity

- Si onboarding: 6 personas × 12 semanas × 50 % foco (los nuevos entran al 30 % en Q3, 80 % en Q4) ≈ 40 persona-semanas efectivas.
- Si freeze continúa: 4 × 34 persona-semanas, se aplican los recortes del escenario.

## Q4 — Consolidación, revisión y semilla

### Objetivos del trimestre

1. **Hard-remove** de las 6 piezas deprecadas en Q3 (si pasó el TTL — típicamente 90-180 d, ajustar).
2. **Revisión semestral** del ADR y de los trusted committers.
3. **Encuesta de developer experience** (CSAT, net promoter interno).
4. **Postmortem agregado del año**: qué funcionó, qué no, qué llevamos al año 2.
5. **Diseño del próximo plugin grande** (ADR + prototipo) para implementación en año 2.
6. **Plan de año 2 draft** publicado para feedback.

### Platform SLO targets

Mismos que Q3. Revisión formal: si algún SLO lleva 2 trimestres estable con budget sobrado, considerar **subir** el objetivo. Si uno falló consistentemente, **bajar** honestamente.

### Scope

- **Incluido**: hard-removes, revisión semestral, CSAT, planificación año 2.
- **Excluido**: nuevas features grandes — es un trimestre de **consolidación**.

### Riesgos

- Hard-removes pueden encontrar consumidores no detectados → **mitigación**: emergency help window + 48 h de soporte intensivo.
- Fatiga de equipo tras un año denso → **mitigación**: trimestre deliberadamente ligero en nuevas features.

### Hiring / capacity

- Si fuimos 6: ~45 persona-semanas (equipo asentado).
- Si fuimos 4: ~34 persona-semanas; menos ambición en diseño año 2 (lo movemos a Q1 año 2).

## Escenarios

### Escenario 1 — Crecimiento rápido (ingeniería ×2 en 12 meses)

**Qué cambia:**

- La **demanda** sobre la plataforma crece más rápido que nuestra capacidad incluso con hiring.
- Nuevos equipos entran con stacks heterogéneos que no cubren nuestros templates (Rust, Scala, ciertos frameworks ML).
- Presión política por "integrar YA" todo lo nuevo.

**Qué se mantiene (no negociable):**

- Los 4 SLOs y la deprecation policy. Si no, se rompe el contrato con los equipos actuales.
- CODEOWNERS y SLA de review. Si no, el platform team se funde.

**Qué se sacrifica:**

- Nuevos templates propios → se transfieren al modelo inner-source **antes** de lo planeado (Q2 en vez de Q3).
- Dashboard "Platform Status" se publica más tarde (Q4) porque la instrumentación se complica con más tenants.
- Diseño de plugin grande se mueve a año 2.

**SLOs re-ajustados:**

- **Scaffolder p95**: afloja a < 90 s mientras se añade capacidad al backend (más workers).
- **Catalog freshness**: afloja a < 10 min hasta que escalemos el sync.

**Comunicación en < 2 semanas:**

- Anuncio en all-hands: "crecimiento acelerado → prioridades reorganizadas → inner-source acelerado → aquí los nuevos SLO targets temporales".
- Office hour especial con los equipos nuevos para onboarding express.
- FAQ pública con "cuándo esperar X".

### Escenario 2 — Hiring freeze (2+ trimestres sin contratación)

**Qué cambia:**

- Capacidad congelada en 4 personas durante 6+ meses.
- Demanda sigue creciendo (aunque menos que en Escenario 1).

**Qué se mantiene (no negociable):**

- SLO uptime Backstage y SLO MTTR. Son el contrato básico; si la plataforma se cae, bloquea a todos.
- Oncall. Todos los componentes propios tienen oncall rotatorio.

**Qué se sacrifica:**

- Templates v2 de Node (mantenemos v1 en soporte, no deprecamos). Se diferimos a año 2.
- Dashboard "Platform Status" avanzado (bastará versión básica).
- Office hours baja de quincenal a mensual.
- Diseño de plugin grande se cancela.

**Deprecaciones agresivas (liberar capacidad):**

- Pasar a **maintenance** 3 piezas más (p. ej. XRD de bucket legacy, template Perl que casi nadie usa, API vieja de catálogo).
- Comprimir TTLs de deprecation en 1 nivel (template de 90 d a 60 d) **con comunicación clara** y office hour extra.

**SLOs re-ajustados:**

- Mantener objetivos. Pero si burn-rate dispara freeze, el **freeze dura más** porque hay menos manos para arreglar.
- MTTR p90 pasa a < 3 h (más honesto con equipo reducido).

**Comunicación en < 2 semanas:**

- Mail interno + Slack: "freeze → qué se mantiene y qué baja de prioridad → inner-source es MÁS importante, aquí cómo contribuir".
- Lista pública (no secreta) de piezas que entran en maintenance.
- Office hour especial para re-explicar la escalera trusted-committer.

### Escenario 3 — Consolidación post-merger (adquisición trae IDP rival)

**Qué cambia:**

- Aparece una segunda plataforma (p. ej. Port, Humanitec, o Backstage con otro skin + plugins incompatibles).
- Dos culturas platform-team coexisten.
- Presión política por "elegir el mejor" o "fusionar".

**Qué se mantiene (no negociable):**

- Ownership del catalog unificado — no puede haber dos catálogos de verdad.
- SLO uptime del IDP que termine ganando (sea el nuestro o el otro).

**Qué se sacrifica:**

- Templates nuevos de este año → se congelan hasta decidir qué IDP gana.
- Nuevos XRDs → se congelan.
- Features nuevas → se congelan excepto bugfixes y seguridad.

**Decisión técnica (criterios públicos):**

1. **Adopción real** medida (nº servicios activos, nº equipos, scorecard adoption).
2. **SLO histórico** del último trimestre.
3. **Deuda técnica** medible (versiones de dependencias, tests, docs).
4. **Alineación con roadmap de negocio** post-merger.

Si gana el nuestro: tratamos el IDP rival como un **tenant más** a migrar aplicando el ciclo de deprecation (anuncio → warn → remove) con TTLs extra-generosos (6-12 meses).

Si gana el rival: pasamos a **modo migración inverso** y empezamos a deprecar el nuestro con el mismo ciclo.

Si ninguno gana claramente: **plazo máximo de 2 trimestres** para decidir (nunca eterno; dos IDPs es insostenible).

**SLOs re-ajustados:**

- Mantener los nuestros hasta la decisión. Si somos el "perdedor", **mantener uptime** hasta el final del ciclo (es el contrato: no se abandona a tenants vivos).

**Comunicación en < 2 semanas:**

- All-hands conjunto con el otro platform team: "aquí la realidad, aquí los criterios, aquí el calendario".
- Decision log público en Backstage/Confluence actualizado semanalmente.
- Office hour abierto a ambas organizaciones.
- Honestidad brutal: "sabemos que un lado se va a quedar triste; aquí cómo intentamos minimizar el daño cultural".

## Métricas de éxito

Reportadas trimestralmente en all-hands y públicas en el dashboard "Platform Status".

| Categoría | Métrica | Fuente | Cadencia |
|-----------|---------|--------|----------|
| **DORA** | Deployment frequency (deploys/semana/servicio) | CI events → BigQuery/Prometheus | Semanal |
| **DORA** | Lead time (commit → prod) | Git events + deploy events | Semanal |
| **DORA** | Change failure rate (% deploys que generan incidente) | Deploy events + PagerDuty | Mensual |
| **DORA** | MTTR (de servicios usando golden path) | PagerDuty + git | Mensual |
| **Scorecard** | % servicios en Silver o Gold | Backstage scorecards plugin | Mensual |
| **SLO burn** | Error budget consumido por SLO | Prometheus / Pyrra | Semanal |
| **Satisfaction** | Encuesta CSAT / NPS interno | Google Form trimestral | Trimestral |
| **Platform-specific** | Nº servicios usando templates v2 | Catalog annotations | Mensual |
| **Platform-specific** | Nº PRs inner-source merged | GitHub API | Mensual |
| **Platform-specific** | Tiempo medio de onboarding de un servicio nuevo | Scaffolder events | Trimestral |

**Umbrales mínimos de salud** (orientativos):

- Deploy frequency ≥ **daily** para servicios en golden path.
- Change failure rate < **15 %** (DORA Elite < 5 %, pero somos realistas en año uno).
- % servicios Silver+ ≥ **40 %** fin de año 1 (stretch 50 %).
- % PRs inner-source ≥ **20 %** fin de año 1.

## Roadmap resumen

```
          │   Q1               │   Q2               │   Q3               │   Q4
──────────┼────────────────────┼────────────────────┼────────────────────┼───────────────────
Gobernanza│ ADR publicado      │ SemVer/CHANGELOG   │ Inner-source live  │ Revisión semestral
          │ 4 SLOs instrument. │ en CI              │ 3 trusted comm.    │ Encuesta DX
──────────┼────────────────────┼────────────────────┼────────────────────┼───────────────────
Multi-ten │ Catalog audit 100% │ 8 AppProjects      │ ---                │ Revisión fronteras
          │ Permissions WARN   │ Permissions ENFORCE│                    │
──────────┼────────────────────┼────────────────────┼────────────────────┼───────────────────
Templates │ Limpieza 3 muertos │ v2 Python/Go/Node  │ v1 → maintenance   │ Hard-remove v1
──────────┼────────────────────┼────────────────────┼────────────────────┼───────────────────
Deprec.   │ Policy publicada   │ Primera deprec.    │ 6 piezas en ciclo  │ Hard-removes
──────────┼────────────────────┼────────────────────┼────────────────────┼───────────────────
SLO/freez │ Objetivos iniciales│ Sube a definitivos │ 5º SLO opcional    │ Revisión + ajuste
──────────┼────────────────────┼────────────────────┼────────────────────┼───────────────────
Comms     │ #platform-* lanzan │ Office hour quinc. │ Dashboard pub.     │ All-hands anual
──────────┴────────────────────┴────────────────────┴────────────────────┴───────────────────
```

## Anti-roadmap (lo que NO vamos a hacer este año)

1. Reescribir Backstage.
2. Nuevo plugin propio grande (p. ej. "Cost Explorer interno").
3. Auto-provisioning de nuevos dominios cloud (sigue siendo ticket).
4. Multi-cloud (seguimos en GCP; AWS/Azure si llegan, se evalúa año 2).
5. Service mesh propio (reutilizamos Istio ya desplegado).
6. Portal mobile.
7. Chatbot IA sobre el catalog (bonito, no urgente).

Cada punto tiene razón pública en el canal de anuncios. "No" es una respuesta válida y la damos **con explicación**.
