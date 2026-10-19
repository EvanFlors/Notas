# REFERENCE — jk-01-01-when-not-jenkins-adr

> Una **referencia** razonada. No es la única respuesta correcta — es un modelo contra el que compararte.

---

# ADR 001 — Decisión sobre Jenkins en Nordhaus Insurance

## Estado

Propuesto (Fase 1, mes 0). Objetivo: ser **Aceptado** por CTO + Security + Finanzas al cierre del Q siguiente, y materializado en Fase 2 con equipo de plataforma.

## Contexto

Nordhaus Insurance opera 1.400 jobs en un Jenkins on-prem desplegado en 2017. La mezcla real es insana: 40% freestyle sin versionar, 35% Scripted Pipeline, 25% Declarative. El controller cae ~1 vez al mes bajo carga de release nocturna; 180 plugins instalados (60 sin uso en 2 años); 3 CVEs críticos en el último año parcheados tarde; `JENKINS_HOME` con backup pero sin restore drill desde 2022; equipo de 2 personas con rotación reciente.

Constraints no negociables:

- **Compliance**: GDPR + Solvency II; logs de pipelines auditables 7 años.
- **Residencia de datos**: datacenter europeo obligatorio.
- **Legal veto a SaaS externo**: nada de github.com ni gitlab.com. Jenkins on-prem, **GHES** o **GitLab self-managed** son opciones; SaaS no.
- **SCM corporativo**: GitLab self-managed desde 2019, bien operado, equipo cómodo.

Expectativa de la CTO: en 24 meses, "sano, y preferiría salir de Jenkins si es posible".

## Decisión

### 1. Recomendación

**Modernizar Jenkins ya + preparar migración por olas a GitLab CI self-managed en horizonte 18-24 meses**. No big-bang. No "fuera Jenkins ya". No "mantener para siempre".

Las dos fases avanzan **en paralelo**:

- **Fase A (0–6 meses) — modernización**: estabilizar lo existente para no explotar en producción mientras se planifica la migración.
- **Fase B (3–24 meses) — migración por olas**: inventario, clasificación, dual-run, OIDC, retirada.

### 2. Diagrama (árbol de decisión aplicado)

```
       ¿Hay Jenkins?  SÍ (1.400 jobs)
                │
       ¿Es moderno?  NO (snowflake con freestyle masivo)
                │
       ¿Repos en GitHub?  NO (GitLab self-managed)
                │
       ¿On-prem obligatorio?  SÍ (GDPR + Solvency II + veto SaaS)
                │
       ¿Dolor operativo recurrente?  SÍ (caídas, CVEs, rotación)
                │
                ▼
  Plan: Modernizar + Migrar por olas a GitLab CI self-managed
  Target: Jenkins apagado o residual al mes 24
```

### 3. Comparación de alternativas

| Opción | Pros | Contras | Veredicto |
|--------|------|---------|-----------|
| Mantener Jenkins "as is" | Cero disrupción corto plazo. | Deuda crece; superficie CVE; equipo quema; no cumple expectativa CTO. | **No** |
| Modernizar Jenkins y quedarse | Equipo lo conoce; infra existente; CloudBees da HA. | Sigue siendo controller SPOF + plugin surface; no resuelve dolor crónico; cuesta persona-año y luego sigue costando. | **Parcial** (sí para los 0–6 meses, no como estado final) |
| Migrar a **GitLab CI** self-managed | SCM ya es GitLab; MRs + CI integrados; menos superficie que Jenkins; OIDC a cloud nativo. | Migración = persona-año; aprendizaje; readaptar Shared Libs. | **Sí**, como target de 24 meses |
| Migrar a **GitHub Enterprise Server** (GHES) | Mejor DX; marketplace. | Requiere migrar SCM también; coste de licencia GHES; justificar reemplazo de GitLab = proyecto aparte. | **No** (no toca el SCM) |
| Migrar a **Argo Workflows** | Nativo K8s. | Nordhaus no es K8s-first; CI de apps no es su caso; sumaría complejidad. | **No** (fuera de encaje) |
| **CloudBees CI** | HA real, soporte 24×7, auditoría enterprise. | Licencia cara; nos ata más a Jenkins en lugar de salir. | **Diferido** (solo si la migración se cancela y la CTO decide quedarse 5+ años) |

### 4. Framework de migración (aplicado al escenario)

1. **Inventario** (mes 0–2): script que enumera los 1.400 jobs, dueño actual, última ejecución, plugins requeridos, criticidad (0=nadie se queja, 3=incidente de negocio si cae), destino de deploy. Esperamos descubrir que 20–30% no se usan.
2. **Clasificación** (mes 2–3): cada job cae en `migrar`, `consolidar`, `retirar`. Decisión documentada por job con firma del equipo dueño.
3. **Dual-run** (mes 4–18): se migran olas de 50–100 jobs; durante 4 semanas corren en Jenkins **y** en GitLab CI con comparación de outputs y tiempos. Primero jobs de **bajo riesgo** (lint, builds de servicios de staging). Jobs **release-crítico** van en la ola 5+ cuando el equipo ya tiene confianza.
4. **OIDC federation** (mes 6+): reemplazar `withCredentials` + secretos de larga vida por **OIDC** desde GitLab CI a los clouds. Ganancia de seguridad neta, independiente de la plataforma.
5. **Retirada** (mes 20–24): cuando los jobs en Jenkins = 0 (o residuales con dueño identificado), apagamos. **Backup histórico** de logs y artefactos archivado para los 7 años de retención Solvency II. ADR final de cierre.

### 5. Fase A — modernización (0–6 meses, obligatoria)

Lo que **no** puede esperar a la migración:

- **Backup verificado**: restore drill mensual del `JENKINS_HOME`. Sin esto no se puede defender nada.
- **Plugin audit**: eliminar los 60 sin uso; pinnear versiones; habilitar feed de advisories.
- **Freeze de freestyle**: no se admiten jobs freestyle nuevos. Los existentes se migran a Declarative en la ola correspondiente.
- **Agents efímeros**: si no están, se introduce el **Kubernetes plugin** (o Docker) para romper contaminación entre builds.
- **Script approval**: inventario y limpieza; sandbox activado en todos los pipelines.
- **Pipeline estándar**: Shared Library con un `standardBuild()` versionado, para que las nuevas migraciones consuman el estándar y no copien-pegan.

### 6. Freestyle vs Pipeline

De los 1.400 jobs, los **560 freestyle** no se migran "tal cual" a GitLab CI. Primero se convierten a **Declarative Pipeline** (`Jenkinsfile` en el repo del código) en un refactor Jenkins-interno. Esto convierte el job en algo **leído desde el repo** y, por tanto, **migrable** a `.gitlab-ci.yml` directamente. Intentar migrar freestyle directo a GitLab es rehacer el trabajo dos veces.

### 7. Superficie CVE / plugins / sandbox

Jenkins acumuló 3 CVEs críticos en 12 meses, todos de plugins, parcheados tarde. El plan de modernización reduce la superficie: menos plugins, pinned, con feed activo. La migración a GitLab CI **elimina** esta superficie (GitLab tiene su propio ciclo de CVEs, pero sin la amplificación del plugin-ecosystem de Jenkins). **Groovy sandbox + script approval** quedan activos durante toda la fase A; ninguna excepción.

## Consecuencias

### Positivas

- Dolor operativo baja desde el mes 2 (modernización); confianza del equipo aumenta.
- A 24 meses, superficie de ataque reducida drásticamente (fin del plugin ecosystem).
- Un solo producto para SCM + CI (GitLab) → menos herramientas que operar.
- OIDC federation reemplaza secretos de larga vida en todo el flujo → ganancia neta de seguridad.
- Jobs retirados en inventario (~20–30%) nunca más consumen ciclos ni oscurecen el panorama.
- Cumple la expectativa de la CTO sin asumir riesgo de big-bang.

### Negativas

- Migración = **persona-año** de capacidad del equipo de plataforma durante ~18 meses. Hay que presupuestarlo.
- Dual-run **duplica cómputo** temporalmente (coste de agents durante la migración).
- Riesgo de que un pipeline crítico se migre con bug no detectado y rompa una release. **Mitigación**: olas con dual-run obligatorio ≥ 4 semanas, cutover solo con firma del equipo dueño.
- La fase A invierte en Jenkins algo que vamos a retirar; **justificado** porque sin estabilidad no se puede migrar nada.
- Dependencia de la **retención histórica**: logs y artefactos deben archivarse antes de apagar Jenkins. No trivial.

## Alternativas descartadas

### Alternativa A — Mantener Jenkins "as is" y añadir CloudBees

- Pros: HA, soporte enterprise, cero migración.
- Contras: la raíz del dolor (plugin surface, equipo rotando, snowflake) **no se resuelve** por pagar soporte. Coste recurrente alto que no mueve la organización hacia una plataforma más mantenible.
- **Por qué no**: optimiza el status quo en lugar de atacar la deuda.

### Alternativa B — Migrar todo a GitLab CI en 6 meses (big-bang)

- Pros: termina antes.
- Contras: historial estándar: 1.400 jobs no se migran limpiamente en 6 meses sin romper algo crítico. Riesgo inaceptable para release nocturnas de aseguradora.
- **Por qué no**: la lección empírica (`jk-08`) es que big-bang de CI falla casi siempre.

### Alternativa C — Fuera Jenkins y todo nuevo en GitLab CI; mantener Jenkins "congelado" para los jobs legacy

- Pros: menor coste de migración.
- Contras: "congelado" nunca es congelado; los jobs legacy siguen necesitando plugins actualizados por CVEs; termina siendo peor que ambos a la vez.
- **Por qué no**: pospone el problema en lugar de resolverlo.

### Alternativa D — Migrar a Argo Workflows (K8s-native)

- Pros: fin del controller monolítico.
- Contras: Nordhaus **no** es una org K8s-first; usar Argo para CI de apps "normales" es forzar la herramienta.
- **Por qué no**: fuera de encaje del escenario.

---

## Nota de implementación

- Los números concretos de coste (horas, USD/año) viven en la actividad `02-jenkins-cost-estimate` como ejercicio complementario. Este ADR cita el plan; la estimación financiera va aparte.
- El equipo de plataforma debe crecer de 2 → 3 personas durante los meses 6–18 para absorber la migración sin matar operaciones.
- Revisión del ADR obligatoria cada 6 meses contra métricas: jobs migrados, jobs retirados, incidentes imputables al cambio, horas invertidas vs plan.
